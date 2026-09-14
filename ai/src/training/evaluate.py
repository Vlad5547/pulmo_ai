"""Score a trained checkpoint on a split — the test split runs here, once.

    ai\\.venv\\Scripts\\python.exe ai\\src\\training\\evaluate.py                    # best.pt on test
    ai\\.venv\\Scripts\\python.exe ai\\src\\training\\evaluate.py --split val
    ai\\.venv\\Scripts\\python.exe ai\\src\\training\\evaluate.py --checkpoint <path>

The test split is deliberately isolated from ``train.py``: it is read only
after the best checkpoint has been chosen on validation ROC-AUC. The metrics
are appended to ``results.json`` of the experiment and also written to
``metrics_<split>.json``, together with per-image predictions
(``predictions_<split>.csv``) so the thesis can plot ROC/PR curves later.
"""

from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path

import torch

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from src.config import get_training_config  # noqa: E402
from src.data.dataset import RsnaPneumoniaDataset, build_dataloader  # noqa: E402
from src.models import build_model  # noqa: E402
from src.training.metrics import MetricAccumulator, format_metrics  # noqa: E402
from src.training.train import pick_device  # noqa: E402


def evaluate(
    checkpoint_path: Path,
    split: str = "test",
    *,
    batch_size: int | None = None,
    device_name: str | None = None,
    threshold: float = 0.5,
    max_batches: int | None = None,
) -> dict:
    base = get_training_config()
    device = pick_device(device_name)

    checkpoint = torch.load(str(checkpoint_path), map_location=device,
                            weights_only=False)
    saved = checkpoint.get("config", {})
    model = build_model(
        dropout=float(saved.get("dropout", base.dropout)),
        spatial_dropout=float(
            saved.get("spatial_dropout", base.spatial_dropout)
        ),
        image_size=int(saved.get("image_size", base.image_size)),
    ).to(device)
    model.load_state_dict(checkpoint["model_state"])
    model.eval()

    dataset = RsnaPneumoniaDataset(split=split, train_mode=False)
    loader = build_dataloader(
        dataset,
        batch_size=batch_size or base.batch_size,
        shuffle=False,
        num_workers=base.num_workers,
    )

    print(f"PulmoAI - evaluating {checkpoint_path.name} on '{split}'")
    print(f"  device       : {device}")
    print(f"  checkpoint   : epoch {checkpoint.get('epoch')} "
          f"(val {base.monitor_metric}="
          f"{checkpoint.get('val_metrics', {}).get(base.monitor_metric, float('nan')):.4f})")
    print(f"  images       : {len(dataset)} "
          f"({dataset.positive_count} positive)")

    accumulator = MetricAccumulator(threshold=threshold)
    rows: list[dict] = []
    with torch.inference_mode():
        for step, batch in enumerate(loader):
            if max_batches is not None and step >= max_batches:
                break
            images = batch["image"].to(device)
            targets = batch["label"].to(device)
            logits = model(images)
            accumulator.update(logits, targets)
            probabilities = torch.sigmoid(logits).cpu()
            for i, sop in enumerate(batch["sop_instance_uid"]):
                rows.append({
                    "sop_instance_uid": sop,
                    "class_label": batch["class_label"][i],
                    "target": int(targets[i].item()),
                    "probability": round(float(probabilities[i]), 6),
                    "prediction": int(float(probabilities[i]) >= threshold),
                })

    metrics = accumulator.compute()
    print(f"  {split:<12} {format_metrics(metrics)}")
    return {"metrics": metrics, "predictions": rows,
            "checkpoint": str(checkpoint_path), "split": split,
            "threshold": threshold}


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    base = get_training_config()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--experiment", default=base.experiment_name)
    parser.add_argument("--checkpoint", type=Path, default=None,
                        help="default: <experiment>/best.pt")
    parser.add_argument("--split", default="test", choices=["train", "val", "test"])
    parser.add_argument("--batch-size", type=int, default=None)
    parser.add_argument("--threshold", type=float, default=0.5)
    parser.add_argument("--device", default=None)
    parser.add_argument("--max-batches", type=int, default=None)
    parser.add_argument("--no-write", action="store_true")
    args = parser.parse_args()

    run_dir = base.experiments_dir / args.experiment
    checkpoint_path = args.checkpoint or (run_dir / "best.pt")
    if not checkpoint_path.is_file():
        raise FileNotFoundError(
            f"{checkpoint_path} not found — train the model first."
        )

    outcome = evaluate(
        checkpoint_path, args.split,
        batch_size=args.batch_size, device_name=args.device,
        threshold=args.threshold, max_batches=args.max_batches,
    )

    if args.no_write:
        return 0

    run_dir.mkdir(parents=True, exist_ok=True)
    metrics_path = run_dir / f"metrics_{args.split}.json"
    metrics_path.write_text(
        json.dumps({k: v for k, v in outcome.items() if k != "predictions"},
                   indent=2),
        encoding="utf-8",
    )

    predictions_path = run_dir / f"predictions_{args.split}.csv"
    with predictions_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(outcome["predictions"][0]))
        writer.writeheader()
        writer.writerows(outcome["predictions"])

    results_path = run_dir / "results.json"
    if results_path.is_file():
        results = json.loads(results_path.read_text(encoding="utf-8"))
        results[f"{args.split}_metrics"] = outcome["metrics"]
        results_path.write_text(json.dumps(results, indent=2), encoding="utf-8")

    print(f"  wrote {metrics_path}")
    print(f"  wrote {predictions_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
