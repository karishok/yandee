"""Download the chosen animal recordings and cut each into a short (at most
MAX_LEN seconds), loudness-matched 44.1 kHz mono 16-bit WAV clip.

usage: python3 -I tool/fetch_animal_sounds.py RAW_DIR OUT_DIR
Writes OUT_DIR/<id>.wav (copy to assets/demo_content/<scene>/<id>_sound.wav) and
OUT_DIR/credits.json. Needs ffmpeg, curl and numpy.

The recordings are Freesound's HQ MP3 previews, which need no API key; the cow is
a Wikimedia Commons file. Only recordings of the real animal that allow commercial
use belong in CHOICES: no CC BY-NC, no imitations, no synthesised sounds.
"""
import html, json, re, subprocess, sys, time
from pathlib import Path
import numpy as np

UA = "yandee-sound-fetcher/1.0 (educational kids app)"
SR = 44100
HOP = int(0.02 * SR)
MAX_LEN = 2.0  # seconds, lead-in and tail included

# id -> (scene, Freesound "user/sound id"), or (scene, credits of a file from elsewhere)
CHOICES = {
    "cow":      ("farm",   {"title": "Mudchute cow 1.ogg",
                            "url": "https://upload.wikimedia.org/wikipedia/commons/4/48/Mudchute_cow_1.ogg",
                            "page": "https://commons.wikimedia.org/wiki/File:Mudchute_cow_1.ogg",
                            "license": "CC BY-SA 3.0",
                            "license_url": "https://creativecommons.org/licenses/by-sa/3.0/",
                            "artist": "Secretlondon"}),
    "pig":      ("farm",   "JarredGibb/233183"),
    "chicken":  ("farm",   "dobroide/120587"),
    "rooster":  ("farm",   "InspectorJ/439472"),
    "horse":    ("farm",   "foxen10/149024"),
    "sheep":    ("farm",   "n_audioman/321967"),
    "goat":     ("farm",   "beskhu/273911"),
    "duck":     ("farm",   "D4XX/607226"),
    "dog":      ("farm",   "crazymonke9/418108"),
    "fox":      ("forest", "AndrewJonesFoto/362127"),
    "hedgehog": ("forest", "ffdown/570301"),
    "squirrel": ("forest", "BullSam/509507"),
    "bear":     ("forest", "celldroid/763026"),
    "elephant": ("zoo",    "vataaa/148873"),
    "lion":     ("zoo",    "roman_cgr/223978"),
    "monkey":   ("zoo",    "craigsmith/675430"),
    "zebra":    ("zoo",    "TheKingOfGeeks360/850661"),
    "tiger":    ("zoo",    "videog/149190"),
    "hippo":    ("zoo",    "noisymichael/612318"),
    "seagull":  ("sea",    "Vurca/318092"),
}


def http(url):
    # curl rather than urllib: python.org builds for macOS ship without a CA bundle.
    data = subprocess.run(["curl", "-sS", "--fail", "--max-time", "120", "-A", UA, url],
                          check=True, capture_output=True).stdout
    time.sleep(1.5)
    return data


def info(ref):
    """Title, license and preview URL, read from the public sound page."""
    user, sid = ref.split("/")
    page = f"https://freesound.org/people/{user}/sounds/{sid}/"
    t = http(page).decode("utf-8", "replace")
    lic = re.search(r"creativecommons\.org/(licenses|publicdomain)/([a-z\-]+)/([0-9.]+)", t)
    kind = lic.group(2)
    if kind not in ("zero", "by"):
        raise SystemExit(f"{ref}: license {kind} is not CC0 or CC BY")
    return {
        "title": html.unescape(re.search(r'og:audio:title" content="([^"]*)"', t).group(1)),
        "url": re.search(r'https://cdn\.freesound\.org/previews/[^"]*?-hq\.mp3', t).group(0),
        "page": page,
        "license": "CC0" if kind == "zero" else "CC BY " + lic.group(3),
        "license_url": "https://creativecommons.org/" + "/".join(lic.groups()) + "/",
        "artist": user,
    }


