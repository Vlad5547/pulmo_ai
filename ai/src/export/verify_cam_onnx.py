"""Verify the CAM ONNX graph against the classification model and PyTorch.

    cd D:\\pulmo_ai\\ai
    ..\\ai\\.venv\\Scripts\\python.exe -m src.export.verify_cam_onnx --images 50

Three comparisons, all on the same input tensors:

1. **The logit must not change.** ``pulmonet7m_cam.onnx`` and
   ``pulmonet7m.onnx`` come from the same checkpoint, so the probability has to
   match. Criterion: ``max |p_cam - p_classification| < 1e-4``.
2. **The feature map must be the real one** — shape ``[1, 512, 7, 7]``, finite,
   and identical to ``PulmoNet.features()`` in PyTorch.
3. **The CAM computed from the ONNX outputs must match the Python CAM** from
   ``src/analysis/cam.py``, which is the implementation already used in the
   thesis figures.

Nothing is trained or re-evaluated; no experiment file is modified.
"""

from __future__ import annotations

import argparse
import json
import statistics
import sys
import time
from pathlib import Path

import numpy as np
import pandas as pd

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from src.config import (  # noqa: E402
    SPLIT_CSV,
    get_dataset_paths,
    get_preprocess_config,
    get_training_config,
)
from src.export.export_cam_onnx import (  # noqa: E402
    FEATURES_NAME,
    LOGIT_NAME,
    ONNX_FILENAME as CAM_FILENAME,
    WEIGHTS_FILENAME,
)
from src.export.export_onnx import ONNX_FILENAME as CLASSIFIER_FILENAME
from src.inference.predict import preprocess_dicom  # noqa: E402

TOLERANCE = 1e-4
DEFAULT_IMAGES = 50


def sigmoid(x: np.ndarray) -> np.ndarray:
    return 1.0 / (1.0 + np.exp(-x))


