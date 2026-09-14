"""Export the trained PulmoNet-7M checkpoint to ONNX (fp32, opset 17).

    cd D:\\pulmo_ai\\ai
    ..\\ai\\.venv\\Scripts\\python.exe -m src.export.export_onnx

What is exported
----------------
**The network only.** Preprocessing stays outside the graph: the exported model
takes the tensor the training Dataset produces — ``[1, 1, 224, 224]`` float32,
already resized and normalised with the dataset statistics (mean 0.4932,
std 0.2458) — and returns one raw logit. Sigmoid is applied by the caller, as
in training. Baking the resize/normalisation into the graph is a separate
decision and is deliberately not done here.

The checkpoint is read, never written; no training, no evaluation.
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

import torch

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from src.config import get_preprocess_config, get_training_config  # noqa: E402
from src.inference.predict import load_model  # noqa: E402

OPSET = 17
INPUT_NAME = "input"
OUTPUT_NAME = "logit"
ONNX_FILENAME = "pulmonet7m.onnx"


class LogitWrapper(torch.nn.Module):
    """Keeps the exported output shaped ``[1, 1]`` instead of a bare scalar.

    ``PulmoNet.forward`` squeezes the last dimension, which makes the ONNX
    output rank-1 and awkward for mobile runtimes. The wrapper only reshapes —
    no weights, no arithmetic, no change to the model itself.
    """

    def __init__(self, model: torch.nn.Module) -> None:
        super().__init__()
        self.model = model

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.model(x).reshape(-1, 1)


def export(
    checkpoint_path: Path | None = None,
    out_dir: Path | None = None,
    *,
    opset: int = OPSET,
) -> dict:
    config = get_training_config()
    preprocess = get_preprocess_config()
    checkpoint_path = Path(checkpoint_path or config.run_dir / "best.pt")
    out_dir = Path(out_dir or config.run_dir / "export")
    out_dir.mkdir(parents=True, exist_ok=True)
    onnx_path = out_dir / ONNX_FILENAME

    # export on CPU: deterministic and independent of the local GPU
    model, checkpoint, _ = load_model(checkpoint_path, torch.device("cpu"))
    model.eval()
    counts = model.parameter_counts()

    size = preprocess.image_size
    shape = (1, preprocess.channels, size, size)
    example = torch.randn(*shape, dtype=torch.float32)

    print("PulmoAI - ONNX export")
    print(f"  checkpoint : {checkpoint_path} (epoch {checkpoint.get('epoch')})")
    print(f"  parameters : {counts['total']:,}".replace(",", " "))
    print(f"  input      : {shape} float32")
    print(f"  opset      : {opset}, fp32, no quantisation")

    started = time.time()
    torch.onnx.export(
        LogitWrapper(model),
        (example,),
        str(onnx_path),
        input_names=[INPUT_NAME],
        output_names=[OUTPUT_NAME],
        opset_version=opset,
        do_constant_folding=True,  # folds BatchNorm into the convolutions
        dynamo=False,              # stable TorchScript exporter
        dynamic_axes=None,         # fixed [1, 1, 224, 224] - best for mobile
    )
    elapsed = time.time() - started

    # --- structural check -------------------------------------------------
    import onnx

    graph = onnx.load(str(onnx_path))
    onnx.checker.check_model(graph)
    ops = sorted({node.op_type for node in graph.graph.node})
    initialisers = sum(
        int(torch.tensor(list(init.dims)).prod()) if init.dims else 1
        for init in graph.graph.initializer
    )

    with torch.no_grad():
        torch_logit = float(model(example).reshape(-1)[0])

    summary = {
        "onnx_path": str(onnx_path),
        "file_size_bytes": onnx_path.stat().st_size,
        "file_size_mb": round(onnx_path.stat().st_size / 1e6, 2),
        "opset": opset,
        "ir_version": graph.ir_version,
        "producer": f"torch {torch.__version__}",
        "precision": "fp32",
        "quantisation": "none",
        "input_name": INPUT_NAME,
        "input_shape": list(shape),
        "output_name": OUTPUT_NAME,
        "output_shape": [1, 1],
        "operators": ops,
        "initialiser_elements": initialisers,
        "torch_parameters": counts["total"],
        "preprocessing_inside_graph": False,
        "export_seconds": round(elapsed, 2),
        "reference_logit_on_random_input": round(torch_logit, 6),
    }

    print(f"  operators  : {', '.join(ops)}")
    print(f"  weights    : {initialisers:,} elements in the graph vs "
          f"{counts['total']:,} torch parameters (BatchNorm folded)"
          .replace(",", " "))
    print(f"  wrote      : {onnx_path}  "
          f"({summary['file_size_mb']:.2f} MB) in {elapsed:.1f}s")
    print("  graph passed onnx.checker")
    print("\n  Preprocessing is NOT part of the graph: feed the same "
          "[1, 1, 224, 224]\n  tensor the Dataset produces "
          f"(mean {preprocess.grayscale_mean}, std {preprocess.grayscale_std}).")
    print("  Next: verify_onnx.py before anything touches Flutter.")
    return summary


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--checkpoint", type=Path, default=None)
    parser.add_argument("--out", type=Path, default=None)
    parser.add_argument("--opset", type=int, default=OPSET)
    args = parser.parse_args()

    summary = export(args.checkpoint, args.out, opset=args.opset)
    out_dir = Path(args.out or get_training_config().run_dir / "export")
    (out_dir / "export_graph.json").write_text(
        json.dumps(summary, indent=2), encoding="utf-8"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
