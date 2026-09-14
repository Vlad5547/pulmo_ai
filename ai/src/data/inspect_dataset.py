"""Inspect the local RSNA Pneumonia Detection Challenge dataset.

Read-only: the script never renames, moves, copies or modifies anything under
the dataset root, and it never loads pixel data. DICOM files are opened one at
a time with ``stop_before_pixels=True`` and a restricted tag list, so memory
stays flat regardless of the number of studies.

What it does
------------
1. parses the MD.ai annotation export and builds the label lookup table;
2. walks ``<dataset>/images`` recursively for ``*.dcm`` files;
3. reads the UIDs (and a few useful attributes) from every DICOM header;
4. joins annotations to files on SOPInstanceUID, validating Study/Series;
5. prints a statistics report;
6. writes lightweight mapping files (paths + UIDs + labels + boxes) to
   ``ai/data/processed/``.

Usage
-----
    python ai/src/data/inspect_dataset.py
    python ai/src/data/inspect_dataset.py --limit 500      # quick smoke run
    python ai/src/data/inspect_dataset.py --no-write       # report only
"""

from __future__ import annotations

import argparse
import csv
import json
import sys
import time
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from pathlib import Path

import pydicom
from pydicom.errors import InvalidDicomError

# Allow running the file directly: add ai/ to sys.path so `src.config` resolves.
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from src.config import (  # noqa: E402
    BOXES_CSV,
    CLASS_LUNG_OPACITY,
    CLASS_NORMAL,
    CLASS_NOT_NORMAL,
    GROUND_TRUTH_GROUP,
    MAPPING_CSV,
    SUMMARY_JSON,
    DatasetPaths,
    get_dataset_paths,
)

# Only these tags are pulled from each header — keeps the scan fast.
DICOM_TAGS = [
    "StudyInstanceUID",
    "SeriesInstanceUID",
    "SOPInstanceUID",
    "Modality",
    "BodyPartExamined",
    "ViewPosition",
    "Rows",
    "Columns",
    "PatientID",
    "PatientAge",
    "PatientSex",
]

UNMATCHED_CSV = "unmatched_annotations.csv"


# ---------------------------------------------------------------------------
# Annotations
# ---------------------------------------------------------------------------


@dataclass
class LabelInfo:
    label_id: str
    name: str
    group: str
    type: str  # "global" (image level) or "local" (drawn region)
    scope: str  # "instance" or "study"
    annotation_mode: str | None  # "bbox" or None


@dataclass
class Annotations:
    """Parsed MD.ai export."""

    project_name: str
    labels: dict[str, LabelInfo]
    label_group_names: list[str]
    studies: list[dict]
    annotations: list[dict]

    # derived, ground-truth group only
    class_by_sop: dict[str, str] = field(default_factory=dict)
    boxes_by_sop: dict[str, list[dict]] = field(default_factory=dict)
    sop_to_study: dict[str, str] = field(default_factory=dict)

    # every "group::label" seen for an image, across all reader groups; used to
    # explain images that the ground-truth group does not cover
    raw_labels_by_sop: dict[str, set[str]] = field(default_factory=dict)


def load_annotations(path: Path) -> Annotations:
    with path.open("r", encoding="utf-8") as handle:
        raw = json.load(handle)

    labels: dict[str, LabelInfo] = {}
    group_names: list[str] = []
    for group in raw.get("labelGroups", []):
        group_names.append(group.get("name", ""))
        for label in group.get("labels", []):
            labels[label["id"]] = LabelInfo(
                label_id=label["id"],
                # names in the export carry stray trailing spaces
                name=(label.get("name") or "").strip(),
                group=group.get("name", ""),
                type=label.get("type", ""),
                scope=label.get("scope", ""),
                annotation_mode=label.get("annotationMode"),
            )

    datasets = raw.get("datasets", [])
    studies: list[dict] = []
    annotations: list[dict] = []
    for dataset in datasets:
        studies.extend(dataset.get("studies", []))
        annotations.extend(dataset.get("annotations", []))

    parsed = Annotations(
        project_name=raw.get("name", ""),
        labels=labels,
        label_group_names=group_names,
        studies=studies,
        annotations=annotations,
    )
    _derive_ground_truth(parsed)
    return parsed


