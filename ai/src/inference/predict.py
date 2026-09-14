"""Inference on a single DICOM with the trained PulmoNet-7M checkpoint.

    cd D:\\pulmo_ai\\ai
    ..\\ai\\.venv\\Scripts\\python.exe -m src.inference.predict --dicom "<path>"

or, from the repository root:

    ai\\.venv\\Scripts\\python.exe ai\\src\\inference\\predict.py --dicom "<path>"

The preprocessing is **not reimplemented here**: this module calls the very
functions the training Dataset calls (``dicom_to_float_tensor`` →
``resize_image`` → ``normalize_intensity`` from ``src.data.preprocessing``), in
the same order and with the same ``PreprocessConfig``, with augmentation off —
exactly the evaluation path. ``test_inference.py`` asserts tensor equality
against ``RsnaPneumoniaDataset`` so the two can never drift apart.

Nothing is trained, no checkpoint is written, the dataset is only read.
"""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass
from pathlib import Path

import pydicom
import torch

if __package__ in (None, ""):  # allow running the file directly
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from src.config import (  # noqa: E402
    PreprocessConfig,
    get_preprocess_config,
    get_training_config,
)
from src.data.preprocessing import (  # noqa: E402
    dicom_to_float_tensor,
    normalize_intensity,
    resize_image,
)
from src.models import CLASS_NAMES, build_model  # noqa: E402

DEFAULT_THRESHOLD = 0.5  # fixed on the validation split, before the test run


@dataclass(frozen=True)
class Prediction:
    """Result of one inference call."""

    path: str
    probability: float
    predicted_class: str
    predicted_label: int
    threshold: float
    checkpoint: str
    device: str

    def as_dict(self) -> dict:
        return {
            "input_path": self.path,
            "probability": round(self.probability, 6),
            "predicted_label": self.predicted_label,
            "predicted_class": self.predicted_class,
            "threshold": self.threshold,
            "model_checkpoint": self.checkpoint,
            "device": self.device,
        }

    def __str__(self) -> str:
        return (
            f"Image       : {self.path}\n"
            f"Probability : {self.probability:.4f}\n"
            f"Prediction  : {self.predicted_class}\n"
            f"Threshold   : {self.threshold:.2f}"
        )


def default_checkpoint() -> Path:
    config = get_training_config()
    return config.run_dir / "best.pt"


def pick_device(requested: str | None = None) -> torch.device:
    if requested:
        return torch.device(requested)
    return torch.device("cuda" if torch.cuda.is_available() else "cpu")


def preprocess_dicom(
    path: str | Path, config: PreprocessConfig | None = None
) -> torch.Tensor:
    """DICOM file -> ``[1, S, S]`` tensor, identical to the evaluation path."""
    config = config or get_preprocess_config()
    ds = pydicom.dcmread(str(path))
    image = dicom_to_float_tensor(
        ds.pixel_array,
        photometric_interpretation=getattr(
            ds, "PhotometricInterpretation", "MONOCHROME2"
        ),
        bits_stored=int(getattr(ds, "BitsStored", 8)),
    )
    image = resize_image(image, config.image_size)
    # no augmentation: this is the eval path (train_mode=False in the Dataset)
    return normalize_intensity(image, config)


def load_model(
    checkpoint_path: str | Path | None = None,
    device: torch.device | None = None,
) -> tuple[torch.nn.Module, dict, torch.device]:
    """Load ``best.pt`` in eval mode. The checkpoint file is only read."""
    checkpoint_path = Path(checkpoint_path or default_checkpoint())
    if not checkpoint_path.is_file():
        raise FileNotFoundError(
            f"Checkpoint not found: {checkpoint_path}. Train the model first."
        )
    device = device or pick_device()
    base = get_training_config()

    checkpoint = torch.load(str(checkpoint_path), map_location=device,
                            weights_only=False)
    saved = checkpoint.get("config", {})
    model = build_model(
        dropout=float(saved.get("dropout", base.dropout)),
        spatial_dropout=float(saved.get("spatial_dropout", base.spatial_dropout)),
        image_size=int(saved.get("image_size", base.image_size)),
    ).to(device)
    model.load_state_dict(checkpoint["model_state"])
    model.eval()
    return model, checkpoint, device


@torch.inference_mode()
def predict_dicom(
    dicom_path: str | Path,
    *,
    model: torch.nn.Module | None = None,
    checkpoint_path: str | Path | None = None,
    device: torch.device | None = None,
    threshold: float = DEFAULT_THRESHOLD,
) -> Prediction:
    """Run the trained model on one DICOM file."""
    checkpoint_path = Path(checkpoint_path or default_checkpoint())
    if model is None:
        model, _, device = load_model(checkpoint_path, device)
    else:
        device = device or next(model.parameters()).device

    tensor = preprocess_dicom(dicom_path).unsqueeze(0).to(device)
    logit = model(tensor)
    probability = float(torch.sigmoid(logit).squeeze())
    label = int(probability >= threshold)

    return Prediction(
        path=str(dicom_path),
        probability=probability,
        predicted_class=CLASS_NAMES[label],
        predicted_label=label,
        threshold=threshold,
        checkpoint=str(checkpoint_path),
        device=str(device),
    )


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dicom", required=True, help="path to a .dcm file")
    parser.add_argument("--checkpoint", default=None,
                        help="default: <experiment>/best.pt")
    parser.add_argument("--threshold", type=float, default=DEFAULT_THRESHOLD,
                        help="decision threshold, fixed on validation (0.5)")
    parser.add_argument("--device", default=None)
    parser.add_argument("--json", action="store_true",
                        help="print the result as JSON")
    args = parser.parse_args()

    result = predict_dicom(
        args.dicom,
        checkpoint_path=args.checkpoint,
        device=pick_device(args.device),
        threshold=args.threshold,
    )
    print(json.dumps(result.as_dict(), indent=2) if args.json else result)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
