"""Export a CAM-capable ONNX graph from the same checkpoint.

    cd D:\\pulmo_ai\\ai
    ..\\ai\\.venv\\Scripts\\python.exe -m src.export.export_cam_onnx

Why a second file
-----------------
``pulmonet7m.onnx`` declares one output (``logit``). ONNX Runtime can only
return tensors that are declared graph outputs, so the last convolutional
feature map is not reachable from it — requesting it raises
``INVALID_ARGUMENT: Invalid output name``. Rather than modify the verified
classification model, this script exports a second graph from the **same
``best.pt``**, with the same architecture and the same weights, that declares
two outputs:

* ``logit``    ``[1, 1]``      — identical to the classification model;
* ``features`` ``[1, 512, 7, 7]`` — the output of block 5, the map global
  average pooling collapses.

No training, no new weights, no architecture change: the wrapper only exposes a
tensor that already exists inside the network.

The classifier weights that turn the feature map into a CAM are written to
``cam_weights.json`` next to the model, so the app can compute
``cam = sum_k w_k * features_k`` explicitly instead of hiding it in the graph.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import torch

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from src.config import get_preprocess_config, get_training_config  # noqa: E402
from src.inference.predict import load_model  # noqa: E402

OPSET = 17
INPUT_NAME = "input"
LOGIT_NAME = "logit"
FEATURES_NAME = "features"
ONNX_FILENAME = "pulmonet7m_cam.onnx"
WEIGHTS_FILENAME = "cam_weights.json"


class CamWrapper(torch.nn.Module):
    """Returns the logit and the feature map the logit was computed from.

    Both come from a single forward pass, so exposing the map costs nothing at
    inference time. The arithmetic is the model's own: ``features()`` followed
    by global average pooling and the linear classifier.
    """

    def __init__(self, model: torch.nn.Module) -> None:
        super().__init__()
        self.model = model

    def forward(self, x: torch.Tensor) -> tuple[torch.Tensor, torch.Tensor]:
        features = self.model.features(x)                       # [1, 512, 7, 7]
        pooled = torch.flatten(self.model.gap(features), 1)     # [1, 512]
        logit = self.model.classifier(pooled).reshape(-1, 1)    # [1, 1]
        return logit, features


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

    model, checkpoint, _ = load_model(checkpoint_path, torch.device("cpu"))
    model.eval()

    size = preprocess.image_size
    shape = (1, preprocess.channels, size, size)
    example = torch.randn(*shape, dtype=torch.float32)

    print("PulmoAI - CAM ONNX export")
    print(f"  checkpoint : {checkpoint_path} (epoch {checkpoint.get('epoch')})")
    print(f"  input      : {shape} float32")
    print(f"  outputs    : {LOGIT_NAME} [1, 1], {FEATURES_NAME} [1, 512, 7, 7]")
    print(f"  opset      : {opset}, fp32, no quantisation, no new weights")

    torch.onnx.export(
        CamWrapper(model),
        (example,),
        str(onnx_path),
        input_names=[INPUT_NAME],
        output_names=[LOGIT_NAME, FEATURES_NAME],
        opset_version=opset,
        do_constant_folding=True,
        dynamo=False,
        dynamic_axes=None,
    )

    import onnx

    graph = onnx.load(str(onnx_path))
    onnx.checker.check_model(graph)
    outputs = {
        o.name: [d.dim_value for d in o.type.tensor_type.shape.dim]
        for o in graph.graph.output
    }

    # The CAM weights are the classifier's: cam = sum_k w_k * features_k.
    weight = model.classifier.weight.detach().reshape(-1).tolist()
    bias = float(model.classifier.bias.detach().reshape(-1)[0])
    (out_dir / WEIGHTS_FILENAME).write_text(
        json.dumps(
            {
                "note": "Classifier weights of PulmoNet-7M. CAM(y, x) = "
                        "sum_k weight[k] * features[k, y, x]; the bias only "
                        "shifts the logit and is irrelevant to the map.",
                "source_checkpoint": str(checkpoint_path),
                "feature_channels": len(weight),
                "weight": [round(w, 8) for w in weight],
                "bias": bias,
            },
            indent=2,
        ),
        encoding="utf-8",
    )

    summary = {
        "onnx_path": str(onnx_path),
        "file_size_bytes": onnx_path.stat().st_size,
        "file_size_mb": round(onnx_path.stat().st_size / 1e6, 2),
        "opset": opset,
        "input_name": INPUT_NAME,
        "input_shape": list(shape),
        "outputs": outputs,
        "operators": sorted({node.op_type for node in graph.graph.node}),
        "weights_file": str(out_dir / WEIGHTS_FILENAME),
        "classifier_bias": bias,
        "same_checkpoint_as_classification_model": True,
        "new_weights": False,
    }

    print(f"  outputs    : {outputs}")
    print(f"  wrote      : {onnx_path} ({summary['file_size_mb']:.2f} MB)")
    print(f"  wrote      : {out_dir / WEIGHTS_FILENAME} "
          f"({len(weight)} classifier weights)")
    print("  graph passed onnx.checker")
    print("\n  Next: verify_cam_onnx.py - the logit must match "
          "pulmonet7m.onnx before this reaches Flutter.")
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
    (out_dir / "export_cam_graph.json").write_text(
        json.dumps(summary, indent=2), encoding="utf-8"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
