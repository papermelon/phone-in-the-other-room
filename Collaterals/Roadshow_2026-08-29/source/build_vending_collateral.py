#!/usr/bin/env python3
"""Build the first-pass Counting Sheep vending-machine collateral kit."""

from pathlib import Path
from typing import Iterable

from PIL import Image, ImageDraw, ImageFont
from reportlab.lib.colors import Color, HexColor, white
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas
from reportlab.lib.utils import ImageReader


ROOT = Path(__file__).resolve().parents[3]
KIT = ROOT / "Collaterals" / "Roadshow_2026-08-29"
PREVIEWS = KIT / "previews"
PDF_OUT = ROOT / "output" / "pdf"

OLLIE = ROOT / "Assets.xcassets" / "dog" / "dog_classic_sleeping.imageset" / "dog_classic_sleeping.png"
MOCKUP_BASE = KIT / "source" / "booth_environment_imagegen.png"
HERO_SCENE = KIT / "source" / "hero_phone_resting_place_imagegen.png"
NFC_SCENE = KIT / "source" / "nfc_pairing_imagegen.png"

ROUND_FONT = "/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf"
BODY_FONT = "Helvetica"
BODY_BOLD = "Helvetica-Bold"
HEAD_FONT = "CountingSheepRounded"

CREAM = HexColor("#FAF7EA")
PAPER = HexColor("#FFFDF6")
INK = HexColor("#1F201A")
MOSS = HexColor("#587744")
MOSS_DARK = HexColor("#334B32")
MOSS_LIGHT = HexColor("#B9CC92")
AMBER = HexColor("#EBAF38")
LAVENDER = HexColor("#7B73A9")
LAVENDER_LIGHT = HexColor("#C9C1DA")
WOOD = HexColor("#8F5A35")
FLOOR = HexColor("#D8BD91")
MUTED = HexColor("#696A5F")


def register_fonts() -> None:
    pdfmetrics.registerFont(TTFont(HEAD_FONT, ROUND_FONT))


def rounded_label(c: canvas.Canvas, text: str, x: float, y: float, width: float, height: float,
                  fill=MOSS, text_color=white, size: float = 10) -> None:
    c.setFillColor(fill)
    c.roundRect(x, y, width, height, height / 2, stroke=0, fill=1)
    c.setFillColor(text_color)
    c.setFont(BODY_BOLD, size)
    c.drawCentredString(x + width / 2, y + (height - size) / 2 + 1.5, text)


def wrap_lines(text: str, font_name: str, font_size: float, max_width: float) -> list[str]:
    words = text.split()
    lines: list[str] = []
    current = ""
    for word in words:
        trial = word if not current else f"{current} {word}"
        if pdfmetrics.stringWidth(trial, font_name, font_size) <= max_width:
            current = trial
        else:
            if current:
                lines.append(current)
            current = word
    if current:
        lines.append(current)
    return lines


def draw_wrapped(c: canvas.Canvas, text: str, x: float, y_top: float, max_width: float,
                 font_name: str, font_size: float, leading: float, color=INK,
                 max_lines: int | None = None) -> float:
    lines = wrap_lines(text, font_name, font_size, max_width)
    if max_lines is not None:
        lines = lines[:max_lines]
    c.setFillColor(color)
    c.setFont(font_name, font_size)
    y = y_top
    for line in lines:
        c.drawString(x, y, line)
        y -= leading
    return y


def crop_marks(c: canvas.Canvas, trim_x: float, trim_y: float, trim_w: float, trim_h: float,
               mark: float = 4 * mm, gap: float = 1.2 * mm) -> None:
    c.saveState()
    c.setStrokeColor(INK)
    c.setLineWidth(0.35)
    for x in (trim_x, trim_x + trim_w):
        c.line(x, trim_y - gap, x, trim_y - gap - mark)
        c.line(x, trim_y + trim_h + gap, x, trim_y + trim_h + gap + mark)
    for y in (trim_y, trim_y + trim_h):
        c.line(trim_x - gap, y, trim_x - gap - mark, y)
        c.line(trim_x + trim_w + gap, y, trim_x + trim_w + gap + mark, y)
    c.restoreState()


