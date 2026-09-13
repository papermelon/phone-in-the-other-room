#!/usr/bin/env python3
"""Build registered Ollie motion sprites from the approved 2026-08-28 studies.

The atlas has a painted checkerboard. Local Apple Vision foreground masks are frozen by
source-crop hash, preserving Ollie's white fur without uploading, redrawing, or colour-keying
the source. Default output is QA-only; publishing is deliberately explicit.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter


CANVAS = 512
BASELINE_Y = 470
REPO = Path(__file__).resolve().parents[2]
OUTPUT = REPO / "output/design/ollie-motion-20260828"
SOURCES = OUTPUT / "sources"
USED_VISION_MASKS: set[Path] = set()
WORK = Path("/tmp/counting-sheep-ollie-motion-20260828")
ASSETS = REPO / "Assets.xcassets/dog"
EXTERNAL_ATLAS = Path("/Users/ngawangchime/.codex/generated_images/01a041c4-6ec5-78f0-a807-e3a755f21a9e/exec-f829a7f2-3f66-426e-a4c8-e0b88e595e29.png")
ATLAS = SOURCES / "ollie-motion-atlas-20260828.png"
ORIGINAL_EAR_STUDY = REPO / "output/design/home-minimal-20260828/assets/ollie-ear-reference-study.png"
ORIGINAL_TONGUE_STUDY = REPO / "output/design/home-minimal-20260828/assets/ollie-tongue-welcome-study.png"
EAR_STUDY = SOURCES / ORIGINAL_EAR_STUDY.name
TONGUE_STUDY = SOURCES / ORIGINAL_TONGUE_STUDY.name
NEUTRAL = ASSETS / "dog_classic_home_idle_frame_01.imageset/dog_classic_home_idle_frame_01.png"
OVERLAYS = {
    "moss_bandana": ASSETS / "dog_classic_farm_moss_bandana_equipped_overlay.imageset/dog_classic_farm_moss_bandana_equipped_overlay.png",
    "moon_kerchief": ASSETS / "dog_classic_farm_moon_kerchief_equipped_overlay.imageset/dog_classic_farm_moon_kerchief_equipped_overlay.png",
    "brass_trail_bell": ASSETS / "dog_classic_farm_brass_trail_bell_equipped_overlay.imageset/dog_classic_farm_brass_trail_bell_equipped_overlay.png",
}
HOME_IDLE = {
    frame: ASSETS / f"dog_classic_home_idle_frame_{frame:02d}.imageset/dog_classic_home_idle_frame_{frame:02d}.png"
    for frame in range(1, 7)
}
ATLAS_CROPS = {
    2: (384, 0, 768, 341),
    3: (768, 0, 1152, 341),
    5: (0, 341, 384, 683),
    6: (384, 341, 768, 683),
    # The tail in these cells crosses the nominal 384px grid boundary.  The local Vision
    # mask selects Ollie only, so the left overhang is preserved without neighbouring art.
    7: (763, 341, 1152, 683),
    8: (1137, 341, 1536, 683),
    9: (0, 683, 384, 1024),
    10: (384, 683, 768, 1024),
    11: (768, 670, 1152, 1024),
}


def rgba(path: Path) -> Image.Image:
    return Image.open(path).convert("RGBA")


def display_path(path: Path) -> str:
    return str(path.relative_to(REPO)) if path.is_relative_to(REPO) else str(path)


def binary_close(mask: np.ndarray, size: int) -> np.ndarray:
    image = Image.fromarray((mask * 255).astype("uint8"))
    return np.asarray(image.filter(ImageFilter.MaxFilter(size)).filter(ImageFilter.MinFilter(size))) > 0


def fill_outside(mask: np.ndarray) -> np.ndarray:
    """Flood only detected background; dog-white interior pixels are protected later."""
    h, w = mask.shape
    outside = np.zeros((h, w), dtype=bool)
    queue: deque[tuple[int, int]] = deque()
    for x in range(w):
        for y in (0, h - 1):
            if not mask[y, x] and not outside[y, x]:
                outside[y, x] = True
                queue.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if not mask[y, x] and not outside[y, x]:
                outside[y, x] = True
                queue.append((y, x))
    while queue:
        y, x = queue.popleft()
        for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
            if 0 <= ny < h and 0 <= nx < w and not mask[ny, nx] and not outside[ny, nx]:
                outside[ny, nx] = True
                queue.append((ny, nx))
    return ~outside


def vision_matte(source: Image.Image, pose: int) -> Image.Image:
    """Use macOS's local foreground-instance model instead of a colour key.

    The checker and Ollie's white blaze can share exact RGB values.  Vision derives the
    complete dog instance locally, including its white interior, without uploading art or
    redrawing it.  The helper is compiled from the versioned sibling Swift source.
    """
    WORK.mkdir(parents=True, exist_ok=True)
    executable = WORK / "foreground-mask"
    if not executable.exists():
        subprocess.run(["xcrun", "swiftc", str(REPO / "scripts/art/foreground_mask.swift"), "-o", str(executable)], check=True)
    source_hash = hashlib.sha256(source.convert("RGBA").tobytes()).hexdigest()
    persisted = SOURCES / "vision-masks" / f"atlas-pose-{pose:02d}-{source_hash[:16]}-mask.png"
    source_path = WORK / f"atlas-pose-{pose:02d}-source.png"
    mask_path = WORK / f"atlas-pose-{pose:02d}-mask.png"
    if persisted.exists() and Image.open(persisted).size == source.size:
        mask_path = persisted
    else:
        source.save(source_path)
        subprocess.run([str(executable), str(source_path), str(mask_path)], check=True)
        persisted.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(mask_path, persisted)
        mask_path = persisted
    USED_VISION_MASKS.add(mask_path)
    result = source.convert("RGBA")
    result.putalpha(Image.open(mask_path).convert("L"))
    return result


def dark_study_matte(source: Image.Image) -> Image.Image:
    array = np.asarray(source.convert("RGB"), dtype=np.int16)
    # Studies sit on a near-black neutral background. Keep the painted edge but discard
    # its dark surround; dilation bridges paper texture voids in the white chest.
    spread = array.max(axis=2) - array.min(axis=2)
    luminance = array.mean(axis=2)
    seed = (luminance > 28) & ((spread > 3) | (luminance > 60))
    seed = binary_close(seed, 3)
    alpha = Image.fromarray((fill_outside(seed) * 255).astype("uint8"))
    result = source.convert("RGBA")
    result.putalpha(alpha)
    return result


def crop_alpha(image: Image.Image, padding: int = 2) -> Image.Image:
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("empty alpha after extraction")
    x0, y0, x1, y1 = bbox
    return image.crop((max(0, x0 - padding), max(0, y0 - padding), min(image.width, x1 + padding), min(image.height, y1 + padding)))


def place_on_canvas(image: Image.Image, scale: float, baseline: int = BASELINE_Y, center_x: int = 256) -> Image.Image:
    cropped = crop_alpha(image)
    resized = cropped.resize((round(cropped.width * scale), round(cropped.height * scale)), Image.Resampling.LANCZOS)
    out = Image.new("RGBA", (CANVAS, CANVAS))
    out.alpha_composite(resized, (round(center_x - resized.width / 2), baseline - resized.height))
    return out


def atlas_cell(source: Image.Image, pose: int) -> Image.Image:
    if pose in ATLAS_CROPS:
        return source.crop(ATLAS_CROPS[pose])
    col = (pose - 1) % 4
    row = (pose - 1) // 4
    x0 = col * 384
    x1 = (col + 1) * 384
    y_bounds = (0, 341, 683, 1024)
    return source.crop((x0, y_bounds[row], x1, y_bounds[row + 1]))


def repair_pose9_neck(source: Image.Image) -> Image.Image:
    """Restore Vision's enclosed white neck island from the original source RGB."""
    result = source.copy()
    alpha = np.array(result.getchannel("A"), dtype=np.uint8, copy=True)
    # This is a fully enclosed foreground hole in pose 09; outside-connected gaps between
    # paws/tail remain transparent. Filling it restores the atlas's own white-fur pixels.
    enclosed = fill_outside(alpha > 128) & (alpha == 0)
    alpha[enclosed] = 255
    result.putalpha(Image.fromarray(alpha))
    return result


