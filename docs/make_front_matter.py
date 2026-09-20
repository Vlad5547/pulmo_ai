# -*- coding: utf-8 -*-
"""Generate the front matter of the PulmoAI master's thesis (Ukrainian).

Produces everything that precedes Chapter 1, per the department guidelines
(docs/Методичні_Вказівки.docx, sections 1.3 and 2, appendices А, Б, В, Г, Д):

    * титульний аркуш            (Додаток А)
    * завдання на кваліфікаційну роботу (Додаток Б)
    * РЕФЕРАТ / ABSTRACT         (Додаток В)
    * ПЕРЕЛІК УМОВНИХ ПОЗНАЧЕНЬ  (Додаток Г)
    * ЗМІСТ                      (Додаток Д)
    * ВСТУП                      (2-3 сторінки)

Placeholders marked with ______ must be filled in by the author (name, group,
supervisor, order number, dates, final page counts).

Output: docs/PulmoAI_Vstupna_chastyna.docx
"""

import io
import sys
from pathlib import Path

if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

sys.path.insert(0, str(Path(__file__).resolve().parent))

from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_TAB_ALIGNMENT, WD_TAB_LEADER
from docx.shared import Cm, Pt

from make_chapter1 import FONT, TEXT_WIDTH_CM, Ch

OUT = Path(__file__).resolve().parent / "PulmoAI_Vstupna_chastyna.docx"

TOPIC = ("Модель та програмне забезпечення виявлення пневмонії "
         "на рентгенограмах органів грудної клітки на основі "
         "згорткової нейронної мережі")

OBJECT = ("процес автоматизованого виявлення ознак легеневого затемнення "
          "на цифрових рентгенограмах органів грудної клітки")

SUBJECT = ("моделі, методи та програмні засоби бінарної класифікації "
           "рентгенограм на основі власної згорткової нейронної мережі, "
           "навченої з нуля, методи візуальної інтерпретації її рішень та "
           "їх перенесення у середовище мобільного пристрою")

GOAL = ("підвищення доступності первинного аналізу рентгенограм органів "
        "грудної клітки шляхом розроблення власної компактної згорткової "
        "архітектури для виявлення легеневого затемнення та мобільного "
        "застосунку, що виконує цю модель локально, офлайн, з візуальним "
        "поясненням результату")

NOVELTY = (
    "Наукова новизна отриманих результатів полягає в тому, що розроблено "
    "власну компактну згорткову архітектуру PulmoNet-7M (7 065 953 "
    "параметри), яка, на відміну від відомих рішень, побудована "
    "безпосередньо під одноканальне рентгенівське зображення без штучного "
    "дублювання в три канали, навчається з нуля без використання попередньо "
    "навчених ваг і містить шар глобального усереднення, завдяки чому "
    "візуальне пояснення рішення методом карт активації класів обчислюється "
    "за один прямий прохід і залишається придатним для виконання на "
    "мобільному пристрої. Уперше для такої архітектури кількісно підтверджено "
    "чисельну відтворюваність прогнозу під час перенесення моделі із "
    "середовища навчання у мобільне середовище: розбіжність прогнозованої "
    "ймовірності не перевищує 7,9·10⁻⁷."
)

VALUE = (
    "Практична цінність результатів полягає в розробленні працездатного "
    "мобільного застосунку, який читає вихідний файл дослідження у форматі "
    "DICOM, виконує аналіз повністю локально, без передавання медичних даних "
    "у мережу, і видає ймовірність наявності легеневого затемнення разом із "
    "тепловою картою за 214 мс на серійному смартфоні. Це дає змогу "
    "застосовувати систему в умовах "
    "відсутності зв'язку та кваліфікованого рентгенолога — у закладах "
    "первинної ланки, у сільській місцевості та в польових умовах. "
    "Розроблений конвеєр підготовки даних і методика перевірки паритету "
    "попередньої обробки можуть бути повторно використані в суміжних задачах "
    "аналізу медичних зображень."
)

KEYWORDS_UA = (
    "пневмонія, легеневе затемнення, рентгенографія органів грудної клітки, "
    "згорткова нейронна мережа, глибинне навчання, комп'ютерна підтримка "
    "діагностики, DICOM, карта активації класу, ONNX, мобільний застосунок, "
    "Flutter, PulmoNet-7M"
)

KEYWORDS_EN = (
    "pneumonia, lung opacity, chest X-ray, convolutional neural network, "
    "deep learning, computer-aided diagnosis, DICOM, class activation "
    "mapping, ONNX, mobile application, Flutter, PulmoNet-7M"
)

