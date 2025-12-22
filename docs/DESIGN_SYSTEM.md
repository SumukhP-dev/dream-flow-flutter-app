# Dream Flow AI - Complete Design System Documentation

This document provides comprehensive design specifications for the Dream Flow AI consumer app, formatted for easy translation into design tokens (TypeScript constants) for implementation.

---

## 1. Color Palette

### Primary Brand Colors
- **Primary Purple**: `#8B5CF6` (RGB: 139, 92, 246)
- **Primary Blue**: `#3B82F6` (RGB: 59, 130, 246)
- **Secondary Cyan**: `#06B6D4` (RGB: 6, 182, 212)
- **Secondary Sky Blue**: `#0EA5E9` (RGB: 14, 165, 233)

### Background Colors (Dark Mode Only)
- **Background Primary**: `#0A0A0A` (RGB: 10, 10, 10) - Main app background
- **Background Secondary**: `#05020C` (RGB: 5, 2, 12) - Screen backgrounds
- **Background Tertiary**: `#07040F` (RGB: 7, 4, 15) - Gradient end
- **Background Gradient Start**: `#120E2B` (RGB: 18, 14, 43) - Gradient start
- **Surface/Card Background**: `#1A1A1A` (RGB: 26, 26, 26) - Input fields, dialogs
- **Glass Card Background**: `rgba(255, 255, 255, 0.04)` - Glass morphism cards
- **Glass Card Border**: `rgba(255, 255, 255, 0.08)` - Glass card borders

### Text Colors
- **Text Primary**: `#FFFFFF` (RGB: 255, 255, 255) - Main text
- **Text Secondary**: `rgba(255, 255, 255, 0.9)` - Secondary text (90% opacity)
- **Text Tertiary**: `rgba(255, 255, 255, 0.75)` - Tertiary text (75% opacity)
- **Text Quaternary**: `rgba(255, 255, 255, 0.7)` - Quaternary text (70% opacity)
- **Text Disabled**: `rgba(255, 255, 255, 0.6)` - Disabled text (60% opacity)
- **Text Muted**: `rgba(255, 255, 255, 0.65)` - Muted text (65% opacity)
- **Grey Text**: `Colors.grey[400]` - Form labels, helper text

### Border Colors
- **Border Default**: `rgba(255, 255, 255, 0.2)` - Default borders
- **Border Focus**: `#8B5CF6` - Focused input borders
- **Border Error**: `#FF0000` (RGB: 255, 0, 0) - Error state borders
- **Border Subtle**: `rgba(255, 255, 255, 0.1)` - Subtle borders
- **Border Divider**: `rgba(255, 255, 255, 0.1)` - Dividers

### Status Colors
- **Success**: `#16A34A` (RGB: 22, 163, 74) - Success messages, snackbars
- **Error**: `#FF0000` (RGB: 255, 0, 0) - Error states
- **Error Accent**: `Colors.redAccent` - Error accents
- **Warning**: Not explicitly defined (uses error red)
- **Info**: `#3B82F6` (RGB: 59, 130, 246) - Info states (uses primary blue)

### Gradients
- **Primary Gradient** (Logo/Buttons):
  - Start: `#8B5CF6` (Primary Purple)
  - End: `#3B82F6` (Primary Blue)
  - Direction: `topLeft` to `bottomRight`

- **Secondary Gradient** (Header Icons):
  - Start: `#8B5CF6` (Primary Purple)
  - End: `#06B6D4` (Secondary Cyan)
  - Direction: `topLeft` to `bottomRight`

- **Background Gradient** (Home Screen):
  - Start: `#120E2B` (RGB: 18, 14, 43)
  - End: `#07040F` (RGB: 7, 4, 15)
  - Direction: `topCenter` to `bottomCenter`

- **Radial Gradient** (Decorative Orbs):
  - Purple Orb: `#8B5CF6` at 45% opacity, transparent
  - Blue Orb: `#0EA5E9` at 35% opacity, transparent

- **Preset Card Gradient**:
  - Start: `rgba(255, 255, 255, 0.08)`
  - End: `rgba(255, 255, 255, 0.02)`
  - Direction: `topLeft` to `bottomRight`

---

## 2. Typography

### Font Family
- **Primary Font**: System default (Roboto on Android, SF Pro on iOS)
- **Fallback**: Material Design default font stack
- **Font Package**: Uses Flutter's default Material Design fonts

