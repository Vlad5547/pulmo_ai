"""Measure what the Dart DICOM decoder's rounding does to the probability.

The Flutter app reads a DICOM with its own baseline-JPEG decoder (the `image`
package); the Python pipeline uses pylibjpeg. The two disagree by at most one
LSB on about 4 % of pixels — an IDCT rounding difference, not a bug — and this
script answers the only question that matters: how much does that move the
model's output?

Run `flutter test test/dicom_dataset_parity_test.dart` first; it writes the Dart
tensors to `build/dart_dicom_tensors/`. Then:

    & $py ai\\src\\export\\check_dicom_parity.py
"""

from __future__ import annotations

import io
import json
import sys
from pathlib import Path

import numpy as np
import onnxruntime as ort

if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

ROOT = Path(__file__).resolve().parents[3]
DART = ROOT / "build" / "dart_dicom_tensors"
REFERENCE = ROOT / "test" / "fixtures" / "tensors"
EXPECTED = ROOT / "test" / "fixtures" / "expected.json"
MODEL = (
    ROOT
    / "ai"
    / "experiments"
    / "pulmonet7m-scratch"
    / "export"
    / "pulmonet7m.onnx"
)


def probability(session: ort.InferenceSession, tensor: np.ndarray) -> float:
    logit = session.run(None, {"input": tensor.reshape(1, 1, 224, 224)})[0]
    return float(1.0 / (1.0 + np.exp(-logit.item())))


def main() -> int:
    if not DART.exists():
        print("No Dart tensors. Run the Flutter DICOM parity test first:")
        print("  flutter test test/dicom_dataset_parity_test.dart")
        return 1

    session = ort.InferenceSession(str(MODEL), providers=["CPUExecutionProvider"])
    expected = json.loads(EXPECTED.read_text(encoding="utf-8"))
    by_file = {item["file"].replace(".png", ""): item for item in expected["images"]}

    print(f"{'study':<12}{'python':>12}{'dart(dicom)':>14}{'|dp|':>12}{'verdict':>10}")
    print("-" * 60)

    worst = 0.0
    flipped = 0
    threshold = float(expected["threshold"])

    for path in sorted(DART.glob("*.f32")):
        name = path.stem
        dart = np.fromfile(path, dtype=np.float32)
        reference = np.fromfile(REFERENCE / f"{name}.f32", dtype=np.float32)

        p_dart = probability(session, dart)
        p_reference = probability(session, reference)
        delta = abs(p_dart - p_reference)
        worst = max(worst, delta)

        same = (p_dart >= threshold) == (p_reference >= threshold)
        if not same:
            flipped += 1
        print(
            f"{name:<12}{p_reference:>12.6f}{p_dart:>14.6f}"
            f"{delta:>12.2e}{'same' if same else 'FLIPPED':>10}"
        )

    print("-" * 60)
    print(f"worst |dp| over {len(list(DART.glob('*.f32')))} studies: {worst:.3e}")
    print(f"verdicts changed: {flipped}")
    print(
        "\nInterpretation: the gap comes from the JPEG decoder, not from the "
        "DICOM parsing.\nThe PNG path agrees with Python to ~1e-06; this path "
        "is bounded by one LSB\nof 8-bit pixel data, which is the accuracy the "
        "stored image itself has."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
