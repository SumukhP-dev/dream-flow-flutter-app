"""
Utility script to regenerate the Stripe subscription product images (premium & family)
so they stay aligned with the in-app settings UI.
"""

from __future__ import annotations

import math
import textwrap
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, Optional, Tuple

from PIL import Image, ImageDraw, ImageFilter, ImageFont

WIDTH = HEIGHT = 512
TOP_COLOR = (18, 14, 43)
BOTTOM_COLOR = (7, 4, 15)
PROJECT_ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = PROJECT_ROOT / "stripe_product_images"


@dataclass(frozen=True)
class PlanSpec:
    slug: str
    plan_label: str
    price: str
    period_label: str
    description: str
    highlight: str
    badge_text: Optional[str]
    badge_color: Optional[Tuple[int, int, int]]
    highlight_color: Tuple[int, int, int]
    icon_gradient: Tuple[Tuple[int, int, int], Tuple[int, int, int]]
    output_filename: str


PLAN_SPECS = (
    PlanSpec(
        slug="premium",
        plan_label="Premium Plan",
        price="$4.99",
        period_label="/month",
        description="All premium benefits for one listener with zero ads or limits.",
        highlight="Perfect for solo listeners going completely ad-free.",
        badge_text=None,
        badge_color=None,
        highlight_color=(190, 255, 214),
        icon_gradient=((139, 92, 246), (14, 165, 233)),
        output_filename="premium-subscription.png",
    ),
    PlanSpec(
        slug="family",
        plan_label="Family Plan",
        price="$14.99",
        period_label="/month",
        description="Unlimited stories for up to 5 family members with shared libraries.",
        highlight="Includes kid-safe profiles & parental controls.",
        badge_text="Family Bundle",
        badge_color=(96, 165, 250),
        highlight_color=(164, 221, 255),
        icon_gradient=((139, 92, 246), (14, 165, 233)),
        output_filename="family-subscription.png",
    ),
)


def _vertical_gradient() -> Image.Image:
    base = Image.new("RGB", (WIDTH, HEIGHT))
    pixels = base.load()

    for y in range(HEIGHT):
        ratio = y / (HEIGHT - 1)
        color = tuple(
            int(TOP_COLOR[i] * (1 - ratio) + BOTTOM_COLOR[i] * ratio) for i in range(3)
        )
        for x in range(WIDTH):
            pixels[x, y] = color

    return base.convert("RGBA")


def _with_glow(
    image: Image.Image, bbox: Tuple[float, float, float, float], color, blur
) -> Image.Image:
    glow = Image.new("RGBA", image.size, (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse(bbox, fill=color)
    glow = glow.filter(ImageFilter.GaussianBlur(blur))
    return Image.alpha_composite(image, glow)


def _load_font(candidates: Iterable[str], size: int) -> ImageFont.FreeTypeFont:
    font_dirs = [
        Path("C:/Windows/Fonts"),
        Path("/System/Library/Fonts"),
        Path("/Library/Fonts"),
    ]

    for directory in font_dirs:
        for name in candidates:
            path = directory / name
            if path.exists():
                return ImageFont.truetype(str(path), size)

    return ImageFont.load_default()


def _build_icon(gradient_colors: Tuple[Tuple[int, int, int], Tuple[int, int, int]]) -> Image.Image:
    size = 96
    gradient = Image.new("RGBA", (size, size))
    grad_draw = ImageDraw.Draw(gradient)
    top_color, bottom_color = gradient_colors
    for y in range(size):
        ratio = y / (size - 1)
        color = tuple(
            int(top_color[i] * (1 - ratio) + bottom_color[i] * ratio) for i in range(3)
        )
        grad_draw.line([(0, y), (size, y)], fill=color, width=1)

    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, size - 1, size - 1), radius=24, fill=255
    )

    icon = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    icon.paste(gradient, mask=mask)

    star = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    star_draw = ImageDraw.Draw(star)
    cx = cy = size / 2
    outer = 26
    inner = 12
    points = []
    for i in range(10):
        angle = math.radians(-90 + i * 36)
        radius = outer if i % 2 == 0 else inner
        points.append((cx + radius * math.cos(angle), cy + radius * math.sin(angle)))
    star_draw.polygon(points, fill=(255, 255, 255, 235))
    icon = Image.alpha_composite(icon, star)

    outline = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(outline).rounded_rectangle(
        (1, 1, size - 2, size - 2), radius=24, outline=(255, 255, 255, 130), width=2
    )
    icon = Image.alpha_composite(icon, outline)
    return icon