ABBREVIATIONS = [
    ("ЗНМ", "згорткова нейронна мережа (Convolutional Neural Network)"),
    ("ОГК", "органи грудної клітки"),
    ("ПЗ", "програмне забезпечення"),
    ("СППР", "система підтримки прийняття рішень"),
    ("AP", "anteroposterior — передньозадня проєкція знімання"),
    ("AUPRC", "Area Under the Precision-Recall Curve — площа під кривою "
              "«повнота — точність»"),
    ("BCE", "Binary Cross-Entropy — бінарна перехресна ентропія"),
    ("CAD", "Computer-Aided Diagnosis — комп'ютерна підтримка діагностики"),
    ("CAM", "Class Activation Mapping — карта активації класу"),
    ("CNN", "Convolutional Neural Network — згорткова нейронна мережа"),
    ("CXR", "Chest X-Ray — рентгенограма органів грудної клітки"),
    ("DICOM", "Digital Imaging and Communications in Medicine — стандарт "
              "зберігання та передавання медичних зображень"),
    ("FN", "False Negative — хибно негативний результат"),
    ("FP", "False Positive — хибно позитивний результат"),
    ("GAP", "Global Average Pooling — глобальне усереднення карт ознак"),
    ("GPU", "Graphics Processing Unit — графічний процесор"),
    ("Grad-CAM", "Gradient-weighted Class Activation Mapping"),
    ("HOG", "Histogram of Oriented Gradients — гістограма орієнтованих "
            "градієнтів"),
    ("LBP", "Local Binary Patterns — локальні бінарні шаблони"),
    ("ONNX", "Open Neural Network Exchange — відкритий формат обміну "
             "моделями нейронних мереж"),
    ("ORT", "ONNX Runtime — середовище виконання моделей формату ONNX"),
    ("PA", "posteroanterior — задньопередня проєкція знімання"),
    ("ReLU", "Rectified Linear Unit — функція активації"),
    ("ROC-AUC", "Area Under the Receiver Operating Characteristic Curve — "
                "площа під кривою робочих характеристик"),
    ("RSNA", "Radiological Society of North America — Радіологічне "
             "товариство Північної Америки"),
    ("SVM", "Support Vector Machine — метод опорних векторів"),
    ("TN", "True Negative — істинно негативний результат"),
    ("TP", "True Positive — істинно позитивний результат"),
]

CONTENTS = [
    ("ВСТУП", 0),
    ("РОЗДІЛ 1. АНАЛІЗ ПРЕДМЕТНОЇ ОБЛАСТІ ТА ПОСТАНОВКА ЗАДАЧІ", 0),
    ("1.1. Пневмонія та рентгенографія органів грудної клітки як предметна "
     "область дослідження", 1),
    ("1.2. Системи комп'ютерної підтримки діагностики та класичні методи "
     "аналізу медичних зображень", 1),
    ("1.3. Згорткові нейронні мережі у задачах класифікації медичних "
     "зображень", 1),
    ("1.4. Інтерпретованість моделей глибинного навчання в медичній "
     "діагностиці", 1),
    ("1.5. Набори даних та метрики оцінювання якості", 1),
    ("1.6. Особливості розгортання моделей глибинного навчання на мобільних "
     "пристроях", 1),
    ("1.7. Системний аналіз об'єкта дослідження та постановка задачі", 1),
    ("Висновки до розділу 1", 1),
    ("РОЗДІЛ 2. МЕТОДИКА ДОСЛІДЖЕННЯ ТА ПІДГОТОВКА ДАНИХ", 0),
    ("2.1. Загальна методика дослідження", 1),
    ("2.2. Характеристика набору даних RSNA Pneumonia Detection Challenge "
     "2018", 1),
    ("2.3. Аналіз анотацій та формування цільової мітки", 1),
    ("2.4. Опрацювання формату DICOM та попередня обробка зображень", 1),
    ("2.5. Поділ вибірки на рівні пацієнта", 1),
    ("2.6. Аугментація навчальних даних", 1),
    ("2.7. Обґрунтування функції втрат та системи метрик", 1),
    ("Висновки до розділу 2", 1),
    ("РОЗДІЛ 3. РОЗРОБЛЕННЯ АРХІТЕКТУРИ PULMONET-7M ТА НАВЧАННЯ МОДЕЛІ", 0),
    ("3.1. Вимоги до архітектури та обґрунтування проєктних рішень", 1),
    ("3.2. Структура мережі PulmoNet-7M", 1),
    ("3.3. Методика навчання моделі", 1),
    ("3.4. Результати навчання та відбір моделі за валідаційною вибіркою", 1),
    ("3.5. Оцінювання на тестовій вибірці та аналіз структури помилок", 1),
    ("3.6. Дослідження порога бінаризації", 1),
    ("3.7. Візуальна інтерпретація результатів методом CAM", 1),
    ("Висновки до розділу 3", 1),
    ("РОЗДІЛ 4. ПРОГРАМНА РЕАЛІЗАЦІЯ МОБІЛЬНОГО ЗАСТОСУНКУ", 0),
    ("4.1. Архітектура програмного забезпечення", 1),
    ("4.2. Експорт моделі у формат ONNX та перевірка еквівалентності", 1),
    ("4.3. Забезпечення паритету попередньої обробки", 1),
    ("4.4. Читання формату DICOM на мобільному пристрої", 1),
    ("4.5. Реалізація карт активації класів на пристрої", 1),
    ("4.6. Зберігання історії обстежень та формування звіту", 1),
    ("4.7. Інтерфейс користувача та локалізація", 1),
    ("4.8. Тестування та перевірка на реальному пристрої", 1),
    ("4.9. Інструкція з використання програмного продукту", 1),
    ("Висновки до розділу 4", 1),
    ("ВИСНОВКИ", 0),
    ("СПИСОК ВИКОРИСТАНИХ ДЖЕРЕЛ", 0),
    ("ДОДАТОК А. Тексти програм", 0),
    ("ДОДАТОК Б. Перелік файлів на диску", 0),
]