def fit_image(c: canvas.Canvas, path: Path, x: float, y: float, width: float, height: float) -> None:
    with Image.open(path) as img:
        iw, ih = img.size
    scale = min(width / iw, height / ih)
    draw_w, draw_h = iw * scale, ih * scale
    c.drawImage(ImageReader(str(path)), x + (width - draw_w) / 2, y + (height - draw_h) / 2,
                width=draw_w, height=draw_h, mask="auto")


def cover_image(c: canvas.Canvas, path: Path, x: float, y: float, width: float, height: float) -> None:
    """Crop an image to fill a rectangle without distortion."""
    with Image.open(path) as source:
        image = source.convert("RGB")
        source_ratio = image.width / image.height
        target_ratio = width / height
        if source_ratio > target_ratio:
            crop_width = int(image.height * target_ratio)
            left = (image.width - crop_width) // 2
            image = image.crop((left, 0, left + crop_width, image.height))
        else:
            crop_height = int(image.width / target_ratio)
            top = (image.height - crop_height) // 2
            image = image.crop((0, top, image.width, top + crop_height))
        c.drawImage(ImageReader(image), x, y, width=width, height=height, mask="auto")


def draw_paw(c: canvas.Canvas, x: float, y: float, size: float, color=MOSS) -> None:
    c.saveState()
    c.setFillColor(color)
    c.circle(x, y, size * 0.22, stroke=0, fill=1)
    for dx, dy in ((-0.28, 0.25), (-0.09, 0.37), (0.12, 0.37), (0.29, 0.22)):
        c.circle(x + dx * size, y + dy * size, size * 0.10, stroke=0, fill=1)
    c.restoreState()


def draw_phone_bed(c: canvas.Canvas, x: float, y: float, width: float, height: float) -> None:
    c.saveState()
    c.setFillColor(PAPER)
    c.setStrokeColor(MOSS_DARK)
    c.setLineWidth(2)
    c.roundRect(x, y, width, height, 6 * mm, stroke=1, fill=1)
    c.setFillColor(INK)
    c.roundRect(x + width * 0.34, y + height * 0.16, width * 0.32, height * 0.64,
                3 * mm, stroke=0, fill=1)
    c.setFillColor(LAVENDER_LIGHT)
    c.roundRect(x + width * 0.37, y + height * 0.22, width * 0.26, height * 0.50,
                2 * mm, stroke=0, fill=1)
    c.setFillColor(AMBER)
    c.circle(x + width * 0.50, y + height * 0.76, 1.2 * mm, stroke=0, fill=1)
    c.setFillColor(MOSS_LIGHT)
    c.circle(x + width * 0.80, y + height * 0.34, 10 * mm, stroke=0, fill=1)
    c.setFillColor(MOSS_DARK)
    c.setFont(BODY_BOLD, 7)
    c.drawCentredString(x + width * 0.80, y + height * 0.32, "NFC")
    c.restoreState()


def draw_scene_background(c: canvas.Canvas, page_w: float, page_h: float) -> None:
    c.setFillColor(CREAM)
    c.rect(0, 0, page_w, page_h, stroke=0, fill=1)
    c.setFillColor(LAVENDER_LIGHT)
    c.rect(0, page_h * 0.42, page_w, page_h * 0.58, stroke=0, fill=1)
    c.setFillColor(MOSS_LIGHT)
    c.circle(page_w * 0.18, page_h * 0.44, page_w * 0.34, stroke=0, fill=1)
    c.setFillColor(LAVENDER)
    c.circle(page_w * 0.73, page_h * 0.46, page_w * 0.40, stroke=0, fill=1)
    c.setFillColor(CREAM)
    c.rect(0, 0, page_w, page_h * 0.43, stroke=0, fill=1)


