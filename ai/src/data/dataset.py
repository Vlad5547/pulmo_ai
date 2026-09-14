"""PyTorch ``Dataset`` over the local RSNA DICOM files.

Design notes
------------
* Lazy by construction: only ``dataset_mapping.csv`` / ``bounding_boxes.csv``
  (a few MB of text) live in RAM. Pixel data is read from disk one image at a
  time inside ``__getitem__`` and released immediately afterwards.
* The DICOM files are opened read-only and never written back.
* Labels are binary: ``Lung Opacity`` -> 1, ``Normal`` and
  ``No Lung Opacity / Not Normal`` -> 0. Images without an adjudicated label
  (``matched == 0``) are dropped.
* Bounding boxes travel with the sample so the same dataset can feed a
  detector or a Grad-CAM evaluation later. Boxes are returned both in resized
  pixel coordinates (xyxy) and normalised 0..1 (the format the Flutter UI
  already speaks).
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import pandas as pd
import pydicom
import torch
from torch.utils.data import DataLoader, Dataset

from src.config import (
    BOXES_CSV,
    CLASS_LUNG_OPACITY,
    MAPPING_CSV,
    SPLIT_CSV,
    DatasetPaths,
    PreprocessConfig,
    get_dataset_paths,
    get_preprocess_config,
)
from src.data.preprocessing import (
    augment,
    dicom_to_float_tensor,
    normalize_boxes,
    normalize_intensity,
    resize_image,
    scale_boxes,
)

SPLIT_NAMES = ("train", "val", "test")


@dataclass
class Sample:
    """Plain view of one dataset item (what ``__getitem__`` returns as dict)."""

    image: torch.Tensor  # [C, S, S] float32, normalised
    label: torch.Tensor  # scalar float32, 0.0 / 1.0
    boxes: torch.Tensor  # [N, 4] xyxy in resized pixels
    boxes_normalized: torch.Tensor  # [N, 4] xyxy in 0..1
    sop_instance_uid: str
    relative_path: str
    class_label: str


class RsnaPneumoniaDataset(Dataset):
    """Binary pneumonia (lung opacity) classification over RSNA DICOM files.

    Parameters
    ----------
    split:
        ``"train"``, ``"val"``, ``"test"`` or ``None`` for every labelled image.
        Requires ``dataset_split.csv`` (produced by ``split_dataset.py``) unless
        ``None``.
    train_mode:
        enables augmentation. Defaults to ``split == "train"``.
    """

    def __init__(
        self,
        split: str | None = "train",
        *,
        paths: DatasetPaths | None = None,
        config: PreprocessConfig | None = None,
        train_mode: bool | None = None,
        frame: pd.DataFrame | None = None,
        seed: int | None = None,
    ) -> None:
        self.paths = paths or get_dataset_paths()
        self.config = config or get_preprocess_config()
        self.split = split
        self.train_mode = (split == "train") if train_mode is None else train_mode

        self.frame = (
            frame.reset_index(drop=True)
            if frame is not None
            else self._load_frame(split)
        )
        self.boxes_by_sop = self._load_boxes()
        self._generator = torch.Generator()
        if seed is not None:
            self._generator.manual_seed(seed)

    # -- construction ------------------------------------------------------

    def _processed(self, name: str) -> Path:
        path = self.paths.processed_dir / name
        if not path.is_file():
            raise FileNotFoundError(
                f"{path} not found. Run ai/src/data/inspect_dataset.py "
                "(and split_dataset.py for splits) first."
            )
        return path

    def _load_frame(self, split: str | None) -> pd.DataFrame:
        frame = pd.read_csv(self._processed(MAPPING_CSV))
        frame = frame[frame["matched"] == 1].copy()

        if split is not None:
            if split not in SPLIT_NAMES:
                raise ValueError(f"split must be one of {SPLIT_NAMES} or None")
            splits = pd.read_csv(self._processed(SPLIT_CSV))
            wanted = splits.loc[splits["split"] == split, "sop_instance_uid"]
            frame = frame[frame["sop_instance_uid"].isin(set(wanted))]

        return frame.reset_index(drop=True)

    def _load_boxes(self) -> dict[str, torch.Tensor]:
        """xyxy boxes in the original 1024x1024 frame, keyed by SOPInstanceUID."""
        boxes = pd.read_csv(self._processed(BOXES_CSV))
        needed = set(self.frame["sop_instance_uid"])
        boxes = boxes[boxes["sop_instance_uid"].isin(needed)]

        grouped: dict[str, torch.Tensor] = {}
        for sop, group in boxes.groupby("sop_instance_uid", sort=False):
            xyxy = torch.tensor(
                [
                    [
                        row.x,
                        row.y,
                        row.x + row.width,
                        row.y + row.height,
                    ]
                    for row in group.itertuples()
                ],
                dtype=torch.float32,
            )
            grouped[str(sop)] = xyxy
        return grouped

    # -- torch API ---------------------------------------------------------

    def __len__(self) -> int:
        return len(self.frame)

    def __getitem__(self, index: int) -> dict:
        row = self.frame.iloc[index]
        sop = str(row["sop_instance_uid"])
        dicom_path = self.paths.images_dir / str(row["relative_path"])

        # read-only, one file at a time; the array is dropped at the end
        ds = pydicom.dcmread(str(dicom_path))
        image = dicom_to_float_tensor(
            ds.pixel_array,
            photometric_interpretation=getattr(
                ds, "PhotometricInterpretation", "MONOCHROME2"
            ),
            bits_stored=int(getattr(ds, "BitsStored", 8)),
        )
        source_height, source_width = image.shape[-2:]

        boxes = self.boxes_by_sop.get(sop, torch.zeros((0, 4), dtype=torch.float32))
        size = self.config.image_size
        image = resize_image(image, size)
        boxes = scale_boxes(boxes, source_width, source_height, size)

        if self.train_mode:
            image, boxes = augment(image, boxes, self.config, self._generator)

        boxes_normalized = normalize_boxes(boxes, size, size)
        image = normalize_intensity(image, self.config)

        label = 1.0 if row["class_label"] == CLASS_LUNG_OPACITY else 0.0

        return {
            "image": image,
            "label": torch.tensor(label, dtype=torch.float32),
            "boxes": boxes,
            "boxes_normalized": boxes_normalized,
            "sop_instance_uid": sop,
            "relative_path": str(row["relative_path"]),
            "class_label": str(row["class_label"]),
        }

    # -- helpers -----------------------------------------------------------

    @property
    def labels(self) -> torch.Tensor:
        values = (self.frame["class_label"] == CLASS_LUNG_OPACITY).astype("float32")
        return torch.tensor(values.to_numpy())

    @property
    def positive_count(self) -> int:
        return int(self.labels.sum())

    @property
    def negative_count(self) -> int:
        return len(self) - self.positive_count

    def class_weights(self) -> torch.Tensor:
        """``pos_weight`` for ``BCEWithLogitsLoss`` (negatives / positives)."""
        positives = max(self.positive_count, 1)
        return torch.tensor([self.negative_count / positives], dtype=torch.float32)


def collate_samples(batch: list[dict]) -> dict:
    """Collate that keeps the variable number of boxes per image intact."""
    return {
        "image": torch.stack([item["image"] for item in batch]),
        "label": torch.stack([item["label"] for item in batch]),
        "boxes": [item["boxes"] for item in batch],
        "boxes_normalized": [item["boxes_normalized"] for item in batch],
        "sop_instance_uid": [item["sop_instance_uid"] for item in batch],
        "relative_path": [item["relative_path"] for item in batch],
        "class_label": [item["class_label"] for item in batch],
    }


def build_dataloader(
    dataset: RsnaPneumoniaDataset,
    *,
    batch_size: int = 16,
    shuffle: bool | None = None,
    num_workers: int = 0,
    pin_memory: bool = False,
) -> DataLoader:
    """DataLoader with the box-aware collate.

    ``num_workers=0`` is the safe default on Windows; raise it when training
    from a script guarded by ``if __name__ == "__main__"``.
    """
    if shuffle is None:
        shuffle = dataset.train_mode
    return DataLoader(
        dataset,
        batch_size=batch_size,
        shuffle=shuffle,
        num_workers=num_workers,
        pin_memory=pin_memory,
        collate_fn=collate_samples,
        persistent_workers=num_workers > 0,
    )


def build_dataloaders(
    *,
    batch_size: int = 16,
    num_workers: int = 0,
    config: PreprocessConfig | None = None,
) -> dict[str, DataLoader]:
    """Convenience: train/val/test loaders in one call."""
    loaders: dict[str, DataLoader] = {}
    for split in SPLIT_NAMES:
        dataset = RsnaPneumoniaDataset(split=split, config=config)
        loaders[split] = build_dataloader(
            dataset,
            batch_size=batch_size,
            shuffle=split == "train",
            num_workers=num_workers,
        )
    return loaders
