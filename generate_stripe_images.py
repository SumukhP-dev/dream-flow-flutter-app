#!/usr/bin/env python3
"""
Generate placeholder images for Stripe products.

This script creates simple placeholder images that you can use temporarily
or as a base for custom designs. The images are 512x512px PNG files.

Requirements:
    pip install Pillow
"""

from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os
from pathlib import Path
import math

# Create output directory
OUTPUT_DIR = Path("stripe_product_images")
OUTPUT_DIR.mkdir(exist_ok=True)

# Color scheme (matches Dream Flow brand)
COLORS = {
    "premium": {
        "bg": "#8B5CF6",  # Primary Purple (brand color)
        "text": "#FFFFFF",  # White
        "accent": "#3B82F6"  # Primary Blue (brand color)
    },
    "family": {
        "bg": "#3B82F6",  # Primary Blue (brand color)
        "text": "#FFFFFF",  # White
        "accent": "#06B6D4"  # Secondary Cyan (brand color)
    }
}

def hex_to_rgb(hex_color):
    """Convert hex color to RGB tuple."""
    hex_color = hex_color.lstrip('#')
    return tuple(int(hex_color[i:i+2], 16) for i in (0, 2, 4))

def create_gradient_background(size, start_color, end_color):
    """Create a gradient background matching app icon style."""
    img = Image.new('RGB', size, start_color)
    draw = ImageDraw.Draw(img)
    
    width, height = size
    for y in range(height):
        # Calculate color interpolation
        ratio = y / height
        r = int(hex_to_rgb(start_color)[0] * (1 - ratio) + hex_to_rgb(end_color)[0] * ratio)
        g = int(hex_to_rgb(start_color)[1] * (1 - ratio) + hex_to_rgb(end_color)[1] * ratio)
        b = int(hex_to_rgb(start_color)[2] * (1 - ratio) + hex_to_rgb(end_color)[2] * ratio)
        draw.line([(0, y), (width, y)], fill=(r, g, b))
    
    return img

def draw_crescent_moon_simple(draw, center_x, center_y, radius, rotation=0):
    """Draw a simplified crescent moon for product images."""
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
    
    # Draw outer circle (moon)
    draw.ellipse(outer_bbox, fill=hex_to_rgb("#FFFFFF"))
    
    # Draw inner circle to create crescent (using background gradient color)
    draw.ellipse(inner_bbox, fill=hex_to_rgb("#3B82F6"))

