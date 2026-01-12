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
    
    # Pricing information
    PRICING = {
        "premium": {
            "monthly": "$4.99/mo",
            "annual": "$39.99/year",
            "annual_monthly": "$3.33/mo"
        },
        "family": {
            "monthly": "$10.00/mo",
            "annual": "$79.99/year",
            "annual_monthly": "$6.67/mo"
        }
    }
    
    # Create gradient background (matching app icon style)
    img = create_gradient_background(size, colors["bg"], colors["accent"])
    draw = ImageDraw.Draw(img)
    
    # Try to use a nice font, fallback to default
    try:
        # Try to use a system font (adjust path for your OS)
        font_large = ImageFont.truetype("arial.ttf", 60)
        font_medium = ImageFont.truetype("arial.ttf", 40)
        font_small = ImageFont.truetype("arial.ttf", 24)
        font_price = ImageFont.truetype("arial.ttf", 48)
    except:
        # Fallback to default font
        font_large = ImageFont.load_default()
        font_medium = ImageFont.load_default()
        font_small = ImageFont.load_default()
        font_price = ImageFont.load_default()
    
    # Load and add Dream Flow AI logo at top
    logo_path = Path("dream-flow-app/app/assets/images/app_logo.png")
    logo_loaded = False
    icon_y = 80
    if logo_path.exists():
        try:
            logo = Image.open(logo_path)
            # Resize logo to fit nicely at the top
            logo_size = 120
            logo = logo.resize((logo_size, logo_size), Image.Resampling.LANCZOS)
            
            # Calculate position (centered at top)
            logo_x = (size[0] - logo_size) // 2
            logo_y = 40
            
            # Paste logo onto image (handle transparency if present)
            if logo.mode == 'RGBA':
                img.paste(logo, (logo_x, logo_y), logo)
            else:
                img.paste(logo, (logo_x, logo_y))
            
            logo_loaded = True
            icon_y = logo_y + logo_size + 20  # Position badge below logo
        except Exception as e:
            print(f"[WARNING] Could not load logo: {e}. Using fallback crescent moon.")
            logo_loaded = False
    else:
        print(f"[WARNING] Logo not found at {logo_path}. Using fallback crescent moon.")
        logo_loaded = False
    
    # Fallback to crescent moon if logo not loaded
    if not logo_loaded:
        icon_size = 80
        icon_x = size[0] // 2
        moon_radius = icon_size // 2
        draw_crescent_moon_simple(draw, icon_x, icon_y, moon_radius, rotation=-20)
        icon_y = icon_y + moon_radius + 20
    
    # Add tier-specific features - Highlight "No ads" as primary benefit
    primary_feature = "NO ADS"
    
    # Draw "NO ADS" badge prominently
    try:
        font_badge = ImageFont.truetype("arial.ttf", 32)
        font_bold = ImageFont.truetype("arial.ttf", 28)
    except:
        font_badge = ImageFont.load_default()
        font_bold = ImageFont.load_default()
    
    # Calculate badge position (below logo/icon, above tier name)
    bbox_badge = draw.textbbox((0, 0), primary_feature, font=font_badge)
    badge_width = bbox_badge[2] - bbox_badge[0]
    badge_height = bbox_badge[3] - bbox_badge[1]
    badge_x = (size[0] - badge_width) // 2
    badge_y = icon_y
    
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
    
    # Draw main text (tier name) - positioned lower below NO ADS badge
    text = name.upper()
    if is_annual:
        text += "\n(ANNUAL)"
    
    # Calculate text position (centered, below badge with more spacing)
    bbox = draw.textbbox((0, 0), text, font=font_large)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]
    
    x = (size[0] - text_width) // 2
    y = badge_y + badge_height + badge_padding + 50  # Position lower below "NO ADS" badge (increased spacing from 20 to 50)
    
    # Draw text with outline for better visibility
    outline_width = 2
    for adj in range(-outline_width, outline_width + 1):
        for adj2 in range(-outline_width, outline_width + 1):
            draw.text((x + adj, y + adj2), text, font=font_large, 
                     fill=(0, 0, 0, 128))
    
    draw.text((x, y), text, font=font_large, fill=hex_to_rgb(colors["text"]))
    
    # Draw pricing information prominently
    pricing_info = PRICING.get(tier, PRICING["premium"])
    if is_annual:
        price_text = pricing_info["annual"]
        price_subtext = f"({pricing_info['annual_monthly']})"
    else:
        price_text = pricing_info["monthly"]
        price_subtext = ""
    
    # Draw price
    bbox_price = draw.textbbox((0, 0), price_text, font=font_price)
    price_width = bbox_price[2] - bbox_price[0]
    price_height = bbox_price[3] - bbox_price[1]
    price_x = (size[0] - price_width) // 2
    price_y = y + text_height + 15
    
    # Draw price with outline
    outline_width = 2
    for adj in range(-outline_width, outline_width + 1):
        for adj2 in range(-outline_width, outline_width + 1):
            draw.text((price_x + adj, price_y + adj2), price_text, font=font_price, 
                     fill=(0, 0, 0, 128))
    draw.text((price_x, price_y), price_text, font=font_price, fill=hex_to_rgb("#FFD700"))  # Gold price
    
    # Draw price subtext if annual
    subtext_y = price_y + price_height + 5  # Initialize for family members positioning
    if price_subtext:
        try:
            font_subtext = ImageFont.truetype("arial.ttf", 28)
        except:
            font_subtext = ImageFont.load_default()
        bbox_subtext = draw.textbbox((0, 0), price_subtext, font=font_subtext)
        subtext_width = bbox_subtext[2] - bbox_subtext[0]
        subtext_x = (size[0] - subtext_width) // 2
        subtext_y = price_y + price_height + 5
        draw.text((subtext_x, subtext_y), price_subtext, font=font_subtext, 
                 fill=hex_to_rgb(colors["text"]))
    
    # Add family member count for family tier (positioned below price/subtext)
    if tier == "family":
        family_members_text = "6 FAMILY MEMBERS"
        try:
            font_family = ImageFont.truetype("arial.ttf", 30)
        except:
            font_family = ImageFont.load_default()
        
        bbox_family = draw.textbbox((0, 0), family_members_text, font=font_family)
        family_width = bbox_family[2] - bbox_family[0]
        family_height = bbox_family[3] - bbox_family[1]
        family_x = (size[0] - family_width) // 2
        
        # Position below price (or below price subtext if annual)
        if price_subtext:
            family_y = subtext_y + 25  # Below subtext
        else:
            family_y = price_y + price_height + 20  # Below price
        
        # Draw family members badge
        family_padding = 12
        family_bg_bbox = [
            family_x - family_padding,
            family_y - family_padding // 2,
            family_x + family_width + family_padding,
            family_y + family_height + family_padding // 2
        ]
        try:
            draw.rounded_rectangle(family_bg_bbox, radius=8, fill=hex_to_rgb("#06B6D4"))  # Cyan badge
        except AttributeError:
            draw.rectangle(family_bg_bbox, fill=hex_to_rgb("#06B6D4"))  # Cyan badge
        draw.text((family_x, family_y), family_members_text, font=font_family, fill=(255, 255, 255))  # White text
    
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
        if price_subtext:
            savings_y = subtext_y + bbox_subtext[3] - bbox_subtext[1] + 15
        else:
            savings_y = price_y + price_height + 15
        
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
    # Only add sparkles if we used the fallback crescent moon
    if not logo_loaded:
        icon_x = size[0] // 2
        moon_radius = 40
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

