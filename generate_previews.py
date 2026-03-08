#!/usr/bin/env python3
"""Generate widget preview PNGs for the DualMate widget picker.

Renders at 3x resolution then downsamples with LANCZOS for crisp antialiasing.
Uses Roboto font and matches the actual widget layout as closely as possible.

Schedule widget: day column (label + date number) | divider | items with bg rects
Canteen widget:  day column (label + "d MMM")     | divider | items without bg rects

Emoji characters are used for canteen meal types (monochrome Roboto glyphs).
Price format matches NumberFormat.getCurrencyInstance(Locale.GERMANY): "3,60 €"

Font paths can be configured with CLI flags or env vars:
- `--font-regular` / `DUALMATE_FONT_REGULAR`
- `--font-bold` / `DUALMATE_FONT_BOLD`
- `--font-medium` / `DUALMATE_FONT_MEDIUM`
- `--font-emoji` / `DUALMATE_FONT_EMOJI`

By default the script looks in `/tmp/roboto/` and `/tmp/NotoEmoji.ttf`.
"""

import argparse
import os
from PIL import Image, ImageDraw, ImageFont

# -- Default paths -----------------------------------------------------------
DEFAULT_SCHEDULE_OUT = "android/app/src/main/res/drawable-nodpi/schedule_now_widget_preview.png"
DEFAULT_CANTEEN_OUT = "android/app/src/main/res/drawable-nodpi/canteen_today_widget_preview.png"
DEFAULT_FONT_REG = "/tmp/roboto/Roboto-Regular.ttf"
DEFAULT_FONT_BOLD = "/tmp/roboto/Roboto-Bold.ttf"
DEFAULT_FONT_MED = "/tmp/roboto/Roboto-Medium.ttf"
DEFAULT_FONT_EMOJI = "/tmp/NotoEmoji.ttf"

# -- Colors (dark theme from colors.xml) ------------------------------------
BG = "#1C1B1F"
DAY_LABEL = "#CAC4D0"
DIVIDER = "#3D3B44"
ITEM_TEXT = "#F5EFF7"
SUBTITLE_TEXT = "#CAC4D0"
SECONDARY_TEXT = "#B0A8B8"
ITEM_BG_CURRENT = "#353441"
ITEM_BG_FUTURE = "#2B2A33"
ACCENT_CURRENT = "#F27D7D"
ACCENT_FUTURE = "#E85C5C"

# -- Rendering dimensions ---------------------------------------------------
# Real widget is ~900px wide on 420dpi device.
# We render at 3x final size then downsample for antialiasing.
SCALE = 3
FINAL_W, FINAL_H = 732, 460
W, H = FINAL_W * SCALE, FINAL_H * SCALE
CORNER_R = 24 * SCALE
PADDING = 8 * SCALE
ACCENT_W = 5 * SCALE
ACCENT_GAP = 6 * SCALE
DIVIDER_W = 2 * SCALE
ITEM_MARGIN_B = 4 * SCALE
ITEM_CORNER = 8 * SCALE

# Day column widths
SCHED_DAY_COL_W = 48 * SCALE
CANTEEN_DAY_COL_W = 92 * SCALE
DIVIDER_MARGIN = 6 * SCALE


def hex_to_rgb(h, *, alpha_position=None):
    """Return an RGB tuple from `#RRGGBB` or `#AARRGGBB`/`#RRGGBBAA`.

    Six-digit hex is treated as RGB. Eight-digit hex requires an explicit
    `alpha_position`: `first` for ARGB, `last` for RGBA.
    """
    h = h.lstrip("#")
    if len(h) == 6:
        rgb = h
    elif len(h) == 8:
        if alpha_position == "first":
            rgb = h[2:]
        elif alpha_position == "last":
            rgb = h[:-2]
        else:
            raise ValueError(
                "8-digit hex colors require alpha_position='first' (ARGB) "
                "or alpha_position='last' (RGBA)"
            )
    else:
        raise ValueError(f"Unsupported hex color format: {h!r}")
    return tuple(int(rgb[i : i + 2], 16) for i in (0, 2, 4))