### Font Sizes
- **Display Large**: `57px` (default Material 3)
- **Display Medium**: `45px` (default Material 3)
- **Display Small**: `36px` (default Material 3)
- **Headline Large**: `32px` - App title, major headings
- **Headline Medium**: `28px` (default Material 3)
- **Headline Small**: `24px` (default Material 3)
- **Title Large**: `22px` (default Material 3)
- **Title Medium**: `18px` - Card titles, section headers
- **Title Small**: `16px` - Subsection headers
- **Body Large**: `16px` - Primary body text
- **Body Medium**: `15px` - Secondary body text, story paragraphs
- **Body Small**: `14px` - Helper text, descriptions
- **Label Large**: `14px` - Button labels, form labels
- **Label Medium**: `12px` - Small labels, captions
- **Label Small**: `11px` (default Material 3)

### Font Weights
- **Regular**: `FontWeight.w400` (400) - Body text
- **Medium**: `FontWeight.w500` (500) - Medium emphasis
- **Semi-Bold**: `FontWeight.w600` (600) - Section headers, labels
- **Bold**: `FontWeight.w700` (700) - Card titles, major headings
- **Bold**: `FontWeight.bold` (700) - App title, primary headings

### Line Heights
- **Tight**: `1.2` - Compact text (session cards)
- **Normal**: `1.3` - Preset card descriptions
- **Relaxed**: `1.45` - Story paragraphs, body text
- **Default**: Material Design defaults for other text styles

### Letter Spacing
- Uses Material Design 3 default letter spacing (typically 0px for most text)

### Text Styles by Context

#### Headings
- **App Title**: 
  - Size: `32px`
  - Weight: `bold` (700)
  - Color: `#FFFFFF`
  
- **Card Title**: 
  - Size: `18px`
  - Weight: `700`
  - Color: `#FFFFFF`

- **Section Header**: 
  - Size: `16px`
  - Weight: `600`
  - Color: `rgba(255, 255, 255, 0.9)`

#### Body Text
- **Primary Body**: 
  - Size: `16px`
  - Weight: `400`
  - Color: `#FFFFFF` or `rgba(255, 255, 255, 0.9)`
  
- **Secondary Body**: 
  - Size: `15px`
  - Weight: `400`
  - Color: `rgba(255, 255, 255, 0.9)`
  - Line Height: `1.45`

- **Helper Text**: 
  - Size: `14px`
  - Weight: `400`
  - Color: `rgba(255, 255, 255, 0.65)`

#### Labels
- **Form Label**: 
  - Size: `14px`
  - Weight: `400`
  - Color: `rgba(255, 255, 255, 0.8)` or `Colors.grey[400]`

- **Caption**: 
  - Size: `12px`
  - Weight: `400`
  - Color: `rgba(255, 255, 255, 0.6)`

#### Buttons
- **Button Text**: 
  - Size: `16px`
  - Weight: `bold` (700) for primary, `600` for secondary
  - Color: `#FFFFFF`

---

## 3. Spacing & Layout

### Base Spacing Unit
- **Base Unit**: `4px` (implicit, not explicitly defined)
- **Common Multipliers**: 2x, 3x, 4x, 5x, 6x, 8x, 10x, 12x, 16x, 20x, 24x, 32x, 40x, 48x

### Common Spacing Values
- **XS**: `4px` - Minimal spacing
- **S**: `8px` - Small spacing
- **M**: `12px` - Medium spacing
- **L**: `16px` - Large spacing (most common)
- **XL**: `20px` - Extra large spacing
- **XXL**: `24px` - Section spacing
- **XXXL**: `32px` - Major section spacing
- **XXXXL**: `40px` - Screen edge spacing
- **XXXXXL**: `48px` - Large section spacing

### Padding Values
- **Screen Padding**: `20px` - Standard screen padding
- **Card Padding**: `20px` - Standard card internal padding
- **Input Padding**: `16px` vertical, `12px` horizontal - Text field padding
- **Button Padding**: `16px` vertical, `24px` horizontal - Button padding
- **Small Card Padding**: `16px` - Compact cards
- **Icon Padding**: `12px` horizontal, `6px` vertical - Badge/pill padding

