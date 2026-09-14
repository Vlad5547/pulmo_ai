"""End-to-end smoke test of the PulmoAI data pipeline, in one command.

    ai\\.venv\\Scripts\\python.exe ai\\src\\data\\smoke_test.py

Covers: config/paths -> mapping & split artefacts -> patient overlap ->
raw DICOM read -> photometric handling -> preprocessing -> Dataset ->
DataLoader. Only a handful of images are decoded (``--samples`` per class,
``--batches`` batches), so the run takes seconds and never holds more than one
image at a time. The dataset itself is opened read-only.

Exit code 0 = every stage passed.
"""

from __future__ import annotations

import argparse
import sys
import tracemalloc
from pathlib import Path

import numpy as np
import pandas as pd
import pydicom
import torch

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from src.config import (  # noqa: E402
    BOXES_CSV,
    CLASS_LUNG_OPACITY,
    CLASS_NORMAL,
    CLASS_NOT_NORMAL,
    MAPPING_CSV,
    SPLIT_CSV,
    get_dataset_paths,
    get_preprocess_config,
    get_split_config,
)
from src.data.dataset import (  # noqa: E402
    SPLIT_NAMES,
    RsnaPneumoniaDataset,
    build_dataloader,
)
from src.data.preprocessing import dicom_to_float_tensor  # noqa: E402

CLASSES = (CLASS_LUNG_OPACITY, CLASS_NORMAL, CLASS_NOT_NORMAL)


class Report:
    """Collects check results so one failure does not hide the rest."""

    def __init__(self) -> None:
        self.passed = 0
        self.failed: list[str] = []

    def check(self, condition: bool, description: str, detail: str = "") -> bool:
        if condition:
            self.passed += 1
            print(f"    [ok]   {description}" + (f"  ({detail})" if detail else ""))
        else:
            self.failed.append(description)
            print(f"    [FAIL] {description}" + (f"  ({detail})" if detail else ""))
        return condition

    def stage(self, title: str) -> None:
        print(f"\n{title}")
        print("-" * len(title))


def stage_paths(report: Report):
    report.stage("1. Configuration and dataset paths")
    paths = get_dataset_paths()
    paths.validate()
    print(f"    dataset root : {paths.root}")
    print(f"    images       : {paths.images_dir}")
    print(f"    annotations  : {paths.annotations_file.name}")
    print(f"    processed    : {paths.processed_dir}")

    preprocess = get_preprocess_config()
    split_config = get_split_config()
    print(f"    image_size={preprocess.image_size} "
          f"channels={preprocess.channels} seed={split_config.seed} "
          f"ratios={split_config.train_ratio}/{split_config.val_ratio}/"
          f"{split_config.test_ratio}")

    for name in (MAPPING_CSV, BOXES_CSV, SPLIT_CSV):
        report.check(
            (paths.processed_dir / name).is_file(),
            f"{name} exists",
            f"{(paths.processed_dir / name).stat().st_size / 1e6:.1f} MB"
            if (paths.processed_dir / name).is_file() else "missing",
        )
    return paths, preprocess


def stage_split(report: Report, paths) -> pd.DataFrame:
    report.stage("2. Split statistics")
    split = pd.read_csv(paths.processed_dir / SPLIT_CSV)
    mapping = pd.read_csv(paths.processed_dir / MAPPING_CSV)
    usable = int((mapping["matched"] == 1).sum())

    header = (f"    {'split':<7}{'images':>9}{'patients':>10}{'positive':>10}"
              f"{'negative':>10}{'pos rate':>10}")
    print(header)
    print("    " + "-" * (len(header) - 4))
    total = 0
    for name in SPLIT_NAMES:
        part = split[split["split"] == name]
        positives = int(part["target"].sum())
        total += len(part)
        print(f"    {name:<7}{len(part):>9,}{part['patient_id'].nunique():>10,}"
              f"{positives:>10,}{len(part) - positives:>10,}"
              f"{positives / max(len(part), 1):>10.4f}".replace(",", " "))

    report.check(total == len(split), "every row has a known split")
    report.check(total == usable,
                 "split covers exactly the labelled images",
                 f"{total} vs {usable} usable in mapping")
    report.check(
        split["sop_instance_uid"].nunique() == len(split),
        "no duplicated image in the split file",
    )
    excluded = len(mapping) - usable
    report.check(excluded == 316,
                 "unlabelled images stay out of the split", f"{excluded} excluded")
    return split