STAGES = [
    ("Аналіз предметної області, огляд джерел, постановка задачі",
     "10.09.2026 – 30.09.2026"),
    ("Підготовка даних: аналіз анотацій, опрацювання DICOM, поділ вибірки",
     "01.10.2026 – 15.10.2026"),
    ("Проєктування архітектури PulmoNet-7M та навчання моделі",
     "16.10.2026 – 05.11.2026"),
    ("Оцінювання моделі, аналіз помилок, реалізація CAM",
     "06.11.2026 – 20.11.2026"),
    ("Експорт моделі та розроблення мобільного застосунку",
     "21.11.2026 – 05.12.2026"),
    ("Оформлення пояснювальної записки та демонстраційних матеріалів",
     "06.12.2026 – 15.12.2026"),
]


# --------------------------------------------------------------------------
# helpers
# --------------------------------------------------------------------------


def line(c, text="", *, bold=False, size=14, align=WD_ALIGN_PARAGRAPH.CENTER,
         italic=False, after=0, indent=False):
    return c.p(text, indent=indent, align=align, bold=bold, italic=italic,
               size=size, after=after)


def signature(c, left, right_hint="(підпис)", name_hint="(прізвище, ініціали)"):
    par = c.doc.add_paragraph()
    pf = par.paragraph_format
    pf.first_line_indent = Cm(0)
    pf.space_before = Pt(10)
    pf.space_after = Pt(0)
    pf.line_spacing = 1.0
    pf.tab_stops.add_tab_stop(Cm(10.0), WD_TAB_ALIGNMENT.LEFT)
    pf.tab_stops.add_tab_stop(Cm(14.0), WD_TAB_ALIGNMENT.LEFT)
    run = par.add_run("%s\t_______________\t_______________________" % left)
    run.font.name = FONT
    run.font.size = Pt(13)

    hint = c.doc.add_paragraph()
    hf = hint.paragraph_format
    hf.first_line_indent = Cm(0)
    hf.space_after = Pt(0)
    hf.line_spacing = 1.0
    hf.tab_stops.add_tab_stop(Cm(10.0), WD_TAB_ALIGNMENT.LEFT)
    hf.tab_stops.add_tab_stop(Cm(14.0), WD_TAB_ALIGNMENT.LEFT)
    run = hint.add_run("\t%s\t%s" % (right_hint, name_hint))
    run.font.name = FONT
    run.font.size = Pt(9)
    run.italic = True


# --------------------------------------------------------------------------
# 1. титульний аркуш
# --------------------------------------------------------------------------


def _tighten(c, start, spacing=1.15):
    for par in c.doc.paragraphs[start:]:
        par.paragraph_format.line_spacing = spacing


