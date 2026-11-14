#!/usr/bin/env python3
"""Cut object silhouettes out of a scene's pictures and store them in scene.json.

Content-preparation tool for the flashlight game: an object with an
`outline` is a flashlight target, and the outline is the shape it shows
through the dark once found. Not used by the app at runtime.

For every requested object id, on the scene's default picture and (when
the scene has one) its realistic picture, this finds the object with
macOS's subject detection (tool/subject_masks.swift, the same thing that
lifts a subject out of a photo), simplifies its silhouette to a polygon
and writes it as normalized [x, y] points:

    objects[i].outline            - default picture
    realistic.outlines[<id>]      - realistic picture

macOS only. Needs Xcode's `swift` and `pip install opencv-python-headless numpy`.

    python3 tool/extract_outlines.py assets/demo_content/forest \
        bear fox hare squirrel hedgehog --preview /tmp/outlines --write

Always look at the previews before committing: detection is a good first
guess, not a guarantee. Remember to bump the scene's `version` so the
updated scene.json is re-seeded on devices.
"""

import argparse
import json
import subprocess
import sys
import tempfile
from pathlib import Path

import cv2
import numpy as np

HELPER = Path(__file__).with_name("subject_masks.swift")

# How far outside its tap zone an object may reach, as a share of the
# picture's width/height. Tap zones are drawn snugly, sometimes too snugly.
ZONE_MARGIN = 0.02
# A detected subject with more than this share of itself outside the zone
# is the object glued to a neighbour (a squirrel and the stump it sits on).
MAX_SPILL = 0.15
# Polygon simplification tolerance, as a share of the outline's perimeter.
SIMPLIFY = 0.0025


def subject_masks(image):
    """One boolean mask per subject macOS finds in [image]."""
    with tempfile.TemporaryDirectory() as tmp:
        source = Path(tmp) / "picture.png"
        cv2.imwrite(str(source), image)
        subprocess.run(["swift", str(HELPER), str(source), tmp, "mask"], check=True, capture_output=True)
        return [cv2.imread(str(path), cv2.IMREAD_GRAYSCALE) > 127 for path in sorted(Path(tmp).glob("mask_*.png"))]


def zone_of(rect, width, height, margin):
    x0 = max(0, int((rect["x"] - margin) * width))
    y0 = max(0, int((rect["y"] - margin) * height))
    x1 = min(width, int((rect["x"] + rect["width"] + margin) * width))
    y1 = min(height, int((rect["y"] + rect["height"] + margin) * height))
    return x0, y0, x1, y1


def mask_for(image, masks, rect):
    """The object's own mask: the subject filling most of its tap zone."""
    height, width = image.shape[:2]
    x0, y0, x1, y1 = zone_of(rect, width, height, ZONE_MARGIN)
    mask = max(masks, key=lambda m: int(m[y0:y1, x0:x1].sum()), default=None)
    if mask is None or not mask[y0:y1, x0:x1].any():
        return None
    inside = int(mask[y0:y1, x0:x1].sum())
    if 1 - inside / int(mask.sum()) <= MAX_SPILL:
        return mask

    # Glued to a neighbour. Look again at the zone alone, cut exactly at the
    # tap zone's edge on the sides the neighbour is on, so there is as
    # little of the neighbour in the picture as possible.
    tx0, ty0, tx1, ty1 = zone_of(rect, width, height, 0)
    spilled = {
        "left": int(mask[y0:y1, :x0].sum()),
        "top": int(mask[:y0].sum()),
        "right": int(mask[y0:y1, x1:].sum()),
        "bottom": int(mask[y1:].sum()),
    }
    # A side counts when a real share of the neighbour is there, not just
    # a corner of it poking past the zone.
    spills = {side: area >= 0.25 * sum(spilled.values()) for side, area in spilled.items()}
    cx0 = tx0 if spills["left"] else x0
    cy0 = ty0 if spills["top"] else y0
    cx1 = tx1 if spills["right"] else x1
    cy1 = ty1 if spills["bottom"] else y1
    crop_masks = subject_masks(image[cy0:cy1, cx0:cx1])
    if not crop_masks:
        return None
    # A sliver of the neighbour along the cut edge (the top of the stump
    # under the squirrel) can survive this; that is fixed by hand in
    # scene.json, hence the warning.
    print(f"  glued to a neighbour on the {', '.join(s for s, on in spills.items() if on)}: check the preview")
    full = np.zeros((height, width), bool)
    full[cy0:cy1, cx0:cx1] = max(crop_masks, key=lambda m: int(m.sum()))
    return full


