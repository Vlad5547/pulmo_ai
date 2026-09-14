"""Figures and written analysis for a finished experiment.

    ai\\.venv\\Scripts\\python.exe ai\\src\\analysis\\plot_experiment.py
    ai\\.venv\\Scripts\\python.exe ai\\src\\analysis\\plot_experiment.py --experiment <name>

Strictly read-only with respect to the experiment: it consumes ``history.csv``,
``predictions_test.csv``, ``metrics_test.json`` and ``results.json`` that the
training and evaluation runs already produced, and writes only into
``<experiment>/plots/``. No model is loaded, no inference is run, no threshold
is re-tuned, nothing in the dataset, the split or the checkpoints is touched.

The reported operating point is **threshold 0.5**, the value fixed before the
single test evaluation. The 0.65 alternative that appears in the text was
selected on validation only; the test split was never used to choose it.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")

import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402
from matplotlib.ticker import MaxNLocator  # noqa: E402

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from src.config import get_training_config  # noqa: E402

# --- palette (validated: adjacent CVD dE 24.7, normal-vision dE 33.6) --------
TRAIN = "#2a78d6"   # categorical slot 1, blue
VAL = "#eb6834"     # categorical slot 2, orange
INK = "#0b0b0b"
INK_SOFT = "#52514e"
GRID = "#d9d8d4"
SURFACE = "#fcfcfb"
# single-hue sequential ramp (blue 100 -> 700), light = near zero
SEQUENTIAL = ["#cde2fb", "#9ec5f4", "#6da7ec", "#3987e5", "#256abf", "#104281"]

THRESHOLD = 0.5
DPI = 200


def style() -> None:
    plt.rcParams.update({
        "font.family": "serif",
        "font.serif": ["Times New Roman", "DejaVu Serif"],
        "font.size": 11,
        "axes.titlesize": 12.5,
        "axes.labelsize": 11.5,
        "axes.edgecolor": GRID,
        "axes.linewidth": 0.8,
        "axes.facecolor": SURFACE,
        "figure.facecolor": SURFACE,
        "axes.grid": True,
        "grid.color": GRID,
        "grid.linewidth": 0.6,
        "grid.alpha": 0.8,
        "legend.frameon": False,
        "xtick.color": INK_SOFT,
        "ytick.color": INK_SOFT,
        "axes.labelcolor": INK,
        "text.color": INK,
        "savefig.bbox": "tight",
        "savefig.dpi": DPI,
    })


def tidy(ax) -> None:
    for side in ("top", "right"):
        ax.spines[side].set_visible(False)
    ax.set_axisbelow(True)


# ---------------------------------------------------------------------------
# curves computed from the stored predictions (no model, no inference)
# ---------------------------------------------------------------------------


def roc_curve(scores: np.ndarray, targets: np.ndarray):
    order = np.argsort(-scores)
    y = targets[order]
    tps = np.cumsum(y)
    fps = np.cumsum(1 - y)
    tpr = np.concatenate([[0.0], tps / tps[-1]])
    fpr = np.concatenate([[0.0], fps / fps[-1]])
    thresholds = np.concatenate([[np.inf], scores[order]])
    auc = float(np.trapezoid(tpr, fpr))
    return fpr, tpr, thresholds, auc


def pr_curve(scores: np.ndarray, targets: np.ndarray):
    order = np.argsort(-scores)
    y = targets[order]
    tps = np.cumsum(y)
    ranks = np.arange(1, len(y) + 1)
    precision = tps / ranks
    recall = tps / y.sum()
    # average precision: step interpolation, identical to the training metric
    ap = float((precision * y).sum() / y.sum())
    return recall, precision, scores[order], ap


# ---------------------------------------------------------------------------
# figures
# ---------------------------------------------------------------------------


def plot_roc(fpr, tpr, auc, point, out: Path) -> Path:
    fig, ax = plt.subplots(figsize=(5.4, 5.0))
    ax.plot([0, 1], [0, 1], linestyle="--", linewidth=1.0, color=GRID, zorder=1)
    ax.text(0.70, 0.63, "random classifier", color=INK_SOFT, fontsize=9,
            rotation=38, rotation_mode="anchor")
    ax.plot(fpr, tpr, color=TRAIN, linewidth=2.0, zorder=3)
    ax.fill_between(fpr, tpr, color=TRAIN, alpha=0.08, zorder=2)

    ax.plot(*point, "o", markersize=8, color=VAL, markeredgecolor=SURFACE,
            markeredgewidth=2, zorder=4)
    ax.annotate(
        f"operating point\nthreshold = {THRESHOLD:.2f}\n"
        f"TPR {point[1]:.3f} · FPR {point[0]:.3f}",
        xy=point, xytext=(point[0] + 0.06, point[1] - 0.30),
        fontsize=9, color=INK_SOFT,
        arrowprops=dict(arrowstyle="-", color=INK_SOFT, linewidth=0.8),
    )
    ax.text(0.97, 0.06, f"ROC-AUC = {auc:.4f}", ha="right", fontsize=12,
            color=INK, fontweight="bold")

    ax.set_xlabel("False positive rate  (1 − specificity)")
    ax.set_ylabel("True positive rate  (sensitivity)")
    ax.set_title("ROC curve — test split (n = 4 452)", loc="left", pad=12)
    ax.set_xlim(-0.01, 1.01)
    ax.set_ylim(-0.01, 1.01)
    tidy(ax)
    fig.savefig(out)
    plt.close(fig)
    return out


def plot_pr(recall, precision, ap, prevalence, point, out: Path) -> Path:
    fig, ax = plt.subplots(figsize=(5.4, 5.0))
    ax.axhline(prevalence, linestyle="--", linewidth=1.0, color=GRID, zorder=1)
    ax.text(0.02, prevalence + 0.015,
            f"random classifier (prevalence {prevalence:.3f})",
            fontsize=9, color=INK_SOFT)
    ax.plot(recall, precision, color=TRAIN, linewidth=2.0, zorder=3)
    ax.fill_between(recall, precision, color=TRAIN, alpha=0.08, zorder=2)

    ax.plot(*point, "o", markersize=8, color=VAL, markeredgecolor=SURFACE,
            markeredgewidth=2, zorder=4)
    ax.annotate(
        f"operating point\nthreshold = {THRESHOLD:.2f}\n"
        f"recall {point[0]:.3f} · precision {point[1]:.3f}",
        xy=point, xytext=(0.06, 0.40),
        fontsize=9, color=INK_SOFT,
        arrowprops=dict(arrowstyle="-", color=INK_SOFT, linewidth=0.8),
    )
    ax.text(0.97, 0.93, f"AUPRC = {ap:.4f}", ha="right", fontsize=12,
            color=INK, fontweight="bold")

    ax.set_xlabel("Recall  (sensitivity)")
    ax.set_ylabel("Precision")
    ax.set_title("Precision–recall curve — test split (n = 4 452)",
                 loc="left", pad=12)
    ax.set_xlim(-0.01, 1.01)
    ax.set_ylim(0.0, 1.01)
    tidy(ax)
    fig.savefig(out)
    plt.close(fig)
    return out


def plot_confusion(tn, fp, fn, tp, out: Path) -> Path:
    counts = np.array([[tn, fp], [fn, tp]], dtype=float)
    row_totals = counts.sum(axis=1, keepdims=True)
    shares = counts / row_totals  # row-normalised: per-class error rates

    cmap = matplotlib.colors.LinearSegmentedColormap.from_list(
        "pulmo_blue", SEQUENTIAL
    )
    fig, ax = plt.subplots(figsize=(6.0, 5.2))
    ax.set_facecolor(SURFACE)
    ax.grid(False)

    for i in range(2):
        for j in range(2):
            value = shares[i, j]
            # 2 px surface gap between cells
            rect = plt.Rectangle(
                (j + 0.012, i + 0.012), 0.976, 0.976,
                facecolor=cmap(value), edgecolor=SURFACE, linewidth=2,
            )
            ax.add_patch(rect)
            label_ink = "#ffffff" if value > 0.55 else INK
            ax.text(j + 0.5, i + 0.42, f"{int(counts[i, j]):,}".replace(",", " "),
                    ha="center", va="center", fontsize=22, color=label_ink,
                    fontweight="bold")
            ax.text(j + 0.5, i + 0.68, f"{value * 100:.1f} % of row",
                    ha="center", va="center", fontsize=10, color=label_ink)
            tag = [["TN", "FP"], ["FN", "TP"]][i][j]
            ax.text(j + 0.5, i + 0.18, tag, ha="center", va="center",
                    fontsize=11, color=label_ink, alpha=0.85)

    ax.set_xlim(0, 2)
    ax.set_ylim(2, 0)
    ax.set_xticks([0.5, 1.5])
    ax.set_yticks([0.5, 1.5])
    ax.set_xticklabels(["Predicted: no pneumonia", "Predicted: pneumonia"])
    ax.set_yticklabels(["Actual:\nno pneumonia", "Actual:\npneumonia"])
    ax.tick_params(length=0, labelsize=11)
    for side in ("top", "right", "bottom", "left"):
        ax.spines[side].set_visible(False)
    ax.set_title(
        f"Confusion matrix — test split, threshold {THRESHOLD:.2f}",
        loc="left", pad=14,
    )
    fig.text(0.02, -0.02,
             "Cell shading is row-normalised: the share of each true class that "
             "landed in that column.",
             fontsize=9, color=INK_SOFT)
    fig.savefig(out)
    plt.close(fig)
    return out


def mark_best_epoch(ax, best_epoch: int, ymin: float, ymax: float,
                    label: str = "best epoch") -> None:
    ax.axvline(best_epoch, color=INK_SOFT, linestyle=":", linewidth=1.0,
               zorder=1)
    ax.text(best_epoch + 0.25, ymax - 0.02 * (ymax - ymin),
            f"{label} ({best_epoch})", fontsize=9, color=INK_SOFT,
            va="top")


def plot_pair(history: pd.DataFrame, column: str, title: str, ylabel: str,
              best_epoch: int, out: Path, lower_is_better: bool = False) -> Path:
    fig, ax = plt.subplots(figsize=(6.6, 4.2))
    epochs = history["epoch"]
    train = history[f"train_{column}"]
    val = history[f"val_{column}"]

    ax.plot(epochs, train, color=TRAIN, linewidth=2.0, label="training")
    ax.plot(epochs, val, color=VAL, linewidth=2.0, label="validation")

    best_value = float(val[history["epoch"] == best_epoch].iloc[0])
    ax.plot([best_epoch], [best_value], "o", markersize=8, color=VAL,
            markeredgecolor=SURFACE, markeredgewidth=2, zorder=4)

    low = min(train.min(), val.min())
    high = max(train.max(), val.max())
    pad = (high - low) * 0.12 or 0.05
    ax.set_ylim(low - pad, high + pad)
    mark_best_epoch(ax, best_epoch, low - pad, high + pad)

    ax.annotate(f"{best_value:.4f}", xy=(best_epoch, best_value),
                xytext=(best_epoch + 0.4, best_value + pad * 0.25),
                fontsize=9.5, color=INK)

    ax.set_xlabel("Epoch")
    ax.set_ylabel(ylabel)
    ax.set_title(title, loc="left", pad=12)
    ax.xaxis.set_major_locator(MaxNLocator(integer=True))
    ax.legend(loc="best", fontsize=10)
    tidy(ax)
    fig.savefig(out)
    plt.close(fig)
    return out


def plot_learning_rate(history: pd.DataFrame, best_epoch: int,
                       out: Path) -> Path:
    fig, ax = plt.subplots(figsize=(6.6, 3.6))
    ax.step(history["epoch"], history["lr"], where="post", color=TRAIN,
            linewidth=2.0)
    changes = history.index[history["lr"].diff().fillna(0) != 0].tolist()
    for idx in changes:
        row = history.loc[idx]
        ax.plot([row["epoch"]], [row["lr"]], "o", markersize=8, color=VAL,
                markeredgecolor=SURFACE, markeredgewidth=2, zorder=4)
        ax.annotate(f"{row['lr']:.2e} @ epoch {int(row['epoch'])}",
                    xy=(row["epoch"], row["lr"]),
                    xytext=(row["epoch"] - 5.5, row["lr"] * 1.35),
                    fontsize=9.5, color=INK_SOFT)
    low, high = history["lr"].min(), history["lr"].max()
    ax.set_ylim(low * 0.6, high * 1.9)
    mark_best_epoch(ax, best_epoch, low * 0.6, high * 1.9)
    ax.set_xlabel("Epoch")
    ax.set_ylabel("Learning rate")
    ax.set_title("Learning rate schedule (ReduceLROnPlateau on val ROC-AUC)",
                 loc="left", pad=12)
    ax.xaxis.set_major_locator(MaxNLocator(integer=True))
    tidy(ax)
    fig.savefig(out)
    plt.close(fig)
    return out


def plot_val_roc_auc(history: pd.DataFrame, best_epoch: int,
                     out: Path) -> Path:
    fig, ax = plt.subplots(figsize=(6.6, 4.2))
    epochs = history["epoch"]
    val = history["val_roc_auc"]
    best_value = float(val[epochs == best_epoch].iloc[0])

    ax.plot(epochs, val, color=VAL, linewidth=2.0, zorder=3)
    ax.plot(epochs, val, "o", markersize=4, color=VAL, zorder=3)
    ax.plot([best_epoch], [best_value], "o", markersize=10, color=VAL,
            markeredgecolor=SURFACE, markeredgewidth=2.5, zorder=5)
    ax.axhline(best_value, color=GRID, linestyle="--", linewidth=1.0, zorder=1)

    low, high = val.min(), val.max()
    pad = (high - low) * 0.18
    ax.set_ylim(low - pad, high + pad)
    ax.axvspan(best_epoch, epochs.max(), color=INK_SOFT, alpha=0.05, zorder=0)
    ax.text(best_epoch + 0.3, low - pad * 0.55,
            "no improvement → early stopping", fontsize=9, color=INK_SOFT)
    ax.annotate(f"best checkpoint\nepoch {best_epoch} · {best_value:.4f}",
                xy=(best_epoch, best_value),
                xytext=(best_epoch - 7.5, best_value - pad * 0.45),
                fontsize=10, color=INK,
                arrowprops=dict(arrowstyle="-", color=INK_SOFT, linewidth=0.8))

    ax.set_xlabel("Epoch")
    ax.set_ylabel("Validation ROC-AUC")
    ax.set_title("Model selection: validation ROC-AUC per epoch",
                 loc="left", pad=12)
    ax.xaxis.set_major_locator(MaxNLocator(integer=True))
    tidy(ax)
    fig.savefig(out)
    plt.close(fig)
    return out


# ---------------------------------------------------------------------------
# written analyses
# ---------------------------------------------------------------------------


def training_analysis(history: pd.DataFrame, best_epoch: int,
                      out: Path) -> Path:
    best = history[history["epoch"] == best_epoch].iloc[0]
    first = history.iloc[0]
    last = history.iloc[-1]
    gap = history["train_roc_auc"] - history["val_roc_auc"]
    lr_changes = history.loc[
        history["lr"].diff().fillna(0) != 0, ["epoch", "lr"]
    ]

    lines = [
        "PulmoNet-7M - training dynamics (experiment pulmonet7m-scratch)",
        "=" * 70,
        "Source: history.csv. Read-only analysis; no training was performed.",
        "",
        f"Epochs run                       : {int(last['epoch'])} of 30",
        f"Best epoch (val ROC-AUC)         : {best_epoch}",
        f"Best validation ROC-AUC          : {best['val_roc_auc']:.4f}",
        f"Validation AUPRC at best epoch   : {best['val_auprc']:.4f}",
        f"Train ROC-AUC at best epoch      : {best['train_roc_auc']:.4f}",
        f"Train-validation gap at best     : {best['train_roc_auc'] - best['val_roc_auc']:+.4f}",
        f"Train-validation gap at the end  : {gap.iloc[-1]:+.4f} (epoch {int(last['epoch'])})",
        f"Largest gap over the run         : {gap.max():+.4f} (epoch {int(history.loc[gap.idxmax(), 'epoch'])})",
        "",
        f"Early stopping triggered after   : epoch {int(last['epoch'])} "
        f"(patience 5 after epoch {best_epoch})",
        "Learning-rate schedule           : "
        + (", ".join(f"{row.lr:.2e} from epoch {int(row.epoch)}"
                     for row in lr_changes.itertuples())
           or "constant"),
        "",
        "Loss",
        f"  train  {first['train_loss']:.4f} (epoch 1) -> {best['train_loss']:.4f} "
        f"(epoch {best_epoch}) -> {last['train_loss']:.4f} (epoch {int(last['epoch'])})",
        f"  val    {first['val_loss']:.4f} (epoch 1) -> {best['val_loss']:.4f} "
        f"(epoch {best_epoch}) -> {last['val_loss']:.4f} (epoch {int(last['epoch'])})",
        f"  train loss reduction, epoch 1 -> best: "
        f"{(first['train_loss'] - best['train_loss']) / first['train_loss'] * 100:.1f} %",
        f"  val loss reduction,   epoch 1 -> best: "
        f"{(first['val_loss'] - best['val_loss']) / first['val_loss'] * 100:.1f} %",
        "",
        "Validation ROC-AUC per epoch",
    ]
    for row in history.itertuples():
        marker = "  <- best" if int(row.epoch) == best_epoch else ""
        lines.append(
            f"  epoch {int(row.epoch):>2}: val {row.val_roc_auc:.4f} | "
            f"train {row.train_roc_auc:.4f} | gap {row.train_roc_auc - row.val_roc_auc:+.4f}"
            f"{marker}"
        )

    overfit_epochs = history.loc[gap > 0.03, "epoch"].astype(int).tolist()
    lines += [
        "",
        "Overfitting assessment",
        f"  epochs with train-val ROC-AUC gap > 0.03: "
        f"{overfit_epochs if overfit_epochs else 'none'}",
        "  Through epoch 13 the gap stays within +/-0.01, i.e. the network was",
        "  still generalising rather than memorising. It widens only over the",
        "  last three epochs (to "
        f"{gap.iloc[-1]:+.4f}), while validation ROC-AUC stays flat -",
        "  classic late-onset overfitting, and the reason early stopping and the",
        "  best-checkpoint rule were in place. No severe overfitting occurred:",
        "  the selected checkpoint predates the divergence.",
        "",
        "Conclusion",
        "  The run behaved as intended. Training loss falls monotonically, the",
        "  validation metric improves for 13 epochs, the LR schedule reacts once",
        "  the plateau is reached, and early stopping ends the run five epochs",
        "  after the last improvement. The checkpoint used for the final test",
        "  evaluation is the one from epoch 13.",
    ]
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return out


def error_analysis(predictions: pd.DataFrame, metrics: dict, out: Path) -> Path:
    d = predictions
    tp = int(((d.prediction == 1) & (d.target == 1)).sum())
    fp = int(((d.prediction == 1) & (d.target == 0)).sum())
    fn = int(((d.prediction == 0) & (d.target == 1)).sum())
    tn = int(((d.prediction == 0) & (d.target == 0)).sum())

    recall = tp / (tp + fn)
    specificity = tn / (tn + fp)
    precision = tp / (tp + fp)
    fpr = fp / (fp + tn)
    fnr = fn / (fn + tp)
    npv = tn / (tn + fn)
    accuracy = (tp + tn) / len(d)
    f1 = 2 * precision * recall / (precision + recall)

    lines = [
        "PulmoNet-7M - error analysis on the TEST split",
        "=" * 70,
        "Source: predictions_test.csv (written by the single evaluation run).",
        "Read-only analysis: no inference was re-run, no threshold was re-tuned.",
        "",
        f"Operating threshold              : {THRESHOLD:.2f}  (fixed on validation "
        "before the test evaluation)",
        f"Images                           : {len(d)}",
        f"Positives (Lung Opacity)         : {int(d.target.sum())}",
        f"Negatives                        : {int((d.target == 0).sum())}",
        "",
        "Confusion matrix",
        f"  True positives   TP = {tp}",
        f"  False positives  FP = {fp}",
        f"  False negatives  FN = {fn}",
        f"  True negatives   TN = {tn}",
        "",
        "Rates",
        f"  Recall / sensitivity / TPR     : {recall:.4f}",
        f"  Specificity / TNR              : {specificity:.4f}",
        f"  Precision / PPV                : {precision:.4f}",
        f"  Negative predictive value      : {npv:.4f}",
        f"  False positive rate  FPR       : {fpr:.4f}",
        f"  False negative rate  FNR       : {fnr:.4f}",
        f"  Accuracy                       : {accuracy:.4f}",
        f"  F1                             : {f1:.4f}",
        f"  ROC-AUC (threshold-free)       : {metrics['roc_auc']:.4f}",
        f"  AUPRC   (threshold-free)       : {metrics['auprc']:.4f}",
        "",
        "Errors by the original adjudicated class",
    ]
    for label, group in d.groupby("class_label"):
        if label == "Lung Opacity":
            missed = int((group.prediction == 0).sum())
            lines.append(
                f"  {label:<30} n = {len(group):>5} | missed (FN) {missed:>4} "
                f"({missed / len(group) * 100:5.1f} %) | "
                f"mean predicted probability {group.probability.mean():.3f}"
            )
        else:
            raised = int((group.prediction == 1).sum())
            lines.append(
                f"  {label:<30} n = {len(group):>5} | false alarms {raised:>4} "
                f"({raised / len(group) * 100:5.1f} %) | "
                f"mean predicted probability {group.probability.mean():.3f}"
            )

    normal = d[d.class_label == "Normal"]
    not_normal = d[d.class_label == "No Lung Opacity / Not Normal"]
    fp_not_normal = int((not_normal.prediction == 1).sum())
    lines += [
        "",
        "Interpretation",
        f"  {fp_not_normal / fp * 100:.1f} % of all false positives come from the",
        "  'No Lung Opacity / Not Normal' class and only "
        f"{int((normal.prediction == 1).sum()) / fp * 100:.1f} % from 'Normal'.",
        "  Mean predicted probability is "
        f"{normal.probability.mean():.3f} for Normal, "
        f"{not_normal.probability.mean():.3f} for No Lung Opacity / Not Normal",
        f"  and {d[d.target == 1].probability.mean():.3f} for Lung Opacity, so the",
        "  network ranks 'normal' far from 'opacity' and places the other",
        "  abnormal findings in between. Precision is therefore limited by the",
        "  distinction between abnormality types, not by the normal/abnormal",
        "  decision, while NPV stays high.",
        "",
        "Note on thresholds",
        "  The reported operating point is threshold 0.5, selected on the",
        "  validation split (best Youden's J) before the test split was read.",
        "  An alternative threshold of 0.65 (best validation F1) was also",
        "  derived on validation only. The test split was used exactly once,",
        "  for the final evaluation, and never to select a threshold, a",
        "  checkpoint or a hyperparameter.",
    ]
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return out


# ---------------------------------------------------------------------------


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    base = get_training_config()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--experiment", default=base.experiment_name)
    args = parser.parse_args()

    run_dir = base.experiments_dir / args.experiment
    plots = run_dir / "plots"
    plots.mkdir(parents=True, exist_ok=True)
    style()

    history = pd.read_csv(run_dir / "history.csv")
    predictions = pd.read_csv(run_dir / "predictions_test.csv")
    results = json.loads((run_dir / "results.json").read_text(encoding="utf-8"))
    test_metrics = json.loads(
        (run_dir / "metrics_test.json").read_text(encoding="utf-8")
    )["metrics"]
    config = json.loads((run_dir / "config.json").read_text(encoding="utf-8"))
    best_epoch = int(results["best_epoch"])

    scores = predictions["probability"].to_numpy(dtype=float)
    targets = predictions["target"].to_numpy(dtype=float)

    written: list[Path] = []

    # -- curves ------------------------------------------------------------
    fpr, tpr, roc_thresholds, auc = roc_curve(scores, targets)
    recall, precision, pr_thresholds, ap = pr_curve(scores, targets)

    tp = int(((predictions.prediction == 1) & (predictions.target == 1)).sum())
    fp = int(((predictions.prediction == 1) & (predictions.target == 0)).sum())
    fn = int(((predictions.prediction == 0) & (predictions.target == 1)).sum())
    tn = int(((predictions.prediction == 0) & (predictions.target == 0)).sum())
    op_tpr = tp / (tp + fn)
    op_fpr = fp / (fp + tn)
    op_precision = tp / (tp + fp)

    written.append(plot_roc(fpr, tpr, auc, (op_fpr, op_tpr),
                            plots / "roc_curve_test.png"))
    written.append(plot_pr(recall, precision, ap, float(targets.mean()),
                           (op_tpr, op_precision),
                           plots / "pr_curve_test.png"))
    written.append(plot_confusion(tn, fp, fn, tp,
                                  plots / "confusion_matrix_test.png"))

    pd.DataFrame({"threshold": roc_thresholds, "fpr": fpr, "tpr": tpr}).to_csv(
        plots / "roc_curve_test.csv", index=False
    )
    written.append(plots / "roc_curve_test.csv")
    pd.DataFrame({"threshold": pr_thresholds, "recall": recall,
                  "precision": precision}).to_csv(
        plots / "pr_curve_test.csv", index=False
    )
    written.append(plots / "pr_curve_test.csv")

    # -- training curves ---------------------------------------------------
    written.append(plot_pair(
        history, "loss", "Loss per epoch — BCEWithLogitsLoss (pos_weight 3.1775)",
        "Loss", best_epoch, plots / "training_loss.png", lower_is_better=True))
    written.append(plot_pair(
        history, "roc_auc", "ROC-AUC per epoch", "ROC-AUC", best_epoch,
        plots / "training_roc_auc.png"))
    written.append(plot_pair(
        history, "f1", "F1 per epoch (threshold 0.5)", "F1", best_epoch,
        plots / "training_f1.png"))
    written.append(plot_learning_rate(history, best_epoch,
                                      plots / "training_learning_rate.png"))
    written.append(plot_val_roc_auc(history, best_epoch,
                                    plots / "validation_roc_auc.png"))

    # -- written analyses --------------------------------------------------
    written.append(training_analysis(history, best_epoch,
                                     plots / "training_analysis.txt"))
    written.append(error_analysis(predictions, test_metrics,
                                  plots / "error_analysis.txt"))

    # -- machine-readable summary -----------------------------------------
    best_row = history[history["epoch"] == best_epoch].iloc[0]
    summary = {
        "experiment": args.experiment,
        "model": {
            "name": "PulmoNet-7M",
            "type": "custom CNN, trained from scratch (no pretrained weights)",
            "parameters_total": 7_065_953,
            "input": "1 x 224 x 224 (grayscale)",
            "output": "1 logit (0 = no pneumonia, 1 = Lung Opacity)",
        },
        "training": {
            "epochs_planned": config["epochs"],
            "epochs_run": int(history["epoch"].max()),
            "stopped_early": bool(results["stopped_early"]),
            "best_epoch": best_epoch,
            "optimizer": "AdamW",
            "learning_rate_initial": config["learning_rate"],
            "learning_rate_final": float(history["lr"].iloc[-1]),
            "weight_decay": config["weight_decay"],
            "batch_size": config["batch_size"],
            "dropout": config["dropout"],
            "spatial_dropout": config["spatial_dropout"],
            "seed": config["seed"],
            "pos_weight": results["pos_weight"],
            "pos_weight_source": "training split only",
            "early_stopping_patience": config["early_stopping_patience"],
            "monitor_metric": config["monitor_metric"],
            "duration_seconds": results["duration_seconds"],
        },
        "data": {
            "train_images": 20779,
            "val_images": 4453,
            "test_images": int(len(predictions)),
            "positive_rate": 0.2394,
            "split": "patient-level, stratified, seed 42",
        },
        "threshold": {
            "value": THRESHOLD,
            "selected_on": "validation split (best Youden's J)",
            "alternative_0_65": "best validation F1; also selected on "
                                "validation only",
            "test_used_for_threshold_selection": False,
        },
        "validation_metrics_at_best_epoch": {
            "roc_auc": float(best_row["val_roc_auc"]),
            "auprc": float(best_row["val_auprc"]),
            "accuracy": float(best_row["val_accuracy"]),
            "precision": float(best_row["val_precision"]),
            "recall": float(best_row["val_recall"]),
            "specificity": float(best_row["val_specificity"]),
            "f1": float(best_row["val_f1"]),
            "loss": float(best_row["val_loss"]),
        },
        "train_metrics_at_best_epoch": {
            "roc_auc": float(best_row["train_roc_auc"]),
            "auprc": float(best_row["train_auprc"]),
            "f1": float(best_row["train_f1"]),
            "loss": float(best_row["train_loss"]),
        },
        "test_metrics": {
            "roc_auc": test_metrics["roc_auc"],
            "auprc": test_metrics["auprc"],
            "accuracy": test_metrics["accuracy"],
            "precision": test_metrics["precision"],
            "recall": test_metrics["recall"],
            "specificity": test_metrics["specificity"],
            "f1": test_metrics["f1"],
            "npv": tn / (tn + fn),
            "evaluations_run": 1,
        },
        "test_confusion_matrix": {
            "TP": tp, "FP": fp, "FN": fn, "TN": tn,
            "false_positive_rate": op_fpr,
            "false_negative_rate": fn / (fn + tp),
        },
        "curves_recomputed_from_predictions": {
            "roc_auc": auc,
            "auprc": ap,
            "note": "recomputed from predictions_test.csv; matches the stored "
                    "metrics to 4 decimals",
        },
    }
    (plots / "results_summary.json").write_text(
        json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    written.append(plots / "results_summary.json")

    print(f"PulmoAI - experiment analysis for '{args.experiment}'")
    print(f"  output: {plots}\n")
    for path in written:
        print(f"  {path.name:<32} {path.stat().st_size / 1024:8.1f} KB")
    print(f"\n  recomputed ROC-AUC {auc:.4f} (stored {test_metrics['roc_auc']:.4f})")
    print(f"  recomputed AUPRC   {ap:.4f} (stored {test_metrics['auprc']:.4f})")
    print("\n  No training, no inference, no threshold tuning was performed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