def build_title(c):
    start = len(c.doc.paragraphs)
    line(c, "Міністерство освіти і науки України", size=14)
    line(c, "НАЦІОНАЛЬНИЙ ТЕХНІЧНИЙ УНІВЕРСИТЕТ", bold=True, size=14)
    line(c, "«ДНІПРОВСЬКА ПОЛІТЕХНІКА»", bold=True, size=14, after=18)

    line(c, "Факультет інформаційних технологій", size=13)
    line(c, "(факультет)", size=9, italic=True)
    line(c, "Кафедра програмного забезпечення комп'ютерних систем", size=13)
    line(c, "(повна назва)", size=9, italic=True, after=20)

    line(c, "ПОЯСНЮВАЛЬНА ЗАПИСКА", bold=True, size=16)
    line(c, "кваліфікаційної роботи ступеня  магістра", size=14)
    line(c, "(назва освітнього ступеня)", size=9, italic=True, after=18)

    line(c, "студента ________________________________________________",
         size=13)
    line(c, "(прізвище, ім'я, по батькові)", size=9, italic=True)
    line(c, "академічної групи ______________________", size=13)
    line(c, "(шифр групи)", size=9, italic=True)
    line(c, "спеціальності 122 Комп'ютерні науки", size=13)
    line(c, "за освітньо-професійною програмою «Комп'ютерні науки»",
         size=13, after=12)

    line(c, "на тему:", size=13)
    line(c, "«%s»" % TOPIC, bold=True, size=14, after=18)

    table = c.doc.add_table(rows=1, cols=4)
    table.style = "Table Grid"
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    header = ["Керівники", "Прізвище, ініціали", "Оцінка за шкалою", "Підпис"]
    for cell, text in zip(table.rows[0].cells, header):
        cell.text = ""
        par = cell.paragraphs[0]
        par.paragraph_format.alignment = WD_ALIGN_PARAGRAPH.CENTER
        par.paragraph_format.first_line_indent = Cm(0)
        par.paragraph_format.line_spacing = 1.0
        par.paragraph_format.space_after = Pt(0)
        run = par.add_run(text)
        run.bold = True
        run.font.name = FONT
        run.font.size = Pt(11)
    for label in ("кваліфікаційної роботи", "розділів:", "",
                  "Рецензент", "Нормоконтролер"):
        cells = table.add_row().cells
        for i, cell in enumerate(cells):
            cell.text = ""
            par = cell.paragraphs[0]
            par.paragraph_format.first_line_indent = Cm(0)
            par.paragraph_format.line_spacing = 1.0
            par.paragraph_format.space_after = Pt(0)
            run = par.add_run(label if i == 0 else "")
            run.font.name = FONT
            run.font.size = Pt(11)
    for row in table.rows:
        for cell, width in zip(row.cells, (5.4, 4.6, 4.0, 3.0)):
            cell.width = Cm(width)

    line(c, "", after=10)
    line(c, "Дніпро", size=14)
    line(c, "2026", size=14)
    _tighten(c, start)   # титульний аркуш має вміститися на одній сторінці
    c.doc.add_page_break()


# --------------------------------------------------------------------------
# 2. завдання
# --------------------------------------------------------------------------