def build_hero() -> Path:
    trim_w, trim_h, bleed = 420 * mm, 594 * mm, 3 * mm
    page_w, page_h = trim_w + 2 * bleed, trim_h + 2 * bleed
    out = PDF_OUT / "counting_sheep_hero_poster_A2.pdf"
    c = canvas.Canvas(str(out), pagesize=(page_w, page_h))
    c.setTitle("Counting Sheep Roadshow Hero Poster")
    cover_image(c, HERO_SCENE, 0, 0, page_w, page_h)

    margin = bleed + 28 * mm
    c.saveState()
    c.setFillAlpha(0.93)
    c.setFillColor(CREAM)
    c.roundRect(bleed + 18 * mm, page_h - 172 * mm, 245 * mm, 144 * mm,
                10 * mm, stroke=0, fill=1)
    c.restoreState()
    rounded_label(c, "COUNTING SHEEP  /  29 AUGUST ROADSHOW", margin, page_h - 42 * mm,
                  108 * mm, 10 * mm, fill=MOSS_DARK, size=9)

    c.setFillColor(INK)
    c.setFont(HEAD_FONT, 54)
    y = page_h - 76 * mm
    for line in ("WHERE DOES", "YOUR PHONE", "SLEEP?"):
        c.drawString(margin, y, line)
        y -= 19 * mm

    draw_wrapped(c,
                 "Put your phone to bed in another room. Ollie keeps watch while you wind down, sleep, and begin the morning quietly.",
                 margin, y - 2 * mm, 200 * mm, BODY_FONT, 17, 23, color=INK)

    fit_image(c, OLLIE, bleed + 154 * mm, bleed + 105 * mm, 66 * mm, 50 * mm)

    c.setFillColor(MOSS_DARK)
    c.roundRect(bleed + 18 * mm, bleed + 18 * mm, trim_w - 36 * mm, 92 * mm,
                8 * mm, stroke=0, fill=1)
    c.setFillColor(white)
    c.setFont(HEAD_FONT, 28)
    c.drawString(bleed + 34 * mm, bleed + 72 * mm, "DOWNLOAD COUNTING SHEEP")
    c.setFont(BODY_BOLD, 15)
    c.drawString(bleed + 34 * mm, bleed + 55 * mm, "START YOUR FIRST WIND DOWN TONIGHT")
    c.setFont(BODY_FONT, 10)
    c.drawString(bleed + 34 * mm, bleed + 37 * mm, "Currently available for compatible iPhones.")

    qr_x, qr_y, qr_s = page_w - bleed - 78 * mm, bleed + 27 * mm, 56 * mm
    c.setFillColor(PAPER)
    c.roundRect(qr_x, qr_y, qr_s, qr_s, 4 * mm, stroke=0, fill=1)
    c.setStrokeColor(MOSS_DARK)
    c.setDash(3, 2)
    c.rect(qr_x + 5 * mm, qr_y + 5 * mm, qr_s - 10 * mm, qr_s - 10 * mm, stroke=1, fill=0)
    c.setDash()
    c.setFillColor(MOSS_DARK)
    c.setFont(BODY_BOLD, 9)
    c.drawCentredString(qr_x + qr_s / 2, qr_y + qr_s / 2 + 2, "FINAL APP QR")
    c.setFont(BODY_FONT, 7)
    c.drawCentredString(qr_x + qr_s / 2, qr_y + qr_s / 2 - 10, "REPLACE BEFORE PRINT")

    crop_marks(c, bleed, bleed, trim_w, trim_h)
    c.showPage()
    c.save()
    return out


def draw_mounting_corner(c: canvas.Canvas, x: float, y: float, dx: float, dy: float) -> None:
    c.setLineWidth(0.7)
    c.setStrokeColor(MOSS_DARK)
    c.line(x, y, x + dx, y)
    c.line(x, y, x, y + dy)


