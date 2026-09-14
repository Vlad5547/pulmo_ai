"""Training loop for PulmoNet-7M (custom CNN, trained from scratch).

NOT run yet — the full run needs explicit confirmation. Until then use
``pilot_run.py`` (a few batches) or ``--max-batches``.

    ai\\.venv\\Scripts\\python.exe ai\\src\\training\\train.py --epochs 30
    ai\\.venv\\Scripts\\python.exe ai\\src\\training\\train.py --max-batches 2 --epochs 1

How it behaves
--------------
* loss: ``BCEWithLogitsLoss`` with ``pos_weight`` computed **on train only**;
* validation after every epoch; the **best checkpoint is the one with the best
  validation ROC-AUC** (``--monitor`` to change) and is written to ``best.pt``;
  ``last.pt`` is refreshed every epoch;
* ``ReduceLROnPlateau`` on the same metric, then early stopping once it has not
  improved for ``--early-stopping`` epochs;
* everything lands in ``ai/experiments/<name>/``: ``config.json``,
  ``history.csv``, ``best.pt``, ``last.pt``, ``results.json``;
* **the test split is never read here.** Score it once afterwards with
  ``evaluate.py``, using the best checkpoint.
"""

from __future__ import annotations

import argparse
import csv
import json
import random
import sys
import time
from dataclasses import asdict, replace
from pathlib import Path

import numpy as np
import torch

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from src.config import TrainingConfig, get_training_config  # noqa: E402
from src.data.dataset import RsnaPneumoniaDataset, build_dataloader  # noqa: E402
from src.models import build_model  # noqa: E402
from src.training.losses import build_loss, compute_pos_weight  # noqa: E402
from src.training.metrics import MetricAccumulator, format_metrics  # noqa: E402


def set_seed(seed: int) -> None:
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)
    torch.cuda.manual_seed_all(seed)


def pick_device(requested: str | None = None) -> torch.device:
    if requested:
        return torch.device(requested)
    return torch.device("cuda" if torch.cuda.is_available() else "cpu")


def config_to_json(config: TrainingConfig) -> dict:
    payload = {k: (str(v) if isinstance(v, Path) else v)
               for k, v in asdict(config).items()}
    payload["model_name"] = config.model_name
    payload["pretrained"] = False  # always: the project trains from scratch
    return payload


def run_epoch(
    model: torch.nn.Module,
    loader,
    criterion,
    device: torch.device,
    optimizer: torch.optim.Optimizer | None = None,
    max_batches: int | None = None,
    log_every: int = 50,
) -> dict[str, float]:
    """One pass. ``optimizer=None`` -> evaluation (no grad, no weight update)."""
    training = optimizer is not None
    model.train(training)
    metrics = MetricAccumulator()
    started = time.time()

    for step, batch in enumerate(loader):
        if max_batches is not None and step >= max_batches:
            break
        images = batch["image"].to(device, non_blocking=True)
        targets = batch["label"].to(device, non_blocking=True)

        with torch.set_grad_enabled(training):
            logits = model(images)
            loss = criterion(logits, targets)

        if training:
            optimizer.zero_grad(set_to_none=True)
            loss.backward()
            optimizer.step()

        metrics.update(logits, targets, loss.item())
        if training and log_every and step % log_every == 0:
            print(f"    step {step:>5}  loss={loss.item():.4f}  "
                  f"({time.time() - started:.0f}s)", flush=True)

    return metrics.compute()