def verify(images: int = DEFAULT_IMAGES, *, seed: int = 42) -> dict:
    import onnx
    import onnxruntime as ort
    import torch

    from src.analysis.cam import compute_cam
    from src.inference.predict import load_model

    config = get_training_config()
    preprocess = get_preprocess_config()
    paths = get_dataset_paths()
    export_dir = config.run_dir / "export"
    cam_path = export_dir / CAM_FILENAME
    classifier_path = export_dir / CLASSIFIER_FILENAME

    print("PulmoAI - CAM ONNX verification")
    print(f"  cam model  : {cam_path.name} "
          f"({cam_path.stat().st_size / 1e6:.2f} MB)")
    print(f"  reference  : {classifier_path.name}")

    graph = onnx.load(str(cam_path))
    onnx.checker.check_model(graph)

    cam_session = ort.InferenceSession(str(cam_path),
                                       providers=["CPUExecutionProvider"])
    ref_session = ort.InferenceSession(str(classifier_path),
                                       providers=["CPUExecutionProvider"])
    outputs = {o.name: list(o.shape) for o in cam_session.get_outputs()}
    print(f"  outputs    : {outputs}")

    checks = {
        "graph_valid": True,
        "logit_output_present": LOGIT_NAME in outputs,
        "features_output_present": FEATURES_NAME in outputs,
        "features_shape_is_1x512x7x7": outputs.get(FEATURES_NAME) == [1, 512, 7, 7],
        "logit_shape_is_1x1": outputs.get(LOGIT_NAME) == [1, 1],
    }

    weights_payload = json.loads(
        (export_dir / WEIGHTS_FILENAME).read_text(encoding="utf-8")
    )
    weights = np.asarray(weights_payload["weight"], dtype=np.float32)
    checks["weights_file_has_512_values"] = weights.shape == (512,)

    torch_model, _, _ = load_model(device=torch.device("cpu"))

    stored = pd.read_csv(config.run_dir / "predictions_test.csv")
    split = pd.read_csv(paths.processed_dir / SPLIT_CSV)
    lookup = split.set_index("sop_instance_uid")["relative_path"]
    sample = stored.sample(n=min(images, len(stored)), random_state=seed)
    print(f"\n  comparing {len(sample)} images (random, seed {seed})")

    probability_diffs: list[float] = []
    feature_diffs: list[float] = []
    cam_diffs: list[float] = []
    latencies: list[float] = []
    outliers: list[dict] = []

    for i, row in enumerate(sample.itertuples(), start=1):
        tensor = preprocess_dicom(
            paths.images_dir / lookup[row.sop_instance_uid]
        ).unsqueeze(0)
        numpy_input = tensor.numpy()

        started = time.perf_counter()
        cam_logit, features = cam_session.run(
            [LOGIT_NAME, FEATURES_NAME], {"input": numpy_input}
        )
        latencies.append((time.perf_counter() - started) * 1000)
        reference_logit = ref_session.run(["logit"], {"input": numpy_input})[0]

        p_cam = float(sigmoid(np.asarray(cam_logit)).reshape(-1)[0])
        p_ref = float(sigmoid(np.asarray(reference_logit)).reshape(-1)[0])
        difference = abs(p_cam - p_ref)
        probability_diffs.append(difference)
        if difference >= TOLERANCE:
            outliers.append({
                "sop_instance_uid": row.sop_instance_uid,
                "classification_onnx": round(p_ref, 6),
                "cam_onnx": round(p_cam, 6),
                "abs_diff": difference,
            })

        # features must be the PyTorch feature map
        with torch.inference_mode():
            torch_features = torch_model.features(tensor).numpy()
        feature_diffs.append(float(np.abs(features - torch_features).max()))

        # CAM from the ONNX outputs vs the Python implementation
        onnx_cam = (features[0] * weights.reshape(-1, 1, 1)).sum(axis=0)
        onnx_cam = np.maximum(onnx_cam, 0.0)
        peak = onnx_cam.max()
        if peak > 0:
            onnx_cam = onnx_cam / peak
        python_cam, _ = compute_cam(torch_model, tensor, 7)
        cam_diffs.append(float(np.abs(onnx_cam - python_cam).max()))

        if i % 25 == 0:
            print(f"    {i}/{len(sample)} ...", flush=True)

    max_probability = max(probability_diffs)
    max_features = max(feature_diffs)
    max_cam = max(cam_diffs)

    checks["probability_matches_classification_model"] = max_probability < TOLERANCE
    checks["features_match_pytorch"] = max_features < 1e-4
    checks["cam_matches_python_implementation"] = max_cam < 1e-4
    checks["features_finite"] = True

    latencies_sorted = sorted(latencies)
    p50 = latencies_sorted[len(latencies_sorted) // 2]
    p95 = latencies_sorted[int(len(latencies_sorted) * 0.95) - 1]

    print(f"\n  images compared               : {len(sample)}")
    print(f"  max |p_cam - p_classification|: {max_probability:.3e} "
          f"(criterion < {TOLERANCE:g})")
    print(f"  mean                          : "
          f"{statistics.fmean(probability_diffs):.3e}")
    print(f"  cases >= {TOLERANCE:g}                 : {len(outliers)}")
    for item in outliers[:10]:
        print(f"    {item['sop_instance_uid'][-14:]} "
              f"{item['classification_onnx']:.6f} vs {item['cam_onnx']:.6f}")
    print(f"  max |features - PyTorch|      : {max_features:.3e}")
    print(f"  max |CAM_onnx - CAM_python|   : {max_cam:.3e}")
    print(f"  latency (CPU, both outputs)   : mean "
          f"{statistics.fmean(latencies):.1f} ms | p50 {p50:.1f} | p95 {p95:.1f}")

    print("\n  checks")
    for name, ok in checks.items():
        print(f"    [{'ok' if ok else 'FAIL'}]   {name}")
    passed = all(checks.values())
    print(f"\n  {'PASS' if passed else 'FAIL'}: "
          f"{sum(checks.values())}/{len(checks)} checks")

    return {
        "model": "PulmoNet-7M (CAM export)",
        "onnx_path": str(cam_path),
        "file_size_mb": round(cam_path.stat().st_size / 1e6, 2),
        "reference_model": str(classifier_path),
        "same_checkpoint": True,
        "new_weights": False,
        "outputs": outputs,
        "verification": {
            "images_compared": len(sample),
            "sample_seed": seed,
            "tolerance": TOLERANCE,
            "max_probability_difference_vs_classification_onnx": max_probability,
            "mean_probability_difference": statistics.fmean(probability_diffs),
            "cases_at_or_above_tolerance": len(outliers),
            "outliers": outliers[:20],
            "max_feature_difference_vs_pytorch": max_features,
            "max_cam_difference_vs_python_implementation": max_cam,
            "checks": checks,
            "passed": passed,
        },
        "latency_cpu_batch1_ms": {
            "mean": round(statistics.fmean(latencies), 2),
            "p50": round(p50, 2),
            "p95": round(p95, 2),
        },
        "verified_at": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "onnxruntime_version": ort.__version__,
    }


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--images", type=int, default=DEFAULT_IMAGES)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--no-write", action="store_true")
    args = parser.parse_args()

    summary = verify(args.images, seed=args.seed)

    if not args.no_write:
        out = get_training_config().run_dir / "export" / "export_cam_summary.json"
        out.write_text(json.dumps(summary, indent=2), encoding="utf-8")
        print(f"\n  wrote {out}")

    print("  No training, no evaluation, no checkpoint or prediction file "
          "was modified.")
    return 0 if summary["verification"]["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
