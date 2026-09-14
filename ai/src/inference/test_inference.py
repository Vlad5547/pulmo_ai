"""Smoke tests for the inference pipeline.

    cd D:\\pulmo_ai\\ai
    ..\\ai\\.venv\\Scripts\\python.exe -m src.inference.test_inference
    ..\\ai\\.venv\\Scripts\\python.exe -m pytest src/inference/test_inference.py -v

Read-only: loads the existing checkpoint, reads a handful of DICOM files, runs
no training and writes nothing.
"""

from __future__ import annotations

import sys
from pathlib import Path

import pandas as pd
import torch

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from src.config import (  # noqa: E402
    SPLIT_CSV,
    get_dataset_paths,
    get_preprocess_config,
    get_training_config,
)
from src.data.dataset import RsnaPneumoniaDataset  # noqa: E402
from src.inference.predict import (  # noqa: E402
    DEFAULT_THRESHOLD,
    default_checkpoint,
    load_model,
    predict_dicom,
    preprocess_dicom,
)

CONFIG = get_preprocess_config()
PATHS = get_dataset_paths()


def _sample_paths(n: int = 3, split: str = "test") -> list[Path]:
    frame = pd.read_csv(PATHS.processed_dir / SPLIT_CSV)
    rows = frame[frame["split"] == split].head(n)
    return [PATHS.images_dir / row.relative_path for row in rows.itertuples()]


def test_checkpoint_exists_and_loads() -> None:
    path = default_checkpoint()
    assert path.is_file(), f"{path} is missing"

    model, checkpoint, device = load_model(path)
    assert not model.training, "model must be in eval mode"
    assert checkpoint["epoch"] == 13
    counts = model.parameter_counts()
    assert counts["total"] == 7_065_953
    assert device.type in ("cuda", "cpu")


def test_preprocessing_matches_the_training_dataset_exactly() -> None:
    """The inference path must produce the same tensor as the Dataset."""
    dataset = RsnaPneumoniaDataset(split="test", train_mode=False)
    row = dataset.frame.iloc[0]
    from_dataset = dataset[0]["image"]
    from_inference = preprocess_dicom(PATHS.images_dir / row["relative_path"])

    assert from_inference.shape == from_dataset.shape
    assert torch.equal(from_inference, from_dataset), (
        "inference preprocessing drifted from the Dataset preprocessing"
    )


def test_single_dicom_output_shape_and_range() -> None:
    model, _, device = load_model()
    path = _sample_paths(1)[0]

    tensor = preprocess_dicom(path)
    assert tensor.shape == (1, CONFIG.image_size, CONFIG.image_size)
    assert tensor.dtype == torch.float32
    assert torch.isfinite(tensor).all()

    with torch.inference_mode():
        logit = model(tensor.unsqueeze(0).to(device))
    assert logit.shape == (1,)
    assert torch.isfinite(logit).all()


def test_probability_is_a_valid_probability() -> None:
    model, _, device = load_model()
    for path in _sample_paths(3):
        result = predict_dicom(path, model=model, device=device)
        assert 0.0 <= result.probability <= 1.0
        assert result.predicted_label in (0, 1)
        assert result.threshold == DEFAULT_THRESHOLD
        assert (result.predicted_label == 1) == (
            result.probability >= DEFAULT_THRESHOLD
        )
        assert result.predicted_class in (
            "No Pneumonia", "Pneumonia / Lung Opacity"
        )


def test_predictions_reproduce_the_stored_evaluation() -> None:
    """Re-running the model on a stored image must give the stored probability.

    Reads predictions_test.csv only to compare; nothing is re-evaluated or
    re-tuned, and the file is not modified.
    """
    run_dir = get_training_config().run_dir
    stored = pd.read_csv(run_dir / "predictions_test.csv").head(3)
    dataset = RsnaPneumoniaDataset(split="test", train_mode=False)
    lookup = dataset.frame.set_index("sop_instance_uid")["relative_path"]

    model, _, device = load_model()
    for row in stored.itertuples():
        path = PATHS.images_dir / lookup[row.sop_instance_uid]
        result = predict_dicom(path, model=model, device=device)
        assert abs(result.probability - row.probability) < 1e-4, (
            f"{row.sop_instance_uid}: {result.probability:.6f} != "
            f"{row.probability:.6f}"
        )


def test_deterministic_between_calls() -> None:
    model, _, device = load_model()
    path = _sample_paths(1)[0]
    first = predict_dicom(path, model=model, device=device)
    second = predict_dicom(path, model=model, device=device)
    assert first.probability == second.probability


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    tests = [value for name, value in sorted(globals().items())
             if name.startswith("test_") and callable(value)]
    failures = 0
    print(f"Running {len(tests)} inference checks "
          f"(checkpoint {default_checkpoint().name})\n")
    for test in tests:
        try:
            test()
        except Exception as error:  # noqa: BLE001
            failures += 1
            print(f"  FAIL  {test.__name__}: {error}")
        else:
            print(f"  ok    {test.__name__}")
    print(f"\n{len(tests) - failures}/{len(tests)} passed")
    print("No training, no evaluation, no checkpoint write.")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