def parse_args():
    parser = argparse.ArgumentParser(
        description="Generate DualMate widget preview PNGs.",
    )
    parser.add_argument(
        "--schedule-out",
        default=DEFAULT_SCHEDULE_OUT,
        help=f"Output path for the schedule preview PNG (default: {DEFAULT_SCHEDULE_OUT})",
    )
    parser.add_argument(
        "--canteen-out",
        default=DEFAULT_CANTEEN_OUT,
        help=f"Output path for the canteen preview PNG (default: {DEFAULT_CANTEEN_OUT})",
    )
    parser.add_argument(
        "--font-regular",
        default=os.environ.get("DUALMATE_FONT_REGULAR", DEFAULT_FONT_REG),
        help=(
            "Path to Roboto Regular font "
            f"(env: DUALMATE_FONT_REGULAR, default: {DEFAULT_FONT_REG})"
        ),
    )
    parser.add_argument(
        "--font-bold",
        default=os.environ.get("DUALMATE_FONT_BOLD", DEFAULT_FONT_BOLD),
        help=(
            "Path to Roboto Bold font "
            f"(env: DUALMATE_FONT_BOLD, default: {DEFAULT_FONT_BOLD})"
        ),
    )
    parser.add_argument(
        "--font-medium",
        default=os.environ.get("DUALMATE_FONT_MEDIUM", DEFAULT_FONT_MED),
        help=(
            "Path to Roboto Medium font "
            f"(env: DUALMATE_FONT_MEDIUM, default: {DEFAULT_FONT_MED})"
        ),
    )
    parser.add_argument(
        "--font-emoji",
        default=os.environ.get("DUALMATE_FONT_EMOJI", DEFAULT_FONT_EMOJI),
        help=(
            "Path to NotoEmoji font "
            f"(env: DUALMATE_FONT_EMOJI, default: {DEFAULT_FONT_EMOJI})"
        ),
    )
    return parser.parse_args()


def resolve_font_paths(args):
    return {
        "regular": args.font_regular,
        "bold": args.font_bold,
        "medium": args.font_medium,
        "emoji": args.font_emoji,
    }


def validate_font_paths(font_paths):
    missing = []
    for name, path in font_paths.items():
        if not os.path.isfile(path) or not os.access(path, os.R_OK):
            missing.append((name, path))

    if not missing:
        return

    details = "\n".join(f"- {name}: {path}" for name, path in missing)
    raise RuntimeError(
        "Missing or unreadable font files:\n"
        f"{details}\n\n"
        "Provide fonts with CLI flags (--font-regular, --font-bold, "
        "--font-medium, --font-emoji) or env vars "
        "DUALMATE_FONT_REGULAR, DUALMATE_FONT_BOLD, DUALMATE_FONT_MEDIUM, "
        "DUALMATE_FONT_EMOJI. Defaults are /tmp/roboto/Roboto-*.ttf and "
        "/tmp/NotoEmoji.ttf."
    )


def draw_accent_bar(draw, x, y, h, color):
    r = ACCENT_W // 2
    draw.rounded_rectangle(
        [x, y, x + ACCENT_W, y + h], radius=r, fill=hex_to_rgb(color)
    )


def load_fonts(font_paths):
    """Font sizes proportional to real widget.

    Real widget on 420dpi:  12sp=31px, 13sp=34px, 15sp=39px, 16sp=42px
    Real widget width ~900px.  Our render width = 2196px (732*3).
    Scale factor = 2196/900 ≈ 2.44x.  So 42px title → ~103px in render.
    We express sizes in points for ImageFont.truetype().
    """
    sizes = {}
    for name, pts in [
        ("day_label", 24),   # 12sp — small gray day abbreviation
        ("date_num", 32),    # 16sp — bold date number
        ("title", 34),       # slightly larger for picker readability
        ("subtitle", 27),    # slightly larger while keeping hierarchy
        ("meal_emoji", 28),  # 15sp — canteen emoji (NotoEmoji font)
        ("meal_name", 31),   # slightly larger for picker readability
        ("price", 27),       # slightly larger for picker readability
        ("overflow", 22),    # smaller overflow text
    ]:
        s = int(pts * SCALE)
        bold = name in ("date_num", "title")
        if name == "meal_emoji":
            font_path = font_paths["emoji"]
        elif bold:
            font_path = font_paths["bold"]
        elif name == "meal_name":
            font_path = font_paths["medium"]
        else:
            font_path = font_paths["regular"]
        sizes[name] = ImageFont.truetype(font_path, s)
    return sizes


