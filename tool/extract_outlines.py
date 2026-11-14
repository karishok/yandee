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
guess, not a guarantee. When it gets an object wrong (half of it missing
because its tap zone is small, say), point it at the part of the picture
to look in, as normalized x0,y0,x1,y1 — for the default picture, or with
a `realistic:` prefix for the realistic one:

    --region lion=0.31,0.43,0.70,0.66 --region realistic:lion=0.3,0.4,0.7,0.7

Things that are part of the scenery rather than standing out from it (a
path, a pond) are not "subjects" at all; pick those by their colour
instead, and cut a neighbour that got glued on (the dog in front of its
kennel) back out by its own outline:

    --by-color pond:18@0.62,0.93 --by-color path_1 --subtract doghouse=dog

(`:18` is how far from the sampled colour still counts, `@x,y` where on
the picture to sample it when the middle of the tap zone is something
else — a duck on the pond.) With --by-color the whole patch counts, also
where it runs outside the tap zone: every piece of a path gets the whole
path's outline.

What is still wrong after that is fixed by hand in scene.json. Remember to bump the scene's `version` so the
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


def mask_for(image, masks, rect, region=None, split_glued=True):
    """The object's own mask: the subject filling most of its tap zone.

    With [region] (normalized x0, y0, x1, y1), the subject is looked for in
    that part of the picture alone instead.
    """
    height, width = image.shape[:2]
    x0, y0, x1, y1 = zone_of(rect, width, height, ZONE_MARGIN)
    if region is not None:
        rx0, ry0, rx1, ry1 = (int(region[0] * width), int(region[1] * height), int(region[2] * width), int(region[3] * height))
        crop_masks = subject_masks(image[ry0:ry1, rx0:rx1])
        full_masks = []
        for crop_mask in crop_masks:
            full = np.zeros((height, width), bool)
            full[ry0:ry1, rx0:rx1] = crop_mask
            full_masks.append(full)
        return max(full_masks, key=lambda m: int(m[y0:y1, x0:x1].sum()), default=None)
    mask = max(masks, key=lambda m: int(m[y0:y1, x0:x1].sum()), default=None)
    if mask is None or not mask[y0:y1, x0:x1].any():
        # Not something that stands out in the whole picture (a tree among
        # trees): look at its zone alone.
        crop_masks = subject_masks(image[y0:y1, x0:x1])
        if not crop_masks:
            return None
        print("  only found when looking at its zone alone: check the preview")
        full = np.zeros((height, width), bool)
        full[y0:y1, x0:x1] = max(crop_masks, key=lambda m: int(m.sum()))
        return full
    inside = int(mask[y0:y1, x0:x1].sum())
    if 1 - inside / int(mask.sum()) <= MAX_SPILL or not split_glued:
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


def mask_by_color(image, rect, tolerance, sample=None):
    """The patch of the tap zone's own colour: for scenery such as a path.

    The whole connected patch counts, also where it leaves the tap zone.
    """
    height, width = image.shape[:2]
    x0, y0, x1, y1 = zone_of(rect, width, height, 0)
    lab = cv2.cvtColor(cv2.GaussianBlur(image, (7, 7), 0), cv2.COLOR_BGR2LAB).astype(np.float32)
    if sample is None:
        # The zone's colour is that of its middle, where the object surely is.
        cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
    else:
        cx, cy = int(sample[0] * width), int(sample[1] * height)
    dx, dy = max(2, (x1 - x0) // 8), max(2, (y1 - y0) // 8)
    colour = np.median(lab[max(0, cy - dy) : cy + dy, max(0, cx - dx) : cx + dx].reshape(-1, 3), axis=0)
    patch = (np.linalg.norm(lab - colour, axis=2) < tolerance).astype(np.uint8)
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (9, 9))
    patch = cv2.morphologyEx(patch, cv2.MORPH_CLOSE, kernel, iterations=2)
    patch = cv2.morphologyEx(patch, cv2.MORPH_OPEN, kernel)
    count, labels = cv2.connectedComponents(patch)
    in_zone = labels[y0:y1, x0:x1]
    sizes = np.bincount(in_zone.ravel(), minlength=count)
    sizes[0] = 0  # not the patch
    return labels == int(sizes.argmax()) if sizes.max() > 0 else None


def mask_of_outline(points, width, height, grow):
    """A stored outline as a mask, grown by [grow] pixels."""
    mask = np.zeros((height, width), np.uint8)
    cv2.fillPoly(mask, [np.array([[x * width, y * height] for x, y in points], np.int32)], 1)
    if grow:
        mask = cv2.dilate(mask, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * grow + 1, 2 * grow + 1)))
    return mask > 0


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
    for polygon in polygons:  # one at a time: together, overlaps would cancel out
        cv2.fillPoly(lit, [polygon], 255)
    preview = np.where(lit[..., None] == 255, image, (image * 0.25).astype(np.uint8))
    cv2.polylines(preview, polygons, True, (0, 255, 255), 1)
    cv2.imwrite(str(path), preview)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("scene_dir", type=Path)
    parser.add_argument("object_ids", nargs="+")
    parser.add_argument("--preview", type=Path, help="directory to write preview pictures to")
    parser.add_argument("--write", action="store_true", help="store the outlines in scene.json")
    parser.add_argument(
        "--region",
        action="append",
        default=[],
        metavar="[realistic:]ID=x0,y0,x1,y1",
        help="look for this object in this part of the picture alone",
    )
    parser.add_argument(
        "--by-color",
        action="append",
        default=[],
        metavar="ID[:TOLERANCE][@x,y]",
        help="take the patch of the tap zone's own colour instead of a detected subject",
    )
    parser.add_argument(
        "--subtract",
        action="append",
        default=[],
        metavar="ID=OTHER[,OTHER]",
        help="cut these other objects' outlines out of this one",
    )
    args = parser.parse_args()
    regions = {}
    for spec in args.region:
        key, _, box = spec.partition("=")
        picture, _, object_id = key.rpartition(":")
        regions[(picture or "default", object_id)] = [float(value) for value in box.split(",")]
    by_color = {}
    for spec in args.by_color:
        spec, _, sample = spec.partition("@")
        object_id, _, tolerance = spec.partition(":")
        by_color[object_id] = (float(tolerance or 18), [float(v) for v in sample.split(",")] if sample else None)
    subtract = {}
    for spec in args.subtract:
        object_id, _, others = spec.partition("=")
        subtract[object_id] = others.split(",")

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
            if object_id in by_color:
                mask = mask_by_color(image, rect, *by_color[object_id])
            else:
                # An object whose neighbour is about to be cut out by its
                # outline is taken whole, neighbour and all.
                mask = mask_for(
                    image, masks, rect, regions.get((name, object_id)), split_glued=object_id not in subtract
                )
            for other in subtract.get(object_id, []) if mask is not None else []:
                other_points = (
                    objects[other].get("outline") if name == "default" else (realistic.get("outlines") or {}).get(other)
                )
                if other_points is None:
                    sys.exit(f"{name}: cannot subtract {other} from {object_id}: it has no outline yet")
                mask = mask & ~mask_of_outline(other_points, image.shape[1], image.shape[0], grow=6)
            points = None if mask is None else outline_of(mask)
            if points is None:
                # Nothing to write for this one; it needs --region or an
                # outline drawn by hand.
                print(f"{name}: {object_id}: FOUND NOTHING")
                continue
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