def decode(path):
    # Two high-pass stages take out rumble below ~90 Hz: phone speakers cannot play
    # it, and it would otherwise decide both which fragment is "loudest" and how
    # loud the clip is made.
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-ac", "1", "-ar", str(SR),
                          "-af", "highpass=f=90,highpass=f=90", "-f", "f32le", "-"],
                         check=True, capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.float32).copy()


def cut(x, max_len):
    """The most energetic run of whole calls that fits in max_len seconds."""
    n = len(x) // HOP
    env = np.sqrt(np.mean(x[: n * HOP].reshape(n, HOP) ** 2, axis=1) + 1e-12)
    peak, floor = env.max(), np.percentile(env, 10)
    thr = max(peak * 10 ** (-26 / 20), min(floor * 2.5, peak * 10 ** (-12 / 20)))
    act = env > thr
    # Runs of loud frames are calls; a gap under 0.35 s stays inside one call.
    runs, i = [], 0
    while i < n:
        if act[i]:
            j = i
            while j < n and act[j]:
                j += 1
            if runs and i - runs[-1][1] < 17:
                runs[-1][1] = j
            else:
                runs.append([i, j])
            i = j
        else:
            i += 1
    runs = [r for r in runs if r[1] - r[0] >= 4] or runs or [[0, n]]
    lead, tail = 3, 8                   # 60 ms before the call, 160 ms after it
    win = int(round(max_len / 0.02)) - lead - tail
    best = None
    for k, (s, e) in enumerate(runs):
        end = e
        for _, e2 in runs[k + 1:]:
            if e2 - s > win:
                break
            end = e2
        whole = end - s <= win
        if not whole:
            # One call longer than the clip: keep its loudest stretch, from the
            # onset when that is nearly as loud, so the call still starts naturally.
            energy = np.convolve(env[s:e] ** 2, np.ones(win), mode="valid")
            k2 = int(np.argmax(energy))
            if energy[0] >= 0.8 * energy[k2]:
                k2 = 0
            s, end = s + k2, s + k2 + win
        # Prefer fragments made of whole calls over a piece of a longer one.
        score = float(np.sum(env[s:end] ** 2)) * (1.0 if whole else 0.6)
        if best is None or score > best[0]:
            best = (score, s, end, whole, whole or k2 == 0)
    _, s, end, whole, onset = best
    a, b = max(0, s - lead), min(n, end + tail)
    y = x[a * HOP: b * HOP].astype(np.float64)
    y -= y.mean()
    fi = int((0.015 if onset else 0.08) * SR)
    fo = min(int((0.12 if whole else 0.30) * SR), len(y) // 3)
    y[:fi] *= np.linspace(0, 1, fi)
    y[-fo:] *= np.linspace(1, 0, fo)
    # Same loudness for every clip (RMS of the loud part), peaks capped at -1 dBFS.
    loud_rms = np.sqrt(np.mean(y[np.abs(y) > np.abs(y).max() * 0.05] ** 2))
    y *= 10 ** (-16 / 20) / max(loud_rms, 1e-9)
    pk = np.abs(y).max()
    if pk > 10 ** (-1 / 20):
        y *= 10 ** (-1 / 20) / pk
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
    for key, (scene, ref) in CHOICES.items():
        meta = info(ref) if isinstance(ref, str) else ref
        src = raw_dir / (key + Path(meta["url"]).suffix)
        if not src.exists():
            src.write_bytes(http(meta["url"]))
        y = cut(decode(src), MAX_LEN)
        encode(y, out_dir / f"{key}.wav")
        credits[key] = {"scene": scene, **meta, "seconds": round(len(y) / SR, 2)}
        print(f"{key:9} {len(y)/SR:4.2f}s  {meta['license']:12} {meta['artist']}: {meta['title']}", flush=True)
    (out_dir / "credits.json").write_text(json.dumps(credits, ensure_ascii=False, indent=1))


main()
