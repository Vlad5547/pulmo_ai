"""Checks for the hand-rolled metrics (no data, no model, milliseconds).

    ai\\.venv\\Scripts\\python.exe ai\\src\\training\\test_metrics.py
    ai\\.venv\\Scripts\\python.exe -m pytest ai/src/training/test_metrics.py -v

ROC-AUC is verified against the pairwise definition (brute force over every
positive/negative pair, ties counted as 0.5), which is the ground truth the
rank-based implementation has to reproduce — including on tied scores.
"""

from __future__ import annotations

import sys
from pathlib import Path

import torch

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from src.training.losses import compute_pos_weight  # noqa: E402
from src.training.metrics import (  # noqa: E402
    MetricAccumulator,
    average_precision,
    roc_auc,
)


def _pairwise_auc(scores: torch.Tensor, targets: torch.Tensor) -> float:
    positives = scores[targets == 1]
    negatives = scores[targets == 0]
    wins = sum(
        1.0 if p > n else 0.5 if p == n else 0.0
        for p in positives
        for n in negatives
    )
    return wins / (len(positives) * len(negatives))


def test_roc_auc_matches_pairwise_definition_with_ties() -> None:
    torch.manual_seed(0)
    compared = 0
    for _ in range(8):
        scores = torch.round(torch.rand(40) * 5) / 5  # deliberately tied
        targets = (torch.rand(40) > 0.7).float()
        if targets.sum() in (0, len(targets)):
            continue
        assert abs(roc_auc(scores, targets)
                   - _pairwise_auc(scores, targets)) < 1e-9
        compared += 1
    assert compared >= 5


def test_roc_auc_edge_cases() -> None:
    perfect = roc_auc(torch.tensor([0.9, 0.8, 0.2, 0.1]),
                      torch.tensor([1.0, 1.0, 0.0, 0.0]))
    inverted = roc_auc(torch.tensor([0.1, 0.2, 0.8, 0.9]),
                       torch.tensor([1.0, 1.0, 0.0, 0.0]))
    single_class = roc_auc(torch.tensor([0.3, 0.7]), torch.tensor([0.0, 0.0]))
    assert perfect == 1.0
    assert inverted == 0.0
    assert single_class == 0.5  # undefined -> neutral


def test_average_precision() -> None:
    perfect = average_precision(torch.tensor([0.9, 0.8, 0.2, 0.1]),
                                torch.tensor([1.0, 1.0, 0.0, 0.0]))
    assert abs(perfect - 1.0) < 1e-6
    # ranking 1, 0, 1 -> precisions 1/1 and 2/3, averaged over 2 positives
    hand = average_precision(torch.tensor([0.9, 0.8, 0.7]),
                             torch.tensor([1.0, 0.0, 1.0]))
    assert abs(hand - (1.0 + 2 / 3) / 2) < 1e-6


def test_accumulator_confusion_metrics() -> None:
    # logits > 0 -> predicted positive
    logits = torch.tensor([2.0, 2.0, -2.0, -2.0, 2.0])
    targets = torch.tensor([1.0, 0.0, 0.0, 1.0, 1.0])
    accumulator = MetricAccumulator()
    accumulator.update(logits, targets, loss=0.5)
    metrics = accumulator.compute()

    # tp=2, fp=1, tn=1, fn=1
    assert abs(metrics["accuracy"] - 3 / 5) < 1e-6
    assert abs(metrics["precision"] - 2 / 3) < 1e-6
    assert abs(metrics["recall"] - 2 / 3) < 1e-6
    assert abs(metrics["f1"] - 2 / 3) < 1e-6
    assert abs(metrics["loss"] - 0.5) < 1e-6


def test_pos_weight_comes_from_train_only() -> None:
    import pandas as pd

    frame = pd.DataFrame({"target": [1] * 10 + [0] * 30})
    assert abs(float(compute_pos_weight("train", frame)) - 3.0) < 1e-6

    for split in ("val", "test"):
        try:
            compute_pos_weight(split, frame)
        except ValueError:
            continue
        raise AssertionError(f"pos_weight must refuse the '{split}' split")


def main() -> int:
    tests = [value for name, value in sorted(globals().items())
             if name.startswith("test_") and callable(value)]
    failures = 0
    print(f"Running {len(tests)} metric checks\n")
    for test in tests:
        try:
            test()
        except Exception as error:  # noqa: BLE001
            failures += 1
            print(f"  FAIL  {test.__name__}: {error}")
        else:
            print(f"  ok    {test.__name__}")
    print(f"\n{len(tests) - failures}/{len(tests)} passed")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