def generate_schedule_preview(out_path, font_paths):
    fonts = load_fonts(font_paths)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Background rounded rect
    draw.rounded_rectangle(
        [0, 0, W - 1, H - 1], radius=CORNER_R, fill=hex_to_rgb(BG)
    )

    days = [
        {
            "label": "Mon",
            "date": "10",
            "items": [
                {
                    "title": "Software Engineering",
                    "sub": "09:15 - 10:45 \u2022 A208",
                    "accent": ACCENT_CURRENT,
                    "bg": ITEM_BG_CURRENT,
                },
                {
                    "title": "Databases",
                    "sub": "11:00 - 12:30 \u2022 B114",
                    "accent": ACCENT_FUTURE,
                    "bg": ITEM_BG_FUTURE,
                },
            ],
        },
        {
            "label": "Tue",
            "date": "11",
            "items": [
                {
                    "title": "Project Workshop",
                    "sub": "08:00 - 09:30 \u2022 Online",
                    "accent": ACCENT_FUTURE,
                    "bg": ITEM_BG_FUTURE,
                },
                {
                    "title": "Math Tutorial",
                    "sub": "14:00 - 15:30 \u2022 C301",
                    "accent": ACCENT_FUTURE,
                    "bg": ITEM_BG_FUTURE,
                },
            ],
        },
        {
            "label": "Wed",
            "date": "12",
            "items": [
                {
                    "title": "Business Ethics",
                    "sub": "10:00 - 11:30 \u2022 A105",
                    "accent": ACCENT_FUTURE,
                    "bg": ITEM_BG_FUTURE,
                },
            ],
        },
    ]

    day_col_w = SCHED_DAY_COL_W
    content_top = PADDING
    content_h = H - 2 * PADDING
    day_h = content_h // len(days)

    for di, day in enumerate(days):
        y_base = content_top + di * day_h
        x = PADDING

        # Day label (e.g. "Mon") + date number (e.g. "10") — vertically centered
        # Use font metrics for consistent heights regardless of text content
        lbl_asc, lbl_desc = fonts["day_label"].getmetrics()
        lbl_line_h = lbl_asc + lbl_desc
        date_asc, date_desc = fonts["date_num"].getmetrics()
        date_line_h = date_asc + date_desc
        gap = 2 * SCALE
        block_h = lbl_line_h + gap + date_line_h
        ty = y_base + (day_h - block_h) // 2

        draw.text(
            (x, ty), day["label"],
            fill=hex_to_rgb(DAY_LABEL), font=fonts["day_label"],
        )
        draw.text(
            (x, ty + lbl_line_h + gap), day["date"],
            fill=hex_to_rgb(DAY_LABEL), font=fonts["date_num"],
        )

        # Vertical divider
        div_x = x + day_col_w + DIVIDER_MARGIN
        draw.rectangle(
            [div_x, y_base + 4 * SCALE, div_x + DIVIDER_W, y_base + day_h - 4 * SCALE],
            fill=hex_to_rgb(DIVIDER),
        )

        # Items area
        items_x = div_x + DIVIDER_W + DIVIDER_MARGIN
        items_w = W - PADDING - items_x
        n = len(day["items"])
        avail_h = day_h - 4 * SCALE
        item_h = (avail_h - (n - 1) * ITEM_MARGIN_B) // n if n else avail_h

        for ii, item in enumerate(day["items"]):
            iy = y_base + 2 * SCALE + ii * (item_h + ITEM_MARGIN_B)

            # Item background rectangle (schedule items have these)
            draw.rounded_rectangle(
                [items_x, iy, items_x + items_w, iy + item_h],
                radius=ITEM_CORNER,
                fill=hex_to_rgb(item["bg"]),
            )

            # Accent bar on left side
            bar_inset = 6 * SCALE
            draw_accent_bar(
                draw,
                items_x + 3 * SCALE,
                iy + bar_inset,
                item_h - 2 * bar_inset,
                item["accent"],
            )

            # Title + subtitle — use font metrics for consistent line heights
            # (matches Android wrap_content which uses ascent+descent, not ink bounds)
            title_asc, title_desc = fonts["title"].getmetrics()
            sub_asc, sub_desc = fonts["subtitle"].getmetrics()
            title_line_h = title_asc + title_desc
            sub_line_h = sub_asc + sub_desc
            # Real widget XML has zero spacing between the two TextViews
            block = title_line_h + sub_line_h
            text_y = iy + (item_h - block) // 2
            text_x = items_x + ACCENT_W + ACCENT_GAP + 2 * SCALE

            draw.text(
                (text_x, text_y), item["title"],
                fill=hex_to_rgb(ITEM_TEXT), font=fonts["title"],
            )
            draw.text(
                (text_x, text_y + title_line_h), item["sub"],
                fill=hex_to_rgb(SUBTITLE_TEXT), font=fonts["subtitle"],
            )

    final = img.resize((FINAL_W, FINAL_H), Image.LANCZOS)
    final.save(out_path, "PNG")
    print(f"Schedule preview: {out_path} ({FINAL_W}x{FINAL_H})")


