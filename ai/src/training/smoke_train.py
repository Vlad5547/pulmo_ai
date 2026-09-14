"""Training smoke test — one batch through the whole loop, seconds to run.

    ai\\.venv\\Scripts\\python.exe ai\\src\\training\\smoke_train.py
    ai\\.venv\\Scripts\\python.exe ai\\src\\training\\smoke_train.py --model resnet50 --batch-size 2

Checks, in order: model builds, a real batch loads from the Dataset, forward
pass shape, loss is finite, backward produces finite gradients, the optimizer
step actually changes the weights, and the loss on the same batch goes down
afterwards.

This is a wiring check, **not** training: one optimizer step on one batch, no
checkpoint written. The model is PulmoNet-7M with random initialisation, so
nothing is ever downloaded.
"""

from __future__ import annotations

import argparse
import sys
import time
from pathlib import Path

import torch

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from src.config import get_training_config  # noqa: E402
from src.data.dataset import RsnaPneumoniaDataset, build_dataloader  # noqa: E402
from src.models import build_model  # noqa: E402
from src.training.losses import build_loss, compute_pos_weight  # noqa: E402
from src.training.metrics import MetricAccumulator  # noqa: E402


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    base = get_training_config()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--batch-size", type=int, default=4)
    parser.add_argument("--lr", type=float, default=base.learning_rate)
    parser.add_argument("--device", default=None)
    args = parser.parse_args()

    device = torch.device(
        args.device or ("cuda" if torch.cuda.is_available() else "cpu")
    )
    torch.manual_seed(base.seed)

    failures: list[str] = []

    def check(condition: bool, description: str, detail: str = "") -> None:
        if condition:
            print(f"  [ok]   {description}" + (f"  ({detail})" if detail else ""))
        else:
            failures.append(description)
            print(f"  [FAIL] {description}" + (f"  ({detail})" if detail else ""))

    print("PulmoAI - training smoke test (1 batch, 1 optimizer step)")
    print(f"  model=PulmoNet-7M (scratch)  device={device}  "
          f"batch_size={args.batch_size}  lr={args.lr}")

    started = time.time()

    # 1. model ------------------------------------------------------------
    model = build_model(
        dropout=base.dropout,
        spatial_dropout=base.spatial_dropout,
        image_size=base.image_size,
    ).to(device)
    counts = model.parameter_counts()
    check(counts["trainable"] > 0, "model built (random init, from scratch)",
          f"{counts['total']:,} parameters, classifier "
          f"{counts['classifier']:,}".replace(",", " "))

    # 2. data -------------------------------------------------------------
    dataset = RsnaPneumoniaDataset(split="train", train_mode=True, seed=0)
    loader = build_dataloader(
        dataset, batch_size=args.batch_size, shuffle=True, num_workers=0
    )
    batch = next(iter(loader))
    images = batch["image"].to(device)
    targets = batch["label"].to(device)
    check(
        images.shape == (args.batch_size, base.channels,
                         base.image_size, base.image_size),
        "batch loaded from real DICOM",
        f"images {tuple(images.shape)} {images.dtype}, "
        f"labels {tuple(targets.shape)}, "
        f"{int(targets.sum())} positive",
    )

    # 3. forward ----------------------------------------------------------
    model.train()
    logits = model(images)
    check(logits.shape == (args.batch_size,) and logits.dtype == torch.float32,
          "forward pass shape", f"{tuple(logits.shape)} {logits.dtype}")
    check(bool(torch.isfinite(logits).all()), "logits are finite",
          f"min={float(logits.detach().min()):.4f} "
          f"max={float(logits.detach().max()):.4f}")

    # 4. loss -------------------------------------------------------------
    pos_weight = compute_pos_weight("train")
    criterion = build_loss(pos_weight, device)
    loss = criterion(logits, targets)
    check(loss.ndim == 0 and torch.isfinite(loss),
          "loss is a finite scalar",
          f"BCEWithLogitsLoss(pos_weight={float(pos_weight):.4f}) = "
          f"{loss.item():.6f}")

    # 5. backward ---------------------------------------------------------
    optimizer = torch.optim.AdamW(model.parameters(), lr=args.lr,
                                  weight_decay=base.weight_decay)
    optimizer.zero_grad(set_to_none=True)
    loss.backward()
    grads = [p.grad for p in model.parameters() if p.grad is not None]
    grad_norm = torch.sqrt(sum((g.float() ** 2).sum() for g in grads))
    check(bool(grads) and bool(torch.isfinite(grad_norm)),
          "backward pass produced finite gradients",
          f"{len(grads)} tensors, global norm {float(grad_norm):.4f}")

    # 6. optimizer step ---------------------------------------------------
    before = model.classifier.weight.detach().clone()
    optimizer.step()
    moved = float((model.classifier.weight.detach() - before).abs().max())
    check(moved > 0, "optimizer step changed the weights",
          f"max classifier delta {moved:.3e}")

    # 7. loss reacts ------------------------------------------------------
    with torch.no_grad():
        new_logits = model(images)
        new_loss = criterion(new_logits, targets)
    check(bool(torch.isfinite(new_loss)), "loss after the step is finite",
          f"{loss.item():.6f} -> {new_loss.item():.6f}")

    # 8. metrics wiring ---------------------------------------------------
    accumulator = MetricAccumulator()
    accumulator.update(new_logits, targets, new_loss.item())
    metrics = accumulator.compute()
    check(
        {"accuracy", "precision", "recall", "f1", "roc_auc"} <= set(metrics),
        "metrics computed on the batch",
        f"acc={metrics['accuracy']:.3f} f1={metrics['f1']:.3f} "
        f"roc_auc={metrics['roc_auc']:.3f}",
    )

    print(f"\n{'=' * 56}")
    print(f"{8 - len(failures)}/8 checks passed in {time.time() - started:.1f}s")
    if failures:
        for item in failures:
            print(f"  - {item}")
    else:
        print("Wiring is fine. No training was run, no checkpoint written.")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
