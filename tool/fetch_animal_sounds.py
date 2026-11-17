"""Download chosen Wikimedia Commons recordings and cut each into a short,
loudness-matched 44.1 kHz mono 16-bit WAV clip.

usage: WM_CONTACT=<your contact> python3 -I tool/fetch_animal_sounds.py RAW_DIR OUT_DIR
(Wikimedia throttles anonymous clients hard; a contact in the User-Agent lifts it.)
"""
import json, re, subprocess, sys, time, urllib.parse, urllib.request
from pathlib import Path
import numpy as np

import os
UA = "yandee-sound-fetcher/1.0 (educational kids app; " + os.environ["WM_CONTACT"] + ")" if os.environ.get("WM_CONTACT") else "yandee-sound-fetcher/1.0 (educational kids app)"
API = "https://commons.wikimedia.org/w/api.php"
SR = 44100

# id -> (scene, Commons file title, max clip seconds)
CHOICES = {
    "cow":      ("farm",   "Mudchute cow 1.ogg", 3.0),
    "pig":      ("farm",   "Pig grunt - Erdie.ogg", 3.0),
    "chicken":  ("farm",   "Hen announcing shes lain an egg.ogg", 3.0),
    "rooster":  ("farm",   "Medium rooster crowing.ogg", 4.0),
    "horse":    ("farm",   "Wiehern.ogg", 3.0),
    "sheep":    ("farm",   "Sheep bleating.ogg", 3.0),
    "goat":     ("farm",   "Herd of goats bleating.ogg", 3.0),
    "duck":     ("farm",   "Anas platyrhynchos - Mallard - XC62258.ogg", 3.0),
    "dog":      ("farm",   "Barking of a dog.ogg", 3.0),
    "fox":      ("forest", "Bellender Fuchs.ogg", 3.0),
    "hedgehog": ("forest", "Braunigel Drohgeräusche.ogg", 3.0),
    "squirrel": ("forest", "Squirrel calls.wav", 3.0),
    "bear":     ("forest", "Yellowstone sound library - Grizzly Bears Roar - 001.mp3", 3.5),
    "elephant": ("zoo",    "Elephant voice - trumpeting.ogg", 3.0),
    "lion":     ("zoo",    "Lion raring-sound1TamilNadu178.ogg", 4.0),
    "monkey":   ("zoo",    "Pant-hoot call made by a male chimpanzee.ogg", 4.0),
    "zebra":    ("zoo",    "Grévys zebra (Sound Effects).ogg", 3.5),
    "tiger":    ("zoo",    "439280 schots angry-tiger.wav", 3.5),
    "seagull":  ("sea",    "Gull 2.ogg", 3.0),
}


def http(url, binary=False):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    for attempt in range(6):
        try:
            data = urllib.request.urlopen(req, timeout=60).read()
            time.sleep(2)
            return data if binary else json.loads(data)
        except urllib.error.HTTPError as e:
            if e.code != 429:
                raise
            wait = int(e.headers.get("Retry-After") or 0) or 15 * (attempt + 1)
            print(f"  429, waiting {wait}s", file=sys.stderr)
            time.sleep(wait)
    raise RuntimeError("rate limited: " + url)


def clean(html):
    return re.sub(r"\s+", " ", re.sub(r"<[^>]+>", "", html or "")).strip()


def info(title):
    q = urllib.parse.urlencode({"action": "query", "titles": "File:" + title, "prop": "imageinfo",
                                "iiprop": "url|extmetadata", "format": "json"})
    page = next(iter(http(API + "?" + q)["query"]["pages"].values()))
    ii = page["imageinfo"][0]
    em = ii["extmetadata"]
    return {
        "url": ii["url"],
        "page": ii["descriptionurl"],
        "license": clean(em.get("LicenseShortName", {}).get("value")),
        "license_url": clean(em.get("LicenseUrl", {}).get("value")),
        "artist": clean(em.get("Artist", {}).get("value")) or "unknown",
    }


def decode(path):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-ac", "1", "-ar", str(SR),
                          "-f", "f32le", "-"], check=True, capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.float32).copy()


def cut(x, max_len):
    hop = int(0.02 * SR)
    n = len(x) // hop
    env = np.sqrt(np.mean(x[: n * hop].reshape(n, hop) ** 2, axis=1) + 1e-12)
    win = max(1, int(max_len / 0.02))
    if n > win:
        energy = np.convolve(env ** 2, np.ones(win), mode="valid")
        start = int(np.argmax(energy))
    else:
        start, win = 0, n
    seg_env = env[start:start + win]
    thresh = seg_env.max() * 10 ** (-32 / 20)
    loud = np.nonzero(seg_env > thresh)[0]
    a = max(0, start + loud[0] - 3)          # 60 ms of lead-in
    b = min(n, start + loud[-1] + 1 + 5)     # 100 ms of tail
    y = x[a * hop: b * hop].astype(np.float64)
    y -= y.mean()
    fi, fo = int(0.015 * SR), min(int(0.12 * SR), len(y) // 3)
    y[:fi] *= np.linspace(0, 1, fi)
    y[-fo:] *= np.linspace(1, 0, fo)
    # Same loudness for every clip (RMS of the loud part), peaks capped at -1 dBFS.
    loud_rms = np.sqrt(np.mean(y[np.abs(y) > np.abs(y).max() * 0.05] ** 2))
    y *= 10 ** (-16 / 20) / max(loud_rms, 1e-9)
    peak = np.abs(y).max()
    if peak > 10 ** (-1 / 20):
        y *= 10 ** (-1 / 20) / peak
    return y.astype(np.float32)


def encode(y, path):
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", "1", "-i", "-",
                    "-c:a", "pcm_s16le", "-map_metadata", "-1", "-fflags", "+bitexact", str(path)],
                   input=y.tobytes(), check=True)


def main():
    raw_dir, out_dir = Path(sys.argv[1]), Path(sys.argv[2])
    raw_dir.mkdir(parents=True, exist_ok=True)
    out_dir.mkdir(parents=True, exist_ok=True)
    credits = {}
    for key, (scene, title, max_len) in CHOICES.items():
        meta = info(title)
        src = raw_dir / (key + Path(urllib.parse.urlparse(meta["url"]).path).suffix)
        if not src.exists():
            src.write_bytes(http(meta["url"], binary=True))
        y = cut(decode(src), max_len)
        encode(y, out_dir / f"{key}.wav")
        credits[key] = {"scene": scene, "title": title, **meta, "seconds": round(len(y) / SR, 2)}
        print(f"{key:9} {len(y)/SR:4.1f}s  {meta['license']:14} {title}")
    (out_dir / "credits.json").write_text(json.dumps(credits, ensure_ascii=False, indent=1))


main()