def _derive_ground_truth(parsed: Annotations) -> None:
    """Collapse the ground-truth label group into per-image class + boxes."""
    for ann in parsed.annotations:
        label = parsed.labels.get(ann.get("labelId"))
        if label is None:
            continue
        sop = ann.get("SOPInstanceUID")
        if not sop:
            continue
        parsed.raw_labels_by_sop.setdefault(sop, set()).add(
            f"{label.group}::{label.name}"
        )
        if label.group != GROUND_TRUTH_GROUP:
            continue
        parsed.sop_to_study[sop] = ann.get("StudyInstanceUID", "")
        parsed.class_by_sop[sop] = label.name
        data = ann.get("data")
        if label.annotation_mode == "bbox" and isinstance(data, dict):
            parsed.boxes_by_sop.setdefault(sop, []).append(
                {
                    "x": data.get("x"),
                    "y": data.get("y"),
                    "width": data.get("width"),
                    "height": data.get("height"),
                    "ref_width": ann.get("width"),
                    "ref_height": ann.get("height"),
                    "annotation_number": ann.get("annotationNumber"),
                    "label_name": label.name,
                    "annotation_id": ann.get("id"),
                }
            )


# ---------------------------------------------------------------------------
# DICOM scan
# ---------------------------------------------------------------------------


@dataclass
class DicomRecord:
    path: Path
    relative_path: str
    study_uid: str
    series_uid: str
    sop_uid: str
    modality: str
    body_part: str
    view_position: str
    rows: int | None
    columns: int | None
    patient_id: str
    patient_age: str
    patient_sex: str
    transfer_syntax: str
    dir_study_uid: str
    dir_series_uid: str
    file_stem_uid: str

    @property
    def path_matches_header(self) -> bool:
        return (
            self.dir_study_uid == self.study_uid
            and self.dir_series_uid == self.series_uid
            and self.file_stem_uid == self.sop_uid
        )


def iter_dicom_files(images_dir: Path, limit: int | None = None):
    count = 0
    for path in images_dir.rglob("*.dcm"):
        yield path
        count += 1
        if limit is not None and count >= limit:
            return


def read_dicom_record(path: Path, images_dir: Path) -> DicomRecord | None:
    """Read one header. Returns None if the file cannot be parsed."""
    try:
        ds = pydicom.dcmread(
            str(path), stop_before_pixels=True, specific_tags=DICOM_TAGS
        )
    except (InvalidDicomError, OSError, AttributeError):
        return None

    def value(tag: str, default: str = "") -> str:
        raw = getattr(ds, tag, None)
        return default if raw is None else str(raw)

    return DicomRecord(
        path=path,
        relative_path=str(path.relative_to(images_dir)),
        study_uid=value("StudyInstanceUID"),
        series_uid=value("SeriesInstanceUID"),
        sop_uid=value("SOPInstanceUID"),
        modality=value("Modality"),
        body_part=value("BodyPartExamined"),
        view_position=value("ViewPosition"),
        rows=getattr(ds, "Rows", None),
        columns=getattr(ds, "Columns", None),
        patient_id=value("PatientID"),
        patient_age=value("PatientAge"),
        patient_sex=value("PatientSex"),
        transfer_syntax=str(
            getattr(getattr(ds, "file_meta", None), "TransferSyntaxUID", "")
        ),
        dir_study_uid=path.parent.parent.name,
        dir_series_uid=path.parent.name,
        file_stem_uid=path.stem,
    )


# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------


def human(number: int) -> str:
    return f"{number:,}".replace(",", " ")


def section(title: str) -> None:
    print()
    print(title)
    print("-" * len(title))