def _draw_centered_text(
    draw: ImageDraw.ImageDraw,
    text: str,
    font: ImageFont.FreeTypeFont,
    y: float,
    fill: Tuple[int, int, int, int],
) -> float:
    bbox = draw.textbbox((0, 0), text, font=font)
    width = bbox[2] - bbox[0]
    height = bbox[3] - bbox[1]
    draw.text(((WIDTH - width) / 2, y), text, font=font, fill=fill)
    return y + height


def _wrap_text(text: str, font: ImageFont.FreeTypeFont, max_width: int) -> str:
    lines = []
    for paragraph in text.splitlines():
        for candidate in textwrap.wrap(paragraph, width=40):
            bbox = ImageDraw.Draw(Image.new("RGB", (1, 1))).textbbox(
                (0, 0), candidate, font=font
            )
            if bbox[2] - bbox[0] <= max_width:
                lines.append(candidate)
            else:
                lines.extend(textwrap.wrap(candidate, width=30))
    return "\n".join(lines)


def _prepare_fonts() -> Dict[str, ImageFont.FreeTypeFont]:
    return {
        "small": _load_font(["segoeui.ttf", "Arial.ttf"], 20),
        "medium": _load_font(["segoeui.ttf", "Arial.ttf"], 26),
        "plan": _load_font(["segoeuib.ttf", "Arialbd.ttf"], 36),
        "price": _load_font(["segoeuib.ttf", "Arialbd.ttf"], 60),
        "period": _load_font(["segoeui.ttf", "Arial.ttf"], 20),
        "description": _load_font(["segoeui.ttf", "Arial.ttf"], 18),
        "badge": _load_font(["segoeuib.ttf", "Arialbd.ttf"], 18),
    }