def build_vending_card() -> Path:
    trim_w, trim_h, bleed = 90 * mm, 140 * mm, 3 * mm
    page_w, page_h = trim_w + 2 * bleed, trim_h + 2 * bleed
    out = PDF_OUT / "counting_sheep_vending_card_90x140mm.pdf"
    c = canvas.Canvas(str(out), pagesize=(page_w, page_h))
    c.setTitle("Counting Sheep Vending Card - Front and Back")

    # Front
    c.setFillColor(CREAM)
    c.rect(0, 0, page_w, page_h, stroke=0, fill=1)
    c.setFillColor(MOSS_DARK)
    c.rect(0, page_h - 44 * mm, page_w, 44 * mm, stroke=0, fill=1)
    c.setFillColor(white)
    c.setFont(BODY_BOLD, 8)
    c.drawString(bleed + 8 * mm, page_h - 13 * mm, "COUNTING SHEEP")
    c.setFont(HEAD_FONT, 17)
    c.drawString(bleed + 8 * mm, page_h - 25 * mm, "OLLIE'S")
    c.drawString(bleed + 8 * mm, page_h - 34 * mm, "WIND DOWN KIT")

    mount_x, mount_y, mount_s = bleed + 15 * mm, bleed + 46 * mm, 60 * mm
    c.setFillColor(PAPER)
    c.roundRect(mount_x, mount_y, mount_s, mount_s, 5 * mm, stroke=0, fill=1)
    corner = 7 * mm
    draw_mounting_corner(c, mount_x, mount_y, corner, corner)
    draw_mounting_corner(c, mount_x + mount_s, mount_y, -corner, corner)
    draw_mounting_corner(c, mount_x, mount_y + mount_s, corner, -corner)
    draw_mounting_corner(c, mount_x + mount_s, mount_y + mount_s, -corner, -corner)
    c.setFillColor(MUTED)
    c.setFont(BODY_BOLD, 7)
    c.drawCentredString(mount_x + mount_s / 2, mount_y + mount_s / 2 + 2,
                       "COUNTING SHEEP STICKER")
    c.setFont(BODY_FONT, 6.5)
    c.drawCentredString(mount_x + mount_s / 2, mount_y + mount_s / 2 - 9,
                       "MOUNTING AREA")

    nfc_x, nfc_y, nfc_r = bleed + 72 * mm, bleed + 23 * mm, 10 * mm
    c.setFillColor(MOSS_LIGHT)
    c.setStrokeColor(MOSS_DARK)
    c.setLineWidth(1)
    c.circle(nfc_x, nfc_y, nfc_r, stroke=1, fill=1)
    c.setFillColor(MOSS_DARK)
    c.setFont(BODY_BOLD, 7)
    c.drawCentredString(nfc_x, nfc_y + 1, "NFC")

    c.setFillColor(INK)
    c.setFont(HEAD_FONT, 10.5)
    c.drawString(bleed + 8 * mm, bleed + 34 * mm, "PUT YOUR PHONE")
    c.drawString(bleed + 8 * mm, bleed + 27 * mm, "TO BED.")
    c.setFont(BODY_BOLD, 8.5)
    c.drawString(bleed + 8 * mm, bleed + 18 * mm, "Wake before it does.")
    c.setFillColor(MUTED)
    c.setFont(BODY_FONT, 6.5)
    c.drawString(bleed + 8 * mm, bleed + 10 * mm, "KEEP THIS CARD - SETUP IS ON THE BACK")
    crop_marks(c, bleed, bleed, trim_w, trim_h, mark=2 * mm, gap=0.7 * mm)
    c.showPage()

    # Back
    c.setFillColor(PAPER)
    c.rect(0, 0, page_w, page_h, stroke=0, fill=1)
    c.setFillColor(MOSS_DARK)
    c.roundRect(bleed + 6 * mm, page_h - bleed - 25 * mm, trim_w - 12 * mm, 18 * mm,
                4 * mm, stroke=0, fill=1)
    c.setFillColor(white)
    c.setFont(HEAD_FONT, 13)
    c.drawCentredString(page_w / 2, page_h - bleed - 18 * mm, "YOUR FIRST NFC WIND DOWN")

    steps = [
        ("1", "PLAN", "Finish setup. Allow Screen Time and choose apps to limit."),
        ("2", "PAIR", "Settings > Protection & tags > Start with an NFC tag > Set up NFC tag."),
        ("3", "PLACE", "Place the tag where your phone will rest outside the bedroom."),
        ("4", "START", "Tap Put phone away, then tap the tag. Leave your phone there."),
        ("5", "MORNING", "Apps stay limited through Screen-Free Morning. An early exit stays available in Counting Sheep."),
    ]
    y = page_h - bleed - 34 * mm
    step_height = 16.8 * mm
    for number, title, body in steps:
        c.setFillColor(AMBER if number in ("1", "4") else MOSS_LIGHT)
        c.circle(bleed + 12 * mm, y - 5 * mm, 4.2 * mm, stroke=0, fill=1)
        c.setFillColor(INK)
        c.setFont(BODY_BOLD, 7)
        c.drawCentredString(bleed + 12 * mm, y - 7.5 * mm, number)
        c.setFont(BODY_BOLD, 6.8)
        c.drawString(bleed + 21 * mm, y - 2 * mm, title)
        draw_wrapped(c, body, bleed + 21 * mm, y - 7 * mm, trim_w - 29 * mm,
                     BODY_FONT, 6.4, 7.4, color=INK, max_lines=3)
        y -= step_height

    c.setFillColor(CREAM)
    c.roundRect(bleed + 7 * mm, bleed + 6 * mm, trim_w - 14 * mm, 13 * mm,
                3 * mm, stroke=0, fill=1)
    c.setFillColor(MOSS_DARK)
    c.setFont(BODY_BOLD, 7)
    c.drawCentredString(page_w / 2, bleed + 13 * mm, "PAIR IT ONCE. USE IT NIGHTLY.")
    crop_marks(c, bleed, bleed, trim_w, trim_h, mark=2 * mm, gap=0.7 * mm)
    c.showPage()
    c.save()
    return out