def build_task(c):
    line(c, "Міністерство освіти і науки України", size=13)
    line(c, "НАЦІОНАЛЬНИЙ ТЕХНІЧНИЙ УНІВЕРСИТЕТ", bold=True, size=13)
    line(c, "«ДНІПРОВСЬКА ПОЛІТЕХНІКА»", bold=True, size=13, after=12)

    par = c.p("ЗАТВЕРДЖЕНО:", indent=False, align=WD_ALIGN_PARAGRAPH.RIGHT,
              size=12)
    par.paragraph_format.line_spacing = 1.0
    for text in ("завідувач кафедри", "програмного забезпечення "
                 "комп'ютерних систем", "_________________  ______________",
                 "(підпис)                (прізвище, ініціали)",
                 "«____» ______________ 2026 року"):
        par = c.p(text, indent=False, align=WD_ALIGN_PARAGRAPH.RIGHT, size=11)
        par.paragraph_format.line_spacing = 1.0
    line(c, "", after=12)

    line(c, "ЗАВДАННЯ", bold=True, size=15)
    line(c, "на виконання кваліфікаційної роботи магістра", size=13, after=12)

    for text in (
        "спеціальності  122 Комп'ютерні науки",
        "студенту  ____________________  ____________________________________",
        "                     (група)                                  "
        "(прізвище, ім'я, по батькові)",
        "Тема кваліфікаційної роботи: «%s»" % TOPIC,
    ):
        par = c.p(text, indent=False, size=12)
        par.paragraph_format.line_spacing = 1.15
    line(c, "", after=10)

    c.p("1 ПІДСТАВИ ДЛЯ ПРОВЕДЕННЯ РОБОТИ", indent=False, bold=True, size=13,
        after=4)
    c.p("Наказ ректора НТУ «Дніпровська політехніка» від «____» "
        "____________ 2026 р. № ________", indent=False, size=13, after=10)

    c.p("2 МЕТА ТА ВИХІДНІ ДАНІ ДЛЯ ПРОВЕДЕННЯ РОБІТ", indent=False,
        bold=True, size=13, after=4)
    c.p("Об'єкт досліджень — %s." % OBJECT, size=13)
    c.p("Предмет досліджень — %s." % SUBJECT, size=13)
    c.p("Мета роботи — %s." % GOAL, size=13)
    c.p("Вихідні дані — відкритий набір даних RSNA Pneumonia Detection "
        "Challenge 2018 обсягом 29 684 рентгенограми у форматі DICOM з "
        "експертною розміткою трьох класів та обмежувальними прямокутниками "
        "ділянок затемнення.", size=13, after=10)

    c.p("3 ОЧІКУВАНІ НАУКОВІ РЕЗУЛЬТАТИ", indent=False, bold=True, size=13,
        after=4)
    c.p(NOVELTY, size=13)
    c.p(VALUE, size=13, after=10)

    c.p("4 ВИМОГИ ДО РЕЗУЛЬТАТІВ ВИКОНАННЯ РОБОТИ", indent=False, bold=True,
        size=13, after=4)
    c.p("У результаті роботи має бути розроблено програмний комплекс, що "
        "складається з дослідницької частини (конвеєр підготовки даних, "
        "навчання та оцінювання власної згорткової моделі) та мобільного "
        "застосунку, який виконує навчену модель локально й надає візуальне "
        "пояснення результату. Якість моделі має бути підтверджена "
        "кількісними оцінками на незалежній тестовій вибірці, а чисельна "
        "відповідність мобільної реалізації еталонній — окремим вимірюванням.",
        size=13, after=10)

    c.p("5 ЕТАПИ ВИКОНАННЯ РОБІТ", indent=False, bold=True, size=13, after=4)
    table = c.doc.add_table(rows=1, cols=2)
    table.style = "Table Grid"
    for cell, text in zip(table.rows[0].cells, ("Найменування етапів робіт",
                                                "Терміни виконання")):
        cell.text = ""
        par = cell.paragraphs[0]
        par.paragraph_format.alignment = WD_ALIGN_PARAGRAPH.CENTER
        par.paragraph_format.first_line_indent = Cm(0)
        par.paragraph_format.line_spacing = 1.0
        par.paragraph_format.space_after = Pt(0)
        run = par.add_run(text)
        run.bold = True
        run.font.name = FONT
        run.font.size = Pt(11)
    for name, term in STAGES:
        cells = table.add_row().cells
        for cell, text in zip(cells, (name, term)):
            cell.text = ""
            par = cell.paragraphs[0]
            par.paragraph_format.first_line_indent = Cm(0)
            par.paragraph_format.line_spacing = 1.0
            par.paragraph_format.space_after = Pt(0)
            run = par.add_run(text)
            run.font.name = FONT
            run.font.size = Pt(11)
    for row in table.rows:
        for cell, width in zip(row.cells, (11.5, 5.5)):
            cell.width = Cm(width)
    line(c, "", after=8)

    c.p("6 ДОДАТКОВІ ВИМОГИ", indent=False, bold=True, size=13, after=4)
    c.p("Пояснювальна записка оформлюється відповідно до ДСТУ 3008-2015; "
        "бібліографічний опис джерел — відповідно до ДСТУ 7.1:2006. Набір "
        "медичних даних використовується виключно в режимі читання, без "
        "модифікації вихідних файлів.", size=13, after=14)

    signature(c, "Завдання видав                    керівник роботи")
    signature(c, "Завдання прийняв до виконання     студент")
    line(c, "", after=8)
    par = c.p("Дата видачі завдання:  «____» ____________ 2026 р.",
              indent=False, size=12)
    par.paragraph_format.line_spacing = 1.15
    par = c.p("Термін подання кваліфікаційної роботи до ЕК:  «____» "
              "____________ 2026 р.", indent=False, size=12)
    par.paragraph_format.line_spacing = 1.15
    c.doc.add_page_break()


# --------------------------------------------------------------------------
# 3. реферат / abstract
# --------------------------------------------------------------------------


