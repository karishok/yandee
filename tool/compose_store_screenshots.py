#!/usr/bin/env python3
"""Собирает скриншоты для сторов: подпись сверху, экран игры снизу.

Исходники — сырые снимки симулятора в docs/store/raw/ (1320×2868,
`xcrun simctl io <device> screenshot`). Результат — два набора:

- docs/store/screenshots/ — PNG 1206×2622 для App Store (iPhone 6,3″ —
  обязательный размер в App Store Connect, остальные масштабируются);
- docs/store/screenshots_rustore/ — JPG 1080×1920 для RuStore: консоль
  обрезает всё, что не 9:16, поэтому у RuStore свой холст.

    python3 tool/compose_store_screenshots.py

Нужен Pillow. Шрифт PT Sans входит в macOS и распространяется по
свободной лицензии. Снимки, которых ещё нет в raw/, пропускаются.
"""

from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "docs/store/raw"

FONTS = "/System/Library/Fonts/Supplemental/PTSans.ttc"
BOLD, REGULAR = 7, 0  # номера начертаний внутри PTSans.ttc

BACKGROUND = "#FFF3E3"  # фон иконки приложения
TITLE_COLOR = "#4A2E12"
SUBTITLE_COLOR = "#8A6238"


@dataclass(frozen=True)
class Layout:
    out: Path
    suffix: str  # расширение готовых файлов
    size: tuple[int, int]
    title_size: int
    subtitle_size: int
    subtitle_gap: int  # от заголовка до подзаголовка
    screen_top: int  # экран стоит на одном месте на всех картинках
    screen_width: int
    screen_radius: int


LAYOUTS = [
    Layout(ROOT / "docs/store/screenshots", ".png", (1206, 2622), 121, 57, 26, 566, 1005, 110),
    # Холст 9:16 ниже, поэтому экран уже: иначе низ иллюстрации не влезает.
    Layout(ROOT / "docs/store/screenshots_rustore", ".jpg", (1080, 1920), 100, 48, 22, 450, 740, 82),
]

# (файл, заголовок в одну-две строки, подзаголовок)
SHOTS = [
    ("01_scenes.png", "Первые слова\nмалыша", "10 сцен, больше 100 слов"),
    ("02_explore.png", "Нажал —\nуслышал", "Каждое слово произносит живой голос"),
    ("03_find.png", "Где машина?", "Игра спрашивает — малыш находит"),
    ("04_flashlight.png", "Кто спрятался\nв темноте?", "Фонарик: води лучом и ищи"),
    ("05_realistic.png", "Рисунок или\nкак в жизни", "Переключается одним нажатием"),
    ("06_safe.png", "Без рекламы\nи без интернета", "Без регистрации и покупок"),
]

def compose(raw_path: Path, title: str, subtitle: str, layout: Layout) -> Image.Image:
    canvas = Image.new("RGB", layout.size, BACKGROUND)
    draw = ImageDraw.Draw(canvas)
    title_font = ImageFont.truetype(FONTS, layout.title_size, index=BOLD)
    subtitle_font = ImageFont.truetype(FONTS, layout.subtitle_size, index=REGULAR)
    center_x = layout.size[0] // 2
    title_line = int(layout.title_size * 1.12)

    # Подпись центрируется по высоте над экраном: заголовок в одну строку
    # не прилипает к верхнему краю.
    lines = title.split("\n")
    text_height = len(lines) * title_line + layout.subtitle_gap + layout.subtitle_size
    y = (layout.screen_top - text_height) // 2
    for line in lines:
        draw.text((center_x, y), line, font=title_font, fill=TITLE_COLOR, anchor="ma")
        y += title_line
    y += layout.subtitle_gap
    draw.text((center_x, y), subtitle, font=subtitle_font, fill=SUBTITLE_COLOR, anchor="ma")

    screen = Image.open(raw_path).convert("RGB")
    width = layout.screen_width
    height = round(width * screen.height / screen.width)
    screen = screen.resize((width, height), Image.LANCZOS)
    left = (layout.size[0] - width) // 2
    top = layout.screen_top
    radius = layout.screen_radius

    # Экран уходит за нижний край, поэтому скругляем и оттеняем его целиком,
    # а лишнее обрезает сам холст.
    mask = Image.new("L", screen.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, *screen.size), radius, fill=255)

    shadow = Image.new("RGBA", layout.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (left, top + 24, left + width, top + 24 + height), radius, fill=(74, 46, 18, 70)
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(36))
    canvas.paste(shadow, (0, 0), shadow)
    canvas.paste(screen, (left, top), mask)
    ImageDraw.Draw(canvas).rounded_rectangle(
        (left, top, left + width, top + height), radius, outline="#E7D3BC", width=4
    )
    return canvas


def main() -> None:
    for layout in LAYOUTS:
        layout.out.mkdir(parents=True, exist_ok=True)
        for name, title, subtitle in SHOTS:
            raw_path = RAW / name
            if not raw_path.exists():
                print(f"нет исходника, пропускаю: {raw_path.relative_to(ROOT)}")
                continue
            target = (layout.out / name).with_suffix(layout.suffix)
            image = compose(raw_path, title, subtitle, layout)
            if layout.suffix == ".jpg":
                image.save(target, quality=92, optimize=True)
            else:
                image.save(target, optimize=True)
            print(f"готово: {target.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