def describe_annotations(ann: Annotations) -> None:
    section("1. Annotation file structure")
    print(f"  project           : {ann.project_name}")
    print(f"  label groups      : {len(ann.label_group_names)} "
          f"({', '.join(ann.label_group_names)})")
    print(f"  labels            : {len(ann.labels)}")
    print(f"  studies listed    : {human(len(ann.studies))}")
    print(f"  annotations       : {human(len(ann.annotations))}")

    with_sop = sum(1 for a in ann.annotations if a.get("SOPInstanceUID"))
    with_box = sum(1 for a in ann.annotations if isinstance(a.get("data"), dict))
    print(f"  with SOPInstanceUID: {human(with_sop)} "
          f"({human(len(ann.annotations) - with_sop)} are study-scope only)")
    print(f"  with bbox data     : {human(with_box)}")

    section("2. Annotations per label group / label")
    per_label: Counter[tuple[str, str]] = Counter()
    per_label_boxes: Counter[tuple[str, str]] = Counter()
    for a in ann.annotations:
        label = ann.labels.get(a.get("labelId"))
        if label is None:
            continue
        key = (label.group, label.name)
        per_label[key] += 1
        if isinstance(a.get("data"), dict):
            per_label_boxes[key] += 1
    for (group, name), total in sorted(per_label.items()):
        marker = " <- ground truth" if group == GROUND_TRUTH_GROUP else ""
        print(f"  {group:<14} {name:<30} {human(total):>7}"
              f"  boxes={human(per_label_boxes[(group, name)]):>7}{marker}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--limit", type=int, default=None,
        help="only scan the first N DICOM files (smoke run)",
    )
    parser.add_argument(
        "--no-write", action="store_true",
        help="print the report without writing mapping files",
    )
    parser.add_argument(
        "--out", type=Path, default=None,
        help="override the output directory (default: ai/data/processed)",
    )
    args = parser.parse_args()

    paths: DatasetPaths = get_dataset_paths()
    paths.validate()
    out_dir = args.out or paths.processed_dir

    print("PulmoAI - dataset inspection (read-only)")
    print(f"  dataset root : {paths.root}")
    print(f"  images       : {paths.images_dir}")
    print(f"  annotations  : {paths.annotations_file.name} "
          f"({paths.annotations_file.stat().st_size / 1e6:.1f} MB)")

    started = time.time()
    ann = load_annotations(paths.annotations_file)
    describe_annotations(ann)

    # ---- scan DICOM ------------------------------------------------------
    section("3. DICOM scan")
    records: list[DicomRecord] = []
    unreadable: list[str] = []
    layout_mismatch: list[str] = []
    duplicate_sop: list[str] = []
    seen_sop: set[str] = set()

    scanned = 0
    for path in iter_dicom_files(paths.images_dir, args.limit):
        scanned += 1
        record = read_dicom_record(path, paths.images_dir)
        if record is None:
            unreadable.append(str(path))
            continue
        if not record.path_matches_header:
            layout_mismatch.append(record.relative_path)
        if record.sop_uid in seen_sop:
            duplicate_sop.append(record.sop_uid)
        seen_sop.add(record.sop_uid)
        records.append(record)
        if scanned % 2500 == 0:
            print(f"  ... {human(scanned)} files "
                  f"({time.time() - started:.0f}s)", flush=True)

    print(f"  DICOM files found          : {human(scanned)}")
    print(f"  headers read successfully  : {human(len(records))}")
    print(f"  unreadable files           : {human(len(unreadable))}")
    print(f"  path/header UID mismatches : {human(len(layout_mismatch))}")
    print(f"  duplicate SOPInstanceUID   : {human(len(duplicate_sop))}")
    print(f"  unique StudyInstanceUID    : "
          f"{human(len({r.study_uid for r in records}))}")
    print(f"  unique SeriesInstanceUID   : "
          f"{human(len({r.series_uid for r in records}))}")

    modality = Counter(r.modality for r in records)
    view = Counter(r.view_position or "<empty>" for r in records)
    size = Counter(f"{r.rows}x{r.columns}" for r in records)
    print(f"  modality                   : {dict(modality)}")
    print(f"  view position              : {dict(view)}")
    print(f"  image size                 : {dict(size.most_common(5))}")
    print(f"  transfer syntax            : "
          f"{dict(Counter(r.transfer_syntax for r in records))}")

    # ---- join ------------------------------------------------------------
    section("4. Annotation <-> DICOM matching (key: SOPInstanceUID)")
    matched: list[tuple[DicomRecord, str]] = []
    unmatched_files: list[DicomRecord] = []
    for record in records:
        label = ann.class_by_sop.get(record.sop_uid)
        if label is None:
            unmatched_files.append(record)
        else:
            matched.append((record, label))

    dicom_sops = {r.sop_uid for r in records}
    gt_sops = set(ann.class_by_sop)
    unmatched_annotation_sops = sorted(gt_sops - dicom_sops)

    # study-level consistency of the join
    study_conflicts = sum(
        1 for record, _ in matched
        if ann.sop_to_study.get(record.sop_uid) not in ("", record.study_uid)
    )

    class_counts = Counter(label for _, label in matched)
    box_total = sum(
        len(ann.boxes_by_sop.get(r.sop_uid, [])) for r, _ in matched
    )
    boxes_per_image = Counter(
        len(ann.boxes_by_sop.get(r.sop_uid, []))
        for r, label in matched if label == CLASS_LUNG_OPACITY
    )

    print(f"  DICOM matched to an annotation : {human(len(matched))}")
    print(f"  DICOM without annotation       : {human(len(unmatched_files))}")
    print(f"  annotations without DICOM      : "
          f"{human(len(unmatched_annotation_sops))}")
    print(f"  Study UID conflicts in join    : {human(study_conflicts)}")

    if unmatched_files:
        print("\n  Why images fall outside the ground-truth group "
              "(raw reader labels):")
        reasons: Counter[str] = Counter()
        for record in unmatched_files:
            raw = ann.raw_labels_by_sop.get(record.sop_uid)
            if not raw:
                reasons["<no annotation at all>"] += 1
            elif any("Exclude" in item for item in raw):
                reasons["Exclude (dropped by a reader)"] += 1
            else:
                reasons["annotated by readers, no adjudicated label"] += 1
        for reason, total in reasons.most_common():
            print(f"    {reason:<45} {human(total):>7}")

    section("5. Ground-truth class distribution (label group "
            f"'{GROUND_TRUTH_GROUP}')")
    for name in (CLASS_LUNG_OPACITY, CLASS_NORMAL, CLASS_NOT_NORMAL):
        share = 100 * class_counts[name] / max(len(matched), 1)
        print(f"  {name:<30} {human(class_counts[name]):>7}  ({share:5.2f}%)")
    other = {k: v for k, v in class_counts.items()
             if k not in (CLASS_LUNG_OPACITY, CLASS_NORMAL, CLASS_NOT_NORMAL)}
    if other:
        print(f"  other classes                  : {other}")
    print(f"  bounding boxes total           : {human(box_total)}")
    print(f"  boxes per positive image       : "
          f"{dict(sorted(boxes_per_image.items()))}")

    # ---- write -----------------------------------------------------------
    written: list[Path] = []
    if not args.no_write:
        section("6. Output")
        out_dir.mkdir(parents=True, exist_ok=True)
        written.append(_write_mapping(out_dir, matched, unmatched_files, ann))
        written.append(_write_boxes(out_dir, matched, ann))
        written.append(_write_unmatched(out_dir, unmatched_annotation_sops, ann))
        written.append(
            _write_summary(
                out_dir=out_dir,
                paths=paths,
                ann=ann,
                scanned=scanned,
                records=records,
                matched=matched,
                unmatched_files=unmatched_files,
                unmatched_annotation_sops=unmatched_annotation_sops,
                class_counts=class_counts,
                box_total=box_total,
                unreadable=unreadable,
                layout_mismatch=layout_mismatch,
                duplicate_sop=duplicate_sop,
                elapsed=time.time() - started,
            )
        )
        for path in written:
            print(f"  wrote {path}  "
                  f"({path.stat().st_size / 1024:.0f} KB)")

    print(f"\nDone in {time.time() - started:.1f}s. "
          "No dataset file was modified.")
    return 0