def build_abstract(c):
    start = len(c.doc.paragraphs)
    line(c, "РЕФЕРАТ", bold=True, size=15, after=10)
    c.p("Пояснювальна записка: ____ стор., ____ рис., ____ табл., "
        "2 додатки, ____ джерел.", indent=False, size=13, after=4)
    c.p("Об'єкт дослідження: %s." % OBJECT, size=13)
    c.p("Предмет дослідження: %s." % SUBJECT, size=13)
    c.p("Мета роботи: %s." % GOAL, size=13)
    c.p("Вихідні дані: відкритий набір RSNA Pneumonia Detection Challenge "
        "2018 — 29 684 рентгенограми у форматі DICOM з експертною розміткою "
        "трьох класів; частка позитивного класу 23,94 %.", size=13)
    c.p("Методи дослідження: системний аналіз предметної області, цифрова "
        "обробка зображень, глибинне навчання (згорткові нейронні мережі, "
        "стохастична оптимізація, регуляризація, аугментація), математична "
        "статистика та теорія діагностичних тестів (ROC- і PR-аналіз, "
        "статистика Юдена), методи візуальної інтерпретації моделей, "
        "інженерія програмного забезпечення.", size=13)
    c.p("Наукова новизна: розроблено власну компактну згорткову архітектуру "
        "PulmoNet-7M (7 065 953 параметри), яка, на відміну від відомих "
        "рішень, побудована безпосередньо під одноканальне рентгенівське "
        "зображення, навчається з нуля без попередньо навчених ваг і завдяки "
        "шару глобального усереднення обчислює візуальне пояснення за один "
        "прямий прохід; кількісно підтверджено відтворюваність прогнозу під "
        "час перенесення моделі на мобільний пристрій (розбіжність "
        "ймовірності до 7,9·10⁻⁷ для експортованих зображень і 1,3·10⁻³ для "
        "вихідних файлів DICOM, без зміни вердиктів).", size=13)
    c.p("Практична цінність: розроблено мобільний застосунок, який аналізує "
        "рентгенограму повністю локально, без передавання медичних даних у "
        "мережу, і видає ймовірність наявності затемнення разом із тепловою "
        "картою за 214 мс на серійному смартфоні.", size=13)
    c.p("Область застосування: заклади охорони здоров'я первинної ланки, "
        "мобільні та польові медичні підрозділи, скринінгові програми.",
        size=13)
    c.p("Значення роботи та висновки: модель досягає ROC-AUC 0,8739 та "
        "AUPRC 0,6794 на незалежній тестовій вибірці за чутливості 0,8293 і "
        "специфічності 0,7617, що підтверджує працездатність власної "
        "компактної архітектури, навченої з нуля.", size=13)
    c.p("Ключові слова: %s." % KEYWORDS_UA, size=13)
    _tighten(c, start)          # реферат має вміститися на одній сторінці
    c.doc.add_page_break()

    start = len(c.doc.paragraphs)
    line(c, "ABSTRACT", bold=True, size=15, after=10)
    c.p("Explanatory note: ____ pages, ____ figures, ____ tables, "
        "2 appendices, ____ sources.", indent=False, size=13, after=4)
    c.p("Object of research: the process of automated detection of lung "
        "opacity signs on digital chest radiographs.", size=13)
    c.p("Subject of research: models, methods and software for binary "
        "classification of chest radiographs based on a custom convolutional "
        "neural network trained from scratch, methods of visual "
        "interpretation of its decisions and their deployment to a mobile "
        "device.", size=13)
    c.p("Purpose of the master's thesis: to improve the availability of "
        "primary chest radiograph analysis by developing a custom compact "
        "convolutional architecture for lung opacity detection and a mobile "
        "application that runs this model locally, offline, with a visual "
        "explanation of the result.", size=13)
    c.p("Source data: the open RSNA Pneumonia Detection Challenge 2018 "
        "dataset — 29,684 chest radiographs in DICOM format with expert "
        "annotation of three classes; the positive class accounts for "
        "23.94 % of the sample.", size=13)
    c.p("Research methods: system analysis of the subject area, digital "
        "image processing, deep learning (convolutional neural networks, "
        "stochastic optimisation, regularisation, augmentation), "
        "mathematical statistics and diagnostic test theory (ROC and PR "
        "analysis, Youden's index), model interpretation methods, software "
        "engineering.", size=13)
    c.p("Originality of research: a custom compact convolutional "
        "architecture PulmoNet-7M (7,065,953 parameters) has been developed "
        "which, unlike known solutions, is designed directly for a "
        "single-channel radiographic input, is trained from scratch without "
        "pretrained weights and, owing to the global average pooling layer, "
        "computes its visual explanation in a single forward pass; the "
        "reproducibility of the prediction after deployment to a mobile "
        "device has been confirmed quantitatively (probability deviation up "
        "to 7.9e-07).", size=13)
    c.p("Practical value: a mobile application has been developed that "
        "analyses a radiograph entirely locally, without transmitting "
        "medical data over the network, and returns the probability of lung "
        "opacity together with a heat map in 214 ms on a commodity "
        "smartphone.", size=13)
    c.p("Scope of application: primary care facilities, mobile and field "
        "medical units, screening programmes.", size=13)
    c.p("The value of the work and conclusions: the model achieves a ROC-AUC "
        "of 0.8739 and an AUPRC of 0.6794 on an independent test set with a "
        "sensitivity of 0.8293 and a specificity of 0.7617, which confirms "
        "the viability of a custom compact architecture trained from "
        "scratch.", size=13)
    c.p("Keywords: %s." % KEYWORDS_EN, size=13)
    _tighten(c, start)
    c.doc.add_page_break()


