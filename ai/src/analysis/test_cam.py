"""Smoke tests for the CAM visualisation.

    cd D:\\pulmo_ai\\ai
    ..\\ai\\.venv\\Scripts\\python.exe -m src.analysis.test_cam
    ..\\ai\\.venv\\Scripts\\python.exe -m pytest src/analysis/test_cam.py -v

Writes only into a temporary directory; the experiment folder, the checkpoint
and the dataset are untouched.
"""

from __future__ import annotations

import json
import sys
import tempfile
from pathlib import Path

import numpy as np
import pandas as pd
import torch

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from src.analysis.cam import (  # noqa: E402
    CAM_BINARY_THRESHOLD,
    compute_cam,
    overlap_stats,
    run,
    scaled_boxes,
    to_display_image,
)
from src.config import (  # noqa: E402
    SPLIT_CSV,
    get_dataset_paths,
    get_preprocess_config,
)
from src.inference.predict import load_model, preprocess_dicom  # noqa: E402

CONFIG = get_preprocess_config()
PATHS = get_dataset_paths()


def _row(class_label: str):
    frame = pd.read_csv(PATHS.processed_dir / SPLIT_CSV)
    frame = frame[(frame["split"] == "test") &
                  (frame["class_label"] == class_label)]
    return frame.iloc[0]


def test_cam_shape_range_and_finiteness() -> None:
    model, _, device = load_model()
    row = _row("Lung Opacity")
    tensor = preprocess_dicom(PATHS.images_dir / row.relative_path)
    cam, probability = compute_cam(model, tensor.unsqueeze(0).to(device),
                                   CONFIG.image_size)

    assert cam.shape == (CONFIG.image_size, CONFIG.image_size)
    assert np.isfinite(cam).all(), "CAM contains NaN or Inf"
    assert cam.min() >= 0.0 and cam.max() <= 1.0
    assert abs(cam.max() - 1.0) < 1e-6, "CAM should be normalised by its maximum"
    assert 0.0 <= probability <= 1.0


def test_cam_probability_matches_the_forward_pass() -> None:
    model, _, device = load_model()
    row = _row("Lung Opacity")
    tensor = preprocess_dicom(PATHS.images_dir / row.relative_path)
    batch = tensor.unsqueeze(0).to(device)

    _, cam_probability = compute_cam(model, batch, CONFIG.image_size)
    with torch.inference_mode():
        direct = float(torch.sigmoid(model(batch)).squeeze())
    assert abs(cam_probability - direct) < 1e-5, (
        "CAM head recomputation disagrees with model.forward"
    )


def test_display_image_is_denormalised_to_unit_range() -> None:
    row = _row("Normal")
    tensor = preprocess_dicom(PATHS.images_dir / row.relative_path)
    display = to_display_image(tensor)
    assert display.shape == (CONFIG.image_size, CONFIG.image_size)
    assert np.isfinite(display).all()
    assert display.min() >= 0.0 and display.max() <= 1.0


def test_png_files_and_result_json_are_written() -> None:
    model, _, device = load_model()
    row = _row("Lung Opacity")
    with tempfile.TemporaryDirectory() as tmp:
        out = Path(tmp)
        result = run(PATHS.images_dir / row.relative_path, out,
                     model=model, device=device)
        case_dir = result.pop("_case_dir")

        for name in ("original.png", "heatmap.png", "overlay.png",
                     "ground_truth_boxes.png", "overlay_with_boxes.png",
                     "result.json"):
            path = case_dir / name
            assert path.is_file(), f"{name} was not written"
            assert path.stat().st_size > 1000, f"{name} looks empty"

        payload = json.loads((case_dir / "result.json").read_text(
            encoding="utf-8"))
        assert payload["heatmap_size"] == [CONFIG.image_size, CONFIG.image_size]
        assert 0.0 <= payload["probability"] <= 1.0
        assert payload["threshold"] == 0.5
        assert payload["model_checkpoint"].endswith("best.pt")
        assert "not evidence of disease localisation" in payload["caveat"]


def test_negative_sample_has_no_ground_truth_boxes() -> None:
    row = _row("Normal")
    boxes = scaled_boxes(Path(row.relative_path).stem, CONFIG.image_size)
    assert boxes == []


def test_overlap_stats_are_well_formed() -> None:
    size = CONFIG.image_size
    cam = np.zeros((size, size), dtype=float)
    cam[50:150, 50:150] = 1.0
    boxes = [(50.0, 50.0, 150.0, 150.0)]
    stats = overlap_stats(cam, boxes, size)

    assert abs(stats["iou"] - 1.0) < 1e-6, "identical regions must give IoU 1"
    assert stats["pointing_hit"] is True
    assert str(CAM_BINARY_THRESHOLD) in stats["binarisation_rule"]

    disjoint = overlap_stats(cam, [(0.0, 0.0, 20.0, 20.0)], size)
    assert disjoint["iou"] == 0.0
    assert disjoint["pointing_hit"] is False


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    tests = [value for name, value in sorted(globals().items())
             if name.startswith("test_") and callable(value)]
    failures = 0
    print(f"Running {len(tests)} CAM checks\n")
    for test in tests:
        try:
            test()
        except Exception as error:  # noqa: BLE001
            failures += 1
            print(f"  FAIL  {test.__name__}: {error}")
        else:
            print(f"  ok    {test.__name__}")
    print(f"\n{len(tests) - failures}/{len(tests)} passed")
    print("No training, no evaluation; only a temporary directory was written.")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
