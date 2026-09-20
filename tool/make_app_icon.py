"""Draw the PulmoAI launcher icon.

Two PNGs are produced from the same geometry:

* ``assets/icon/icon.png``            — full-bleed 1024x1024, used for iOS,
  Windows, macOS, the web and the legacy Android icon;
* ``assets/icon/icon_foreground.png`` — transparent 1024x1024 with the artwork
  inside the 66 % safe zone, used as the Android adaptive foreground (the
  system crops an adaptive icon to whatever mask the launcher applies, so
  anything outside that circle can be cut off);
* ``assets/icon/icon_monochrome.png`` — the same silhouette in white, for the
  Android 13+ themed icon.

The motif is a pair of lungs framed by viewfinder brackets: the subject is the
chest, the framing says the app *looks at* an image of it. Everything is one
white silhouette on the app's own seed colour (#0E7C86), so it survives being
scaled down to 48 px, where a second colour or a thin detail would not.

Run:  & $py tool\\make_app_icon.py
"""

from __future__ import annotations

import io
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "icon"

SIZE = 1024
SUPERSAMPLE = 4  # draw big, downscale once — cheap, and keeps edges clean

TEAL_DARK = (7, 71, 79)
TEAL = (14, 124, 134)
TEAL_LIGHT = (38, 178, 180)
WHITE = (255, 255, 255)
BRACKET = (150, 228, 228)

# Right lobe, in units where the trachea is at x = 0 and the lobes span
# y in [-0.42, 0.90]. The inner edge is concave, which is what makes a lung
# read as a lung rather than as a bean.
LOBE = [
    (0.15, -0.28),
    (0.40, -0.44),
    (0.72, -0.20),
    (0.88, 0.22),
    (0.80, 0.66),
    (0.56, 0.88),
    (0.33, 0.80),
    (0.22, 0.44),
    (0.17, 0.08),
]


def _vertical_gradient(size: int, top: tuple, bottom: tuple) -> Image.Image:
    """Background wash, drawn row by row — no numpy needed for 1024 rows."""
    column = Image.new("RGB", (1, size))
    pixels = column.load()
    for y in range(size):
        t = y / (size - 1)
        pixels[0, y] = tuple(
            round(top[i] + (bottom[i] - top[i]) * t) for i in range(3)
        )
    return column.resize((size, size), Image.Resampling.BICUBIC)


def _catmull_rom(points: list, samples: int = 24) -> list:
    """Smooth a control polyline; endpoints are duplicated so nothing drifts."""
    pts = [points[0]] + list(points) + [points[-1]]
    out = []
    for i in range(len(pts) - 3):
        p0, p1, p2, p3 = pts[i], pts[i + 1], pts[i + 2], pts[i + 3]
        for s in range(samples):
            t = s / samples
            t2, t3 = t * t, t * t * t
            out.append(
                (
                    0.5
                    * (
                        2 * p1[0]
                        + (-p0[0] + p2[0]) * t
                        + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t2
                        + (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t3
                    ),
                    0.5
                    * (
                        2 * p1[1]
                        + (-p0[1] + p2[1]) * t
                        + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t2
                        + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t3
                    ),
                )
            )
    out.append(points[-1])
    return out


def _lobe(cx: float, cy: float, unit: float, mirror: bool) -> list:
    smooth = _catmull_rom(LOBE)
    return [
        (cx + (-x if mirror else x) * unit, cy + y * unit) for x, y in smooth
    ]


def _draw_lungs(draw: ImageDraw.ImageDraw, cx: float, cy: float, unit: float):
    stroke = unit * 0.11

    # airway first: the bronchi have to disappear under the lobes, leaving only
    # the short stubs that show in the gap between them
    draw.line(
        [(cx, cy - unit * 0.34), (cx - unit * 0.30, cy - unit * 0.08)],
        fill=WHITE,
        width=round(stroke),
    )
    draw.line(
        [(cx, cy - unit * 0.34), (cx + unit * 0.30, cy - unit * 0.08)],
        fill=WHITE,
        width=round(stroke),
    )
    draw.rounded_rectangle(
        [
            cx - stroke * 0.62,
            cy - unit * 0.92,
            cx + stroke * 0.62,
            cy - unit * 0.28,
        ],
        radius=stroke * 0.62,
        fill=WHITE,
    )

    for mirror in (False, True):
        draw.polygon(_lobe(cx, cy, unit, mirror), fill=WHITE)


def _draw_brackets(draw: ImageDraw.ImageDraw, cx: float, cy: float, unit: float):
    """Four viewfinder corners around the chest."""
    half_w = unit * 1.28
    top = cy - unit * 1.08
    bottom = cy + unit * 1.12
    arm = unit * 0.40
    width = round(unit * 0.09)

    for x, sx in ((cx - half_w, 1), (cx + half_w, -1)):
        for y, sy in ((top, 1), (bottom, -1)):
            draw.line([(x, y), (x + sx * arm, y)], fill=BRACKET, width=width)
            draw.line([(x, y), (x, y + sy * arm)], fill=BRACKET, width=width)
            # a dot at the elbow rounds the join; PIL lines have butt caps and
            # would otherwise leave a notch that is very visible at 48 px
            draw.ellipse(
                [
                    x - width / 2,
                    y - width / 2,
                    x + width / 2,
                    y + width / 2,
                ],
                fill=BRACKET,
            )


def _artwork(size: int, unit: float, with_brackets: bool) -> Image.Image:
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    cx, cy = size / 2, size * 0.5
    if with_brackets:
        _draw_brackets(draw, cx, cy, unit)
    _draw_lungs(draw, cx, cy, unit)
    return layer


def build_full_bleed() -> Image.Image:
    size = SIZE * SUPERSAMPLE
    image = _vertical_gradient(size, TEAL_LIGHT, TEAL_DARK).convert("RGBA")

    # a faint glow behind the artwork keeps the centre bright
    glow = Image.new("L", (size, size), 0)
    ImageDraw.Draw(glow).ellipse(
        [size * 0.10, size * 0.06, size * 0.90, size * 0.86], fill=80
    )
    glow = glow.filter(ImageFilter.GaussianBlur(size * 0.12))
    image = Image.composite(
        Image.new("RGBA", (size, size), TEAL + (255,)), image, glow
    )

    image.alpha_composite(_artwork(size, size * 0.245, with_brackets=True))
    return image.resize((SIZE, SIZE), Image.Resampling.LANCZOS)


def build_foreground() -> Image.Image:
    """Transparent, artwork scaled to stay inside the adaptive safe zone.

    The brackets reach 1.26 units from the centre, so the unit has to keep
    2 x 1.26 x unit under 66 % of the canvas.
    """
    size = SIZE * SUPERSAMPLE
    return _artwork(size, size * 0.185, with_brackets=True).resize(
        (SIZE, SIZE), Image.Resampling.LANCZOS
    )


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)

    build_full_bleed().convert("RGB").save(OUT / "icon.png")
    build_foreground().save(OUT / "icon_foreground.png")

    # Themed icon: one flat silhouette, no brackets — Android tints it with a
    # single colour, so anything relying on two tones disappears.
    size = SIZE * SUPERSAMPLE
    silhouette = _artwork(size, size * 0.205, with_brackets=False).resize(
        (SIZE, SIZE), Image.Resampling.LANCZOS
    )
    mono = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    mono.paste((255, 255, 255, 255), mask=silhouette.split()[3])
    mono.save(OUT / "icon_monochrome.png")

    for name in ("icon.png", "icon_foreground.png", "icon_monochrome.png"):
        print(f"wrote {OUT / name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
