"""PulmoNet-7M — the PulmoAI convolutional network.

A custom CNN, written from basic PyTorch layers only (``Conv2d``,
``BatchNorm2d``, ``ReLU``, ``MaxPool2d``, ``Dropout2d``, ``AdaptiveAvgPool2d``,
``Linear``). No torchvision model, no published backbone, no pretrained
weights, no transfer learning — every parameter starts from random
initialisation.

Input is a **single grayscale channel**: chest radiographs carry no colour, so
the plane is fed to the network as it comes out of the DICOM instead of being
duplicated into RGB.

```
[B, 1, 224, 224]
  stem     Conv3x3 s2 (1->32)                      -> [B,  32, 112, 112]
  block1   Conv3x3 x2 (32->64)      + MaxPool      -> [B,  64,  56,  56]
  block2   Conv3x3 x2 (64->128)     + MaxPool      -> [B, 128,  28,  28]
  block3   Conv3x3 x3 (128->256)    + MaxPool + SD -> [B, 256,  14,  14]
  block4   Conv3x3 x3 (256->384)    + MaxPool + SD -> [B, 384,   7,   7]
  block5   Conv3x3    (384->512)                   -> [B, 512,   7,   7]
  GAP + Dropout + Linear(512, 1)                   -> [B]
```

Every convolution is 3x3, stride 1, padding 1, ``bias=False`` (the following
BatchNorm provides the shift). The only stride-2 convolution is the stem.
``SD`` = spatial dropout (``Dropout2d``).

Output is a raw logit per image; sigmoid is applied only in
:meth:`PulmoNet.predict_proba`, so ``BCEWithLogitsLoss`` stays numerically
stable. Label semantics: **0 = No Pneumonia** (``Normal`` or ``No Lung Opacity
/ Not Normal``), **1 = Pneumonia / Lung Opacity**.
"""

from __future__ import annotations

from dataclasses import dataclass

import torch
import torch.nn as nn

FEATURE_DIM = 512  # channels reaching global average pooling
NUM_CLASSES = 1  # single logit -> binary
CLASS_NAMES = ("No Pneumonia", "Pneumonia / Lung Opacity")
IN_CHANNELS = 1  # grayscale, never duplicated to RGB


@dataclass(frozen=True)
class ModelConfig:
    """Configuration of the classifier instance."""

    dropout: float = 0.4  # before the linear classifier
    spatial_dropout: float = 0.1  # after the stage 3 and 4 pooling
    in_channels: int = IN_CHANNELS
    image_size: int = 224


class ConvBlock(nn.Sequential):
    """``Conv3x3 -> BatchNorm -> ReLU``, the single building unit."""

    def __init__(self, in_channels: int, out_channels: int, stride: int = 1):
        super().__init__(
            nn.Conv2d(
                in_channels, out_channels, kernel_size=3,
                stride=stride, padding=1, bias=False,
            ),
            nn.BatchNorm2d(out_channels),
            nn.ReLU(inplace=True),
        )


def _stage(channels: list[int]) -> nn.Sequential:
    """A stage of consecutive ``ConvBlock``s over ``[c_in, c1, c2, ...]``."""
    return nn.Sequential(
        *[ConvBlock(channels[i], channels[i + 1]) for i in range(len(channels) - 1)]
    )


