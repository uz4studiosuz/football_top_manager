"""Launcher icons and Play Store graphics, drawn from code.

Writes android mipmaps (48–192 px), web icons, store/icon-512.png and
store/feature-graphic.png (1024×500). Run from the project root:

    python -I tool/make_icons.py
"""
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
FONT = ROOT / 'assets' / 'fonts' / 'roboto-bold.ttf'
BLUE, DEEP, WHITE, GOLD = (23, 105, 224), (12, 44, 110), (255, 255, 255), (232, 196, 106)


def ball(draw, cx, cy, r):
    """A classic black-and-white ball: one centre pentagon, five around it."""
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=WHITE, outline=(20, 24, 31), width=max(1, r // 14))

    def pentagon(px, py, pr, rot):
        return [(px + pr * math.cos(rot + i * 2 * math.pi / 5), py + pr * math.sin(rot + i * 2 * math.pi / 5)) for i in range(5)]

    draw.polygon(pentagon(cx, cy, r * 0.34, -math.pi / 2), fill=(20, 24, 31))
    for i in range(5):
        a = -math.pi / 2 + i * 2 * math.pi / 5
        px, py = cx + r * 0.78 * math.cos(a), cy + r * 0.78 * math.sin(a)
        draw.polygon(pentagon(px, py, r * 0.2, a + math.pi / 2), fill=(20, 24, 31))


def icon(size):
    s = size * 4  # draw large, scale down for smooth edges
    img = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # Vertical gradient in a rounded square.
    grad = Image.new('RGBA', (s, s))
    gd = ImageDraw.Draw(grad)
    for y in range(s):
        t = y / s
        gd.line([(0, y), (s, y)], fill=tuple(round(BLUE[i] * (1 - t) + DEEP[i] * t) for i in range(3)) + (255,))
    mask = Image.new('L', (s, s), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, s - 1, s - 1], radius=s * 0.22, fill=255)
    img.paste(grad, (0, 0), mask)
    # Centre circle of a pitch, the ball on the spot, "FTM" underneath.
    d.ellipse([s * 0.18, s * 0.1, s * 0.82, s * 0.74], outline=(255, 255, 255, 70), width=round(s * 0.025))
    d.line([(s * 0.06, s * 0.42), (s * 0.94, s * 0.42)], fill=(255, 255, 255, 70), width=round(s * 0.025))
    ball(d, s * 0.5, s * 0.42, round(s * 0.2))
    font = ImageFont.truetype(str(FONT), round(s * 0.2))
    text = 'FTM'
    w = d.textlength(text, font=font)
    d.text(((s - w) / 2, s * 0.68), text, font=font, fill=WHITE)
    d.rectangle([s * 0.36, s * 0.905, s * 0.64, s * 0.925], fill=GOLD)
    return img.resize((size, size), Image.LANCZOS)


def feature():
    w, h = 1024, 500
    img = Image.new('RGB', (w, h))
    d = ImageDraw.Draw(img)
    for x in range(w):
        t = x / w
        d.line([(x, 0), (x, h)], fill=tuple(round(DEEP[i] * (1 - t) + BLUE[i] * t) for i in range(3)))
    # Faint pitch markings behind the text.
    overlay = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    line = (255, 255, 255, 45)
    od.rectangle([40, 40, w - 40, h - 40], outline=line, width=3)
    od.line([(w // 2, 40), (w // 2, h - 40)], fill=line, width=3)
    od.ellipse([w // 2 - 90, h // 2 - 90, w // 2 + 90, h // 2 + 90], outline=line, width=3)
    od.rectangle([40, h // 2 - 110, 160, h // 2 + 110], outline=line, width=3)
    od.rectangle([w - 160, h // 2 - 110, w - 40, h // 2 + 110], outline=line, width=3)
    img = Image.alpha_composite(img.convert('RGBA'), overlay)
    logo = icon(220)
    img.paste(logo, (90, h // 2 - 110), logo)
    d = ImageDraw.Draw(img)
    title = ImageFont.truetype(str(FONT), 56)
    sub = ImageFont.truetype(str(FONT), 28)
    d.text((350, 165), 'Football Top Manager', font=title, fill=WHITE)
    d.text((352, 250), 'Taktika · Transferlar · Jonli 2D o‘yin', font=sub, fill=GOLD)
    d.text((352, 292), '120+ liga · 46 000+ futbolchi', font=sub, fill=WHITE)
    return img.convert('RGB')


def main():
    res = ROOT / 'android' / 'app' / 'src' / 'main' / 'res'
    for folder, size in [('mipmap-mdpi', 48), ('mipmap-hdpi', 72), ('mipmap-xhdpi', 96), ('mipmap-xxhdpi', 144), ('mipmap-xxxhdpi', 192)]:
        icon(size).save(res / folder / 'ic_launcher.png')
    web = ROOT / 'web'
    for name, size in [('icons/Icon-192.png', 192), ('icons/Icon-512.png', 512), ('icons/Icon-maskable-192.png', 192),
                       ('icons/Icon-maskable-512.png', 512), ('favicon.png', 32)]:
        if (web / name).parent.exists():
            icon(size).save(web / name)
    store = ROOT / 'store'
    store.mkdir(exist_ok=True)
    icon(512).save(store / 'icon-512.png')
    feature().save(store / 'feature-graphic.png')
    print('icons written')


if __name__ == '__main__':
    main()