### Margin Values
- **Element Spacing**: `16px` - Between related elements
- **Section Spacing**: `24px` - Between major sections
- **Card Spacing**: `16px` - Between cards
- **List Item Spacing**: `14px` - Between list items
- **Large Section Spacing**: `40px` - Bottom of screen padding

### Border Radius Values
- **Small**: `12px` - Input fields, small buttons
- **Medium**: `16px` - Buttons, text fields
- **Large**: `18px` - Icon containers, small cards
- **XL**: `20px` - Logo containers, featured elements
- **XXL**: `22px` - Preset cards
- **XXXL**: `24px` - Glass cards, major containers
- **Pill**: `999px` (fully rounded) - Badges, pills, switches

### Container Max-Widths
- Not explicitly defined (full-width on mobile)

### Grid System
- Not using explicit grid system
- Uses Flutter's `Row`, `Column`, and `Wrap` widgets
- Responsive breakpoints handled by Flutter's adaptive layouts

---

## 4. UI Components

### Button Styles

#### Primary Button (ElevatedButton)
- **Background**: `#8B5CF6` (Primary Purple)
- **Foreground**: `#FFFFFF`
- **Padding**: `16px` vertical, `24px` horizontal (symmetric)
- **Border Radius**: `12px` (small), `16px` (large)
- **Elevation**: `8px`
- **Shadow Color**: `#8B5CF6` at 30% opacity
- **Font Size**: `16px`
- **Font Weight**: `bold` (700)
- **Min Height**: `56px` (for large buttons)
- **States**:
  - **Enabled**: Full opacity
  - **Disabled**: Reduced opacity (handled by Flutter)
  - **Loading**: Shows `CircularProgressIndicator` (20x20px, white, strokeWidth: 2)

#### Secondary Button (OutlinedButton)
- **Background**: `rgba(255, 255, 255, 0.02)` or transparent
- **Foreground**: `rgba(255, 255, 255, 0.9)` or `Colors.grey[400]`
- **Border**: `rgba(255, 255, 255, 0.2)` or `Colors.grey[600]`
- **Border Width**: `1px`
- **Padding**: `16px` vertical, `12px` horizontal
- **Border Radius**: `12px`
- **Font Size**: `16px`
- **Font Weight**: `500` or `600`

#### Text Button
- **Foreground**: `#8B5CF6` (Primary Purple)
- **Font Size**: `14px`
- **Font Weight**: `bold` (700)
- **No background or border**

#### Icon Button (Asset Actions)
- **Width**: `185px` (fixed)
- **Background**: `rgba(255, 255, 255, 0.02)`
- **Border**: `rgba(255, 255, 255, 0.2)`
- **Padding**: `12px` horizontal, `14px` vertical
- **Icon Size**: `20px`
- **Font Size**: `13px`
- **Font Weight**: `600`

### Input Field Styles

#### Text Input (TextFormField/TextField)
- **Background**: `#1A1A1A` (filled) or `rgba(255, 255, 255, 0.04)` (glass)
- **Text Color**: `#FFFFFF`
- **Label Color**: `rgba(255, 255, 255, 0.8)` or `Colors.grey[400]`
- **Border Radius**: `12px` (standard), `16px` (glass style)
- **Border Width**: `2px` (focused), `1px` (enabled)
- **Border Colors**:
  - **Default**: `rgba(255, 255, 255, 0.2)` or `Colors.grey[800]`
  - **Focused**: `#8B5CF6` (Primary Purple)
  - **Error**: `#FF0000` (Red)
- **Padding**: `16px` internal padding
- **Icon Color**: `Colors.grey[400]` or `rgba(255, 255, 255, 0.7)`
- **Icon Size**: `20px` (prefix/suffix)

#### Dropdown (DropdownButtonFormField)
- **Background**: `#1E1B2E` (dropdown menu)
- **Text Color**: `#FFFFFF`
- **Label Color**: `rgba(255, 255, 255, 0.8)`
- **Border Radius**: `12px`
- **Border**: `rgba(255, 255, 255, 0.2)` (enabled), `#8B5CF6` (focused)

#### Checkbox
- **Active Color**: `#8B5CF6` (Primary Purple)
- **Check Color**: `#FFFFFF`

#### Slider
- **Active Color**: `#8B5CF6` (Primary Purple)
- **Inactive Color**: `rgba(255, 255, 255, 0.2)`
- **Thumb Color**: `#8B5CF6`