def overlay_anchor(pose: int) -> tuple[int, int, float, bool]:
    """neck anchor, scale, and whether a bandana sits behind the raised head."""
    # Anchors are in the registered 512px canvases, calibrated from the canonical neck at
    # (285, 214). Lying poses move the neck left/down and widen the fabric slightly.
    anchors = {
        1: (295, 259, 1.00, False), 2: (295, 259, 1.00, False), 3: (295, 259, 1.00, False),
        4: (295, 259, 1.00, False), 5: (270, 350, 0.68, False), 6: (275, 380, 0.55, False),
        7: (230, 350, 0.70, False), 8: (245, 388, 0.52, False), 9: (240, 400, 0.48, False),
        10: (245, 380, 0.55, False), 11: (295, 300, 0.85, False), 12: (295, 259, 1.00, False),
    }
    return anchors[pose]


def transform_overlay_at(source: Image.Image, anchor: tuple[int, int, float]) -> Image.Image:
    ax, ay, scale = anchor
    bbox = source.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("empty cosmetic overlay")
    item = source.crop(bbox)
    item = item.resize((round(item.width * scale), round(item.height * scale)), Image.Resampling.LANCZOS)
    out = Image.new("RGBA", (CANVAS, CANVAS))
    # Original overlay is registered around its neck center at x=285,y=214.
    original_center = (285, 214)
    source_center = ((bbox[0] + bbox[2]) / 2, (bbox[1] + bbox[3]) / 2)
    offset_x = (source_center[0] - original_center[0]) * scale
    offset_y = (source_center[1] - original_center[1]) * scale
    x = round(ax + offset_x - item.width / 2)
    y = round(ay + offset_y - item.height / 2)
    out.alpha_composite(item, (x, y))
    return out