def create_one_time_premium_image():
    """Create a product image for one-time premium purchase (ad-free)."""
    # Image dimensions
    size = (512, 512)
    
    # Use premium colors
    colors = COLORS["premium"]
    
    # Create gradient background (matching app icon style)
    img = create_gradient_background(size, colors["bg"], colors["accent"])
    draw = ImageDraw.Draw(img)
    
    # Try to use a nice font, fallback to default
    try:
        font_large = ImageFont.truetype("arial.ttf", 60)
        font_medium = ImageFont.truetype("arial.ttf", 40)
        font_small = ImageFont.truetype("arial.ttf", 24)
        font_badge = ImageFont.truetype("arial.ttf", 32)
    except:
        font_large = ImageFont.load_default()
        font_medium = ImageFont.load_default()
        font_small = ImageFont.load_default()
        font_badge = ImageFont.load_default()
    
    # Load and add Dream Flow AI logo at top
    logo_path = Path("dream-flow-app/app/assets/images/app_logo.png")
    if logo_path.exists():
        try:
            logo = Image.open(logo_path)
            # Resize logo to fit nicely at the top
            logo_size = 120
            logo = logo.resize((logo_size, logo_size), Image.Resampling.LANCZOS)
            
            # Calculate position (centered at top)
            logo_x = (size[0] - logo_size) // 2
            logo_y = 40
            
            # Paste logo onto image (handle transparency if present)
            if logo.mode == 'RGBA':
                img.paste(logo, (logo_x, logo_y), logo)
            else:
                img.paste(logo, (logo_x, logo_y))
            
            icon_y = logo_y + logo_size + 20  # Position badge below logo
        except Exception as e:
            print(f"[WARNING] Could not load logo: {e}. Using fallback.")
            icon_y = 80
    else:
        print(f"[WARNING] Logo not found at {logo_path}. Using fallback.")
        icon_y = 80
    
    # Draw "NO ADS" badge prominently (below logo)
    primary_feature = "NO ADS"
    bbox_badge = draw.textbbox((0, 0), primary_feature, font=font_badge)
    badge_width = bbox_badge[2] - bbox_badge[0]
    badge_height = bbox_badge[3] - bbox_badge[1]
    badge_x = (size[0] - badge_width) // 2
    badge_y = icon_y + 30  # More space below logo
    
    # Draw badge background (rounded rectangle)
    badge_padding = 15
    badge_bg_bbox = [
        badge_x - badge_padding,
        badge_y - badge_padding // 2,
        badge_x + badge_width + badge_padding,
        badge_y + badge_height + badge_padding // 2
    ]
    try:
        draw.rounded_rectangle(badge_bg_bbox, radius=10, fill=hex_to_rgb("#FFD700"))  # Gold badge
    except AttributeError:
        draw.rectangle(badge_bg_bbox, fill=hex_to_rgb("#FFD700"))  # Gold badge
    draw.text((badge_x, badge_y), primary_feature, font=font_badge, fill=(0, 0, 0))  # Black text on gold
    
    # Draw main text (tier name) - positioned with proper spacing below badge
    text = "PREMIUM"
    bbox = draw.textbbox((0, 0), text, font=font_large)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]
    x = (size[0] - text_width) // 2
    y = badge_y + badge_height + badge_padding + 30  # Position below "NO ADS" badge with spacing
    
    # Draw text with outline for better visibility
    outline_width = 2
    for adj in range(-outline_width, outline_width + 1):
        for adj2 in range(-outline_width, outline_width + 1):
            draw.text((x + adj, y + adj2), text, font=font_large, 
                     fill=(0, 0, 0, 128))
    
    draw.text((x, y), text, font=font_large, fill=hex_to_rgb(colors["text"]))
    
    # Draw "ONE-TIME PURCHASE" badge - positioned with proper spacing
    purchase_text = "ONE-TIME PURCHASE"
    try:
        font_purchase = ImageFont.truetype("arial.ttf", 28)
    except:
        font_purchase = ImageFont.load_default()
    
    bbox_purchase = draw.textbbox((0, 0), purchase_text, font=font_purchase)
    purchase_width = bbox_purchase[2] - bbox_purchase[0]
    purchase_height = bbox_purchase[3] - bbox_purchase[1]
    purchase_x = (size[0] - purchase_width) // 2
    purchase_y = y + text_height + 25  # More spacing below PREMIUM text
    
    # Draw purchase badge background
    purchase_padding = 12
    purchase_bg_bbox = [
        purchase_x - purchase_padding,
        purchase_y - purchase_padding // 2,
        purchase_x + purchase_width + purchase_padding,
        purchase_y + purchase_height + purchase_padding // 2
    ]
    try:
        draw.rounded_rectangle(purchase_bg_bbox, radius=8, fill=hex_to_rgb("#16A34A"))  # Green badge
    except AttributeError:
        draw.rectangle(purchase_bg_bbox, fill=hex_to_rgb("#16A34A"))  # Green badge
    draw.text((purchase_x, purchase_y), purchase_text, font=font_purchase, fill=(255, 255, 255))
    
    # Draw "LIFETIME ACCESS" text - positioned with proper spacing
    lifetime_text = "LIFETIME ACCESS"
    bbox_lifetime = draw.textbbox((0, 0), lifetime_text, font=font_medium)
    lifetime_width = bbox_lifetime[2] - bbox_lifetime[0]
    lifetime_x = (size[0] - lifetime_width) // 2
    lifetime_y = purchase_y + purchase_height + purchase_padding + 25  # More spacing below badge
    
    draw.text((lifetime_x, lifetime_y), lifetime_text, font=font_medium, 
             fill=hex_to_rgb(colors["text"]))
    
    # Save image
    filename = "premium-one-time.png"
    filepath = OUTPUT_DIR / filename
    img.save(filepath, "PNG", optimize=True)
    print(f"[OK] Created: {filepath}")
    
    return filepath

def main():
    """Generate all product images."""
    print("Generating Stripe product images...")
    print("=" * 50)
    
    # Generate Premium images (monthly only)
    create_product_image("Premium", "premium", is_annual=False)
    
    # Generate Family images (monthly only)
    create_product_image("Family", "family", is_annual=False)
    
    # Generate one-time premium purchase image
    create_one_time_premium_image()
    
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