class PulmoNet(nn.Module):
    """PulmoNet-7M: 14 convolutions in 5 stages, GAP head, one logit out."""

    def __init__(self, config: ModelConfig | None = None) -> None:
        super().__init__()
        self.config = config or ModelConfig()

        if self.config.in_channels != IN_CHANNELS:
            raise ValueError(
                "PulmoNet takes a single grayscale channel; keep "
                "PULMOAI_IMAGE_CHANNELS=1. The Dataset already emits "
                "[1, H, W] - grayscale is never duplicated into RGB."
            )

        # 224 -> 112: cheap early downsampling, the 224 px raster carries no
        # useful detail below this scale after the 1024 -> 224 resize.
        self.stem = ConvBlock(self.config.in_channels, 32, stride=2)

        # simple local features (edges, rib and diaphragm borders)
        self.block1 = _stage([32, 64, 64])
        self.pool1 = nn.MaxPool2d(2, 2)

        # textures: lung markings, vascular shadows, parenchymal grain
        self.block2 = _stage([64, 128, 128])
        self.pool2 = nn.MaxPool2d(2, 2)

        # mid-level patterns: denser regions and their borders
        self.block3 = _stage([128, 256, 256, 256])
        self.pool3 = nn.MaxPool2d(2, 2)
        self.spatial_drop3 = nn.Dropout2d(self.config.spatial_dropout)

        # large structures and their arrangement across the lung fields
        self.block4 = _stage([256, 384, 384, 384])
        self.pool4 = nn.MaxPool2d(2, 2)
        self.spatial_drop4 = nn.Dropout2d(self.config.spatial_dropout)

        # compress into the descriptor that global pooling collapses
        self.block5 = ConvBlock(384, FEATURE_DIM)

        self.gap = nn.AdaptiveAvgPool2d(1)
        self.dropout = nn.Dropout(self.config.dropout)
        self.classifier = nn.Linear(FEATURE_DIM, NUM_CLASSES)

        self._initialise_weights()

    # -- forward -----------------------------------------------------------

    def features(self, x: torch.Tensor) -> torch.Tensor:
        """``[B, 1, H, W] -> [B, 512, H/32, W/32]`` feature map.

        Exposed separately because this is the map a CAM-style heatmap would
        be computed from later.
        """
        x = self.stem(x)
        x = self.pool1(self.block1(x))
        x = self.pool2(self.block2(x))
        x = self.spatial_drop3(self.pool3(self.block3(x)))
        x = self.spatial_drop4(self.pool4(self.block4(x)))
        return self.block5(x)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        """``[B, 1, H, W] -> [B]`` logits."""
        x = self.features(x)
        x = torch.flatten(self.gap(x), 1)
        return self.classifier(self.dropout(x)).squeeze(-1)

    @torch.inference_mode()
    def predict_proba(self, x: torch.Tensor) -> torch.Tensor:
        """``[B, 1, H, W] -> [B]`` probabilities of class 1 (pneumonia)."""
        return torch.sigmoid(self.forward(x))

    # -- initialisation ----------------------------------------------------

    def _initialise_weights(self) -> None:
        """Kaiming (He) init — the standard choice for ReLU networks."""
        for module in self.modules():
            if isinstance(module, nn.Conv2d):
                nn.init.kaiming_normal_(
                    module.weight, mode="fan_out", nonlinearity="relu"
                )
            elif isinstance(module, nn.BatchNorm2d):
                nn.init.ones_(module.weight)
                nn.init.zeros_(module.bias)
            elif isinstance(module, nn.Linear):
                nn.init.normal_(module.weight, std=0.01)
                nn.init.zeros_(module.bias)

    # -- introspection -----------------------------------------------------

    def parameter_counts(self) -> dict[str, int]:
        def count(module: nn.Module) -> int:
            return sum(p.numel() for p in module.parameters())

        counts = {
            "stem": count(self.stem),
            "block1": count(self.block1),
            "block2": count(self.block2),
            "block3": count(self.block3),
            "block4": count(self.block4),
            "block5": count(self.block5),
            "classifier": count(self.classifier),
        }
        counts["total"] = sum(p.numel() for p in self.parameters())
        counts["trainable"] = sum(
            p.numel() for p in self.parameters() if p.requires_grad
        )
        return counts

    def describe(self) -> str:
        counts = self.parameter_counts()
        n = lambda value: f"{value:,}".replace(",", " ")  # noqa: E731
        size = self.config.image_size
        return (
            "PulmoNet-7M (custom CNN, random init, trained from scratch)\n"
            f"  input       : {self.config.in_channels}x{size}x{size} "
            "(grayscale, not duplicated to RGB)\n"
            f"  output      : 1 logit  (0 = {CLASS_NAMES[0]}, "
            f"1 = {CLASS_NAMES[1]})\n"
            f"  parameters  : {n(counts['total'])} "
            f"({counts['total'] * 4 / 1e6:.1f} MB fp32)\n"
            f"  stem        : {n(counts['stem'])}\n"
            f"  block1      : {n(counts['block1'])}\n"
            f"  block2      : {n(counts['block2'])}\n"
            f"  block3      : {n(counts['block3'])}\n"
            f"  block4      : {n(counts['block4'])}\n"
            f"  block5      : {n(counts['block5'])}\n"
            f"  classifier  : {n(counts['classifier'])}\n"
            f"  dropout     : {self.config.dropout} "
            f"(spatial {self.config.spatial_dropout})"
        )


def build_model(
    *,
    dropout: float = 0.4,
    spatial_dropout: float = 0.1,
    image_size: int = 224,
) -> PulmoNet:
    """Factory used by the training and evaluation scripts."""
    return PulmoNet(
        ModelConfig(
            dropout=dropout,
            spatial_dropout=spatial_dropout,
            image_size=image_size,
        )
    )
