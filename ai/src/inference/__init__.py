"""Inference with the trained PulmoNet-7M checkpoint.

Symbols are resolved lazily so that ``python -m src.inference.predict`` does
not import the module twice (which makes runpy warn).
"""

from typing import TYPE_CHECKING

if TYPE_CHECKING:  # pragma: no cover - typing only
    from src.inference.predict import (
        DEFAULT_THRESHOLD,
        Prediction,
        default_checkpoint,
        load_model,
        pick_device,
        predict_dicom,
        preprocess_dicom,
    )

__all__ = [
    "DEFAULT_THRESHOLD",
    "Prediction",
    "default_checkpoint",
    "load_model",
    "pick_device",
    "predict_dicom",
    "preprocess_dicom",
]


def __getattr__(name: str):
    if name in __all__:
        from src.inference import predict as _predict

        return getattr(_predict, name)
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")