def build_onboarding_poster() -> Path:
    trim_w, trim_h, bleed = 297 * mm, 420 * mm, 3 * mm
    page_w, page_h = trim_w + 2 * bleed, trim_h + 2 * bleed
    out = PDF_OUT / "counting_sheep_NFC_onboarding_poster_A3.pdf"
    c = canvas.Canvas(str(out), pagesize=(page_w, page_h))
    c.setTitle("Counting Sheep NFC Onboarding Poster")
    c.setFillColor(CREAM)
    c.rect(0, 0, page_w, page_h, stroke=0, fill=1)

    margin = bleed + 20 * mm
    rounded_label(c, "COUNTING SHEEP STARTER GUIDE", margin, page_h - 32 * mm,
                  88 * mm, 9 * mm, fill=MOSS_DARK, size=8.5)
    c.setFillColor(INK)
    c.setFont(HEAD_FONT, 34)
    c.drawString(margin, page_h - 56 * mm, "YOUR FIRST")
    c.drawString(margin, page_h - 72 * mm, "NFC WIND DOWN")
    c.setFont(BODY_BOLD, 13)
    c.setFillColor(MOSS_DARK)
    c.drawString(margin, page_h - 88 * mm, "PAIR IT ONCE. USE IT NIGHTLY.")

    image_x = page_w - margin - 124 * mm
    image_y = page_h - 109 * mm
    image_w = 124 * mm
    image_h = 82 * mm
    cover_image(c, NFC_SCENE, image_x, image_y, image_w, image_h)
    c.setStrokeColor(MOSS_DARK)
    c.setLineWidth(1.5)
    c.roundRect(image_x, image_y, image_w, image_h, 6 * mm, stroke=1, fill=0)

    steps = [
        ("1", "PLAN", "Finish your Wind Down starting point. Allow Screen Time and choose the apps or categories you want Counting Sheep to limit."),
        ("2", "PAIR", "Open Settings > Protection & tags. Choose Start with an NFC tag, then tap Set up NFC tag."),
        ("3", "PLACE", "Place the paired tag where your phone should rest outside the bedroom. The location stays private on your iPhone."),
        ("4", "START", "When Wind Down begins, tap Put phone away. Hold the top of your iPhone near the tag, then leave the phone there."),
        ("5", "WAKE FIRST", "Selected apps stay limited through Screen-Free Morning. If you need your phone sooner, Counting Sheep keeps an early exit available."),
    ]

    box_w = page_w - 2 * margin
    box_h = 37 * mm
    y = page_h - 137 * mm
    for index, title, body in steps:
        c.setFillColor(PAPER)
        c.setStrokeColor(MOSS_DARK if index in ("1", "4") else LAVENDER)
        c.setLineWidth(1.6)
        c.roundRect(margin, y - box_h, box_w, box_h, 6 * mm, stroke=1, fill=1)
        c.setFillColor(AMBER if index in ("1", "4") else MOSS_LIGHT)
        c.circle(margin + 17 * mm, y - box_h / 2, 9 * mm, stroke=0, fill=1)
        c.setFillColor(INK)
        c.setFont(HEAD_FONT, 15)
        c.drawCentredString(margin + 17 * mm, y - box_h / 2 - 5, index)
        c.setFont(BODY_BOLD, 11)
        c.drawString(margin + 35 * mm, y - 14 * mm, title)
        draw_wrapped(c, body, margin + 35 * mm, y - 24 * mm, box_w - 48 * mm,
                     BODY_FONT, 10, 13, color=INK, max_lines=3)
        y -= box_h + 5 * mm

    fit_image(c, OLLIE, margin, bleed + 11 * mm, 55 * mm, 42 * mm)
    c.setFillColor(MOSS_DARK)
    c.roundRect(margin + 63 * mm, bleed + 15 * mm, box_w - 63 * mm, 30 * mm,
                5 * mm, stroke=0, fill=1)
    c.setFillColor(white)
    c.setFont(HEAD_FONT, 16)
    c.drawString(margin + 74 * mm, bleed + 32 * mm, "PUT YOUR PHONE TO BED.")
    c.setFont(BODY_BOLD, 9.5)
    c.drawString(margin + 74 * mm, bleed + 22 * mm, "Wake before it does.")
    crop_marks(c, bleed, bleed, trim_w, trim_h)
    c.showPage()
    c.save()
    return out


