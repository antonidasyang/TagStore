#!/usr/bin/env python3
"""
Generate a beautiful, anti-aliased icon for TagStore.
Requires: pip install pillow
"""

import os
import sys
from math import pi, sin, cos

try:
    from PIL import Image, ImageDraw, ImageFilter, ImageFont
except ImportError:
    print("Please install Pillow:")
    print("  pip install pillow")
    sys.exit(1)

def create_icon(size):
    """Create a beautiful TagStore icon at the specified size with anti-aliasing."""
    # Render at 4x size for anti-aliasing, then downscale
    scale = 4
    s = size * scale
    
    img = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img, 'RGBA')
    
    # Helper for scaled coordinates
    def sc(val):
        return int(val * s / 512)
    
    pad = sc(24)
    
    # === Background: Gradient-like rounded square ===
    # Base blue
    corner_radius = sc(80)
    draw.rounded_rectangle(
        [pad, pad, s - pad, s - pad],
        radius=corner_radius,
        fill=(79, 70, 229)  # Indigo-600
    )
    
    # Lighter overlay on top-left for depth
    overlay = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    overlay_draw = ImageDraw.Draw(overlay, 'RGBA')
    overlay_draw.rounded_rectangle(
        [pad, pad, s - pad, s - pad],
        radius=corner_radius,
        fill=(99, 102, 241, 80)  # Lighter indigo, semi-transparent
    )
    # Gradient mask
    for y in range(s):
        alpha = int(255 * (1 - y / s) * 0.5)
        for x in range(s):
            px = overlay.getpixel((x, y))
            if px[3] > 0:
                overlay.putpixel((x, y), (px[0], px[1], px[2], min(px[3], alpha)))
    img = Image.alpha_composite(img, overlay)
    draw = ImageDraw.Draw(img, 'RGBA')
    
    # === File/Document shape (white, rounded) ===
    doc_left = sc(100)
    doc_right = sc(412)
    doc_top = sc(90)
    doc_bottom = sc(420)
    doc_radius = sc(24)
    
    # Shadow
    shadow = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow, 'RGBA')
    shadow_draw.rounded_rectangle(
        [doc_left + sc(8), doc_top + sc(12), doc_right + sc(8), doc_bottom + sc(12)],
        radius=doc_radius,
        fill=(0, 0, 0, 60)
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=sc(12)))
    img = Image.alpha_composite(img, shadow)
    draw = ImageDraw.Draw(img, 'RGBA')
    
    # Main document
    draw.rounded_rectangle(
        [doc_left, doc_top, doc_right, doc_bottom],
        radius=doc_radius,
        fill=(255, 255, 255)
    )
    
    # Folded corner effect
    fold_size = sc(50)
    fold_points = [
        (doc_right - fold_size, doc_top),
        (doc_right, doc_top + fold_size),
        (doc_right, doc_top),
    ]
    draw.polygon(fold_points, fill=(229, 231, 235))  # Gray-200
    
    # Fold shadow line
    draw.line(
        [(doc_right - fold_size, doc_top), (doc_right, doc_top + fold_size)],
        fill=(209, 213, 219),  # Gray-300
        width=sc(3)
    )
    
    # === Tag chips on the document ===
    def draw_tag(x, y, width, dot_color, text_width_ratio=0.6):
        tag_height = sc(44)
        tag_radius = sc(22)
        
        # Tag background
        draw.rounded_rectangle(
            [x, y, x + width, y + tag_height],
            radius=tag_radius,
            fill=(243, 244, 246)  # Gray-100
        )
        
        # Colored dot
        dot_r = sc(10)
        dot_cx = x + sc(22)
        dot_cy = y + tag_height // 2
        draw.ellipse(
            [dot_cx - dot_r, dot_cy - dot_r, dot_cx + dot_r, dot_cy + dot_r],
            fill=dot_color
        )
        
        # Text lines (simulated)
        line_y = y + tag_height // 2
        line_start = x + sc(42)
        line_end = x + int(width * text_width_ratio)
        draw.rounded_rectangle(
            [line_start, line_y - sc(4), line_end, line_y + sc(4)],
            radius=sc(4),
            fill=(156, 163, 175)  # Gray-400
        )
    
    # Three tags with different colors
    draw_tag(sc(130), sc(160), sc(140), (59, 130, 246))    # Blue
    draw_tag(sc(130), sc(220), sc(180), (16, 185, 129))    # Emerald
    draw_tag(sc(130), sc(280), sc(160), (168, 85, 247))    # Purple
    
    # === Magnifying glass / Search icon ===
    glass_cx = sc(340)
    glass_cy = sc(340)
    glass_r = sc(55)
    glass_inner_r = sc(40)
    
    # Glass circle
    draw.ellipse(
        [glass_cx - glass_r, glass_cy - glass_r, glass_cx + glass_r, glass_cy + glass_r],
        fill=(79, 70, 229),  # Indigo
        outline=(255, 255, 255),
        width=sc(8)
    )
    
    # Inner circle (lens)
    draw.ellipse(
        [glass_cx - glass_inner_r, glass_cy - glass_inner_r, 
         glass_cx + glass_inner_r, glass_cy + glass_inner_r],
        fill=(129, 140, 248)  # Lighter indigo
    )
    
    # Shine on lens
    shine_offset = sc(12)
    shine_r = sc(12)
    draw.ellipse(
        [glass_cx - shine_offset - shine_r, glass_cy - shine_offset - shine_r,
         glass_cx - shine_offset + shine_r, glass_cy - shine_offset + shine_r],
        fill=(255, 255, 255, 180)
    )
    
    # Handle
    handle_start_x = glass_cx + int(glass_r * 0.7)
    handle_start_y = glass_cy + int(glass_r * 0.7)
    handle_len = sc(45)
    handle_end_x = handle_start_x + int(handle_len * 0.7)
    handle_end_y = handle_start_y + int(handle_len * 0.7)
    
    draw.line(
        [(handle_start_x, handle_start_y), (handle_end_x, handle_end_y)],
        fill=(255, 255, 255),
        width=sc(14)
    )
    # Handle end cap
    draw.ellipse(
        [handle_end_x - sc(10), handle_end_y - sc(10),
         handle_end_x + sc(10), handle_end_y + sc(10)],
        fill=(255, 255, 255)
    )
    
    # === Sparkle (AI indicator) ===
    def draw_sparkle(cx, cy, size, color):
        points = []
        for i in range(8):
            angle = i * pi / 4 - pi / 2
            r = size if i % 2 == 0 else size * 0.35
            points.append((cx + r * cos(angle), cy + r * sin(angle)))
        draw.polygon(points, fill=color)
    
    draw_sparkle(sc(420), sc(100), sc(32), (251, 191, 36))  # Amber
    draw_sparkle(sc(450), sc(150), sc(18), (253, 224, 71))  # Yellow lighter
    
    # Downscale with high-quality resampling for anti-aliasing
    img = img.resize((size, size), Image.Resampling.LANCZOS)
    
    return img

def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    ico_path = os.path.join(script_dir, "icon.ico")
    
    # Generate multiple sizes for ICO
    sizes = [16, 24, 32, 48, 64, 128, 256]
    images = []
    
    print("Generating icon sizes with anti-aliasing...")
    for size in sizes:
        print(f"  {size}x{size}")
        img = create_icon(size)
        images.append(img)
    
    # Save as ICO
    print(f"Saving to: {ico_path}")
    images[0].save(
        ico_path,
        format='ICO',
        sizes=[(img.width, img.height) for img in images],
        append_images=images[1:]
    )
    
    # Also save individual PNGs
    for img in images:
        size = img.width
        png_path = os.path.join(script_dir, f"icon_{size}.png")
        img.save(png_path, "PNG")
        print(f"Saved: icon_{size}.png")
    
    print("Done!")

if __name__ == "__main__":
    main()
