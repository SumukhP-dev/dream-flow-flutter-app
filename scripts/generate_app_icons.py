#!/usr/bin/env python3
"""
Generate custom Dream Flow app icons for all platforms.

Icon Design Concept:
- Stylized crescent moon with flowing stars/dream elements
- Purple to blue gradient (brand colors: #8B5CF6 to #3B82F6)
- Sparkle/magic elements to represent AI generation
- Modern, clean design that stands out from nature-based competitor icons
- Recognizable at small sizes

Requirements:
    pip install Pillow
"""

from PIL import Image, ImageDraw, ImageFilter
import os
from pathlib import Path
import math

# Brand colors
PRIMARY_PURPLE = "#8B5CF6"  # RGB: 139, 92, 246
PRIMARY_BLUE = "#3B82F6"    # RGB: 59, 130, 246
SECONDARY_CYAN = "#06B6D4"  # RGB: 6, 182, 212
BACKGROUND = "#0A0A0A"      # Dark background

def hex_to_rgb(hex_color):
    """Convert hex color to RGB tuple."""
    hex_color = hex_color.lstrip('#')
    return tuple(int(hex_color[i:i+2], 16) for i in (0, 2, 4))

def create_gradient_background(size, start_color, end_color):
    """Create a gradient background with enhanced smoothness and radial overlay."""
    img = Image.new('RGB', size, start_color)
    draw = ImageDraw.Draw(img)
    
    width, height = size
    center_x, center_y = width // 2, height // 2
    max_dist = math.sqrt(center_x**2 + center_y**2)
    
    # Create smooth linear gradient
    for y in range(height):
        # Calculate color interpolation
        ratio = y / height
        r = int(hex_to_rgb(start_color)[0] * (1 - ratio) + hex_to_rgb(end_color)[0] * ratio)
        g = int(hex_to_rgb(start_color)[1] * (1 - ratio) + hex_to_rgb(end_color)[1] * ratio)
        b = int(hex_to_rgb(start_color)[2] * (1 - ratio) + hex_to_rgb(end_color)[2] * ratio)
        draw.line([(0, y), (width, y)], fill=(r, g, b))
    
    # Add subtle radial gradient overlay for depth
    for y in range(height):
        for x in range(width):
            dist = math.sqrt((x - center_x)**2 + (y - center_y)**2)
            radial_ratio = min(dist / max_dist, 1.0)
            # Subtle darkening at edges
            darken = int(radial_ratio * 15)  # Max 15 points darker at edges
            current = img.getpixel((x, y))
            new_r = max(0, current[0] - darken)
            new_g = max(0, current[1] - darken)
            new_b = max(0, current[2] - darken)
            img.putpixel((x, y), (new_r, new_g, new_b))
    
    return img