def draw_trim_box(c: canvas.Canvas, x: float, y: float, w: float, h: float,
                  fill, title: str, body: Iterable[str] = ()) -> None:
    c.setFillColor(fill)
    c.setStrokeColor(INK)
    c.setLineWidth(0.5)
    c.roundRect(x, y, w, h, 4 * mm, stroke=1, fill=1)
    c.setFillColor(white if fill in (MOSS_DARK, MOSS, LAVENDER) else INK)
    c.setFont(HEAD_FONT, 13)
    c.drawCentredString(x + w / 2, y + h - 12 * mm, title)
    body_y = y + h - 24 * mm
    c.setFont(BODY_BOLD, 8.5)
    for line in body:
        c.drawCentredString(x + w / 2, body_y, line)
        body_y -= 10 * mm


def build_machine_labels() -> Path:
    page_w, page_h = A4
    out = PDF_OUT / "counting_sheep_machine_labels_A4.pdf"
    c = canvas.Canvas(str(out), pagesize=A4)
    c.setTitle("Counting Sheep Vending Machine Labels")
    c.setFillColor(CREAM)
    c.rect(0, 0, page_w, page_h, stroke=0, fill=1)
    c.setFillColor(MUTED)
    c.setFont(BODY_FONT, 7)
    c.drawString(12 * mm, page_h - 10 * mm, "FIRST-PASS LABEL SHEET - CONFIRM MACHINE DIMENSIONS BEFORE FINAL PRINT")

    margin = 15 * mm
    panel_w = page_w - 2 * margin
    draw_trim_box(c, margin, page_h - 76 * mm, panel_w, 55 * mm, MOSS_DARK,
                  "GET YOUR COUNTING SHEEP STARTER KIT",
                  ("DOWNLOAD THE APP  /  SHOW US YOUR NEW FARM  /  GET ONE KIT",))

    inst_y, inst_h = page_h - 174 * mm, 84 * mm
    c.setFillColor(PAPER)
    c.setStrokeColor(INK)
    c.roundRect(margin, inst_y, panel_w, inst_h, 5 * mm, stroke=1, fill=1)
    c.setFillColor(INK)
    c.setFont(HEAD_FONT, 17)
    c.drawString(margin + 10 * mm, inst_y + inst_h - 17 * mm, "START YOUR COUNTING SHEEP JOURNEY")
    instructions = [
        "1  DOWNLOAD COUNTING SHEEP",
        "2  SHOW US YOUR NEW FARM",
        "3  PRESS THE BUTTON",
        "4  TAKE YOUR WIND DOWN KIT HOME",
    ]
    y = inst_y + inst_h - 32 * mm
    for text in instructions:
        c.setFillColor(MOSS_LIGHT if text.startswith(("1", "3")) else LAVENDER_LIGHT)
        c.roundRect(margin + 10 * mm, y - 5 * mm, panel_w - 20 * mm, 12 * mm,
                    3 * mm, stroke=0, fill=1)
        c.setFillColor(INK)
        c.setFont(BODY_BOLD, 10)
        c.drawString(margin + 15 * mm, y - 1 * mm, text)
        y -= 15 * mm

    slot_y = 50 * mm
    draw_trim_box(c, margin, slot_y, panel_w, 28 * mm, LAVENDER,
                  "A QUIETER NIGHT STARTS HERE")

    button_r = 27.5 * mm
    button_x = page_w - margin - button_r
    button_y = 29 * mm
    c.setFillColor(AMBER)
    c.setStrokeColor(INK)
    c.circle(button_x, button_y, button_r, stroke=1, fill=1)
    c.setFillColor(INK)
    c.setFont(HEAD_FONT, 10)
    c.drawCentredString(button_x, button_y + 3, "DISPENSE")
    c.drawCentredString(button_x, button_y - 10, "KIT")

    c.setFillColor(INK)
    c.setFont(BODY_BOLD, 8)
    c.drawString(margin, 18 * mm, "CUT ALONG OUTER EDGES")
    c.showPage()
    c.save()
    return out


