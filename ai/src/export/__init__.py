"""Export of the trained PulmoNet-7M checkpoint to a mobile-friendly format."""

from typing import TYPE_CHECKING

if TYPE_CHECKING:  # pragma: no cover - typing only
    from src.export.export_onnx import INPUT_NAME, OPSET, OUTPUT_NAME, export

__all__ = ["INPUT_NAME", "OPSET", "OUTPUT_NAME", "export"]


def __getattr__(name: str):
    if name in __all__:
        from src.export import export_onnx as _export

        return getattr(_export, name)
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")