def outline_of(mask):
    """A mask's biggest blob as a list of normalized [x, y] points."""
    height, width = mask.shape
    contours, _ = cv2.findContours(mask.astype(np.uint8), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
    if not contours:
        return None
    contour = max(contours, key=cv2.contourArea)
    polygon = cv2.approxPolyDP(contour, SIMPLIFY * cv2.arcLength(contour, True), True)
    return [[round(int(px) / width, 3), round(int(py) / height, 3)] for px, py in polygon.reshape(-1, 2)]


def draw_preview(image, outlines, path):
    """The picture as the game shows it: dark, with the outlines lit."""
    height, width = image.shape[:2]
    polygons = [np.array([[x * width, y * height] for x, y in points], np.int32) for points in outlines.values()]
    lit = np.zeros((height, width), np.uint8)
    cv2.fillPoly(lit, polygons, 255)
    preview = np.where(lit[..., None] == 255, image, (image * 0.25).astype(np.uint8))
    cv2.polylines(preview, polygons, True, (0, 255, 255), 1)
    cv2.imwrite(str(path), preview)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("scene_dir", type=Path)
    parser.add_argument("object_ids", nargs="+")
    parser.add_argument("--preview", type=Path, help="directory to write preview pictures to")
    parser.add_argument("--write", action="store_true", help="store the outlines in scene.json")
    args = parser.parse_args()

    scene_path = args.scene_dir / "scene.json"
    raw = scene_path.read_text(encoding="utf-8")
    scene = json.loads(raw)
    objects = {obj["id"]: obj for obj in scene["objects"]}
    unknown = [object_id for object_id in args.object_ids if object_id not in objects]
    if unknown:
        sys.exit(f"No such object(s) in {scene_path}: {', '.join(unknown)}")

    realistic = scene.get("realistic")
    pictures = [("default", scene["background"], {oid: objects[oid]["rect"] for oid in args.object_ids})]
    if realistic:
        rects = realistic.get("rects", {})
        pictures.append(
            ("realistic", realistic["background"], {oid: rects.get(oid, objects[oid]["rect"]) for oid in args.object_ids})
        )

    for name, file_name, rects in pictures:
        image = cv2.imread(str(args.scene_dir / file_name), cv2.IMREAD_COLOR)
        if image is None:
            sys.exit(f"Cannot read {args.scene_dir / file_name}")
        masks = subject_masks(image)
        outlines = {}
        for object_id, rect in rects.items():
            mask = mask_for(image, masks, rect)
            points = None if mask is None else outline_of(mask)
            if points is None:
                sys.exit(f"{name}: found nothing for {object_id}")
            outlines[object_id] = points
            print(f"{name}: {object_id}: {len(points)} points")
        if args.preview:
            args.preview.mkdir(parents=True, exist_ok=True)
            draw_preview(image, outlines, args.preview / f"{scene['id']}_{name}.png")
        if name == "default":
            for object_id, points in outlines.items():
                objects[object_id]["outline"] = points
        else:
            realistic["outlines"] = {**realistic.get("outlines", {}), **outlines}

    if args.write:
        text = json.dumps(scene, ensure_ascii=False, separators=(",", ":"))
        scene_path.write_text(text + ("\n" if raw.endswith("\n") else ""), encoding="utf-8")
        print(f"Wrote {scene_path}")


if __name__ == "__main__":
    main()
