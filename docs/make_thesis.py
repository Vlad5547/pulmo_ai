# -*- coding: utf-8 -*-
"""Assemble the whole explanatory note of the PulmoAI master's thesis.

Front matter (title page, завдання, реферат/ABSTRACT, перелік умовних
позначень, зміст, вступ) + Chapter 1 + список використаних джерел, in one
file, formatted per the department guidelines (DSTU 3008-2015).

Chapters 2-4 are not written yet; when they are, add their compose() calls
between compose_chapter1() and build_references().

Output: docs/PulmoAI_poyasnyuvalna_zapyska.docx
"""

import io
import sys
from pathlib import Path

if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

sys.path.insert(0, str(Path(__file__).resolve().parent))

import make_chapter1
import make_front_matter
from make_chapter1 import Ch

OUT = Path(__file__).resolve().parent / "PulmoAI_poyasnyuvalna_zapyska.docx"


def build():
    make_chapter1.make_figures()

    c = Ch()
    make_front_matter.compose(c)

    # кожний розділ починають з нової сторінки (методичка, п. 2.1)
    c.doc.add_page_break()
    make_chapter1.compose(c)

    # СПИСОК ВИКОРИСТАНИХ ДЖЕРЕЛ (сам по собі відкриває нову сторінку)
    make_chapter1.build_references(c)

    c.doc.save(OUT)
    print("Explanatory note written to: %s" % OUT)
    print("Front matter + Chapter 1: %d figures, %d tables, %d sources"
          % (c.fig_no, c.tab_no, len(make_chapter1.REFERENCES)))


if __name__ == "__main__":
    build()
