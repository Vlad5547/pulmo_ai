"""Class activation maps for the trained PulmoNet-7M checkpoint.

    cd D:\\pulmo_ai\\ai
    ..\\ai\\.venv\\Scripts\\python.exe -m src.analysis.cam --dicom "<path>"

or, from the repository root:

    ai\\.venv\\Scripts\\python.exe ai\\src\\analysis\\cam.py --dicom "<path>"

Method — plain CAM (Zhou et al., 2016), which the architecture supports
natively because the head is ``global average pooling -> Linear(512, 1)``:

    features  = model.features(x)            # [1, 512, 7, 7]
    weights   = model.classifier.weight      # [1, 512]
    cam[y, x] = sum_k weights[k] * features[k, y, x]

The map is ReLU-ed (only evidence *for* the positive class is shown),
normalised to 0..1 by its own maximum and resized bilinearly to the model
input size. No architecture change, no extra layer, no gradient: the
checkpoint is read and never written.

**What the map is and is not.** It shows which regions of the image the model's
own decision function responded to. It is a visualisation of model behaviour,
not evidence of disease localisation and not a diagnostic output. The map is
computed on a 7x7 grid and upsampled, so its spatial precision is roughly
32 px of the 224 px input.
"""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass
from pathlib import Path

import matplotlib

matplotlib.use("Agg")

import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402
import torch  # noqa: E402
import torch.nn.functional as F  # noqa: E402

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from src.config import (  # noqa: E402
    BOXES_CSV,
    get_dataset_paths,
    get_preprocess_config,
    get_training_config,
)
from src.inference.predict import (  # noqa: E402
    DEFAULT_THRESHOLD,
    load_model,
    pick_device,
    predict_dicom,
    preprocess_dicom,
)

# Fixed in advance, not tuned on any split: the standard CAM localisation rule
# (Zhou et al. 2016) binarises the normalised map at 0.5 of its maximum.
CAM_BINARY_THRESHOLD = 0.5

INK = "#0b0b0b"
INK_SOFT = "#52514e"
BOX_COLOR = "#1baf7a"  # categorical slot 3, distinct from the heatmap ramp


@dataclass(frozen=True)
class CamResult:
    cam: np.ndarray            # [S, S] in 0..1
    display: np.ndarray        # [S, S] grayscale image the model saw, 0..1
    probability: float
    predicted_label: int
    peak_yx: tuple[int, int]


@torch.inference_mode()
def compute_cam(
    model: torch.nn.Module, tensor: torch.Tensor, size: int
) -> tuple[np.ndarray, float]:
    """Return the normalised CAM and the positive-class probability."""
    features = model.features(tensor)              # [1, C, h, w]
    weights = model.classifier.weight.detach()     # [1, C]
    cam = (features * weights.view(1, -1, 1, 1)).sum(dim=1, keepdim=True)
    cam = F.relu(cam)
    cam = F.interpolate(cam, size=(size, size), mode="bilinear",
                        align_corners=False)
    cam = cam.squeeze().float().cpu().numpy()

    peak = float(cam.max())
    if peak > 0:
        cam = cam / peak
    logit = model.classifier(
        torch.flatten(model.gap(features), 1)
    )
    probability = float(torch.sigmoid(logit).squeeze())
    return cam, probability


def to_display_image(tensor: torch.Tensor) -> np.ndarray:
    """Undo the mean/std normalisation for display (the image the model saw)."""
    config = get_preprocess_config()
    image = tensor.squeeze().detach().cpu().numpy()
    image = image * config.grayscale_std + config.grayscale_mean
    return np.clip(image, 0.0, 1.0)


def scaled_boxes(sop_uid: str, size: int) -> list[tuple[float, float, float, float]]:
    """Ground-truth boxes for one image, scaled to the model input, xyxy."""
    paths = get_dataset_paths()
    boxes = pd.read_csv(paths.processed_dir / BOXES_CSV)
    rows = boxes[boxes["sop_instance_uid"] == sop_uid]
    out = []
    for row in rows.itertuples():
        scale = size / float(row.dicom_columns)
        out.append((row.x * scale, row.y * scale,
                    (row.x + row.width) * scale, (row.y + row.height) * scale))
    return out


# ---------------------------------------------------------------------------
# figures
# ---------------------------------------------------------------------------


