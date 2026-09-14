"""Create a reproducible, patient-grouped, stratified train/val/test split.

Why grouped by patient
----------------------
Two radiographs of the same patient are highly correlated: the same anatomy,
the same devices, often the same episode of illness. If one lands in train and
the other in validation, the model can recognise the patient instead of the
disease and the validation score becomes optimistic. Grouping by patient makes
every split contain disjoint patients.

In this particular export ``PatientID`` is 1:1 with ``StudyInstanceUID``
(30 000 unique IDs for 30 000 images), so grouping currently changes nothing —
but it is applied anyway, so the split stays correct if the dataset is ever
extended with follow-up studies.

Why stratified
--------------
Positives are only ~24 % of the data. Random splitting would let the positive
rate drift between splits and make metrics hard to compare, so patients are
bucketed by their label before being dealt out.

Usage
-----
    python ai/src/data/split_dataset.py
    python ai/src/data/split_dataset.py --seed 7 --train 0.8 --val 0.1 --test 0.1
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from collections import Counter
from pathlib import Path

import numpy as np
import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from src.config import (  # noqa: E402
    CLASS_LUNG_OPACITY,
    MAPPING_CSV,
    SPLIT_CSV,
    SPLIT_SUMMARY_JSON,
    SplitConfig,
    get_dataset_paths,
    get_split_config,
)

SPLIT_NAMES = ("train", "val", "test")


def load_labelled_mapping(processed_dir: Path) -> pd.DataFrame:
    path = processed_dir / MAPPING_CSV
    if not path.is_file():
        raise FileNotFoundError(
            f"{path} not found — run ai/src/data/inspect_dataset.py first."
        )
    frame = pd.read_csv(path)
    total = len(frame)
    labelled = frame[frame["matched"] == 1].copy()
    labelled["target"] = (labelled["class_label"] == CLASS_LUNG_OPACITY).astype(int)
    print(f"  mapping rows            : {total:,}".replace(",", " "))
    print(f"  dropped (no adjudicated label): "
          f"{total - len(labelled):,}".replace(",", " "))
    print(f"  usable images           : {len(labelled):,}".replace(",", " "))
    return labelled


def make_split(frame: pd.DataFrame, config: SplitConfig) -> pd.DataFrame:
    """Assign every row a split, grouping by patient and stratifying by label.

    A patient's stratum is the maximum of that patient's labels: if any of the
    patient's images shows opacity, the whole patient counts as positive, so a
    positive patient never gets split across sets.
    """
    config.validate()
    group_col = config.group_column
    if group_col not in frame.columns:
        raise KeyError(
            f"Column '{group_col}' is missing from the mapping. "
            "Patient-level splitting needs a real patient identifier — "
            "re-run inspect_dataset.py, which reads PatientID from the DICOM "
            "headers."
        )
    if frame[group_col].isna().any():
        raise ValueError(f"Column '{group_col}' contains empty values.")

    patients = (
        frame.groupby(group_col)[config.stratify_column]
        .max()
        .reset_index()
        .rename(columns={config.stratify_column: "stratum"})
    )

    rng = np.random.default_rng(config.seed)
    assignment: dict[str, str] = {}

    for stratum, bucket in patients.groupby("stratum"):
        ids = bucket[group_col].to_numpy()
        # sort first, so the shuffle depends only on the seed and not on the
        # row order produced by pandas
        ids = np.sort(ids)
        rng.shuffle(ids)

        n = len(ids)
        n_train = int(round(n * config.train_ratio))
        n_val = int(round(n * config.val_ratio))
        n_train = min(n_train, n)
        n_val = min(n_val, n - n_train)

        for patient in ids[:n_train]:
            assignment[patient] = "train"
        for patient in ids[n_train:n_train + n_val]:
            assignment[patient] = "val"
        for patient in ids[n_train + n_val:]:
            assignment[patient] = "test"
        print(f"  stratum {stratum}: {n:,} patients -> "
              f"train {n_train:,} / val {n_val:,} / "
              f"test {n - n_train - n_val:,}".replace(",", " "))

    result = frame[[
        "sop_instance_uid", "study_instance_uid", group_col,
        "class_label", "target", "num_boxes", "relative_path",
    ]].copy()
    result["split"] = result[group_col].map(assignment)
    if result["split"].isna().any():
        raise RuntimeError("Some rows were not assigned to a split")
    return result


def verify_no_leakage(split: pd.DataFrame, group_col: str) -> list[str]:
    """Return the patients that appear in more than one split (must be empty)."""
    per_patient = split.groupby(group_col)["split"].nunique()
    return sorted(per_patient[per_patient > 1].index.tolist())


def summarise(split: pd.DataFrame, group_col: str) -> dict:
    summary: dict[str, dict] = {}
    total = len(split)
    for name in SPLIT_NAMES:
        part = split[split["split"] == name]
        positives = int(part["target"].sum())
        summary[name] = {
            "images": len(part),
            "patients": int(part[group_col].nunique()),
            "positive": positives,
            "negative": len(part) - positives,
            "positive_rate": round(positives / max(len(part), 1), 4),
            "share_of_dataset": round(len(part) / max(total, 1), 4),
            "boxes": int(part["num_boxes"].sum()),
            "classes": Counter(part["class_label"]),
        }
    return summary


def print_summary(summary: dict) -> None:
    header = (f"{'split':<6}{'images':>9}{'patients':>10}{'positive':>10}"
              f"{'negative':>10}{'pos rate':>10}{'boxes':>9}")
    print(header)
    print("-" * len(header))
    for name in SPLIT_NAMES:
        s = summary[name]
        print(f"{name:<6}{s['images']:>9,}{s['patients']:>10,}"
              f"{s['positive']:>10,}{s['negative']:>10,}"
              f"{s['positive_rate']:>10.4f}{s['boxes']:>9,}".replace(",", " "))
    print()
    for name in SPLIT_NAMES:
        classes = summary[name]["classes"]
        print(f"  {name:<6} " + "  ".join(
            f"{label}: {count:,}".replace(",", " ")
            for label, count in sorted(classes.items())
        ))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seed", type=int, default=None)
    parser.add_argument("--train", type=float, default=None)
    parser.add_argument("--val", type=float, default=None)
    parser.add_argument("--test", type=float, default=None)
    parser.add_argument("--out", type=Path, default=None)
    parser.add_argument("--no-write", action="store_true")
    args = parser.parse_args()

    base = get_split_config()
    config = SplitConfig(
        train_ratio=args.train if args.train is not None else base.train_ratio,
        val_ratio=args.val if args.val is not None else base.val_ratio,
        test_ratio=args.test if args.test is not None else base.test_ratio,
        seed=args.seed if args.seed is not None else base.seed,
    )
    config.validate()

    paths = get_dataset_paths()
    out_dir = args.out or paths.processed_dir

    print("PulmoAI - patient-grouped stratified split")
    print(f"  ratios : train {config.train_ratio} / val {config.val_ratio} "
          f"/ test {config.test_ratio}")
    print(f"  seed   : {config.seed}")
    print(f"  group  : {config.group_column} (stratified by "
          f"{config.stratify_column})\n")

    frame = load_labelled_mapping(paths.processed_dir)
    print()
    split = make_split(frame, config)

    leaked = verify_no_leakage(split, config.group_column)
    print(f"\n  patients in more than one split: {len(leaked)}")
    if leaked:
        raise RuntimeError(f"Patient leakage detected: {leaked[:5]}")

    print()
    summary = summarise(split, config.group_column)
    print_summary(summary)

    if not args.no_write:
        out_dir.mkdir(parents=True, exist_ok=True)
        split_path = out_dir / SPLIT_CSV
        split.to_csv(split_path, index=False)

        payload = {
            "generated_at": time.strftime("%Y-%m-%dT%H:%M:%S"),
            "seed": config.seed,
            "ratios": {
                "train": config.train_ratio,
                "val": config.val_ratio,
                "test": config.test_ratio,
            },
            "group_column": config.group_column,
            "stratify_column": config.stratify_column,
            "images_total": len(split),
            "patients_total": int(split[config.group_column].nunique()),
            "leaked_patients": len(leaked),
            "splits": {
                name: {k: (dict(v) if isinstance(v, Counter) else v)
                       for k, v in stats.items()}
                for name, stats in summary.items()
            },
        }
        summary_path = out_dir / SPLIT_SUMMARY_JSON
        summary_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")

        print(f"\n  wrote {split_path}")
        print(f"  wrote {summary_path}")

    print("\nDone. No dataset file was modified.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
