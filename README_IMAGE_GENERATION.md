# Stripe Product Image Generation

## Quick Start

### Option 1: Generate Placeholder Images (Python)

1. **Install Pillow** (if not already installed):
   ```bash
   pip install Pillow
   ```

2. **Run the image generator**:
   ```bash
   python generate_stripe_images.py
   ```

3. **Images will be created in** `stripe_product_images/`:
   - `premium-subscription.png`
   - `premium-subscription-annual.png`
   - `family-subscription.png`
   - `family-subscription-annual.png`

4. **Review and customize**:
   - Images are 512x512px PNG files
   - Under 2MB (typically ~50-100KB)
   - Ready to upload to Stripe
   - You can edit colors in the script to match your brand

### Option 2: Use Design Tools (Recommended for Production)

For professional-looking images, use design tools:

1. **Canva** (Easiest - Free tier available)
   - Go to https://www.canva.com
   - Create custom design (512x512px)
   - Use templates for "Product Badge" or "App Icon"
   - Export as PNG

2. **Figma** (Professional - Free tier available)
   - Create 512x512px frame
   - Design your product badge
   - Export as PNG

3. **Custom Design**
   - Use your app's brand colors
   - Include tier name (Premium/Family)
   - Add key features or value proposition
   - Keep it simple and professional

## Image Requirements

- **Format**: PNG, JPEG, or WEBP
- **Size**: Under 2MB
- **Dimensions**: 512x512px or larger (square)
- **Aspect Ratio**: 1:1 (square)

## Customizing Generated Images

Edit `generate_stripe_images.py` to customize:

1. **Colors**: Change `COLORS` dictionary
   ```python
   COLORS = {
       "premium": {
           "bg": "#YOUR_COLOR",  # Background
           "text": "#FFFFFF",     # Text color
           "accent": "#FFD700"    # Accent color
       },
       ...
   }
   ```

2. **Text**: Modify the `features` strings in `create_product_image()`

3. **Fonts**: Update font paths (currently uses system default)

## Uploading to Stripe

1. Go to Stripe Dashboard → Products
2. Create or edit a product
3. Click "Upload" in the Image section
4. Select your generated image file
5. Save the product

## Notes

- Generated images are placeholders - customize for production
- You can create products in Stripe first and add images later
- Images can be updated anytime in Stripe Dashboard
- Test how images look at checkout before going live

## See Also

- `STRIPE_IMAGE_REQUIREMENTS.md` - Detailed image specifications
- `MANUAL_SETUP_STEPS.md` - Complete Stripe setup guide