def transform_overlay(source: Image.Image, pose: int) -> Image.Image:
    ax, ay, scale, _ = overlay_anchor(pose)
    return transform_overlay_at(source, (ax, ay, scale))


def create_overlay_with_occlusion(overlay: Image.Image, base: Image.Image, pose: int, cosmetic: str, neck_y: int | None = None) -> Image.Image:
    # A collar/bandana lies at the throat. Only the upper part that crosses a raised head
    # is placed behind the dog; the hanging fabric/bell remains visibly in front.
    alpha = np.array(overlay.getchannel("A"), dtype=np.uint8, copy=True)
    body = np.asarray(base.getchannel("A"), dtype=np.uint8)
    yy = np.indices(alpha.shape)[0]
    # Collars are repositioned below the actual jaw so fabric and bell remain opaque and
    # recognizable. Only the small upper collar section crossing the jaw goes behind Ollie.
    if pose in {1, 4, 12} or neck_y is not None:
        overlap = body > 220
        alpha[overlap & (yy < 255)] = 0
    else:
        neck = neck_y if neck_y is not None else overlay_anchor(pose)[1]
        under_jaw = (body > 220) & (yy < neck - 3)
        alpha[under_jaw] = 0
        if pose in {7, 8, 9, 10, 11}:
            # The lowest lying frames put head, jaw, and forepaws in front of a collar.
            # A per-pose contour avoids the earlier horizontal cut, which left cloth across
            # a cheek or as a badge on a paw. Fabric survives only at true side/knot gaps.
            contours = {
                7: [[(205, 220), (390, 225), (385, 355), (465, 350), (490, 455), (205, 470), (195, 345)]],
                8: [[(230, 265), (465, 270), (455, 400), (490, 390), (500, 470), (235, 475), (220, 365)]],
                9: [[(230, 295), (480, 295), (490, 470), (220, 470)]],
                10: [[(220, 225), (435, 230), (430, 380), (480, 365), (490, 470), (235, 470), (200, 340)]],
                11: [[(215, 115), (395, 120), (390, 290), (240, 320), (205, 245)]],
            }
            foreground = Image.new("L", (CANVAS, CANVAS))
            draw = ImageDraw.Draw(foreground)
            for contour in contours[pose]:
                draw.polygon(contour, fill=255)
            alpha[(body > 220) & (np.asarray(foreground) > 0)] = 0
    result = overlay.copy()
    result.putalpha(Image.fromarray(alpha))
    return result