def stage_overlap(report: Report, split: pd.DataFrame) -> None:
    report.stage("3. Patient overlap between splits")
    patients = {
        name: set(split.loc[split["split"] == name, "patient_id"])
        for name in SPLIT_NAMES
    }
    images = {
        name: set(split.loc[split["split"] == name, "sop_instance_uid"])
        for name in SPLIT_NAMES
    }
    pairs = (("train", "val"), ("train", "test"), ("val", "test"))
    for a, b in pairs:
        shared = patients[a] & patients[b]
        report.check(not shared, f"patients {a} & {b} = 0",
                     f"{len(shared)} shared" if shared else "")
    for a, b in pairs:
        shared = images[a] & images[b]
        report.check(not shared, f"images {a} & {b} = 0",
                     f"{len(shared)} shared" if shared else "")
    report.check(
        sum(len(p) for p in patients.values())
        == len(set().union(*patients.values())),
        "patient sets are mutually disjoint overall",
    )


def stage_samples(report: Report, paths, preprocess, per_class: int) -> None:
    report.stage(f"4. Real samples ({per_class} per class, decoded one by one)")
    dataset = RsnaPneumoniaDataset(split=None, train_mode=False)
    boxes_csv = pd.read_csv(paths.processed_dir / BOXES_CSV)
    size = preprocess.image_size

    for class_name in CLASSES:
        indices = dataset.frame.index[
            dataset.frame["class_label"] == class_name
        ][:per_class].tolist()
        print(f"\n  {class_name}  ({len(indices)} checked)")
        report.check(bool(indices), f"{class_name}: samples available")

        for index in indices:
            row = dataset.frame.loc[index]
            sop = str(row["sop_instance_uid"])
            short = sop.rsplit(".", 1)[-1]
            dicom_path = paths.images_dir / str(row["relative_path"])

            # --- raw DICOM -------------------------------------------------
            ds = pydicom.dcmread(str(dicom_path))
            array = ds.pixel_array
            photometric = str(ds.PhotometricInterpretation)
            report.check(
                array.ndim == 2 and array.dtype == np.uint8,
                f"...{short}: pixel_array decoded",
                f"{array.shape} {array.dtype} "
                f"[{array.min()}..{array.max()}] {photometric} "
                f"{ds.file_meta.TransferSyntaxUID.name}",
            )

            # --- photometric handling --------------------------------------
            as_mono2 = dicom_to_float_tensor(array, "MONOCHROME2", 8)
            as_mono1 = dicom_to_float_tensor(array, "MONOCHROME1", 8)
            report.check(
                torch.allclose(as_mono1, 1.0 - as_mono2, atol=1e-6),
                f"...{short}: MONOCHROME1 is the inverse of MONOCHROME2",
            )
            report.check(
                float(as_mono2.min()) >= 0.0 and float(as_mono2.max()) <= 1.0,
                f"...{short}: float image in [0, 1]",
                f"min={float(as_mono2.min()):.3f} max={float(as_mono2.max()):.3f}",
            )

            # --- through the Dataset ---------------------------------------
            sample = dataset[index]
            image, label = sample["image"], sample["label"]
            report.check(
                image.shape == (preprocess.channels, size, size)
                and image.dtype == torch.float32
                and bool(torch.isfinite(image).all()),
                f"...{short}: tensor shape/dtype",
                f"{tuple(image.shape)} {image.dtype} "
                f"mean={float(image.mean()):.3f} std={float(image.std()):.3f}",
            )
            expected = 1.0 if class_name == CLASS_LUNG_OPACITY else 0.0
            report.check(
                float(label) == expected and label.dtype == torch.float32,
                f"...{short}: label = {expected}",
                f"class='{sample['class_label']}'",
            )

            # --- boxes ------------------------------------------------------
            boxes = sample["boxes"]
            expected_boxes = int(
                (boxes_csv["sop_instance_uid"] == sop).sum()
            )
            report.check(
                len(boxes) == expected_boxes,
                f"...{short}: {expected_boxes} box(es) as in bounding_boxes.csv",
            )
            if class_name == CLASS_LUNG_OPACITY:
                report.check(len(boxes) >= 1,
                             f"...{short}: positive sample has boxes")
                report.check(
                    bool((boxes >= 0).all() and (boxes <= size).all()),
                    f"...{short}: boxes inside the {size}x{size} frame",
                    f"x[{float(boxes[:, 0].min()):.1f}..{float(boxes[:, 2].max()):.1f}] "
                    f"y[{float(boxes[:, 1].min()):.1f}..{float(boxes[:, 3].max()):.1f}]",
                )
                report.check(
                    bool((boxes[:, 2] > boxes[:, 0]).all()
                         and (boxes[:, 3] > boxes[:, 1]).all()),
                    f"...{short}: boxes are valid xyxy (x2>x1, y2>y1)",
                )
                normalized = sample["boxes_normalized"]
                report.check(
                    bool((normalized >= 0).all() and (normalized <= 1).all()),
                    f"...{short}: normalised boxes in 0..1",
                    f"{[round(v, 3) for v in normalized[0].tolist()]}",
                )
                # scaling must be consistent with the original 1024 frame
                original = boxes_csv[boxes_csv["sop_instance_uid"] == sop].iloc[0]
                scale = size / float(original["dicom_columns"])
                report.check(
                    abs(float(boxes[0, 0]) - original["x"] * scale) < 1e-3,
                    f"...{short}: box scaled by {scale:.4f} from the 1024 frame",
                )
            else:
                report.check(len(boxes) == 0,
                             f"...{short}: negative sample carries no box")