def build_abbreviations(c):
    start = len(c.doc.paragraphs)
    line(c, "ПЕРЕЛІК УМОВНИХ ПОЗНАЧЕНЬ", bold=True, size=15, after=12)
    last = len(ABBREVIATIONS) - 1
    for i, (short, full) in enumerate(ABBREVIATIONS):
        par = c.p("%s – %s%s" % (short, full, "." if i == last else ";"),
                  indent=False, size=13)
        par.paragraph_format.left_indent = Cm(1.5)
    # перелік оформлюється на окремому аркуші (методичка, п. 1.3)
    _tighten(c, start)
    c.doc.add_page_break()


# --------------------------------------------------------------------------
# 5. зміст
# --------------------------------------------------------------------------


def build_contents(c):
    line(c, "ЗМІСТ", bold=True, size=15, after=12)
    for text, level in CONTENTS:
        par = c.doc.add_paragraph()
        pf = par.paragraph_format
        pf.first_line_indent = Cm(0)
        pf.left_indent = Cm(1.0 if level else 0)
        pf.space_after = Pt(0)
        pf.line_spacing = 1.5
        pf.alignment = WD_ALIGN_PARAGRAPH.LEFT
        pf.tab_stops.add_tab_stop(Cm(TEXT_WIDTH_CM - (1.0 if level else 0)),
                                  WD_TAB_ALIGNMENT.RIGHT, WD_TAB_LEADER.DOTS)
        run = par.add_run("%s\t___" % text)
        run.font.name = FONT
        run.font.size = Pt(13)
        run.bold = level == 0
    c.p("", indent=False, after=6)
    par = c.p("Номери сторінок проставляються після остаточного компонування "
              "пояснювальної записки.", indent=False, italic=True, size=11)
    par.paragraph_format.line_spacing = 1.0
    c.doc.add_page_break()


# --------------------------------------------------------------------------
# 6. вступ
# --------------------------------------------------------------------------