def _bare_axes(size_inches: float = 4.6):
    fig, ax = plt.subplots(figsize=(size_inches, size_inches))
    ax.set_xticks([])
    ax.set_yticks([])
    for side in ("top", "right", "bottom", "left"):
        ax.spines[side].set_visible(False)
    return fig, ax


def save_original(display: np.ndarray, out: Path) -> Path:
    fig, ax = _bare_axes()
    ax.imshow(display, cmap="gray", vmin=0, vmax=1)
    ax.set_title("Model input (grayscale, 224x224)", fontsize=10, color=INK)
    fig.savefig(out, dpi=200, bbox_inches="tight")
    plt.close(fig)
    return out


def save_heatmap(cam: np.ndarray, out: Path) -> Path:
    fig, ax = _bare_axes()
    image = ax.imshow(cam, cmap="inferno", vmin=0, vmax=1)
    ax.set_title("Class activation map (normalised)", fontsize=10, color=INK)
    bar = fig.colorbar(image, ax=ax, fraction=0.046, pad=0.03)
    bar.set_label("relative activation", fontsize=9, color=INK_SOFT)
    bar.ax.tick_params(labelsize=8, colors=INK_SOFT)
    fig.savefig(out, dpi=200, bbox_inches="tight")
    plt.close(fig)
    return out


def save_overlay(display: np.ndarray, cam: np.ndarray, out: Path,
                 probability: float, boxes=None, title: str | None = None) -> Path:
    fig, ax = _bare_axes(5.0)
    ax.imshow(display, cmap="gray", vmin=0, vmax=1)
    ax.imshow(cam, cmap="inferno", alpha=0.42, vmin=0, vmax=1)
    if boxes:
        for x1, y1, x2, y2 in boxes:
            ax.add_patch(plt.Rectangle(
                (x1, y1), x2 - x1, y2 - y1, fill=False,
                edgecolor=BOX_COLOR, linewidth=2.0,
            ))
        ax.plot([], [], color=BOX_COLOR, linewidth=2.0,
                label="adjudicated bounding box")
        ax.legend(loc="lower right", fontsize=8, frameon=True,
                  facecolor="white", framealpha=0.85, edgecolor="none")
    ax.set_title(
        title or f"CAM overlay — p(opacity) = {probability:.3f}",
        fontsize=10, color=INK,
    )
    fig.savefig(out, dpi=200, bbox_inches="tight")
    plt.close(fig)
    return out


def save_boxes_only(display: np.ndarray, boxes, out: Path) -> Path:
    fig, ax = _bare_axes()
    ax.imshow(display, cmap="gray", vmin=0, vmax=1)
    for x1, y1, x2, y2 in boxes:
        ax.add_patch(plt.Rectangle(
            (x1, y1), x2 - x1, y2 - y1, fill=False,
            edgecolor=BOX_COLOR, linewidth=2.0,
        ))
    ax.set_title("Adjudicated bounding boxes (ground truth)", fontsize=10,
                 color=INK)
    fig.savefig(out, dpi=200, bbox_inches="tight")
    plt.close(fig)
    return out


# ---------------------------------------------------------------------------
# exploratory overlap statistics
# ---------------------------------------------------------------------------


def overlap_stats(cam: np.ndarray, boxes, size: int) -> dict:
    """Exploratory agreement between the CAM and the ground-truth boxes.

    Two deliberately simple, pre-declared measures — neither is tuned on any
    split and neither is a measure of diagnostic performance:

    * **pointing hit** — is the single strongest CAM pixel inside a box?
      Threshold-free.
    * **IoU@0.5max** — IoU between the box union and the CAM binarised at
      0.5 of its own maximum, the standard CAM localisation rule.
    """
    if not boxes:
        return {}
    gt = np.zeros((size, size), dtype=bool)
    for x1, y1, x2, y2 in boxes:
        gt[int(max(y1, 0)):int(min(y2, size)),
           int(max(x1, 0)):int(min(x2, size))] = True

    mask = cam >= CAM_BINARY_THRESHOLD
    intersection = int(np.logical_and(mask, gt).sum())
    union = int(np.logical_or(mask, gt).sum())
    peak_y, peak_x = np.unravel_index(int(np.argmax(cam)), cam.shape)

    return {
        "binarisation_rule": f"cam >= {CAM_BINARY_THRESHOLD} x max(cam) "
                             "(fixed in advance, not tuned)",
        "iou": round(intersection / union, 4) if union else 0.0,
        "cam_area_fraction": round(float(mask.mean()), 4),
        "box_area_fraction": round(float(gt.mean()), 4),
        "intersection_over_cam": round(intersection / int(mask.sum()), 4)
                                 if mask.sum() else 0.0,
        "pointing_hit": bool(gt[peak_y, peak_x]),
        "cam_peak_xy": [int(peak_x), int(peak_y)],
    }