def train(
    config: TrainingConfig,
    *,
    max_batches: int | None = None,
    device_name: str | None = None,
) -> dict:
    set_seed(config.seed)
    device = pick_device(device_name)
    run_dir = config.run_dir
    run_dir.mkdir(parents=True, exist_ok=True)

    print(f"PulmoAI - training '{config.experiment_name}' "
          f"(PulmoNet-7M, scratch)")
    print(f"  device        : {device}")
    print(f"  run dir       : {run_dir}")

    train_set = RsnaPneumoniaDataset(split="train", train_mode=True,
                                     seed=config.seed)
    val_set = RsnaPneumoniaDataset(split="val", train_mode=False)
    train_loader = build_dataloader(
        train_set, batch_size=config.batch_size, shuffle=True,
        num_workers=config.num_workers, pin_memory=device.type == "cuda",
    )
    val_loader = build_dataloader(
        val_set, batch_size=config.batch_size, shuffle=False,
        num_workers=config.num_workers, pin_memory=device.type == "cuda",
    )
    print(f"  train         : {len(train_set)} images "
          f"({train_set.positive_count} positive)")
    print(f"  validation    : {len(val_set)} images "
          f"({val_set.positive_count} positive)")

    pos_weight = compute_pos_weight("train") if config.use_pos_weight else None
    if pos_weight is not None:
        print(f"  pos_weight    : {float(pos_weight):.4f} (train only)")

    model = build_model(
        dropout=config.dropout,
        spatial_dropout=config.spatial_dropout,
        image_size=config.image_size,
    ).to(device)
    print("  " + model.describe().replace("\n", "\n  "))

    criterion = build_loss(pos_weight, device)
    optimizer = torch.optim.AdamW(
        model.parameters(),
        lr=config.learning_rate,
        weight_decay=config.weight_decay,
    )
    scheduler = torch.optim.lr_scheduler.ReduceLROnPlateau(
        optimizer, mode="max",
        factor=config.scheduler_factor, patience=config.scheduler_patience,
    )

    (run_dir / "config.json").write_text(
        json.dumps(config_to_json(config), indent=2), encoding="utf-8"
    )
    history_path = run_dir / "history.csv"
    best_score = -float("inf")
    best_epoch = -1
    best_metrics: dict[str, float] = {}
    epochs_without_improvement = 0
    stopped_early = False
    started = time.time()

    for epoch in range(1, config.epochs + 1):
        print(f"\nEpoch {epoch}/{config.epochs}")
        train_metrics = run_epoch(
            model, train_loader, criterion, device, optimizer, max_batches
        )
        val_metrics = run_epoch(
            model, val_loader, criterion, device, None, max_batches
        )
        print(f"  train  {format_metrics(train_metrics)}")
        print(f"  val    {format_metrics(val_metrics)}")

        score = val_metrics.get(config.monitor_metric, float("nan"))
        scheduler.step(score)
        _append_history(history_path, epoch, train_metrics, val_metrics,
                        optimizer.param_groups[0]["lr"])

        checkpoint = {
            "epoch": epoch,
            "model_state": model.state_dict(),
            "optimizer_state": optimizer.state_dict(),
            "config": config_to_json(config),
            "val_metrics": val_metrics,
            "pos_weight": float(pos_weight) if pos_weight is not None else None,
        }
        torch.save(checkpoint, run_dir / "last.pt")

        if score > best_score + config.min_delta:
            best_score, best_epoch, best_metrics = score, epoch, val_metrics
            epochs_without_improvement = 0
            torch.save(checkpoint, run_dir / "best.pt")
            print(f"  -> new best val {config.monitor_metric}={score:.4f}, "
                  f"saved best.pt")
        else:
            epochs_without_improvement += 1
            print(f"  no improvement for {epochs_without_improvement} "
                  f"epoch(s) (best {best_score:.4f} @ epoch {best_epoch})")
            if epochs_without_improvement >= config.early_stopping_patience:
                stopped_early = True
                print(f"  early stopping after epoch {epoch}")
                break

    results = {
        "experiment": config.experiment_name,
        "model": config.model_name,
        "pretrained": False,
        "finished_at": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "duration_seconds": round(time.time() - started, 1),
        "epochs_run": epoch,
        "stopped_early": stopped_early,
        "monitor_metric": config.monitor_metric,
        "best_epoch": best_epoch,
        "best_val_score": best_score,
        "best_val_metrics": best_metrics,
        "pos_weight": float(pos_weight) if pos_weight is not None else None,
        "config": config_to_json(config),
        "test_metrics": None,  # filled in by evaluate.py
    }
    (run_dir / "results.json").write_text(
        json.dumps(results, indent=2), encoding="utf-8"
    )

    print(f"\nBest validation {config.monitor_metric}: {best_score:.4f} "
          f"(epoch {best_epoch})")
    print(f"Artefacts in {run_dir}")
    print("Test split untouched - run evaluate.py with best.pt when ready.")
    return results


def _append_history(path: Path, epoch: int, train_metrics: dict,
                    val_metrics: dict, lr: float) -> None:
    row = {"epoch": epoch, "lr": lr}
    row.update({f"train_{k}": v for k, v in train_metrics.items()})
    row.update({f"val_{k}": v for k, v in val_metrics.items()})
    write_header = not path.is_file()
    with path.open("a", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(row))
        if write_header:
            writer.writeheader()
        writer.writerow(row)


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):  # cp1251 consoles choke on non-ASCII
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    base = get_training_config()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--epochs", type=int, default=base.epochs)
    parser.add_argument("--batch-size", type=int, default=base.batch_size)
    parser.add_argument("--lr", type=float, default=base.learning_rate)
    parser.add_argument("--weight-decay", type=float, default=base.weight_decay)
    parser.add_argument("--dropout", type=float, default=base.dropout)
    parser.add_argument("--seed", type=int, default=base.seed)
    parser.add_argument("--num-workers", type=int, default=base.num_workers)
    parser.add_argument("--experiment", default=base.experiment_name)
    parser.add_argument("--monitor", default=base.monitor_metric)
    parser.add_argument("--early-stopping", type=int,
                        default=base.early_stopping_patience)
    parser.add_argument("--no-pos-weight", action="store_true")
    parser.add_argument("--device", default=None)
    parser.add_argument("--max-batches", type=int, default=None,
                        help="cap batches per epoch (wiring check, not training)")
    args = parser.parse_args()

    config = replace(
        base,
        epochs=args.epochs,
        batch_size=args.batch_size,
        learning_rate=args.lr,
        weight_decay=args.weight_decay,
        dropout=args.dropout,
        seed=args.seed,
        num_workers=args.num_workers,
        experiment_name=args.experiment,
        monitor_metric=args.monitor,
        early_stopping_patience=args.early_stopping,
        use_pos_weight=not args.no_pos_weight,
    )
    train(config, max_batches=args.max_batches, device_name=args.device)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
