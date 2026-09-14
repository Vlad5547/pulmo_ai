"""Pilot run: does the loss actually go down before we spend hours training?

    ai\\.venv\\Scripts\\python.exe ai\\src\\training\\pilot_run.py
    ai\\.venv\\Scripts\\python.exe ai\\src\\training\\pilot_run.py --batches 6 --epochs 8 --lr 1e-3

Deliberately overfits a **small fixed subset** of the training split (a few
batches, reused every pass). A randomly initialised PulmoNet-7M that cannot
drive the loss down on 32-64 images has a broken pipeline — this catches that
in a minute instead of after an epoch over 20 779 images.

It is a diagnostic, not training: no checkpoint is written, the validation and
test splits are never touched, and the subset is far too small to learn
anything transferable.
"""

from __future__ import annotations

import argparse
import sys
import time
from pathlib import Path

import torch

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from src.config import get_training_config  # noqa: E402
from src.data.dataset import (  # noqa: E402
    RsnaPneumoniaDataset,
    build_dataloader,
)
from src.models import build_model  # noqa: E402
from src.training.losses import build_loss, compute_pos_weight  # noqa: E402
from src.training.metrics import MetricAccumulator, format_metrics  # noqa: E402
from src.training.train import pick_device, set_seed  # noqa: E402


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    base = get_training_config()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--batches", type=int, default=4,
                        help="batches in the fixed subset")
    parser.add_argument("--batch-size", type=int, default=8)
    parser.add_argument("--epochs", type=int, default=6,
                        help="passes over that subset")
    parser.add_argument("--lr", type=float, default=1e-3)
    parser.add_argument("--seed", type=int, default=base.seed)
    parser.add_argument("--device", default=None)
    args = parser.parse_args()

    set_seed(args.seed)
    device = pick_device(args.device)

    print("PulmoAI - pilot run (overfit a small fixed subset, no checkpoint)")
    print(f"  device={device}  batches={args.batches}  "
          f"batch_size={args.batch_size}  epochs={args.epochs}  lr={args.lr}")

    # --- fixed subset ----------------------------------------------------
    dataset = RsnaPneumoniaDataset(split="train", train_mode=False, seed=0)
    subset_size = args.batches * args.batch_size
    generator = torch.Generator().manual_seed(args.seed)
    indices = torch.randperm(len(dataset), generator=generator)[:subset_size]
    subset_frame = dataset.frame.iloc[indices.tolist()].reset_index(drop=True)
    subset = RsnaPneumoniaDataset(
        split=None, frame=subset_frame, train_mode=False, seed=args.seed
    )
    loader = build_dataloader(
        subset, batch_size=args.batch_size, shuffle=False, num_workers=0
    )
    print(f"  subset: {len(subset)} images "
          f"({subset.positive_count} positive / {subset.negative_count} negative)")

    # --- model / loss / optimiser ----------------------------------------
    model = build_model(dropout=base.dropout,
                        spatial_dropout=base.spatial_dropout,
                        image_size=base.image_size)
    model = model.to(device)
    print("  " + model.describe().replace("\n", "\n  "))

    pos_weight = compute_pos_weight("train")
    criterion = build_loss(pos_weight, device)
    optimizer = torch.optim.AdamW(model.parameters(), lr=args.lr,
                                  weight_decay=base.weight_decay)
    print(f"  pos_weight={float(pos_weight):.4f} (train split)\n")

    # --- loop -------------------------------------------------------------
    started = time.time()
    epoch_losses: list[float] = []
    model.train()
    for epoch in range(1, args.epochs + 1):
        metrics = MetricAccumulator()
        for batch in loader:
            images = batch["image"].to(device)
            targets = batch["label"].to(device)

            logits = model(images)
            loss = criterion(logits, targets)
            optimizer.zero_grad(set_to_none=True)
            loss.backward()
            optimizer.step()
            metrics.update(logits, targets, loss.item())

        summary = metrics.compute()
        epoch_losses.append(summary["loss"])
        print(f"  epoch {epoch}/{args.epochs}  {format_metrics(summary)}"
              f"  ({time.time() - started:.0f}s)", flush=True)

    # --- verdict ----------------------------------------------------------
    first, last, best = epoch_losses[0], epoch_losses[-1], min(epoch_losses)
    decreased = last < first
    finite = all(torch.isfinite(torch.tensor(epoch_losses)))
    print(f"\n  loss {first:.4f} -> {last:.4f}  "
          f"(best {best:.4f}, drop {100 * (first - last) / first:+.1f}%)")

    checks = [
        (finite, "all epoch losses are finite"),
        (decreased, "loss decreased over the pilot run"),
        (last < first * 0.95, "loss dropped by more than 5%"),
    ]
    for ok, description in checks:
        print(f"  [{'ok' if ok else 'FAIL'}]   {description}")

    failed = [d for ok, d in checks if not ok]
    print(f"\n{len(checks) - len(failed)}/{len(checks)} checks passed in "
          f"{time.time() - started:.0f}s")
    if failed:
        print("  Pipeline looks wrong - do not start the full run yet.")
    else:
        print("  Pipeline learns. Nothing was saved; the full run still needs "
              "to be started explicitly.")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
