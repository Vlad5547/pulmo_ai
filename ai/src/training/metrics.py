"""Binary classification metrics, implemented on plain tensors.

No scikit-learn dependency: ROC-AUC and AUPRC are computed from the ranked
scores directly, which is exact and cheap for the split sizes here (<= 21 k
samples). ROC-AUC uses the Mann–Whitney U identity with proper tie handling.

Accumulate over a whole epoch with :class:`MetricAccumulator`, then call
``compute()`` once — batch-averaged AUC would be meaningless.
"""

from __future__ import annotations

from dataclasses import dataclass, field

import torch


@dataclass
class MetricAccumulator:
    """Collects logits and targets across batches, computes metrics once."""

    threshold: float = 0.5
    _logits: list[torch.Tensor] = field(default_factory=list)
    _targets: list[torch.Tensor] = field(default_factory=list)
    _loss_sum: float = 0.0
    _samples: int = 0

    def update(
        self,
        logits: torch.Tensor,
        targets: torch.Tensor,
        loss: float | None = None,
    ) -> None:
        self._logits.append(logits.detach().float().flatten().cpu())
        self._targets.append(targets.detach().float().flatten().cpu())
        if loss is not None:
            self._loss_sum += float(loss) * targets.shape[0]
            self._samples += int(targets.shape[0])

    def reset(self) -> None:
        self._logits.clear()
        self._targets.clear()
        self._loss_sum = 0.0
        self._samples = 0

    @property
    def is_empty(self) -> bool:
        return not self._logits

    def compute(self) -> dict[str, float]:
        if self.is_empty:
            return {}
        logits = torch.cat(self._logits)
        targets = torch.cat(self._targets)
        probabilities = torch.sigmoid(logits)
        predictions = (probabilities >= self.threshold).float()

        tp = float(((predictions == 1) & (targets == 1)).sum())
        tn = float(((predictions == 0) & (targets == 0)).sum())
        fp = float(((predictions == 1) & (targets == 0)).sum())
        fn = float(((predictions == 0) & (targets == 1)).sum())

        precision = tp / (tp + fp) if tp + fp else 0.0
        recall = tp / (tp + fn) if tp + fn else 0.0
        specificity = tn / (tn + fp) if tn + fp else 0.0
        f1 = (
            2 * precision * recall / (precision + recall)
            if precision + recall
            else 0.0
        )

        metrics = {
            "accuracy": (tp + tn) / max(len(targets), 1),
            "precision": precision,
            "recall": recall,
            "specificity": specificity,
            "f1": f1,
            "roc_auc": roc_auc(probabilities, targets),
            "auprc": average_precision(probabilities, targets),
            "positives": tp + fn,
            "predicted_positives": tp + fp,
        }
        if self._samples:
            metrics["loss"] = self._loss_sum / self._samples
        return metrics


def roc_auc(scores: torch.Tensor, targets: torch.Tensor) -> float:
    """Area under the ROC curve via the rank (Mann-Whitney U) identity.

    Ties get averaged ranks, which is what sklearn does too. Returns 0.5 when
    one of the classes is absent (AUC is undefined there).
    """
    positives = targets == 1
    n_pos = int(positives.sum())
    n_neg = int((~positives).sum())
    if n_pos == 0 or n_neg == 0:
        return 0.5

    ranks = _average_ranks(scores)
    rank_sum = float(ranks[positives].sum())
    return (rank_sum - n_pos * (n_pos + 1) / 2) / (n_pos * n_neg)


def average_precision(scores: torch.Tensor, targets: torch.Tensor) -> float:
    """Area under the precision-recall curve (step interpolation, as sklearn)."""
    n_pos = float((targets == 1).sum())
    if n_pos == 0:
        return 0.0

    order = torch.argsort(scores, descending=True)
    sorted_targets = targets[order]
    tp = torch.cumsum(sorted_targets, dim=0)
    ranks = torch.arange(1, len(sorted_targets) + 1, dtype=torch.float32)
    precision = tp / ranks
    return float((precision * sorted_targets).sum() / n_pos)


def _average_ranks(values: torch.Tensor) -> torch.Tensor:
    """1-based ranks with ties replaced by their average rank."""
    order = torch.argsort(values)
    ranks = torch.empty(len(values), dtype=torch.float64)
    ranks[order] = torch.arange(1, len(values) + 1, dtype=torch.float64)

    sorted_values = values[order]
    index = 0
    while index < len(sorted_values):
        end = index
        while (
            end + 1 < len(sorted_values)
            and sorted_values[end + 1] == sorted_values[index]
        ):
            end += 1
        if end > index:
            average = (index + end + 2) / 2  # ranks are 1-based
            ranks[order[index:end + 1]] = average
        index = end + 1
    return ranks


def format_metrics(metrics: dict[str, float]) -> str:
    order = ("loss", "roc_auc", "auprc", "accuracy", "precision", "recall", "f1")
    parts = [
        f"{key}={metrics[key]:.4f}" for key in order if key in metrics
    ]
    return "  ".join(parts)