# ---------------------------------------------------------------------------


def run(
    dicom_path: str | Path,
    out_dir: Path,
    *,
    model=None,
    device=None,
    checkpoint_path: Path | None = None,
    threshold: float = DEFAULT_THRESHOLD,
    with_boxes: bool = True,
) -> dict:
    """Produce original / heatmap / overlay (+ boxes) and result.json."""
    dicom_path = Path(dicom_path)
    config = get_preprocess_config()
    size = config.image_size

    if model is None:
        model, _, device = load_model(checkpoint_path)
    device = device or next(model.parameters()).device
    checkpoint_path = Path(checkpoint_path or
                           get_training_config().run_dir / "best.pt")

    tensor = preprocess_dicom(dicom_path, config).unsqueeze(0).to(device)
    cam, probability = compute_cam(model, tensor, size)
    display = to_display_image(tensor)
    label = int(probability >= threshold)

    sop_uid = dicom_path.stem
    boxes = scaled_boxes(sop_uid, size) if with_boxes else []

    case_dir = out_dir / sop_uid
    case_dir.mkdir(parents=True, exist_ok=True)
    written = [
        save_original(display, case_dir / "original.png"),
        save_heatmap(cam, case_dir / "heatmap.png"),
        save_overlay(display, cam, case_dir / "overlay.png", probability),
    ]
    if boxes:
        written.append(save_boxes_only(display, boxes,
                                       case_dir / "ground_truth_boxes.png"))
        written.append(save_overlay(
            display, cam, case_dir / "overlay_with_boxes.png", probability,
            boxes=boxes,
            title=f"CAM + adjudicated boxes — p(opacity) = {probability:.3f}",
        ))

    from src.models import CLASS_NAMES

    result = {
        "input_path": str(dicom_path),
        "sop_instance_uid": sop_uid,
        "probability": round(probability, 6),
        "threshold": threshold,
        "predicted_label": label,
        "predicted_class": CLASS_NAMES[label],
        "heatmap_size": [int(cam.shape[0]), int(cam.shape[1])],
        "heatmap_native_grid": [7, 7],
        "model_checkpoint": str(checkpoint_path),
        "method": "CAM (Zhou et al. 2016): GAP weights x last conv feature map",
        "caveat": "The map shows image regions associated with the model's "
                  "decision. It is not evidence of disease localisation and "
                  "not a diagnostic output.",
        "ground_truth_boxes": len(boxes),
        "files": [str(path.relative_to(out_dir)) for path in written],
    }
    stats = overlap_stats(cam, boxes, size)
    if stats:
        result["cam_box_agreement"] = stats

    (case_dir / "result.json").write_text(
        json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    result["_case_dir"] = case_dir
    return result


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    base = get_training_config()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dicom", required=True, nargs="+",
                        help="one or more .dcm paths")
    parser.add_argument("--out", type=Path, default=base.run_dir / "cam")
    parser.add_argument("--checkpoint", type=Path, default=None)
    parser.add_argument("--threshold", type=float, default=DEFAULT_THRESHOLD)
    parser.add_argument("--device", default=None)
    parser.add_argument("--no-boxes", action="store_true",
                        help="skip the ground-truth box overlays")
    args = parser.parse_args()

    device = pick_device(args.device)
    model, _, device = load_model(args.checkpoint, device)
    print(f"PulmoAI - CAM ({device}, checkpoint "
          f"{args.checkpoint or base.run_dir / 'best.pt'})")

    for path in args.dicom:
        result = run(path, args.out, model=model, device=device,
                     checkpoint_path=args.checkpoint,
                     threshold=args.threshold, with_boxes=not args.no_boxes)
        case_dir = result.pop("_case_dir")
        line = (f"  {result['sop_instance_uid'][-12:]}  "
                f"p={result['probability']:.4f}  "
                f"{result['predicted_class']}")
        if "cam_box_agreement" in result:
            stats = result["cam_box_agreement"]
            line += (f"  | boxes={result['ground_truth_boxes']} "
                     f"IoU={stats['iou']:.3f} "
                     f"pointing_hit={stats['pointing_hit']}")
        print(line)
        print(f"      -> {case_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