#### Switch
- **Active Thumb**: `#FFFFFF`
- **Active Track**: `rgba(255, 255, 255, 0.5)`
- **Inactive Thumb**: `Colors.grey[400]`
- **Inactive Track**: `rgba(255, 255, 255, 0.2)`

### Card/Container Styles

#### Glass Card (Primary Card Style)
- **Background**: `rgba(255, 255, 255, 0.04)`
- **Border**: `rgba(255, 255, 255, 0.08)`
- **Border Radius**: `24px`
- **Padding**: `20px`
- **Shadow**: 
  - Color: `rgba(0, 0, 0, 0.2)`
  - Blur: `20px`
  - Offset: `(0, 10)`

#### Preset Card
- **Background**: Gradient from `rgba(255, 255, 255, 0.08)` to `rgba(255, 255, 255, 0.02)`
- **Border**: `rgba(255, 255, 255, 0.08)`
- **Border Radius**: `22px`
- **Padding**: `16px`
- **Width**: `220px` (fixed)
- **Height**: `170px` (featured), `140px` (session cards)

#### Session Card
- **Background**: Gradient from `rgba(255, 255, 255, 0.08)` to `rgba(255, 255, 255, 0.02)`
- **Border**: `rgba(255, 255, 255, 0.08)`
- **Border Radius**: `20px`
- **Width**: `160px` (fixed)
- **Height**: `140px` (fixed)

#### Video Card
- **Border Radius**: `24px`
- **Shadow**: 
  - Color: `rgba(0, 0, 0, 0.3)`
  - Blur: `25px`
  - Offset: `(0, 16)`
- **Aspect Ratio**: `16:9`

### Modal/Dialog Styles

#### Alert Dialog
- **Background**: `#1A1A1A`
- **Title Color**: `#FFFFFF`
- **Content Color**: `Colors.grey` or `rgba(255, 255, 255, 0.7)`
- **Action Button Color**: `Colors.blue` or `#8B5CF6`

### Navigation Patterns

#### AppBar
- **Background**: Transparent
- **Elevation**: `0`
- **Foreground Color**: `#FFFFFF`
- **Title Font Weight**: `bold` (700)

#### Bottom Navigation
- Not currently implemented (uses AppBar navigation)

#### Tabs
- Not currently implemented

### Loading States and Animations

#### CircularProgressIndicator
- **Color**: `#FFFFFF`
- **Stroke Width**: `2px`
- **Size**: `20px` (small), `32px` (default)

#### LinearProgressIndicator
- **Color**: `#FFFFFF`
- **Background**: `rgba(255, 255, 255, 0.15)`

#### Loading States
- **Button Loading**: `20x20px` CircularProgressIndicator
- **Image Loading**: Full-size CircularProgressIndicator with `strokeWidth: 2`
- **Video Loading**: Full-size CircularProgressIndicator

### Empty States

#### Video Error Placeholder
- **Background**: Gradient from purple/blue to black
- **Icon**: `Icons.videocam_off_rounded`, `64px`, `Colors.white70`
- **Title**: `20px`, `FontWeight.w600`, `#FFFFFF`
- **Message**: `14px`, `rgba(255, 255, 255, 0.7)`
- **Retry Button**: OutlinedButton style with white border

#### Image Error Placeholder
- **Background**: `rgba(255, 255, 255, 0.05)`
- **Icon**: `Icons.broken_image`, `Colors.white54`

### Choice Chips
- **Background (Unselected)**: `rgba(255, 255, 255, 0.05)`
- **Background (Selected)**: `#8B5CF6` (Primary Purple)
- **Text Color (Unselected)**: `rgba(255, 255, 255, 0.7)`
- **Text Color (Selected)**: `#FFFFFF`
- **Border Radius**: `18px` (implicit from chip style)
- **Padding**: `12px` horizontal, `16px` vertical (implicit)

### Badges/Pills
- **Background**: `rgba(255, 255, 255, 0.1)`
- **Border Radius**: `999px` (fully rounded)
- **Padding**: `12px` horizontal, `6px` vertical
- **Font Size**: `12px`
- **Font Weight**: `500`
- **Text Color**: `#FFFFFF`

### Snackbar
- **Success Background**: `#16A34A` (Green)
- **Error Background**: `Colors.redAccent`
- **Text Color**: `#FFFFFF`
- **Action Color**: `#FFFFFF`