def create_product_image(name, tier, is_annual=False):
    """Create a product image for Stripe."""
    # Image dimensions
    size = (512, 512)
    
    # Get colors based on tier
    colors = COLORS.get(tier, COLORS["premium"])
    
    # Create gradient background (matching app icon style)
    img = create_gradient_background(size, colors["bg"], colors["accent"])
    draw = ImageDraw.Draw(img)
    
    # Try to use a nice font, fallback to default
    try:
        # Try to use a system font (adjust path for your OS)
        font_large = ImageFont.truetype("arial.ttf", 60)
        font_medium = ImageFont.truetype("arial.ttf", 40)
        font_small = ImageFont.truetype("arial.ttf", 24)
    except:
        # Fallback to default font
        font_large = ImageFont.load_default()
        font_medium = ImageFont.load_default()
        font_small = ImageFont.load_default()
    
    # Draw main text (tier name) - positioned below icon and badge
    text = name.upper()
    if is_annual:
        text += "\n(ANNUAL)"
    
    # Calculate text position (centered, below icon)
    bbox = draw.textbbox((0, 0), text, font=font_large)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]
    
    x = (size[0] - text_width) // 2
    y = 200  # Position below icon and "NO ADS" badge
    
    # Draw text with outline for better visibility
    outline_width = 2
    for adj in range(-outline_width, outline_width + 1):
        for adj2 in range(-outline_width, outline_width + 1):
            draw.text((x + adj, y + adj2), text, font=font_large, 
                     fill=(0, 0, 0, 128))
    
    draw.text((x, y), text, font=font_large, fill=hex_to_rgb(colors["text"]))
    
    # Draw app icon (crescent moon) at top
    icon_size = 80
    icon_x = size[0] // 2
    icon_y = 80
    moon_radius = icon_size // 2
    draw_crescent_moon_simple(draw, icon_x, icon_y, moon_radius, rotation=-20)
    
    # Add tier-specific features - Highlight "No ads" as primary benefit
    if tier == "premium":
        # Highlight "No ads" as the main differentiator
        primary_feature = "NO ADS"
        secondary_features = "Unlimited Stories\nAll Themes\nOffline Mode"
    else:  # family
        primary_feature = "NO ADS"
        secondary_features = "Up to 5 Members\nChild Profiles\nFamily Analytics"
    
    # Draw "NO ADS" badge prominently
    try:
        font_badge = ImageFont.truetype("arial.ttf", 32)
        font_bold = ImageFont.truetype("arial.ttf", 28)
    except:
        font_badge = ImageFont.load_default()
        font_bold = ImageFont.load_default()
    
    # Calculate badge position (below icon, above tier name)
    bbox_badge = draw.textbbox((0, 0), primary_feature, font=font_badge)
    badge_width = bbox_badge[2] - bbox_badge[0]
    badge_height = bbox_badge[3] - bbox_badge[1]
    badge_x = (size[0] - badge_width) // 2
    badge_y = icon_y + moon_radius + 20
    
    # Draw badge background (rounded rectangle)
    badge_padding = 15
    badge_bg_bbox = [
        badge_x - badge_padding,
        badge_y - badge_padding // 2,
        badge_x + badge_width + badge_padding,
        badge_y + badge_height + badge_padding // 2
    ]
    # Draw badge with glow effect
    try:
        draw.rounded_rectangle(badge_bg_bbox, radius=10, fill=hex_to_rgb("#FFD700"))  # Gold badge
    except AttributeError:
        # Fallback for older Pillow versions
        draw.rectangle(badge_bg_bbox, fill=hex_to_rgb("#FFD700"))  # Gold badge
    # Draw badge text
    draw.text((badge_x, badge_y), primary_feature, font=font_badge, fill=(0, 0, 0))  # Black text on gold
    
    # Draw secondary features below tier name
    bbox_features = draw.textbbox((0, 0), secondary_features, font=font_small)
    features_width = bbox_features[2] - bbox_features[0]
    features_height = bbox_features[3] - bbox_features[1]
    
    x_features = (size[0] - features_width) // 2
    y_features = y + text_height + 20
    
    draw.text((x_features, y_features), secondary_features, font=font_small, 
             fill=hex_to_rgb(colors["text"]))
    
    # Draw annual savings badge if annual
    if is_annual:
        savings_text = "SAVE 33%"
        try:
            font_savings = ImageFont.truetype("arial.ttf", 36)
        except:
            font_savings = ImageFont.load_default()
        
        bbox_savings = draw.textbbox((0, 0), savings_text, font=font_savings)
        savings_width = bbox_savings[2] - bbox_savings[0]
        savings_height = bbox_savings[3] - bbox_savings[1]
        savings_x = (size[0] - savings_width) // 2
        savings_y = y_features + features_height + 25
        
        # Draw savings badge
        savings_padding = 12
        savings_bg_bbox = [
            savings_x - savings_padding,
            savings_y - savings_padding // 2,
            savings_x + savings_width + savings_padding,
            savings_y + savings_height + savings_padding // 2
        ]
        try:
            draw.rounded_rectangle(savings_bg_bbox, radius=8, fill=hex_to_rgb("#16A34A"))  # Green badge
        except AttributeError:
            # Fallback for older Pillow versions
            draw.rectangle(savings_bg_bbox, fill=hex_to_rgb("#16A34A"))  # Green badge
        draw.text((savings_x, savings_y), savings_text, font=font_savings, fill=(255, 255, 255))
    
    # Add subtle decorative sparkles (matching app icon style)
    sparkle_positions = [
        (icon_x - moon_radius * 1.3, icon_y - moon_radius * 0.5, 8),
        (icon_x + moon_radius * 1.3, icon_y - moon_radius * 0.3, 6),
        (icon_x - moon_radius * 0.8, icon_y + moon_radius * 1.2, 7),
    ]
    
    for sx, sy, sparkle_size in sparkle_positions:
        # Draw diagonal sparkle
        draw.line([(int(sx) - sparkle_size, int(sy) - sparkle_size), 
                   (int(sx) + sparkle_size, int(sy) + sparkle_size)], 
                  fill="#FFFFFF", width=2)
        draw.line([(int(sx) + sparkle_size, int(sy) - sparkle_size), 
                   (int(sx) - sparkle_size, int(sy) + sparkle_size)], 
                  fill="#FFFFFF", width=2)
        # Dots at ends
        dot_size = 3
        for dx, dy in [(-1, -1), (1, -1), (-1, 1), (1, 1)]:
            draw.ellipse([int(sx) + sparkle_size * dx - dot_size, 
                         int(sy) + sparkle_size * dy - dot_size,
                         int(sx) + sparkle_size * dx + dot_size,
                         int(sy) + sparkle_size * dy + dot_size], fill="#FFFFFF")
    
    # Save image
    filename = f"{tier}-subscription"
    if is_annual:
        filename += "-annual"
    filename += ".png"
    
    filepath = OUTPUT_DIR / filename
    img.save(filepath, "PNG", optimize=True)
    print(f"[OK] Created: {filepath}")
    
    return filepath

def main():
    """Generate all product images."""
    print("Generating Stripe product images...")
    print("=" * 50)
    
    # Generate Premium images
    create_product_image("Premium", "premium", is_annual=False)
    create_product_image("Premium", "premium", is_annual=True)
    
    # Generate Family images
    create_product_image("Family", "family", is_annual=False)
    create_product_image("Family", "family", is_annual=True)
    
    print("=" * 50)
    print("[OK] All images generated!")
    print(f"\nImages saved to: {OUTPUT_DIR.absolute()}")
    print("\nNext steps:")
    print("1. Review the generated images")
    print("2. Customize colors/branding if needed")
    print("3. Upload to Stripe Dashboard when creating products")
    print("4. Or use as a base for custom designs in Canva/Figma")

if __name__ == "__main__":
    main()