# ---------------------------------------------------------------------------
# Writers
# ---------------------------------------------------------------------------


def _write_mapping(
    out_dir: Path,
    matched: list[tuple[DicomRecord, str]],
    unmatched_files: list[DicomRecord],
    ann: Annotations,
) -> Path:
    path = out_dir / MAPPING_CSV
    columns = [
        "sop_instance_uid", "study_instance_uid", "series_instance_uid",
        "relative_path", "class_label", "target", "num_boxes", "matched",
        "modality", "body_part", "view_position", "rows", "columns",
        "patient_id", "patient_age", "patient_sex", "transfer_syntax",
        "raw_reader_labels",
    ]
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(columns)
        rows = [(r, label) for r, label in matched]
        rows += [(r, "") for r in unmatched_files]
        for record, label in rows:
            boxes = ann.boxes_by_sop.get(record.sop_uid, [])
            writer.writerow([
                record.sop_uid,
                record.study_uid,
                record.series_uid,
                record.relative_path,
                label,
                1 if label == CLASS_LUNG_OPACITY else 0,
                len(boxes),
                int(bool(label)),
                record.modality,
                record.body_part,
                record.view_position,
                record.rows,
                record.columns,
                record.patient_id,
                record.patient_age,
                record.patient_sex,
                record.transfer_syntax,
                "" if label else ";".join(
                    sorted(ann.raw_labels_by_sop.get(record.sop_uid, ()))
                ),
            ])
    return path