def manifest() -> dict:
    pose_name = lambda number: "dog/dog_classic_home_idle_frame_01" if number in (1, 12) else f"dog/dog_ollie_motion_pose_{number:02d}"
    return {
        "schemaVersion": 1,
        "canvas": {"width": 512, "height": 512, "origin": "topLeft", "pawBaselineY": BASELINE_Y},
        "alpha": "straight RGBA; transparent pixels have alpha 0",
        "poses": {f"{n:02d}": pose_name(n) for n in range(1, 13)},
        "actions": {
            "earTuck": {"poses": [1, 2, 3], "durationsSeconds": [0.16, 0.16, 0.28]},
            "tongueGreeting": {"poses": [1, 4, 1], "durationsSeconds": [0.18, 0.36, 0.21]},
            "settleToRest": {"poses": [3, 5, 6, 7, 8, 9], "durationsSeconds": [0.16, 0.16, 0.18, 0.20, 0.22, 0.30]},
            "resting": {"poses": [9], "durationsSeconds": [5.0]},
            "rise": {"poses": [10, 11, 12], "durationsSeconds": [0.20, 0.18, 0.24]},
        },
        "renderedPreview": {
            "includesFullRestHoldSeconds": 5.0,
            "usesRuntimeActionCadence": True,
            "isShortenedReviewLoop": True,
            "note": "The GIF is a compact review loop; its neutral transition frames use the authored action durations, and pose 09 retains the full five-second resting hold.",
        },
        "cosmetics": {
            cosmetic: {f"{n:02d}": f"dog/dog_ollie_motion_{cosmetic}_pose_{n:02d}" for n in range(1, 13)}
            for cosmetic in OVERLAYS
        },
        "homeIdleCosmetics": {
            cosmetic: {f"{frame:02d}": f"dog/dog_ollie_home_idle_{cosmetic}_frame_{frame:02d}" for frame in range(1, 7)}
            for cosmetic in OVERLAYS
        },
        "atlasSourceCrops": {f"{pose:02d}": list(crop) for pose, crop in ATLAS_CROPS.items()},
        "source": {"atlas": display_path(ATLAS), "earStudy": display_path(EAR_STUDY), "tongueStudy": display_path(TONGUE_STUDY), "neutral": display_path(NEUTRAL)},
    }


def contents_json(filename: str) -> str:
    return json.dumps({"images": [{"filename": filename, "idiom": "universal", "scale": "1x"}], "info": {"author": "xcode", "version": 1}}, indent=2) + "\n"


def write_imageset(name: str, image: Image.Image) -> None:
    folder = ASSETS / f"{name}.imageset"
    folder.mkdir(parents=True, exist_ok=True)
    filename = f"{name}.png"
    image.save(folder / filename)
    (folder / "Contents.json").write_text(contents_json(filename))


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def asset_hashes() -> dict[str, str]:
    hashes: dict[str, str] = {}
    for folder in sorted(ASSETS.glob("dog_ollie_*.imageset")):
        for path in sorted(folder.iterdir()):
            if path.is_file():
                hashes[str(path.relative_to(REPO))] = sha256(path)
    return hashes


