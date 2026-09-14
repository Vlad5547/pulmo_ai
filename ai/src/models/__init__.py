"""The single PulmoAI model: PulmoNet-7M, a custom CNN trained from scratch."""

from src.models.pulmonet import (
    CLASS_NAMES,
    FEATURE_DIM,
    IN_CHANNELS,
    NUM_CLASSES,
    ModelConfig,
    PulmoNet,
    build_model,
)

__all__ = [
    "CLASS_NAMES",
    "FEATURE_DIM",
    "IN_CHANNELS",
    "NUM_CLASSES",
    "ModelConfig",
    "PulmoNet",
    "build_model",
]