def _write_boxes(
    out_dir: Path,
    matched: list[tuple[DicomRecord, str]],
    ann: Annotations,
) -> Path:
    path = out_dir / BOXES_CSV
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow([
            "sop_instance_uid", "study_instance_uid", "relative_path",
            "annotation_id", "annotation_number", "label_name",
            "x", "y", "width", "height",
            "ref_width", "ref_height", "dicom_columns", "dicom_rows",
        ])
        for record, _ in matched:
            for box in ann.boxes_by_sop.get(record.sop_uid, []):
                writer.writerow([
                    record.sop_uid,
                    record.study_uid,
                    record.relative_path,
                    box["annotation_id"],
                    box["annotation_number"],
                    box["label_name"],
                    box["x"], box["y"], box["width"], box["height"],
                    box["ref_width"], box["ref_height"],
                    record.columns, record.rows,
                ])
    return path


def _write_unmatched(
    out_dir: Path, unmatched_sops: list[str], ann: Annotations
) -> Path:
    path = out_dir / UNMATCHED_CSV
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow([
            "sop_instance_uid", "study_instance_uid", "class_label", "num_boxes",
        ])
        for sop in unmatched_sops:
            writer.writerow([
                sop,
                ann.sop_to_study.get(sop, ""),
                ann.class_by_sop.get(sop, ""),
                len(ann.boxes_by_sop.get(sop, [])),
            ])
    return path


def _write_summary(**kw) -> Path:
    out_dir: Path = kw["out_dir"]
    paths: DatasetPaths = kw["paths"]
    ann: Annotations = kw["ann"]
    records: list[DicomRecord] = kw["records"]
    matched = kw["matched"]
    class_counts: Counter = kw["class_counts"]

    per_group: dict[str, dict[str, int]] = defaultdict(dict)
    counter: Counter[tuple[str, str]] = Counter()
    for a in ann.annotations:
        label = ann.labels.get(a.get("labelId"))
        if label:
            counter[(label.group, label.name)] += 1
    for (group, name), total in counter.items():
        per_group[group][name] = total

    summary = {
        "generated_at": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "elapsed_seconds": round(kw["elapsed"], 1),
        "dataset_root": str(paths.root),
        "images_dir": str(paths.images_dir),
        "annotations_file": str(paths.annotations_file),
        "ground_truth_label_group": GROUND_TRUTH_GROUP,
        "annotation_file": {
            "project_name": ann.project_name,
            "label_groups": ann.label_group_names,
            "labels": len(ann.labels),
            "studies_listed": len(ann.studies),
            "annotations_total": len(ann.annotations),
            "annotations_per_group": per_group,
        },
        "dicom": {
            "files_found": kw["scanned"],
            "headers_read": len(records),
            "unreadable": len(kw["unreadable"]),
            "unique_studies": len({r.study_uid for r in records}),
            "unique_series": len({r.series_uid for r in records}),
            "path_header_mismatches": len(kw["layout_mismatch"]),
            "duplicate_sop_instance_uids": len(kw["duplicate_sop"]),
        },
        "matching": {
            "key": "SOPInstanceUID",
            "dicom_matched": len(matched),
            "dicom_unmatched": len(kw["unmatched_files"]),
            "annotations_unmatched": len(kw["unmatched_annotation_sops"]),
        },
        "classes": {
            CLASS_LUNG_OPACITY: class_counts[CLASS_LUNG_OPACITY],
            CLASS_NORMAL: class_counts[CLASS_NORMAL],
            CLASS_NOT_NORMAL: class_counts[CLASS_NOT_NORMAL],
        },
        "bounding_boxes_total": kw["box_total"],
        "examples": {
            "unreadable_files": kw["unreadable"][:10],
            "path_header_mismatches": kw["layout_mismatch"][:10],
        },
    }
    path = out_dir / SUMMARY_JSON
    path.write_text(json.dumps(summary, indent=2), encoding="utf-8")
    return path


if __name__ == "__main__":
    raise SystemExit(main())
