"""Smoke tests for the DICOM Dataset / DataLoader.

Runs either standalone or under pytest:

    ai\\.venv\\Scripts\\python.exe ai\\src\\data\\test_dataset.py
    ai\\.venv\\Scripts\\python.exe -m pytest ai/src/data/test_dataset.py -v

Only a handful of images are read, so the whole file finishes in seconds and
never touches more than one DICOM at a time.
"""

from __future__ import annotations

import sys
from pathlib import Path

import torch

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from src.config import (  # noqa: E402
    CLASS_LUNG_OPACITY,
    get_preprocess_config,
)
from src.data.dataset import (  # noqa: E402
    RsnaPneumoniaDataset,
    build_dataloader,
)

CONFIG = get_preprocess_config()


def _dataset(split: str = "val") -> RsnaPneumoniaDataset:
    return RsnaPneumoniaDataset(split=split, train_mode=False, seed=0)


def test_dataset_loads_and_is_not_empty() -> None:
    dataset = _dataset()
    assert len(dataset) > 0, "validation split is empty"
    assert dataset.positive_count > 0
    assert dataset.negative_count > 0


def test_single_sample_shape_dtype_and_label() -> None:
    dataset = _dataset()
    sample = dataset[0]

    image = sample["image"]
    assert isinstance(image, torch.Tensor)
    assert image.dtype == torch.float32
    assert image.shape == (CONFIG.channels, CONFIG.image_size, CONFIG.image_size)
    assert torch.isfinite(image).all(), "image contains NaN/Inf"

    label = sample["label"]
    assert label.dtype == torch.float32
    assert label.item() in (0.0, 1.0)
    assert (label.item() == 1.0) == (sample["class_label"] == CLASS_LUNG_OPACITY)


def test_positive_sample_has_boxes_inside_the_frame() -> None:
    dataset = _dataset()
    positives = dataset.frame.index[
        dataset.frame["class_label"] == CLASS_LUNG_OPACITY
    ].tolist()
    assert positives, "no positive sample in the validation split"

    sample = dataset[positives[0]]
    boxes = sample["boxes"]
    assert boxes.ndim == 2 and boxes.shape[1] == 4
    assert len(boxes) >= 1, "positive sample has no bounding box"

    size = CONFIG.image_size
    assert boxes.min() >= 0 and boxes.max() <= size
    # xyxy: x2 > x1 and y2 > y1
    assert (boxes[:, 2] > boxes[:, 0]).all()
    assert (boxes[:, 3] > boxes[:, 1]).all()

    normalized = sample["boxes_normalized"]
    assert normalized.shape == boxes.shape
    assert normalized.min() >= 0.0 and normalized.max() <= 1.0


def test_negative_sample_has_no_boxes() -> None:
    dataset = _dataset()
    negatives = dataset.frame.index[
        dataset.frame["class_label"] != CLASS_LUNG_OPACITY
    ].tolist()
    sample = dataset[negatives[0]]
    assert sample["boxes"].shape == (0, 4)
    assert sample["label"].item() == 0.0


def test_several_samples_load_without_error() -> None:
    dataset = _dataset()
    step = max(len(dataset) // 8, 1)
    for index in range(0, min(len(dataset), 8 * step), step):
        sample = dataset[index]
        assert sample["image"].shape[-1] == CONFIG.image_size
        assert sample["sop_instance_uid"]


def test_dataloader_batches_and_keeps_boxes() -> None:
    dataset = _dataset()
    loader = build_dataloader(dataset, batch_size=4, shuffle=False, num_workers=0)
    batch = next(iter(loader))

    assert batch["image"].shape == (
        4, CONFIG.channels, CONFIG.image_size, CONFIG.image_size,
    )
    assert batch["label"].shape == (4,)
    # boxes stay a list: images carry a different number of them
    assert isinstance(batch["boxes"], list) and len(batch["boxes"]) == 4
    for boxes in batch["boxes"]:
        assert boxes.ndim == 2 and boxes.shape[1] == 4


def test_train_augmentation_changes_the_image_but_keeps_the_label() -> None:
    plain = RsnaPneumoniaDataset(split="train", train_mode=False, seed=0)
    augmented = RsnaPneumoniaDataset(split="train", train_mode=True, seed=0)
    a, b = plain[0], augmented[0]
    assert a["label"].item() == b["label"].item()
    assert a["image"].shape == b["image"].shape
    assert not torch.allclose(a["image"], b["image"]), "augmentation had no effect"


def test_rotation_drops_boxes_that_leave_the_frame() -> None:
    from src.config import PreprocessConfig
    from src.data.preprocessing import augment

    config = PreprocessConfig(
        max_rotation_degrees=7.0, random_brightness_contrast=0.0
    )
    image = torch.rand(1, CONFIG.image_size, CONFIG.image_size)
    corner = torch.tensor([[0.0, 0.0, 4.0, 4.0], [50.0, 50.0, 150.0, 150.0]])
    _, boxes = augment(image, corner, config, torch.Generator().manual_seed(1))

    assert len(boxes) == 1, "the collapsed corner box should have been dropped"
    assert (boxes[:, 2] - boxes[:, 0] >= 1).all()
    assert (boxes[:, 3] - boxes[:, 1] >= 1).all()


def test_splits_do_not_overlap() -> None:
    ids = {
        name: set(RsnaPneumoniaDataset(split=name, train_mode=False).frame[
            "sop_instance_uid"
        ])
        for name in ("train", "val", "test")
    }
    assert not ids["train"] & ids["val"]
    assert not ids["train"] & ids["test"]
    assert not ids["val"] & ids["test"]


def main() -> int:
    tests = [value for name, value in sorted(globals().items())
             if name.startswith("test_") and callable(value)]
    failures = 0
    print(f"Running {len(tests)} dataset checks "
          f"(image_size={CONFIG.image_size}, channels={CONFIG.channels})\n")
    for test in tests:
        try:
            test()
        except Exception as error:  # noqa: BLE001 - report and continue
            failures += 1
            print(f"  FAIL  {test.__name__}: {error}")
        else:
            print(f"  ok    {test.__name__}")
    print(f"\n{len(tests) - failures}/{len(tests)} passed")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