def generate_canteen_preview(out_path, font_paths):
    fonts = load_fonts(font_paths)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Background rounded rect
    draw.rounded_rectangle(
        [0, 0, W - 1, H - 1], radius=CORNER_R, fill=hex_to_rgb(BG)
    )

    # Canteen items: emoji + meal name + price right-aligned
    # NO background rectangles on items (just text on dark bg)
    # Price format: "3,60 €" (German locale EUR)
    days = [
        {
            "label": "Mon",
            "date": "10 Mar",
            "items": [
                {"emoji": "\U0001f331", "name": "Lentil Curry", "price": "3,10 \u20ac"},
                {"emoji": "\U0001f357", "name": "Chicken Teriyaki", "price": "4,20 \u20ac"},
            ],
        },
        {
            "label": "Tue",
            "date": "11 Mar",
            "items": [
                {"emoji": "\U0001f96c", "name": "Chili sin Carne", "price": "3,40 \u20ac"},
                {"emoji": "\U0001f437", "name": "Pasta Bolognese", "price": "3,80 \u20ac"},
            ],
        },
        {
            "label": "Wed",
            "date": "12 Mar",
            "items": [
                {"emoji": "\U0001f96c", "name": "Veggie Burger", "price": "3,60 \u20ac"},
            ],
        },
    ]

    day_col_w = CANTEEN_DAY_COL_W
    content_top = PADDING
    content_h = H - 2 * PADDING
    day_h = content_h // len(days)

    for di, day in enumerate(days):
        y_base = content_top + di * day_h
        x = PADDING

        # Day label + date — vertically centered in column
        # Use font metrics for consistent heights
        lbl_asc, lbl_desc = fonts["day_label"].getmetrics()
        lbl_line_h = lbl_asc + lbl_desc
        date_asc, date_desc = fonts["date_num"].getmetrics()
        date_line_h = date_asc + date_desc
        gap = 2 * SCALE
        block_h = lbl_line_h + gap + date_line_h
        ty = y_base + (day_h - block_h) // 2

        draw.text(
            (x, ty), day["label"],
            fill=hex_to_rgb(DAY_LABEL), font=fonts["day_label"],
        )
        draw.text(
            (x, ty + lbl_line_h + gap), day["date"],
            fill=hex_to_rgb(DAY_LABEL), font=fonts["date_num"],
        )

        # Vertical divider
        div_x = x + day_col_w + DIVIDER_MARGIN
        draw.rectangle(
            [div_x, y_base + 4 * SCALE, div_x + DIVIDER_W, y_base + day_h - 4 * SCALE],
            fill=hex_to_rgb(DIVIDER),
        )

        # Items area
        items_x = div_x + DIVIDER_W + DIVIDER_MARGIN
        items_w = W - PADDING - items_x
        n = len(day["items"])
        avail_h = day_h - 4 * SCALE
        item_h = (avail_h - (n - 1) * ITEM_MARGIN_B) // n if n else avail_h

        for ii, item in enumerate(day["items"]):
            iy = y_base + 2 * SCALE + ii * (item_h + ITEM_MARGIN_B)

            # No background rectangle for canteen items

            # Accent bar
            bar_inset = 6 * SCALE
            draw_accent_bar(
                draw,
                items_x + 2 * SCALE,
                iy + bar_inset,
                item_h - 2 * bar_inset,
                ACCENT_FUTURE,
            )

            # Emoji
            emoji_x = items_x + ACCENT_W + ACCENT_GAP + 1 * SCALE
            emoji_asc, emoji_desc = fonts["meal_emoji"].getmetrics()
            emoji_line_h = emoji_asc + emoji_desc
            emoji_y = iy + (item_h - emoji_line_h) // 2
            emoji_w = int(draw.textlength(item["emoji"], font=fonts["meal_emoji"]))
            draw.text(
                (emoji_x, emoji_y), item["emoji"],
                fill=hex_to_rgb(ITEM_TEXT), font=fonts["meal_emoji"],
            )

            # Meal name
            name_x = emoji_x + emoji_w + 6 * SCALE
            meal_asc, meal_desc = fonts["meal_name"].getmetrics()
            meal_line_h = meal_asc + meal_desc
            name_y = iy + (item_h - meal_line_h) // 2
            draw.text(
                (name_x, name_y), item["name"],
                fill=hex_to_rgb(ITEM_TEXT), font=fonts["meal_name"],
            )

            # Price right-aligned
            price_w = draw.textlength(item["price"], font=fonts["price"])
            price_asc, price_desc = fonts["price"].getmetrics()
            price_line_h = price_asc + price_desc
            price_x = items_x + items_w - price_w - 2 * SCALE
            price_y = iy + (item_h - price_line_h) // 2
            draw.text(
                (price_x, price_y), item["price"],
                fill=hex_to_rgb(SECONDARY_TEXT), font=fonts["price"],
            )

    final = img.resize((FINAL_W, FINAL_H), Image.LANCZOS)
    final.save(out_path, "PNG")
    print(f"Canteen preview: {out_path} ({FINAL_W}x{FINAL_H})")


if __name__ == "__main__":
    args = parse_args()
    font_paths = resolve_font_paths(args)
    validate_font_paths(font_paths)
    generate_schedule_preview(args.schedule_out, font_paths)
    generate_canteen_preview(args.canteen_out, font_paths)
    print("Done!")
