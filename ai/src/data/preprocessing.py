"""Preprocessing pipeline for RSNA chest radiographs.

Implemented with plain ``torch`` ops (no torchvision / albumentations) to keep
the dependency list small; every step is explicit and easy to swap later.

Pipeline for one image
----------------------
1. ``pydicom`` pixel_array  -> uint8/uint16 HxW numpy array
2. photometric correction   -> MONOCHROME1 is inverted so that "brighter =
                               denser tissue" holds for every image
3. scale to float32 [0, 1]  -> divided by the real maximum of the stored bit
                               depth (BitsStored), not a hard-coded 255
4. resize to ``image_size`` -> bilinear, antialiased
5. augmentation (train only)-> mild rotation / brightness / contrast
6. normalisation            -> dataset grayscale mean/std, single channel
                               (never duplicated into RGB)

Bounding boxes are transformed with the same geometry so they keep pointing at
the same anatomy after resizing.
"""

from __future__ import annotations

import math

import numpy as np
import torch
import torch.nn.functional as F

from src.config import PreprocessConfig


def dicom_to_float_tensor(
    pixel_array: np.ndarray,
    photometric_interpretation: str = "MONOCHROME2",
    bits_stored: int = 8,
) -> torch.Tensor:
    """Convert a raw DICOM pixel array to a float32 ``[1, H, W]`` tensor in [0, 1].

    MONOCHROME2 (the convention in this dataset) means "0 = black"; MONOCHROME1
    is inverted. Handling both makes the dataset safe for other DICOM sources.
    """
    array = np.asarray(pixel_array)
    if array.ndim != 2:
        raise ValueError(f"Expected a 2D pixel array, got shape {array.shape}")

    tensor = torch.from_numpy(array.astype(np.float32))

    max_value = float((1 << max(int(bits_stored), 1)) - 1)
    observed_max = float(tensor.max())
    if observed_max > max_value:  # defensive: trust the data over the header
        max_value = observed_max
    if max_value > 0:
        tensor = tensor / max_value

    if str(photometric_interpretation).upper() == "MONOCHROME1":
        tensor = 1.0 - tensor

    return tensor.unsqueeze(0).clamp_(0.0, 1.0)


def resize_image(image: torch.Tensor, size: int) -> torch.Tensor:
    """Bilinear resize of a ``[C, H, W]`` tensor to ``[C, size, size]``."""
    return F.interpolate(
        image.unsqueeze(0),
        size=(size, size),
        mode="bilinear",
        align_corners=False,
        antialias=True,
    ).squeeze(0)


def scale_boxes(
    boxes: torch.Tensor, src_width: int, src_height: int, size: int
) -> torch.Tensor:
    """Scale ``[N, 4]`` xyxy boxes from the source frame to a ``size`` square."""
    if boxes.numel() == 0:
        return boxes
    scale = torch.tensor(
        [size / src_width, size / src_height, size / src_width, size / src_height],
        dtype=boxes.dtype,
    )
    return boxes * scale


def normalize_boxes(
    boxes: torch.Tensor, width: int, height: int
) -> torch.Tensor:
    """xyxy pixels -> xyxy in 0..1, the format the Flutter UI expects."""
    if boxes.numel() == 0:
        return boxes
    divisor = torch.tensor([width, height, width, height], dtype=boxes.dtype)
    return (boxes / divisor).clamp_(0.0, 1.0)


def normalize_intensity(
    image: torch.Tensor, config: PreprocessConfig
) -> torch.Tensor:
    """Mean/std normalisation of the single grayscale channel.

    A radiograph has one channel and PulmoNet takes one channel, so the plane
    is passed through as ``[1, H, W]`` — it is never duplicated into RGB.
    The statistics are the dataset's own, measured on the training split.
    """
    if config.channels != 1:
        raise ValueError(
            "PulmoNet takes 1 grayscale channel; "
            f"got PULMOAI_IMAGE_CHANNELS={config.channels}."
        )
    mean = torch.tensor([config.grayscale_mean]).view(1, 1, 1)
    std = torch.tensor([config.grayscale_std]).view(1, 1, 1)
    return (image - mean) / std