def _render_plan_image(plan: PlanSpec, fonts: Dict[str, ImageFont.FreeTypeFont]) -> None:
    image = _vertical_gradient()
    primary_color, secondary_color = plan.icon_gradient
    image = _with_glow(image, (-140, -140, 220, 220), (*primary_color, 180), 80)
    image = _with_glow(
        image,
        (WIDTH - 260, HEIGHT - 260, WIDTH + 100, HEIGHT + 100),
        (*secondary_color, 140),
        120,
    )

    draw = ImageDraw.Draw(image)
    _draw_centered_text(
        draw, "Dream Flow Settings", fonts["small"], 28, (255, 255, 255, 200)
    )
    _draw_centered_text(
        draw, "Premium Subscription", fonts["medium"], 56, (255, 255, 255, 220)
    )

    card_rect = (56, 116, WIDTH - 56, HEIGHT - 44)
    shadow = Image.new("RGBA", image.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (card_rect[0], card_rect[1] + 10, card_rect[2], card_rect[3] + 10),
        radius=38,
        fill=(0, 0, 0, 150),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(14))
    image = Image.alpha_composite(image, shadow)

    card_layer = Image.new("RGBA", image.size, (0, 0, 0, 0))
    card_draw = ImageDraw.Draw(card_layer)
    card_draw.rounded_rectangle(
        card_rect,
        radius=36,
        fill=(14, 11, 28, 235),
        outline=(255, 255, 255, 60),
        width=2,
    )
    image = Image.alpha_composite(image, card_layer)
    draw = ImageDraw.Draw(image)

    icon = _build_icon(plan.icon_gradient)
    icon_x = WIDTH // 2 - icon.width // 2
    icon_y = card_rect[1] + 24
    image.paste(icon, (icon_x, icon_y), icon)

    next_y = icon_y + icon.height + 20
    next_y = _draw_centered_text(
        draw, plan.plan_label, fonts["plan"], next_y, (255, 255, 255, 240)
    )

    price_text = plan.price
    price_bbox = draw.textbbox((0, 0), price_text, font=fonts["price"])
    price_width = price_bbox[2] - price_bbox[0]
    price_height = price_bbox[3] - price_bbox[1]
    price_x = (WIDTH - price_width) / 2
    price_y = next_y + 6
    draw.text(
        (price_x, price_y), price_text, font=fonts["price"], fill=(255, 255, 255, 255)
    )

    period_text = plan.period_label
    period_bbox = draw.textbbox((0, 0), period_text, font=fonts["period"])
    period_height = period_bbox[3] - period_bbox[1]
    draw.text(
        (
            price_x + price_width + 6,
            price_y + price_height - period_height - 6,
        ),
        period_text,
        font=fonts["period"],
        fill=(255, 255, 255, 200),
    )

    desc_text = _wrap_text(
        plan.description,
        fonts["description"],
        max_width=int((card_rect[2] - card_rect[0]) * 0.85),
    )
    desc_bbox = draw.multiline_textbbox(
        (0, 0), desc_text, font=fonts["description"], spacing=4
    )
    desc_width = desc_bbox[2] - desc_bbox[0]
    desc_height = desc_bbox[3] - desc_bbox[1]
    desc_x = (WIDTH - desc_width) / 2
    desc_y = price_y + price_height + 16
    draw.multiline_text(
        (desc_x, desc_y),
        desc_text,
        font=fonts["description"],
        fill=(255, 255, 255, 210),
        spacing=4,
        align="center",
    )

    padding_x = 24
    padding_y = 10
    badge_spacing = 64
    badge_bottom_margin = 16
    has_badge = plan.badge_text and plan.badge_color
    badge_width = badge_height = 0
    if has_badge:
        badge_bbox = draw.textbbox((0, 0), plan.badge_text, font=fonts["badge"])
        badge_width = badge_bbox[2] - badge_bbox[0]
        badge_height = (badge_bbox[3] - badge_bbox[1]) + padding_y * 2

    highlight_text = _wrap_text(
        plan.highlight,
        fonts["description"],
        max_width=int((card_rect[2] - card_rect[0]) * 0.85),
    )
    highlight_bbox = draw.multiline_textbbox(
        (0, 0), highlight_text, font=fonts["description"], spacing=2
    )
    highlight_width = highlight_bbox[2] - highlight_bbox[0]
    highlight_height = highlight_bbox[3] - highlight_bbox[1]
    highlight_x = (WIDTH - highlight_width) / 2
    content_bottom = desc_y + desc_height
    min_highlight_y = content_bottom + 8
    base_highlight_y = content_bottom + 16
    if has_badge:
        max_highlight_y = (
            card_rect[3] - badge_bottom_margin - badge_height - badge_spacing - highlight_height
        )
    else:
        max_highlight_y = card_rect[3] - badge_bottom_margin - highlight_height
    if max_highlight_y < min_highlight_y:
        max_highlight_y = min_highlight_y
    highlight_y = max(base_highlight_y, min_highlight_y)
    highlight_y = min(highlight_y, max_highlight_y)
    draw.multiline_text(
        (highlight_x, highlight_y),
        highlight_text,
        font=fonts["description"],
        fill=plan.highlight_color + (240,),
        spacing=2,
        align="center",
    )

    if has_badge:
        badge_top = highlight_y + highlight_height + badge_spacing
        badge_rect = (
            (WIDTH - (badge_width + padding_x * 2)) / 2,
            badge_top,
            (WIDTH + (badge_width + padding_x * 2)) / 2,
            badge_top + badge_height,
        )
        draw.rounded_rectangle(
            badge_rect,
            radius=20,
            fill=plan.badge_color + (60,),
            outline=plan.badge_color + (200,),
            width=2,
        )
        draw.text(
            (
                badge_rect[0] + padding_x,
                badge_rect[1] + padding_y - 4,
            ),
            plan.badge_text,
            font=fonts["badge"],
            fill=(255, 255, 255, 255),
        )

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    output_path = OUTPUT_DIR / plan.output_filename
    image.convert("RGB").save(output_path)
    print(f"Saved {plan.plan_label} image to {output_path}")


def main() -> None:
    fonts = _prepare_fonts()
    for plan in PLAN_SPECS:
        _render_plan_image(plan, fonts)


if __name__ == "__main__":
    main()