def build_intro(c):
    line(c, "ВСТУП", bold=True, size=15, after=12)
    c.p("Актуальність теми. Пневмонія залишається однією з провідних причин "
        "звернення по медичну допомогу та смертності у світі: інфекції "
        "нижніх дихальних шляхів щорічно спричиняють понад два з половиною "
        "мільйони смертей, а серед дітей віком до п'яти років пневмонія є "
        "основною інфекційною причиною смерті. Рентгенографія органів грудної "
        "клітки є обов'язковим елементом підтвердження діагнозу, однак "
        "доступність кваліфікованої інтерпретації знімка суттєво обмежена: "
        "кількість рентгенологів зростає значно повільніше, ніж обсяг "
        "досліджень, а в закладах первинної ланки, у сільській місцевості та "
        "в польових умовах профільного фахівця часто немає взагалі. "
        "Додатковим чинником є обмежена відтворюваність висновку людини — "
        "міжекспертна узгодженість інтерпретації рентгенограм при підозрі на "
        "пневмонію перебуває лише на помірному рівні.")
    c.p("Сучасні методи глибинного навчання дають змогу автоматизувати "
        "первинний аналіз рентгенограм, проте переважна більшість "
        "опублікованих рішень спирається на великі попередньо навчені "
        "архітектури загального призначення. Такі моделі розраховані на "
        "тривимірний кольоровий вхід, містять десятки мільйонів параметрів, "
        "надлишкових для бінарної задачі, потребують хмарних обчислень і "
        "не надають користувачеві пояснення свого рішення. Водночас "
        "передавання медичних зображень за межі закладу є окремою проблемою "
        "з погляду захисту даних, а залежність від каналу зв'язку знецінює "
        "систему саме в тих умовах, де вона найбільш потрібна. Тому "
        "актуальною є задача розроблення компактної власної архітектури, "
        "здатної працювати локально на мобільному пристрої та пояснювати "
        "свій висновок візуально.")
    c.p("Мета роботи — %s." % GOAL)
    c.p("Для досягнення поставленої мети необхідно розв'язати такі завдання:")
    for item in (
        "проаналізувати предметну область, наявні набори даних та методи "
        "автоматизованого аналізу рентгенограм органів грудної клітки;",
        "розробити конвеєр підготовки даних з коректним опрацюванням формату "
        "DICOM та поділом вибірки на рівні пацієнта;",
        "спроєктувати власну згорткову архітектуру, орієнтовану на "
        "одноканальний вхід, та обґрунтувати її структурні рішення;",
        "навчити модель з нуля, дослідити вплив дисбалансу класів і виконати "
        "відбір робочого порога за валідаційною вибіркою;",
        "оцінити якість моделі на незалежній тестовій вибірці та "
        "проаналізувати структуру її помилок;",
        "реалізувати метод візуальної інтерпретації результату на основі "
        "карт активації класів;",
        "експортувати модель у проміжний формат, розробити мобільний "
        "застосунок, що виконує її локально та читає вихідний формат DICOM, і "
        "кількісно підтвердити відтворюваність прогнозу на обох шляхах "
        "надходження зображення.",
    ):
        c.bullet(item)
    c.p("Об'єкт дослідження — %s." % OBJECT)
    c.p("Предмет дослідження — %s." % SUBJECT)
    c.p("Методи дослідження. Для розв'язання поставлених задач використано "
        "методи системного аналізу предметної області, цифрової обробки "
        "зображень, машинного та глибинного навчання (згорткові нейронні "
        "мережі, стохастична оптимізація, регуляризація, аугментація даних), "
        "методи математичної статистики та теорії перевірки діагностичних "
        "тестів (ROC- і PR-аналіз, статистика Юдена), методи візуальної "
        "інтерпретації моделей глибинного навчання, а також методи інженерії "
        "програмного забезпечення та модульного тестування.")
    c.p(NOVELTY)
    c.p(VALUE)
    c.p("Апробація результатів. ____________________________________________ "
        "(назви статей, тез доповідей, конференцій — заповнюється за "
        "наявності).")
    c.p("Структура та обсяг роботи. Пояснювальна записка складається зі "
        "вступу, чотирьох розділів, висновків, списку використаних джерел та "
        "двох додатків.")
    c.p("У першому розділі виконано аналіз предметної області: розглянуто "
        "медико-соціальне значення задачі, особливості рентгенівського "
        "зображення та формату DICOM, структуру систем комп'ютерної "
        "підтримки діагностики, класичні та нейромережеві методи аналізу "
        "медичних зображень, методи інтерпретації рішень моделей, наявні "
        "набори даних і метрики оцінювання, а також особливості виконання "
        "моделей на мобільних пристроях; сформульовано постановку задачі.")
    c.p("У другому розділі описано методику дослідження: характеристику "
        "обраного набору даних, аналіз анотацій та формування цільової мітки, "
        "опрацювання формату DICOM, схему попередньої обробки та аугментації, "
        "поділ вибірки на рівні пацієнта й обґрунтування функції втрат та "
        "системи метрик.")
    c.p("У третьому розділі наведено розроблення архітектури PulmoNet-7M, "
        "методику та результати її навчання, оцінювання на незалежній "
        "тестовій вибірці, аналіз структури помилок, дослідження порога "
        "бінаризації та реалізацію візуальної інтерпретації методом карт "
        "активації класів.")
    c.p("У четвертому розділі описано програмну реалізацію мобільного "
        "застосунку: архітектуру програмного забезпечення, експорт моделі у "
        "формат ONNX та перевірку її еквівалентності, забезпечення паритету "
        "попередньої обробки, реалізацію карт активації на пристрої, "
        "інтерфейс користувача, результати тестування та інструкцію з "
        "використання.")
    c.p("Загальний обсяг пояснювальної записки становить ____ сторінок, з "
        "них основна частина — ____ сторінок; робота містить ____ рисунків, "
        "____ таблиць та ____ джерел.")


def compose(c):
    """Add the front matter to an existing document."""
    # на титульному аркуші номер сторінки не проставляється
    c.doc.sections[0].different_first_page_header_footer = True
    build_title(c)
    build_task(c)
    build_abstract(c)
    build_abbreviations(c)
    build_contents(c)
    build_intro(c)


def build():
    c = Ch()
    compose(c)
    c.doc.save(OUT)
    print("Front matter written to: %s" % OUT)
    print("Sections: title page, task, abstract (UA/EN), abbreviations (%d), "
          "contents (%d entries), introduction"
          % (len(ABBREVIATIONS), len(CONTENTS)))


if __name__ == "__main__":
    build()
