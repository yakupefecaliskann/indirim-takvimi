"""Uygulama simgesini uretir.

Varsayilan Flutter logosu yerine markaya uygun bir simge: gul kurusu gradyan
zemin uzerinde beyaz alisveris cantasi ve kalp.

Kullanim:  python tools/make_icons.py
"""

import math
import os

from PIL import Image, ImageDraw

OUT_DIRS = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

RES = os.path.join("app", "android", "app", "src", "main", "res")

SIZE = 1024
TOP = (232, 160, 174)      # acik gul kurusu
BOTTOM = (169, 66, 90)     # koyu gul kurusu
WHITE = (255, 255, 255, 255)


def gradient_background(size: int) -> Image.Image:
    """Dikey gradyan + yuvarlatilmis kose."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    grad = Image.new("RGBA", (size, size))
    d = ImageDraw.Draw(grad)
    for y in range(size):
        t = y / (size - 1)
        d.line(
            [(0, y), (size, y)],
            fill=tuple(round(TOP[i] + (BOTTOM[i] - TOP[i]) * t) for i in range(3))
            + (255,),
        )

    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, size - 1, size - 1], radius=round(size * 0.22), fill=255
    )
    img.paste(grad, (0, 0), mask)
    return img


def heart_points(cx: float, cy: float, scale: float, steps: int = 220):
    """Klasik kalp egrisi."""
    pts = []
    for i in range(steps):
        t = 2 * math.pi * i / steps
        x = 16 * math.sin(t) ** 3
        y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((cx + x * scale, cy - y * scale))
    return pts


def draw_bag(img: Image.Image) -> None:
    """Alisveris cantasi: asagi dogru genisleyen trapez govde + ince sap.

    Trapez onemli — duz dikdortgen + ortada kalin sap birlesimi asma kilit
    gibi okunuyor.
    """
    d = ImageDraw.Draw(img)
    s = SIZE

    # Sap: govdeye gore dar ve ince bir yay
    d.arc(
        [s * 0.395, s * 0.255, s * 0.605, s * 0.505],
        start=180,
        end=360,
        fill=WHITE,
        width=round(s * 0.034),
    )

    # Govde: ustu dar, alti genis trapez
    top_y, bottom_y = s * 0.415, s * 0.815
    d.polygon(
        [
            (s * 0.305, top_y),
            (s * 0.695, top_y),
            (s * 0.745, bottom_y),
            (s * 0.255, bottom_y),
        ],
        fill=WHITE,
    )
    # Govdenin ortasinda gul kurusu kalp
    d.polygon(heart_points(s * 0.50, s * 0.625, s * 0.0068), fill=BOTTOM + (255,))


def main() -> None:
    base = gradient_background(SIZE)
    draw_bag(base)

    for folder, px in OUT_DIRS.items():
        path = os.path.join(RES, folder, "ic_launcher.png")
        os.makedirs(os.path.dirname(path), exist_ok=True)
        base.resize((px, px), Image.LANCZOS).save(path, "PNG")
        print(f"yazildi: {path} ({px}x{px})")

    # Magaza / onizleme icin buyuk boy
    os.makedirs("tools", exist_ok=True)
    base.resize((512, 512), Image.LANCZOS).save(
        os.path.join("tools", "icon-512.png"), "PNG"
    )
    print("yazildi: tools/icon-512.png")


if __name__ == "__main__":
    main()