---

## 5. Icons & Imagery

### Icon Style
- **Library**: Material Icons (Flutter's default)
- **Style**: Outlined and filled variants
- **Primary Style**: Rounded variants (`_rounded` suffix)

### Icon Sizes
- **XS**: `16px` - Small icons, badges
- **S**: `18px` - Compact icons
- **M**: `20px` - Standard icons (most common)
- **L**: `24px` - Medium icons
- **XL**: `32px` - Large icons, header icons
- **XXL**: `40px` - Logo icons
- **XXXL**: `64px` - Error placeholders

### Common Icons Used
- `Icons.auto_awesome` / `Icons.auto_awesome_rounded` - Logo, magic
- `Icons.auto_fix_high_rounded` - Header icon
- `Icons.auto_stories` - Story-related
- `Icons.email_outlined` - Email input
- `Icons.lock_outlined` - Password input
- `Icons.person_outlined` - User input
- `Icons.visibility` / `Icons.visibility_off` - Password toggle
- `Icons.psychology` - Focus category
- `Icons.family_restroom` - Family category
- `Icons.spa` - Unwind category
- `Icons.download_rounded` - Download actions
- `Icons.share_rounded` - Share actions
- `Icons.videocam_off_rounded` - Video error
- `Icons.broken_image` - Image error
- `Icons.play_circle_fill` / `Icons.pause_circle_filled` - Audio controls
- `Icons.spatial_audio_off` - Audio icon
- `Icons.cloud_download_outlined` - Offline mode
- `Icons.shield_moon` - Guardrails badge

### Image Treatment
- **Border Radius**: `18px` (frames gallery), `20px` (session cards)
- **Aspect Ratio**: `16:9` (video), variable (images)
- **Fit**: `BoxFit.cover` - Images fill container while maintaining aspect ratio
- **Placeholder**: Gradient background with emoji or loading indicator

### Illustration Style
- **Primary**: Emoji-based (🌿, 💧, 🪨, 🔥, 🏕️, 📚, 🌊, ✨, 🌲, 🌌, 🌙, ⭐, 💤, 🪄)
- **Size**: `24px` (preset cards), `32px` (thumbnails), `18px` (theme selector)
- **Usage**: Theme representation, visual identity

---

## 6. Visual Effects

### Shadow/Elevation Styles

#### Button Shadows
- **Primary Button**:
  - Color: `#8B5CF6` at 30% opacity
  - Blur: `20px`
  - Offset: `(0, 10)`
  - Elevation: `8px`

#### Card Shadows
- **Glass Card**:
  - Color: `rgba(0, 0, 0, 0.2)`
  - Blur: `20px`
  - Offset: `(0, 10)`

#### Video Card Shadow
- **Color**: `rgba(0, 0, 0, 0.3)`
- **Blur**: `25px`
- **Offset**: `(0, 16)`

#### Logo/Icon Container Shadow
- **Color**: `#8B5CF6` at 40% opacity
- **Blur**: `16px`
- **Offset**: `(0, 6)`

### Blur Effects
- Not explicitly using blur effects (glass morphism achieved with opacity)

### Transitions and Animations

#### Duration
- **Fast**: `150ms` - Quick interactions
- **Standard**: `250ms` - Default transitions
- **Slow**: `300ms` - Complex animations

#### Easing
- Default Material Design easing curves
- `AnimatedContainer` uses default `Curves.easeInOut`

#### Animated Components
- **Theme Selection**: `AnimatedContainer` with `250ms` duration
- **Button States**: Material Design default transitions
- **Loading States**: CircularProgressIndicator animations

### Hover States
- Not applicable (mobile-first design)

### Focus States

#### Input Fields
- **Border Color**: `#8B5CF6` (Primary Purple)
- **Border Width**: `2px`
- **Transition**: Material Design default

#### Buttons
- Material Design default focus states

---

## 7. Brand Identity

### Logo Usage and Variations

#### Logo Container
- **Size**: `80x80px` (login/signup), `64x64px` (header)
- **Border Radius**: `20px` (login/signup), `18px` (header)
- **Background**: Gradient from `#8B5CF6` to `#3B82F6` (login/signup) or `#8B5CF6` to `#06B6D4` (header)
- **Icon**: `Icons.auto_awesome` (40px) or `Icons.auto_fix_high_rounded` (32px)
- **Icon Color**: `#FFFFFF`
- **Shadow**: Purple glow effect

### Brand Voice Reflected in UI Copy

#### Tone
- **Soothing**: "Welcome Back", "Join the dream journey"
- **Empathetic**: "Weaves your mood, rituals, and cozy anchors into the narrative"
- **Imaginative**: "Summoning your dream...", "Featured worlds"
- **Bedtime-Safe**: "Soothing-mode guardrails active", "Nightly arc"

#### Common Phrases
- "Dream Flow" - App name
- "Welcome Back" - Login greeting
- "Create Account" - Signup heading
- "Story Seed" - Prompt section
- "Evening Profile" - User profile section
- "Featured worlds" - Theme showcase
- "Recent sessions" - History section
- "Generate Nightly Story" - Primary CTA
- "Summoning your dream..." - Loading state
- "Nightly arc" - Session badge
- "Soothing-mode guardrails active" - Safety badge

### Overall Mood/Aesthetic
- **Calming**: Dark backgrounds, soft gradients, gentle transitions
- **Minimal**: Clean layouts, ample whitespace, focused content
- **Dreamy**: Purple/blue color scheme, soft glows, ethereal gradients
- **Cozy**: Warm language, personalization focus, bedtime-safe content

### Visual Metaphors or Patterns

#### Decorative Elements
- **Radial Gradients**: Purple and blue orbs in background (home screen)
- **Linear Gradients**: Card backgrounds, logo containers
- **Glass Morphism**: Translucent cards with subtle borders
- **Emoji Icons**: Nature and calming elements (🌿, 💧, 🌊, ✨)

#### Patterns
- **Layered Backgrounds**: Gradient base with decorative orbs
- **Card-Based Layout**: Information organized in glass cards
- **Horizontal Scrolling**: Featured worlds and recent sessions
- **Progressive Disclosure**: Collapsible sections, expandable content

---

## 8. Platform-Specific Considerations

### iOS-Specific Design Patterns
- **Switch Style**: Uses `Switch.adaptive` which adapts to iOS style
- **Navigation**: Standard iOS navigation patterns via Flutter
- **Safe Areas**: Uses `SafeArea` widget for notch/status bar handling
- **Font**: Uses SF Pro (system default)

### Android-Specific Design Patterns
- **Material Design 3**: Uses Material 3 design system (`useMaterial3: true`)
- **Navigation**: Standard Android navigation patterns via Flutter
- **Font**: Uses Roboto (system default)
- **Back Button**: Handled by Flutter's AppBar

### Web-Specific Adaptations
- Not explicitly implemented (Flutter web support available but not customized)

### Responsive Breakpoints (Web)
- Not explicitly defined (mobile-first design, would need breakpoints for web)

### Accessibility Features
- **High Contrast Mode**: Available via `AccessibilityService`
  - Black/white color scheme
  - High contrast borders and text
- **Font Scaling**: Available via `AccessibilityService`
  - Range: `0.8x` to `2.0x` (80% to 200%)
  - Default: `1.0x` (100%)
  - Applied to all text styles
- **Semantic Labels**: Uses `Semantics` widget for screen readers
- **Text Scalability**: Uses `TextScaler.linear()` for system font scaling

---

## Design Tokens Summary (TypeScript-Ready Format)

```typescript
// Colors
export const colors = {
  primary: {
    purple: '#8B5CF6',
    blue: '#3B82F6',
  },
  secondary: {
    cyan: '#06B6D4',
    skyBlue: '#0EA5E9',
  },
  background: {
    primary: '#0A0A0A',
    secondary: '#05020C',
    tertiary: '#07040F',
    gradientStart: '#120E2B',
    surface: '#1A1A1A',
    glass: 'rgba(255, 255, 255, 0.04)',
  },
  text: {
    primary: '#FFFFFF',
    secondary: 'rgba(255, 255, 255, 0.9)',
    tertiary: 'rgba(255, 255, 255, 0.75)',
    quaternary: 'rgba(255, 255, 255, 0.7)',
    disabled: 'rgba(255, 255, 255, 0.6)',
    muted: 'rgba(255, 255, 255, 0.65)',
    grey: '#BDBDBD', // grey[400]
  },
  border: {
    default: 'rgba(255, 255, 255, 0.2)',
    focus: '#8B5CF6',
    error: '#FF0000',
    subtle: 'rgba(255, 255, 255, 0.1)',
  },
  status: {
    success: '#16A34A',
    error: '#FF0000',
    errorAccent: '#FF5252', // redAccent
    info: '#3B82F6',
  },
};

// Typography
export const typography = {
  fontFamily: {
    primary: 'System Default', // Roboto (Android), SF Pro (iOS)
  },
  fontSize: {
    displayLarge: 57,
    displayMedium: 45,
    displaySmall: 36,
    headlineLarge: 32,
    headlineMedium: 28,
    headlineSmall: 24,
    titleLarge: 22,
    titleMedium: 18,
    titleSmall: 16,
    bodyLarge: 16,
    bodyMedium: 15,
    bodySmall: 14,
    labelLarge: 14,
    labelMedium: 12,
    labelSmall: 11,
  },
  fontWeight: {
    regular: 400,
    medium: 500,
    semiBold: 600,
    bold: 700,
  },
  lineHeight: {
    tight: 1.2,
    normal: 1.3,
    relaxed: 1.45,
  },
};

// Spacing
export const spacing = {
  xs: 4,
  s: 8,
  m: 12,
  l: 16,
  xl: 20,
  xxl: 24,
  xxxl: 32,
  xxxxl: 40,
  xxxxxl: 48,
};

// Border Radius
export const borderRadius = {
  small: 12,
  medium: 16,
  large: 18,
  xl: 20,
  xxl: 22,
  xxxl: 24,
  pill: 999,
};

// Shadows
export const shadows = {
  button: {
    color: 'rgba(139, 92, 246, 0.3)',
    blur: 20,
    offset: { x: 0, y: 10 },
    elevation: 8,
  },
  card: {
    color: 'rgba(0, 0, 0, 0.2)',
    blur: 20,
    offset: { x: 0, y: 10 },
  },
  videoCard: {
    color: 'rgba(0, 0, 0, 0.3)',
    blur: 25,
    offset: { x: 0, y: 16 },
  },
  logo: {
    color: 'rgba(139, 92, 246, 0.4)',
    blur: 16,
    offset: { x: 0, y: 6 },
  },
};

// Gradients
export const gradients = {
  primary: {
    start: '#8B5CF6',
    end: '#3B82F6',
    direction: 'topLeft to bottomRight',
  },
  secondary: {
    start: '#8B5CF6',
    end: '#06B6D4',
    direction: 'topLeft to bottomRight',
  },
  background: {
    start: '#120E2B',
    end: '#07040F',
    direction: 'topCenter to bottomCenter',
  },
  presetCard: {
    start: 'rgba(255, 255, 255, 0.08)',
    end: 'rgba(255, 255, 255, 0.02)',
    direction: 'topLeft to bottomRight',
  },
};

// Transitions
export const transitions = {
  fast: 150,
  standard: 250,
  slow: 300,
  easing: 'easeInOut',
};

// Icon Sizes
export const iconSizes = {
  xs: 16,
  s: 18,
  m: 20,
  l: 24,
  xl: 32,
  xxl: 40,
  xxxl: 64,
};
```

---

## Notes for Implementation

1. **Dark Mode Only**: The app currently only supports dark mode. Light mode would require additional color definitions.

2. **Material Design 3**: The app uses Flutter's Material Design 3 (`useMaterial3: true`), which provides modern design patterns.

3. **Accessibility**: The app includes accessibility features (high contrast, font scaling) that modify the base design tokens.

4. **Opacity Values**: Many colors use opacity (alpha) values. These are specified as `rgba()` or `withValues(alpha: X)` in Flutter.

5. **Responsive Design**: The app is mobile-first. Web and tablet breakpoints would need to be defined for responsive layouts.

6. **Brand Colors**: The primary brand colors (purple `#8B5CF6` and blue `#3B82F6`) are used consistently throughout the app for primary actions and branding.

7. **Glass Morphism**: The app uses a glass morphism design pattern with translucent cards (`rgba(255, 255, 255, 0.04)` background, `rgba(255, 255, 255, 0.08)` borders).

8. **Emoji as Icons**: The app uses emoji extensively for theme representation, which is part of the brand identity.

---

**Document Version**: 1.0  
**Last Updated**: Based on current codebase analysis  
**App Version**: 1.0.0+1

