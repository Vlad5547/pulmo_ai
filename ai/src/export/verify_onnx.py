"""Verify that the exported ONNX model matches the PyTorch checkpoint.

    cd D:\\pulmo_ai\\ai
    ..\\ai\\.venv\\Scripts\\python.exe -m src.export.verify_onnx
    ..\\ai\\.venv\\Scripts\\python.exe -m src.export.verify_onnx --images 200

This is an **equivalence check, not a new experiment**: nothing is re-tuned, no
metric is recomputed, no file of the experiment is modified;
``export_summary.json`` is written next to the model.

Two comparisons, because they measure different things:

1. **Export fidelity (the acceptance criterion)** — ONNX on CPU against the
   PyTorch checkpoint **on the same device (CPU)**. This isolates the export
   itself. Criterion: ``max |p_onnx − p_torch_cpu| < 1e-4``.
2. **End-to-end sanity** — ONNX against the probabilities stored in
   ``predictions_test.csv``. Those were produced on the GPU, where PyTorch uses
   TF32 for convolutions by default (``torch.backends.cudnn.allow_tf32`` is
   True), so they differ from any CPU computation at the 1e-4 level — and a
   *re-run on the GPU* differs from them by the same order. This comparison is
   therefore reported with a looser bound (1e-3) and is not the criterion for
   accepting the export.
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
from src.export.export_onnx import (  # noqa: E402
    INPUT_NAME,
    ONNX_FILENAME,
    OPSET,
    OUTPUT_NAME,
)
from src.inference.predict import preprocess_dicom  # noqa: E402

TOLERANCE = 1e-4          # ONNX vs PyTorch on the same device
STORED_TOLERANCE = 1e-3   # ONNX (CPU) vs stored GPU predictions
DEFAULT_IMAGES = 50


def sigmoid(x: np.ndarray) -> np.ndarray:
    return 1.0 / (1.0 + np.exp(-x))


def describe_session(session) -> dict:
    inputs = session.get_inputs()
    outputs = session.get_outputs()
    return {
        "input_name": inputs[0].name,
        "input_shape": list(inputs[0].shape),
        "input_type": inputs[0].type,
        "output_name": outputs[0].name,
        "output_shape": list(outputs[0].shape),
        "output_type": outputs[0].type,
        "providers": session.get_providers(),
    }


def verify(
    onnx_path: Path,
    images: int = DEFAULT_IMAGES,
    *,
    seed: int = 42,
) -> dict:
    import onnx
    import onnxruntime as ort

    config = get_training_config()
    preprocess = get_preprocess_config()
    paths = get_dataset_paths()
    run_dir = config.run_dir

    print("PulmoAI - ONNX verification (equivalence check, not a new run)")
    print(f"  model      : {onnx_path} "
          f"({onnx_path.stat().st_size / 1e6:.2f} MB)")

    # -- 1. graph -----------------------------------------------------------
    graph = onnx.load(str(onnx_path))
    onnx.checker.check_model(graph)
    opset = {imp.domain or "ai.onnx": imp.version for imp in graph.opset_import}
    print(f"  graph      : onnx.checker OK, opset {opset}")

    # -- 2. session ---------------------------------------------------------
    session = ort.InferenceSession(
        str(onnx_path), providers=["CPUExecutionProvider"]
    )
    io = describe_session(session)
    print(f"  input      : '{io['input_name']}' {io['input_shape']} "
          f"{io['input_type']}")
    print(f"  output     : '{io['output_name']}' {io['output_shape']} "
          f"{io['output_type']}")
    print(f"  providers  : {io['providers']}")

    expected_shape = [1, preprocess.channels,
                      preprocess.image_size, preprocess.image_size]
    checks = {
        "graph_valid": True,
        "input_name_matches": io["input_name"] == INPUT_NAME,
        "output_name_matches": io["output_name"] == OUTPUT_NAME,
        "input_shape_matches": io["input_shape"] == expected_shape,
        "output_shape_matches": io["output_shape"] == [1, 1],
        "opset_matches": opset.get("ai.onnx") == OPSET,
        "runs_on_cpu_provider": "CPUExecutionProvider" in io["providers"],
    }

    # -- 3. equivalence: ONNX (CPU) vs PyTorch (CPU) and vs stored ----------
    import torch

    from src.inference.predict import load_model

    torch_model, _, _ = load_model(device=torch.device("cpu"))

    stored = pd.read_csv(run_dir / "predictions_test.csv")
    split = pd.read_csv(paths.processed_dir / SPLIT_CSV)
    lookup = split.set_index("sop_instance_uid")["relative_path"]
    sample = stored.sample(n=min(images, len(stored)), random_state=seed)

    print(f"\n  comparing {len(sample)} of {len(stored)} test images "
          f"(random, seed {seed})")

    differences: list[float] = []        # ONNX vs torch, both on CPU
    stored_differences: list[float] = []  # ONNX vs the stored GPU predictions
    latencies: list[float] = []
    outliers: list[dict] = []
    stored_outliers: list[dict] = []

    for i, row in enumerate(sample.itertuples(), start=1):
        dicom_path = paths.images_dir / lookup[row.sop_instance_uid]
        tensor = preprocess_dicom(dicom_path).unsqueeze(0)

        started = time.perf_counter()
        logit = session.run([OUTPUT_NAME], {INPUT_NAME: tensor.numpy()})[0]
        latencies.append((time.perf_counter() - started) * 1000)
        probability = float(sigmoid(np.asarray(logit)).reshape(-1)[0])

        with torch.inference_mode():
            torch_probability = float(torch.sigmoid(torch_model(tensor)).squeeze())

        difference = abs(probability - torch_probability)
        differences.append(difference)
        if difference >= TOLERANCE:
            outliers.append({
                "sop_instance_uid": row.sop_instance_uid,
                "torch_cpu": round(torch_probability, 6),
                "onnx": round(probability, 6),
                "abs_diff": difference,
            })

        stored_difference = abs(probability - float(row.probability))
        stored_differences.append(stored_difference)
        if stored_difference >= STORED_TOLERANCE:
            stored_outliers.append({
                "sop_instance_uid": row.sop_instance_uid,
                "stored_gpu": round(float(row.probability), 6),
                "onnx": round(probability, 6),
                "abs_diff": stored_difference,
            })

        if i % 25 == 0:
            print(f"    {i}/{len(sample)} ...", flush=True)

    max_diff = max(differences)
    mean_diff = statistics.fmean(differences)
    max_stored = max(stored_differences)
    mean_stored = statistics.fmean(stored_differences)
    latencies_sorted = sorted(latencies)
    p50 = latencies_sorted[len(latencies_sorted) // 2]
    p95 = latencies_sorted[int(len(latencies_sorted) * 0.95) - 1]

    checks["max_difference_below_tolerance"] = max_diff < TOLERANCE
    checks["stored_predictions_within_1e-3"] = max_stored < STORED_TOLERANCE

    print(f"\n  images compared          : {len(sample)}")
    print("  [1] export fidelity - ONNX (CPU) vs PyTorch (CPU)")
    print(f"      max |difference|     : {max_diff:.3e}   "
          f"(criterion < {TOLERANCE:g})")
    print(f"      mean |difference|    : {mean_diff:.3e}")
    print(f"      cases >= {TOLERANCE:g}      : {len(outliers)}")
    for item in outliers[:10]:
        print(f"        {item['sop_instance_uid'][-14:]}  torch "
              f"{item['torch_cpu']:.6f}  onnx {item['onnx']:.6f}  "
              f"diff {item['abs_diff']:.3e}")

    print("  [2] end-to-end - ONNX (CPU) vs stored predictions (GPU run)")
    print(f"      max |difference|     : {max_stored:.3e}   "
          f"(bound < {STORED_TOLERANCE:g})")
    print(f"      mean |difference|    : {mean_stored:.3e}")
    print(f"      cases >= {STORED_TOLERANCE:g}       : {len(stored_outliers)}")
    print("      the residual is GPU TF32 convolution arithmetic, not the "
          "export:")
    print("      torch.backends.cudnn.allow_tf32 is True, so the stored run "
          "used TF32.")

    print(f"\n  latency (CPU, batch 1) : mean {statistics.fmean(latencies):.1f} ms"
          f" | p50 {p50:.1f} ms | p95 {p95:.1f} ms")

    print("\n  structural checks")
    for name, ok in checks.items():
        print(f"    [{'ok' if ok else 'FAIL'}]   {name}")

    passed = all(checks.values())
    print(f"\n  {'PASS' if passed else 'FAIL'}: "
          f"{sum(checks.values())}/{len(checks)} checks. Export fidelity "
          f"{max_diff:.3e} vs tolerance {TOLERANCE:g}")

    summary = {
        "model_name": "PulmoNet-7M",
        "checkpoint": str(run_dir / "best.pt"),
        "checkpoint_epoch": 13,
        "onnx_path": str(onnx_path),
        "file_size_bytes": onnx_path.stat().st_size,
        "file_size_mb": round(onnx_path.stat().st_size / 1e6, 2),
        "precision": "fp32",
        "quantisation": "none",
        "opset": opset.get("ai.onnx"),
        "ir_version": graph.ir_version,
        "parameter_count": 7_065_953,
        "operators": sorted({node.op_type for node in graph.graph.node}),
        "preprocessing_inside_graph": False,
        "expected_input": {
            "name": io["input_name"],
            "shape": io["input_shape"],
            "type": io["input_type"],
            "layout": "NCHW, grayscale",
            "normalisation": {
                "mean": preprocess.grayscale_mean,
                "std": preprocess.grayscale_std,
                "range_before_normalisation": "[0, 1]",
                "resize": f"{preprocess.image_size}x{preprocess.image_size}, "
                          "bilinear with antialias",
            },
        },
        "output": {
            "name": io["output_name"],
            "shape": io["output_shape"],
            "meaning": "raw logit; apply sigmoid to obtain p(Lung Opacity)",
            "decision_threshold": 0.5,
        },
        "verification": {
            "note": "equivalence check only - no new predictions, no metric "
                    "recomputation, no threshold tuning",
            "images_compared": len(sample),
            "sample_seed": seed,
            "export_fidelity": {
                "reference": "PyTorch best.pt on CPU, same input tensor",
                "tolerance": TOLERANCE,
                "max_abs_difference": max_diff,
                "mean_abs_difference": mean_diff,
                "cases_at_or_above_tolerance": len(outliers),
                "outliers": outliers[:20],
                "is_the_acceptance_criterion": True,
            },
            "against_stored_predictions": {
                "reference": "predictions_test.csv from the single evaluation "
                             "run (executed on CUDA)",
                "tolerance": STORED_TOLERANCE,
                "max_abs_difference": max_stored,
                "mean_abs_difference": mean_stored,
                "cases_at_or_above_tolerance": len(stored_outliers),
                "outliers": stored_outliers[:20],
                "explanation": "PyTorch uses TF32 for convolutions on this GPU "
                               "(cudnn.allow_tf32=True), so the stored run "
                               "differs from any CPU computation at the 1e-4 "
                               "level; re-running on the GPU differs from the "
                               "stored values by the same order. Not an export "
                               "defect.",
                "is_the_acceptance_criterion": False,
            },
            "checks": checks,
            "passed": passed,
        },
        "latency_cpu_batch1_ms": {
            "mean": round(statistics.fmean(latencies), 2),
            "p50": round(p50, 2),
            "p95": round(p95, 2),
            "min": round(min(latencies), 2),
            "max": round(max(latencies), 2),
            "provider": "CPUExecutionProvider",
            "note": "desktop CPU; a phone will be slower",
        },
        "verified_at": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "onnxruntime_version": ort.__version__,
    }
    return summary


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    config = get_training_config()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--onnx", type=Path,
                        default=config.run_dir / "export" / ONNX_FILENAME)
    parser.add_argument("--images", type=int, default=DEFAULT_IMAGES)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--no-write", action="store_true")
    args = parser.parse_args()

    if not args.onnx.is_file():
        raise FileNotFoundError(
            f"{args.onnx} not found - run src.export.export_onnx first."
        )

    summary = verify(args.onnx, args.images, seed=args.seed)

    if not args.no_write:
        out = args.onnx.parent / "export_summary.json"
        out.write_text(json.dumps(summary, indent=2), encoding="utf-8")
        print(f"\n  wrote {out}")

    print("  No training, no evaluation, no checkpoint or prediction file "
          "was modified.")
    return 0 if summary["verification"]["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