def render_sheet(bases: dict[int, Image.Image], overlays: dict[str, dict[int, Image.Image]]) -> None:
    backgrounds = [("night", (26, 29, 37, 255)), ("grass", (103, 151, 93, 255)), ("paper", (244, 235, 213, 255))]
    poses = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
    rows = [("base", None), *[(name, name) for name in OVERLAYS]]
    sheet = Image.new("RGB", (4 * 384, len(backgrounds) * len(rows) * 3 * 384), (20, 22, 28))
    draw = ImageDraw.Draw(sheet)
    for bg_index, (bg_name, color) in enumerate(backgrounds):
        for layer_index, (label, cosmetic) in enumerate(rows):
            y = (bg_index * len(rows) + layer_index) * 3 * 384
            for index, pose in enumerate(poses):
                tile = Image.new("RGBA", (512, 512), color)
                tile.alpha_composite(bases[pose])
                if cosmetic:
                    tile.alpha_composite(overlays[cosmetic][pose])
                tile.thumbnail((360, 360), Image.Resampling.LANCZOS)
                x = (index % 4) * 384 + (384 - tile.width) // 2
                tile_y = y + (index // 4) * 384 + 24 + (360 - tile.height) // 2
                sheet.paste(tile.convert("RGB"), (x, tile_y))
                draw.text((index % 4 * 384 + 8, y + (index // 4) * 384 + 4), f"{bg_name} {label} {pose:02d}", fill="white")
    sheet.save(OUTPUT / "ollie-motion-contact-sheet.png")


def render_base_review_sheet(bases: dict[int, Image.Image]) -> None:
    backgrounds = [("night", (26, 29, 37, 255)), ("grass", (103, 151, 93, 255))]
    poses = list(range(1, 13))
    tile_size = 256
    sheet = Image.new("RGB", (4 * tile_size, len(backgrounds) * 3 * tile_size), (20, 22, 28))
    draw = ImageDraw.Draw(sheet)
    for bg_index, (label, color) in enumerate(backgrounds):
        for index, pose in enumerate(poses):
            tile = Image.new("RGBA", (CANVAS, CANVAS), color)
            tile.alpha_composite(bases[pose])
            tile.thumbnail((238, 238), Image.Resampling.LANCZOS)
            x = (index % 4) * tile_size + (tile_size - tile.width) // 2
            y = (bg_index * 3 + index // 4) * tile_size + 18 + (238 - tile.height) // 2
            sheet.paste(tile.convert("RGB"), (x, y))
            draw.text(((index % 4) * tile_size + 7, (bg_index * 3 + index // 4) * tile_size + 4), f"{label} {pose:02d}", fill="white")
    sheet.save(OUTPUT / "ollie-motion-base-dark-grass-contact-sheet.png")


def render_home_idle_cosmetics_sheet(bases: dict[int, Image.Image], overlays: dict[str, dict[int, Image.Image]]) -> None:
    tile_size = 256
    rows = [("base", None), *[(name, name) for name in OVERLAYS]]
    sheet = Image.new("RGB", (6 * tile_size, len(rows) * tile_size), (25, 30, 39))
    draw = ImageDraw.Draw(sheet)
    for row, (label, cosmetic) in enumerate(rows):
        for frame in range(1, 7):
            tile = Image.new("RGBA", (CANVAS, CANVAS), (25, 30, 39, 255))
            tile.alpha_composite(bases[frame])
            if cosmetic:
                tile.alpha_composite(overlays[cosmetic][frame])
            tile.thumbnail((238, 238), Image.Resampling.LANCZOS)
            x = (frame - 1) * tile_size + (tile_size - tile.width) // 2
            y = row * tile_size + 18 + (238 - tile.height) // 2
            sheet.paste(tile.convert("RGB"), (x, y))
            draw.text(((frame - 1) * tile_size + 7, row * tile_size + 4), f"{label} idle {frame:02d}", fill="white")
    sheet.save(OUTPUT / "ollie-home-idle-cosmetics-contact-sheet.png")


def render_motion_cosmetics_sheet(bases: dict[int, Image.Image], overlays: dict[str, dict[int, Image.Image]]) -> None:
    poses = [1, 5, 6, 7, 8, 9]
    tile_size = 256
    sheet = Image.new("RGB", (6 * tile_size, len(OVERLAYS) * 2 * tile_size), (21, 25, 34))
    draw = ImageDraw.Draw(sheet)
    for cosmetic_row, cosmetic in enumerate(OVERLAYS):
        for background_row, (name, background) in enumerate((("night", (26, 29, 37, 255)), ("grass", (103, 151, 93, 255)))):
            row = cosmetic_row * 2 + background_row
            for col, pose in enumerate(poses):
                tile = Image.new("RGBA", (CANVAS, CANVAS), background)
                tile.alpha_composite(bases[pose])
                tile.alpha_composite(overlays[cosmetic][pose])
                tile.thumbnail((238, 238), Image.Resampling.LANCZOS)
                x = col * tile_size + (tile_size - tile.width) // 2
                y = row * tile_size + 18 + (238 - tile.height) // 2
                sheet.paste(tile.convert("RGB"), (x, y))
                draw.text((col * tile_size + 7, row * tile_size + 4), f"{name} {cosmetic} {pose:02d}", fill="white")
    sheet.save(OUTPUT / "ollie-motion-neutral-lie-cosmetics-contact-sheet.png")


def render_lie_occlusion_sheet(bases: dict[int, Image.Image], overlays: dict[str, dict[int, Image.Image]]) -> None:
    poses = [7, 9, 11]
    tile_size = 320
    sheet = Image.new("RGB", (3 * tile_size, len(OVERLAYS) * tile_size), (21, 25, 34))
    draw = ImageDraw.Draw(sheet)
    for row, cosmetic in enumerate(OVERLAYS):
        for col, pose in enumerate(poses):
            tile = Image.new("RGBA", (CANVAS, CANVAS), (26, 29, 37, 255))
            tile.alpha_composite(bases[pose])
            tile.alpha_composite(overlays[cosmetic][pose])
            tile.thumbnail((300, 300), Image.Resampling.LANCZOS)
            x = col * tile_size + (tile_size - tile.width) // 2
            y = row * tile_size + 18 + (300 - tile.height) // 2
            sheet.paste(tile.convert("RGB"), (x, y))
            draw.text((col * tile_size + 7, row * tile_size + 4), f"{cosmetic} {pose:02d}", fill="white")
    sheet.save(OUTPUT / "ollie-motion-lie-occlusion-contact-sheet.png")


def render_greeting_cosmetics_sheet(bases: dict[int, Image.Image], overlays: dict[str, dict[int, Image.Image]]) -> None:
    poses = [1, 2, 3, 4]
    tile_size = 256
    sheet = Image.new("RGB", (4 * tile_size, len(OVERLAYS) * tile_size), (21, 25, 34))
    draw = ImageDraw.Draw(sheet)
    for row, cosmetic in enumerate(OVERLAYS):
        for col, pose in enumerate(poses):
            tile = Image.new("RGBA", (CANVAS, CANVAS), (26, 29, 37, 255))
            tile.alpha_composite(bases[pose])
            tile.alpha_composite(overlays[cosmetic][pose])
            tile.thumbnail((238, 238), Image.Resampling.LANCZOS)
            x = col * tile_size + (tile_size - tile.width) // 2
            y = row * tile_size + 18 + (238 - tile.height) // 2
            sheet.paste(tile.convert("RGB"), (x, y))
            draw.text((col * tile_size + 7, row * tile_size + 4), f"{cosmetic} {pose:02d}", fill="white")
    sheet.save(OUTPUT / "ollie-motion-greeting-cosmetics-contact-sheet.png")


def render_gif(bases: dict[int, Image.Image], overlays: dict[str, dict[int, Image.Image]], cosmetic: str | None) -> None:
    order = [1, 2, 3, 1, 4, 1, 3, 5, 6, 7, 8, 9, 9, 10, 11, 12]
    durations = [160, 160, 280, 180, 360, 210, 160, 160, 180, 200, 220, 300, 5000, 200, 180, 240]
    frames = []
    for pose in order:
        frame = Image.new("RGBA", (512, 512), (28, 33, 43, 255))
        frame.alpha_composite(bases[pose])
        if cosmetic:
            frame.alpha_composite(overlays[cosmetic][pose])
        frames.append(frame.convert("P", palette=Image.Palette.ADAPTIVE))
    suffix = cosmetic or "base"
    frames[0].save(OUTPUT / f"ollie-motion-{suffix}.gif", save_all=True, append_images=frames[1:], duration=durations, loop=0, disposal=2)


def validate(bases: dict[int, Image.Image], overlays: dict[str, dict[int, Image.Image]], allow_empty_overlays: bool = False) -> dict:
    rows = []
    for category, images in [("base", bases), *[(name, values) for name, values in overlays.items()]]:
        for pose, image in images.items():
            alpha = image.getchannel("A")
            bbox = alpha.getbbox()
            if image.mode != "RGBA" or image.size != (CANVAS, CANVAS) or (bbox is None and not (allow_empty_overlays and category != "base")):
                raise ValueError(f"invalid {category} pose {pose}")
            edge_pixels = np.asarray(alpha)
            rows.append({"category": category, "pose": pose, "size": list(image.size), "alphaBounds": list(bbox) if bbox else None, "edgeAlphaNonzero": int(np.count_nonzero(np.concatenate([edge_pixels[0], edge_pixels[-1], edge_pixels[:, 0], edge_pixels[:, -1]])))})
    return {"schemaVersion": 1, "allRGBA": True, "canvas": [CANVAS, CANVAS], "items": rows}


def capture_sources() -> None:
    """Freeze the approved external generation for reproducible local processing."""
    SOURCES.mkdir(parents=True, exist_ok=True)
    if not ATLAS.exists():
        if not EXTERNAL_ATLAS.exists():
            raise FileNotFoundError(f"missing atlas; pass --atlas or restore {ATLAS}")
        shutil.copy2(EXTERNAL_ATLAS, ATLAS)
    for source in (ORIGINAL_EAR_STUDY, ORIGINAL_TONGUE_STUDY):
        destination = SOURCES / source.name
        if not destination.exists():
            shutil.copy2(source, destination)


def build(publish: bool, publish_approved_subset: bool = False) -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    atlas_source = rgba(ATLAS)
    neutral = rgba(NEUTRAL)
    bases: dict[int, Image.Image] = {1: neutral, 12: neutral}
    # One shared atlas scale preserves Ollie's head/body size across every transition;
    # lying poses become wider and shorter naturally rather than being normalized to a box.
    atlas_scale = 1.35
    for pose in (2, 3, 5, 6, 7, 8, 9, 10, 11):
        matte = vision_matte(atlas_cell(atlas_source, pose), pose)
        if pose == 9:
            matte = repair_pose9_neck(matte)
        bases[pose] = place_on_canvas(matte, atlas_scale)
    # The complete cleaned atlas cell preserves the approved folded-ear silhouette without
    # a visible graft across Ollie's muzzle.
    tongue_study = dark_study_matte(rgba(TONGUE_STUDY))
    tongue_registered = place_on_canvas(tongue_study, 436 / crop_alpha(tongue_study).height)
    tongue_pixels = np.asarray(tongue_registered.convert("RGB"), dtype=np.int16)
    yy, xx = np.indices((CANVAS, CANVAS))
    pink = (tongue_pixels[:, :, 0] > tongue_pixels[:, :, 1] + 16) & (tongue_pixels[:, :, 0] > tongue_pixels[:, :, 2] + 20) & (xx > 255) & (xx < 360) & (yy > 200) & (yy < 340)
    tongue_layer = tongue_registered.copy()
    tongue_layer.putalpha(Image.fromarray((pink * 255).astype("uint8")))
    bases[4] = neutral.copy()
    bases[4].alpha_composite(tongue_layer)

    overlays: dict[str, dict[int, Image.Image]] = {}
    for cosmetic, path in OVERLAYS.items():
        source = rgba(path)
        overlays[cosmetic] = {}
        for pose in range(1, 13):
            transformed = transform_overlay(source, pose)
            overlays[cosmetic][pose] = create_overlay_with_occlusion(transformed, bases[pose], pose, cosmetic)
    home_idle_bases = {frame: rgba(path) for frame, path in HOME_IDLE.items()}
    home_idle_anchors = {
        1: (295, 259, 1.00), 2: (296, 259, 1.00), 3: (296, 259, 1.00),
        4: (295, 260, 1.00), 5: (295, 260, 1.00), 6: (295, 259, 1.00),
    }
    home_idle_overlays: dict[str, dict[int, Image.Image]] = {}
    for cosmetic, path in OVERLAYS.items():
        home_idle_overlays[cosmetic] = {}
        for frame in range(1, 7):
            transformed = transform_overlay_at(rgba(path), home_idle_anchors[frame])
            home_idle_overlays[cosmetic][frame] = create_overlay_with_occlusion(
                transformed, home_idle_bases[frame], 1, cosmetic, neck_y=home_idle_anchors[frame][1]
            )

    manifest_data = manifest()
    (OUTPUT / "ollie-motion-manifest.json").write_text(json.dumps(manifest_data, indent=2) + "\n")
    # A final candidate may not silently substitute an empty cosmetic layer.  Every pose
    # and every retained head-tilt frame must carry a real, 512px RGBA overlay.
    qa = validate(bases, overlays)
    qa["homeIdleOverlays"] = validate(home_idle_bases, home_idle_overlays)["items"]
    (OUTPUT / "qa.json").write_text(json.dumps(qa, indent=2) + "\n")
    render_sheet(bases, overlays)
    render_base_review_sheet(bases)
    render_home_idle_cosmetics_sheet(home_idle_bases, home_idle_overlays)
    render_motion_cosmetics_sheet(bases, overlays)
    render_lie_occlusion_sheet(bases, overlays)
    render_greeting_cosmetics_sheet(bases, overlays)
    render_gif(bases, overlays, None)
    for cosmetic in OVERLAYS:
        render_gif(bases, overlays, cosmetic)
    if publish or publish_approved_subset:
        for pose in range(2, 12):
            write_imageset(f"dog_ollie_motion_pose_{pose:02d}", bases[pose])
        for cosmetic, images in overlays.items():
            pose_numbers = range(1, 13) if publish else (1, 4, 12)
            for pose in pose_numbers:
                image = images[pose]
                write_imageset(f"dog_ollie_motion_{cosmetic}_pose_{pose:02d}", image)
        for cosmetic, images in home_idle_overlays.items():
            for frame, image in images.items():
                write_imageset(f"dog_ollie_home_idle_{cosmetic}_frame_{frame:02d}", image)
    produced = [
        OUTPUT / "ollie-motion-manifest.json",
        OUTPUT / "qa.json",
        OUTPUT / "ollie-motion-contact-sheet.png",
        OUTPUT / "ollie-motion-base-dark-grass-contact-sheet.png",
        OUTPUT / "ollie-home-idle-cosmetics-contact-sheet.png",
        OUTPUT / "ollie-motion-neutral-lie-cosmetics-contact-sheet.png",
        OUTPUT / "ollie-motion-lie-occlusion-contact-sheet.png",
        OUTPUT / "ollie-motion-greeting-cosmetics-contact-sheet.png",
        OUTPUT / "ollie-motion-base.gif",
        *(OUTPUT / f"ollie-motion-{cosmetic}.gif" for cosmetic in OVERLAYS),
    ]
    input_paths = [ATLAS, EAR_STUDY, TONGUE_STUDY, NEUTRAL, *OVERLAYS.values(), *HOME_IDLE.values(), REPO / "scripts/art/foreground_mask.swift", *sorted(USED_VISION_MASKS)]
    catalog_hashes = asset_hashes()
    provenance = {
        "script": str(Path(__file__).relative_to(REPO)),
        "lastRunMode": "fullPublish" if publish else "approvedSubsetPublish" if publish_approved_subset else "qaOnly",
        "catalogPublicationState": "updatedByThisRun" if (publish or publish_approved_subset) else "existingCatalogSnapshotUnmodifiedByThisRun",
        "inputs": {str(path.relative_to(REPO) if path.is_relative_to(REPO) else path): sha256(path) for path in input_paths},
        "publishedAssetHashes": catalog_hashes,
        "outputs": {str(path.relative_to(REPO)): sha256(path) for path in produced},
    }
    (OUTPUT / "provenance.json").write_text(json.dumps(provenance, indent=2) + "\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--publish", action="store_true", help="write new asset-catalog imagesets after QA")
    parser.add_argument("--publish-approved-subset", action="store_true", help="write accepted base, neutral motion, and home-idle overlays only")
    parser.add_argument("--capture-sources", action="store_true", help="copy the approved external atlas/studies into the versioned QA source directory")
    parser.add_argument("--atlas", type=Path, help="explicit alternate atlas path; takes precedence over the preserved source copy")
    arguments = parser.parse_args()
    if arguments.atlas:
        ATLAS = arguments.atlas
    elif arguments.capture_sources:
        capture_sources()
    if not ATLAS.exists():
        raise SystemExit(f"missing preserved atlas {ATLAS}; run with --capture-sources or pass --atlas")
    build(arguments.publish, arguments.publish_approved_subset)
