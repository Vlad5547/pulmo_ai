"""Loss and class-imbalance handling.

The dataset is 23.9 % positive, so an unweighted BCE happily predicts "no
pneumonia" for everything. ``pos_weight`` multiplies the loss of positive
samples by ``negatives / positives``, which restores the balance without
throwing data away or duplicating images.

The weight is computed **from the training split only** — deriving it from
validation or test would leak information about the held-out label
distribution into the training objective.
"""

from __future__ import annotations

import pandas as pd
import torch
import torch.nn as nn

from src.config import CLASS_LUNG_OPACITY, SPLIT_CSV, get_dataset_paths


def compute_pos_weight(
    split: str = "train", frame: pd.DataFrame | None = None
) -> torch.Tensor:
    """``negatives / positives`` for the requested split (default: train)."""
    if split != "train":
        raise ValueError(
            "pos_weight must be computed on the training split only — "
            f"got '{split}'. Using val/test would leak their label balance."
        )

    if frame is None:
        paths = get_dataset_paths()
        frame = pd.read_csv(paths.processed_dir / SPLIT_CSV)
        frame = frame[frame["split"] == split]

    if "target" in frame.columns:
        positives = int(frame["target"].sum())
    else:
        positives = int((frame["class_label"] == CLASS_LUNG_OPACITY).sum())
    negatives = len(frame) - positives

    if positives == 0:
        raise ValueError("Training split has no positive samples")
    return torch.tensor([negatives / positives], dtype=torch.float32)


def build_loss(
    pos_weight: torch.Tensor | None = None, device: torch.device | str = "cpu"
) -> nn.Module:
    """``BCEWithLogitsLoss`` — sigmoid is fused in, so the model emits logits."""
    if pos_weight is not None:
        pos_weight = pos_weight.to(device)
    return nn.BCEWithLogitsLoss(pos_weight=pos_weight)