def stage_dataloader(report: Report, preprocess, batches: int, batch_size: int) -> None:
    report.stage(f"5. DataLoader ({batches} batches x {batch_size})")
    dataset = RsnaPneumoniaDataset(split="train", train_mode=True, seed=0)
    loader = build_dataloader(
        dataset, batch_size=batch_size, shuffle=True, num_workers=0
    )
    size = preprocess.image_size

    tracemalloc.start()
    seen_positive = False
    varying_counts = False
    iterator = iter(loader)
    for step in range(batches):
        batch = next(iterator)
        images, labels = batch["image"], batch["label"]
        counts = [len(b) for b in batch["boxes"]]
        positives = int(labels.sum())

        report.check(
            images.shape == (batch_size, preprocess.channels, size, size)
            and images.dtype == torch.float32,
            f"batch {step}: images {tuple(images.shape)} {images.dtype}",
        )
        report.check(
            labels.shape == (batch_size,) and labels.dtype == torch.float32
            and bool(((labels == 0) | (labels == 1)).all()),
            f"batch {step}: labels {tuple(labels.shape)}",
            f"{positives} positive / {batch_size - positives} negative",
        )
        report.check(
            isinstance(batch["boxes"], list) and len(batch["boxes"]) == batch_size,
            f"batch {step}: collate kept boxes per image",
            f"box counts {counts}",
        )
        for label, boxes in zip(labels.tolist(), batch["boxes"]):
            if label == 1.0 and len(boxes) == 0:
                report.check(False, f"batch {step}: a positive sample lost its boxes")
                break
            if label == 0.0 and len(boxes) > 0:
                report.check(False, f"batch {step}: a negative sample gained boxes")
                break
        else:
            report.check(True, f"batch {step}: boxes match the labels")

        seen_positive |= positives > 0
        varying_counts |= len(set(counts)) > 1

    current, peak = tracemalloc.get_traced_memory()
    tracemalloc.stop()

    report.check(seen_positive, "positive samples appeared in the batches")
    report.check(
        varying_counts,
        "collate handled a varying number of boxes within one batch",
    )
    report.check(
        peak / 1e6 < 400,
        "python-level memory stayed flat while iterating",
        f"peak {peak / 1e6:.0f} MB, current {current / 1e6:.0f} MB",
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--samples", type=int, default=3,
                        help="samples decoded per class (default 3)")
    parser.add_argument("--batches", type=int, default=3)
    parser.add_argument("--batch-size", type=int, default=8)
    args = parser.parse_args()

    if hasattr(sys.stdout, "reconfigure"):  # keep non-ASCII safe on cp1251 consoles
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    print("PulmoAI - data pipeline smoke test (read-only)")
    report = Report()
    paths, preprocess = stage_paths(report)
    split = stage_split(report, paths)
    stage_overlap(report, split)
    stage_samples(report, paths, preprocess, args.samples)
    stage_dataloader(report, preprocess, args.batches, args.batch_size)

    total = report.passed + len(report.failed)
    print(f"\n{'=' * 60}")
    print(f"{report.passed}/{total} checks passed")
    if report.failed:
        print("\nFailed:")
        for item in report.failed:
            print(f"  - {item}")
    print("No dataset file was modified.")
    return 1 if report.failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