def augment(
    image: torch.Tensor,
    boxes: torch.Tensor,
    config: PreprocessConfig,
    generator: torch.Generator | None = None,
) -> tuple[torch.Tensor, torch.Tensor]:
    """Mild train-time augmentation on a ``[1, S, S]`` image in [0, 1].

    Horizontal flipping is available but disabled by default: left/right is
    diagnostically meaningful on a chest radiograph (heart position, situs),
    so mirroring teaches the model anatomy that does not occur.
    """

    def rand() -> float:
        return float(torch.rand(1, generator=generator))

    if config.random_horizontal_flip > 0 and rand() < config.random_horizontal_flip:
        image = torch.flip(image, dims=[-1])
        if boxes.numel():
            width = image.shape[-1]
            flipped = boxes.clone()
            flipped[:, 0] = width - boxes[:, 2]
            flipped[:, 2] = width - boxes[:, 0]
            boxes = flipped

    if config.max_rotation_degrees > 0:
        degrees = (rand() * 2 - 1) * config.max_rotation_degrees
        if abs(degrees) > 0.1:
            image, boxes = _rotate(image, boxes, degrees)

    jitter = config.random_brightness_contrast
    if jitter > 0:
        brightness = 1.0 + (rand() * 2 - 1) * jitter
        contrast = 1.0 + (rand() * 2 - 1) * jitter
        mean = image.mean()
        image = ((image - mean) * contrast + mean) * brightness
        image = image.clamp_(0.0, 1.0)

    return image, drop_degenerate_boxes(boxes)


def drop_degenerate_boxes(
    boxes: torch.Tensor, min_side: float = 1.0
) -> torch.Tensor:
    """Remove boxes that a geometric transform collapsed to (almost) nothing.

    Rotating an image clips boxes at the border; one that ends up outside the
    frame becomes zero-area and would poison a detection loss.
    """
    if boxes.numel() == 0:
        return boxes
    keep = ((boxes[:, 2] - boxes[:, 0]) >= min_side) & (
        (boxes[:, 3] - boxes[:, 1]) >= min_side
    )
    return boxes[keep]


def _rotate(
    image: torch.Tensor, boxes: torch.Tensor, degrees: float
) -> tuple[torch.Tensor, torch.Tensor]:
    """Rotate image and boxes around the centre by ``degrees``."""
    radians = math.radians(degrees)
    cos, sin = math.cos(radians), math.sin(radians)

    # affine_grid works in normalised [-1, 1] coordinates, so the same matrix
    # applies regardless of the image size.
    theta = torch.tensor([[cos, -sin, 0.0], [sin, cos, 0.0]], dtype=image.dtype)
    grid = F.affine_grid(
        theta.unsqueeze(0), list(image.unsqueeze(0).shape), align_corners=False
    )
    rotated = F.grid_sample(
        image.unsqueeze(0), grid, mode="bilinear",
        padding_mode="zeros", align_corners=False,
    ).squeeze(0)

    if boxes.numel() == 0:
        return rotated, boxes

    height, width = image.shape[-2:]
    cx, cy = width / 2, height / 2
    corners = torch.stack(
        [
            boxes[:, [0, 1]], boxes[:, [2, 1]],
            boxes[:, [2, 3]], boxes[:, [0, 3]],
        ],
        dim=1,
    )  # [N, 4, 2]
    shifted = corners - torch.tensor([cx, cy], dtype=boxes.dtype)
    # image rotates by +degrees, so points rotate by -degrees
    matrix = torch.tensor([[cos, sin], [-sin, cos]], dtype=boxes.dtype)
    rotated_corners = shifted @ matrix.T + torch.tensor([cx, cy], dtype=boxes.dtype)

    x_min = rotated_corners[..., 0].min(dim=1).values.clamp(0, width)
    x_max = rotated_corners[..., 0].max(dim=1).values.clamp(0, width)
    y_min = rotated_corners[..., 1].min(dim=1).values.clamp(0, height)
    y_max = rotated_corners[..., 1].max(dim=1).values.clamp(0, height)
    return rotated, torch.stack([x_min, y_min, x_max, y_max], dim=1)