def draw_crescent_moon(draw, img, center_x, center_y, radius, rotation=0, icon_size=512):
    """Draw a stylized crescent moon with glow, shadow, and highlight effects."""
    # Slightly increase moon size for better small-size visibility
    size_multiplier = 1.0 if icon_size >= 64 else 1.15  # Larger at small sizes
    radius = int(radius * size_multiplier)
    
    # Outer circle (full)
    outer_bbox = [
        center_x - radius,
        center_y - radius,
        center_x + radius,
        center_y + radius
    ]
    
    # Inner circle (offset to create crescent)
    offset = radius * 0.3
    inner_center_x = center_x + offset * math.cos(math.radians(rotation))
    inner_center_y = center_y + offset * math.sin(math.radians(rotation))
    inner_bbox = [
        inner_center_x - radius * 0.85,
        inner_center_y - radius * 0.85,
        inner_center_x + radius * 0.85,
        inner_center_y + radius * 0.85
    ]
    
    # Draw outer glow (soft white/purple glow around moon)
    glow_radius = int(radius * 1.15)
    glow_bbox = [
        center_x - glow_radius,
        center_y - glow_radius,
        center_x + glow_radius,
        center_y + glow_radius
    ]
    # Create glow with semi-transparent white
    glow_color = (255, 255, 255, 40)  # Semi-transparent white
    if img.mode != 'RGBA':
        img = img.convert('RGBA')
    glow_draw = ImageDraw.Draw(img, 'RGBA')
    glow_draw.ellipse(glow_bbox, fill=glow_color)
    
    # Draw outer circle (moon body)
    moon_color = hex_to_rgb(PRIMARY_BLUE)
    draw.ellipse(outer_bbox, fill=moon_color)
    
    # Add inner shadow for depth (darker area on inner edge)
    shadow_offset = int(radius * 0.1)
    shadow_bbox = [
        inner_center_x - radius * 0.85 + shadow_offset,
        inner_center_y - radius * 0.85 + shadow_offset,
        inner_center_x + radius * 0.85 - shadow_offset,
        inner_center_y + radius * 0.85 - shadow_offset
    ]
    shadow_color = tuple(max(0, c - 30) for c in moon_color)  # Darker version
    draw.ellipse(shadow_bbox, fill=shadow_color)
    
    # Draw inner circle to create crescent (using background color)
    draw.ellipse(inner_bbox, fill=hex_to_rgb(BACKGROUND))
    
    # Add subtle highlight on moon edge (top-right area)
    highlight_angle = math.radians(rotation + 45)
    highlight_x = center_x + radius * 0.6 * math.cos(highlight_angle)
    highlight_y = center_y + radius * 0.6 * math.sin(highlight_angle)
    highlight_size = max(2, radius // 8)
    highlight_bbox = [
        highlight_x - highlight_size,
        highlight_y - highlight_size,
        highlight_x + highlight_size,
        highlight_y + highlight_size
    ]
    highlight_color = (255, 255, 255, 80)  # Semi-transparent white highlight
    glow_draw.ellipse(highlight_bbox, fill=highlight_color)
    
    return img

def draw_star(draw, img, x, y, size, color, icon_size=512):
    """Draw a star with subtle glow effects, optimized for small sizes."""
    # Make stars larger at small sizes for better visibility
    size_multiplier = 1.3 if icon_size < 64 else 1.0
    size = int(size * size_multiplier)
    
    points = []
    for i in range(5):
        angle = math.radians(i * 72 - 90)
        outer_x = x + size * math.cos(angle)
        outer_y = y + size * math.sin(angle)
        points.append((outer_x, outer_y))
        
        angle = math.radians(i * 72 - 90 + 36)
        inner_x = x + size * 0.4 * math.cos(angle)
        inner_y = y + size * 0.4 * math.sin(angle)
        points.append((inner_x, inner_y))
    
    # Add subtle glow around star
    if img.mode != 'RGBA':
        img = img.convert('RGBA')
    glow_draw = ImageDraw.Draw(img, 'RGBA')
    glow_size = int(size * 1.3)
    glow_bbox = [
        x - glow_size,
        y - glow_size,
        x + glow_size,
        y + glow_size
    ]
    glow_color = (*color, 30)  # Semi-transparent glow
    glow_draw.ellipse(glow_bbox, fill=glow_color)
    
    # Draw star
    draw.polygon(points, fill=color)
    
    return img

def draw_sparkle(draw, img, x, y, size, color, icon_size=512):
    """Draw a sparkle with glow effects, optimized for different icon sizes."""
    # Optimize sparkle sizes for different icon sizes (larger at small sizes)
    if icon_size < 64:
        size = int(size * 1.4)  # Larger at small sizes
    elif icon_size < 128:
        size = int(size * 1.2)
    
    # Add subtle glow around sparkle
    if img.mode != 'RGBA':
        img = img.convert('RGBA')
    glow_draw = ImageDraw.Draw(img, 'RGBA')
    glow_size = int(size * 1.2)
    glow_bbox = [
        x - glow_size,
        y - glow_size,
        x + glow_size,
        y + glow_size
    ]
    glow_color = (*color, 25)  # Semi-transparent glow
    glow_draw.ellipse(glow_bbox, fill=glow_color)
    
    # Draw 4 diagonal lines forming a star (not a cross)
    line_width = max(1, size // 8)
    # Top-left to bottom-right
    draw.line([(x - size * 0.7, y - size * 0.7), (x + size * 0.7, y + size * 0.7)], 
              fill=color, width=line_width)
    # Top-right to bottom-left
    draw.line([(x + size * 0.7, y - size * 0.7), (x - size * 0.7, y + size * 0.7)], 
              fill=color, width=line_width)
    # Small dots at the 4 diagonal points
    dot_size = max(2, size // 5)
    draw.ellipse([x - size * 0.7 - dot_size, y - size * 0.7 - dot_size, 
                  x - size * 0.7 + dot_size, y - size * 0.7 + dot_size], fill=color)
    draw.ellipse([x + size * 0.7 - dot_size, y - size * 0.7 - dot_size, 
                  x + size * 0.7 + dot_size, y - size * 0.7 + dot_size], fill=color)
    draw.ellipse([x - size * 0.7 - dot_size, y + size * 0.7 - dot_size, 
                  x - size * 0.7 + dot_size, y + size * 0.7 + dot_size], fill=color)
    draw.ellipse([x + size * 0.7 - dot_size, y + size * 0.7 - dot_size, 
                  x + size * 0.7 + dot_size, y + size * 0.7 + dot_size], fill=color)
    
    return img

def create_app_icon(size):
    """Create the Dream Flow app icon with enhanced polish and effects."""
    # Create base with enhanced gradient
    img = create_gradient_background(
        (size, size),
        PRIMARY_PURPLE,
        PRIMARY_BLUE
    )
    
    # Convert to RGBA for transparency effects
    if img.mode != 'RGBA':
        img = img.convert('RGBA')
    
    draw = ImageDraw.Draw(img, 'RGBA')
    
    center_x, center_y = size // 2, size // 2
    
    # Draw crescent moon (main element) with enhancements
    moon_radius = int(size * 0.35)
    img = draw_crescent_moon(draw, img, center_x, center_y, moon_radius, rotation=-20, icon_size=size)
    draw = ImageDraw.Draw(img, 'RGBA')
    
    # Add sparkles around the moon (AI/magic element) with better positioning
    # More balanced distribution around moon
    sparkle_positions = [
        (center_x - moon_radius * 0.65, center_y - moon_radius * 0.85, size * 0.08),
        (center_x + moon_radius * 0.75, center_y - moon_radius * 0.55, size * 0.07),
        (center_x - moon_radius * 0.55, center_y + moon_radius * 0.75, size * 0.08),
        (center_x + moon_radius * 0.85, center_y + moon_radius * 0.45, size * 0.06),
    ]
    
    for x, y, sparkle_size in sparkle_positions:
        img = draw_sparkle(draw, img, int(x), int(y), int(sparkle_size), hex_to_rgb("#FFFFFF"), icon_size=size)
        draw = ImageDraw.Draw(img, 'RGBA')
    
    # Add stars (dream elements) - reduced to 2 for clarity, larger at small sizes
    star_count = 2 if size < 128 else 3
    star_positions = [
        (center_x - moon_radius * 1.2, center_y - moon_radius * 0.3, size * 0.035),
        (center_x + moon_radius * 1.1, center_y + moon_radius * 0.2, size * 0.03),
    ]
    if star_count > 2:
        star_positions.append((center_x - moon_radius * 0.2, center_y - moon_radius * 1.1, size * 0.035))
    
    for x, y, star_size in star_positions[:star_count]:
        img = draw_star(draw, img, int(x), int(y), int(star_size), hex_to_rgb("#FFFFFF"), icon_size=size)
        draw = ImageDraw.Draw(img, 'RGBA')
    
    # Add subtle overall glow effect (lighter blur for polish)
    img_rgb = img.convert('RGB')
    img_rgb = img_rgb.filter(ImageFilter.GaussianBlur(radius=max(1, size * 0.015)))
    
    # Re-draw main elements after blur for clarity (on RGB image)
    draw_rgb = ImageDraw.Draw(img_rgb)
    moon_radius = int(size * 0.35)
    size_multiplier = 1.0 if size >= 64 else 1.15
    moon_radius = int(moon_radius * size_multiplier)
    
    # Re-draw moon
    outer_bbox = [
        center_x - moon_radius,
        center_y - moon_radius,
        center_x + moon_radius,
        center_y + moon_radius
    ]
    offset = moon_radius * 0.3
    inner_center_x = center_x + offset * math.cos(math.radians(-20))
    inner_center_y = center_y + offset * math.sin(math.radians(-20))
    inner_bbox = [
        inner_center_x - moon_radius * 0.85,
        inner_center_y - moon_radius * 0.85,
        inner_center_x + moon_radius * 0.85,
        inner_center_y + moon_radius * 0.85
    ]
    draw_rgb.ellipse(outer_bbox, fill=hex_to_rgb(PRIMARY_BLUE))
    draw_rgb.ellipse(inner_bbox, fill=hex_to_rgb(BACKGROUND))
    
    # Re-draw sparkles
    for x, y, sparkle_size in sparkle_positions:
        sparkle_size_adj = int(sparkle_size * (1.4 if size < 64 else 1.2 if size < 128 else 1.0))
        line_width = max(1, sparkle_size_adj // 8)
        draw_rgb.line([(int(x) - sparkle_size_adj * 0.7, int(y) - sparkle_size_adj * 0.7), 
                       (int(x) + sparkle_size_adj * 0.7, int(y) + sparkle_size_adj * 0.7)], 
                      fill="#FFFFFF", width=line_width)
        draw_rgb.line([(int(x) + sparkle_size_adj * 0.7, int(y) - sparkle_size_adj * 0.7), 
                       (int(x) - sparkle_size_adj * 0.7, int(y) + sparkle_size_adj * 0.7)], 
                      fill="#FFFFFF", width=line_width)
        dot_size = max(2, sparkle_size_adj // 5)
        for dx, dy in [(-0.7, -0.7), (0.7, -0.7), (-0.7, 0.7), (0.7, 0.7)]:
            draw_rgb.ellipse([int(x) + sparkle_size_adj * dx - dot_size, 
                             int(y) + sparkle_size_adj * dy - dot_size,
                             int(x) + sparkle_size_adj * dx + dot_size,
                             int(y) + sparkle_size_adj * dy + dot_size], fill="#FFFFFF")
    
    # Re-draw stars
    for x, y, star_size in star_positions[:star_count]:
        star_size_adj = int(star_size * (1.3 if size < 64 else 1.0))
        points = []
        for i in range(5):
            angle = math.radians(i * 72 - 90)
            outer_x = int(x) + star_size_adj * math.cos(angle)
            outer_y = int(y) + star_size_adj * math.sin(angle)
            points.append((outer_x, outer_y))
            angle = math.radians(i * 72 - 90 + 36)
            inner_x = int(x) + star_size_adj * 0.4 * math.cos(angle)
            inner_y = int(y) + star_size_adj * 0.4 * math.sin(angle)
            points.append((inner_x, inner_y))
        draw_rgb.polygon(points, fill="#FFFFFF")
    
    # Add subtle drop shadow to entire icon for depth
    shadow_img = Image.new('RGBA', (size + 4, size + 4), (0, 0, 0, 0))
    shadow_img.paste(img_rgb, (2, 2))
    shadow_img = shadow_img.filter(ImageFilter.GaussianBlur(radius=max(1, size // 64)))
    final_img = Image.new('RGB', (size, size), hex_to_rgb(BACKGROUND))
    final_img.paste(shadow_img, (-2, -2), shadow_img)
    final_img.paste(img_rgb, (0, 0))
    
    return final_img

def generate_ios_icons():
    """Generate iOS app icons."""
    ios_sizes = {
        "Icon-App-20x20@2x.png": 40,
        "Icon-App-20x20@3x.png": 60,
        "Icon-App-29x29@1x.png": 29,
        "Icon-App-29x29@2x.png": 58,
        "Icon-App-29x29@3x.png": 87,
        "Icon-App-40x40@1x.png": 40,
        "Icon-App-40x40@2x.png": 80,
        "Icon-App-40x40@3x.png": 120,
        "Icon-App-60x60@2x.png": 120,
        "Icon-App-60x60@3x.png": 180,
        "Icon-App-76x76@1x.png": 76,
        "Icon-App-76x76@2x.png": 152,
        "Icon-App-83.5x83.5@2x.png": 167,
        "Icon-App-1024x1024@1x.png": 1024,
    }
    
    ios_dir = Path("frontend_flutter/ios/Runner/Assets.xcassets/AppIcon.appiconset")
    ios_dir.mkdir(parents=True, exist_ok=True)
    
    print("Generating iOS icons...")
    for filename, size in ios_sizes.items():
        icon = create_app_icon(size)
        filepath = ios_dir / filename
        icon.save(filepath, "PNG", optimize=True)
        print(f"  [OK] Created: {filepath} ({size}x{size})")

def generate_android_icons():
    """Generate Android app icons."""
    android_sizes = {
        "mipmap-mdpi/ic_launcher.png": 48,
        "mipmap-hdpi/ic_launcher.png": 72,
        "mipmap-xhdpi/ic_launcher.png": 96,
        "mipmap-xxhdpi/ic_launcher.png": 144,
        "mipmap-xxxhdpi/ic_launcher.png": 192,
    }
    
    android_base = Path("frontend_flutter/android/app/src/main/res")
    
    print("Generating Android icons...")
    for rel_path, size in android_sizes.items():
        icon = create_app_icon(size)
        filepath = android_base / rel_path
        filepath.parent.mkdir(parents=True, exist_ok=True)
        icon.save(filepath, "PNG", optimize=True)
        print(f"  [OK] Created: {filepath} ({size}x{size})")
    
    # Also create adaptive icon foreground (1024x1024, will be cropped by system)
    adaptive_dir = android_base / "mipmap-anydpi-v26"
    adaptive_dir.mkdir(parents=True, exist_ok=True)
    icon = create_app_icon(1024)
    icon.save(adaptive_dir / "ic_launcher_foreground.png", "PNG", optimize=True)
    print(f"  [OK] Created: {adaptive_dir / 'ic_launcher_foreground.png'} (1024x1024)")

def generate_web_icons():
    """Generate web app icons."""
    web_sizes = {
        "Icon-192.png": 192,
        "Icon-512.png": 512,
        "Icon-maskable-192.png": 192,
        "Icon-maskable-512.png": 512,
    }
    
    web_dir = Path("frontend_flutter/web/icons")
    web_dir.mkdir(parents=True, exist_ok=True)
    
    print("Generating web icons...")
    for filename, size in web_sizes.items():
        icon = create_app_icon(size)
        filepath = web_dir / filename
        icon.save(filepath, "PNG", optimize=True)
        print(f"  [OK] Created: {filepath} ({size}x{size})")
    
    # Create favicon (32x32)
    favicon = create_app_icon(32)
    favicon_path = Path("frontend_flutter/web/favicon.png")
    favicon.save(favicon_path, "PNG", optimize=True)
    print(f"  [OK] Created: {favicon_path} (32x32)")

def generate_macos_icons():
    """Generate macOS app icons."""
    macos_sizes = {
        "app_icon_16.png": 16,
        "app_icon_32.png": 32,
        "app_icon_64.png": 64,
        "app_icon_128.png": 128,
        "app_icon_256.png": 256,
        "app_icon_512.png": 512,
        "app_icon_1024.png": 1024,
    }
    
    macos_dir = Path("frontend_flutter/macos/Runner/Assets.xcassets/AppIcon.appiconset")
    macos_dir.mkdir(parents=True, exist_ok=True)
    
    print("Generating macOS icons...")
    for filename, size in macos_sizes.items():
        icon = create_app_icon(size)
        filepath = macos_dir / filename
        icon.save(filepath, "PNG", optimize=True)
        print(f"  [OK] Created: {filepath} ({size}x{size})")

def generate_windows_icon():
    """Generate Windows app icon (ICO format)."""
    # Windows needs ICO format with multiple sizes
    from PIL import Image
    
    windows_dir = Path("frontend_flutter/windows/runner/resources")
    windows_dir.mkdir(parents=True, exist_ok=True)
    
    print("Generating Windows icon...")
    # Create multiple sizes for ICO
    sizes = [16, 32, 48, 64, 128, 256]
    icons = []
    for size in sizes:
        icon = create_app_icon(size)
        icons.append(icon)
    
    # Save as ICO (Pillow handles multi-size ICO)
    ico_path = windows_dir / "app_icon.ico"
    icons[0].save(ico_path, format='ICO', sizes=[(s, s) for s in sizes])
    print(f"  [OK] Created: {ico_path} (multi-size ICO)")

def main():
    """Generate all app icons."""
    print("=" * 60)
    print("Dream Flow - App Icon Generator")
    print("=" * 60)
    print("\nIcon Design:")
    print("  - Stylized crescent moon (sleep/dreams)")
    print("  - Purple to blue gradient (brand colors)")
    print("  - Sparkles and stars (AI generation, magic)")
    print("  - Modern, clean design")
    print("\nGenerating icons for all platforms...\n")
    
    try:
        generate_ios_icons()
        print()
        generate_android_icons()
        print()
        generate_web_icons()
        print()
        generate_macos_icons()
        print()
        generate_windows_icon()
        
        print("\n" + "=" * 60)
        print("[OK] All app icons generated successfully!")
        print("=" * 60)
        print("\nNext steps:")
        print("1. Review the generated icons")
        print("2. Test on devices to ensure they look good")
        print("3. Update app store listings with new icons")
        print("4. Rebuild the app to use new icons")
        
    except Exception as e:
        print(f"\n[ERROR] Failed to generate icons: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main()