def make_branded_mockup() -> Path:
    image = Image.open(MOCKUP_BASE).convert("RGBA")
    draw = ImageDraw.Draw(image, "RGBA")
    head = ImageFont.truetype(ROUND_FONT, 42)
    head_small = ImageFont.truetype(ROUND_FONT, 24)
    body = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 20)
    body_bold = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 19)

    # Large poster overlay.
    draw.rounded_rectangle((215, 58, 630, 455), radius=22, fill=(250, 247, 234, 245))
    draw.rounded_rectangle((245, 84, 440, 119), radius=15, fill=(51, 75, 50, 255))
    draw.text((266, 91), "COUNTING SHEEP", font=body_bold, fill=(255, 255, 255, 255))
    draw.multiline_text((245, 145), "WHERE DOES\nYOUR PHONE\nSLEEP?", font=head,
                        fill=(31, 32, 26, 255), spacing=7)
    draw.multiline_text((247, 337), "Put your phone to bed.\nWake before it does.", font=body,
                        fill=(51, 75, 50, 255), spacing=5)

    # Machine face overlay.
    draw.rounded_rectangle((634, 333, 964, 603), radius=32, fill=(250, 247, 234, 244),
                           outline=(51, 75, 50, 255), width=4)
    draw.text((693, 374), "COUNTING", font=head_small, fill=(31, 32, 26, 255))
    draw.text((714, 410), "SHEEP", font=head_small, fill=(31, 32, 26, 255))
    draw.rounded_rectangle((681, 465, 918, 529), radius=20, fill=(51, 75, 50, 255))
    draw.text((712, 481), "STARTER KIT", font=body_bold, fill=(255, 255, 255, 255))

    # Easel onboarding overlay.
    draw.rounded_rectangle((1178, 399, 1408, 646), radius=22, fill=(250, 247, 234, 244))
    draw.text((1207, 427), "YOUR FIRST", font=head_small, fill=(31, 32, 26, 255))
    draw.text((1201, 460), "WIND DOWN", font=head_small, fill=(31, 32, 26, 255))
    y = 510
    for index, text in enumerate(("PLAN", "PAIR", "PLACE", "START"), start=1):
        draw.ellipse((1201, y - 2, 1227, y + 24), fill=(235, 175, 56, 255))
        draw.text((1209, y), str(index), font=body_bold, fill=(31, 32, 26, 255))
        draw.text((1240, y), text, font=body_bold, fill=(51, 75, 50, 255))
        y += 35

    # Add real sleeping Ollie as a small foreground brand anchor.
    ollie = Image.open(OLLIE).convert("RGBA")
    ollie.thumbnail((150, 150), Image.Resampling.LANCZOS)
    image.alpha_composite(ollie, (462, 748))

    out = PREVIEWS / "counting_sheep_booth_mockup_branded.png"
    image.convert("RGB").save(out, quality=95)
    return out


def main() -> None:
    register_fonts()
    PREVIEWS.mkdir(parents=True, exist_ok=True)
    PDF_OUT.mkdir(parents=True, exist_ok=True)
    outputs = [
        build_hero(),
        build_vending_card(),
        build_onboarding_poster(),
        build_machine_labels(),
    ]
    mockup = make_branded_mockup()
    print("CREATED")
    for output in outputs:
        print(output)
    print(mockup)


if __name__ == "__main__":
    main()
