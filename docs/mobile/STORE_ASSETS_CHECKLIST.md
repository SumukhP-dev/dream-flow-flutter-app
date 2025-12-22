# App Store Assets Checklist

This checklist covers all assets and information needed to publish your app on the App Store and Google Play Store.

## Required Assets

### App Icons

#### iOS
- [ ] 1024x1024px PNG (App Store)
- [ ] 180x180px PNG (iPhone)
- [ ] 120x120px PNG (iPhone)
- [ ] 152x152px PNG (iPad)
- [ ] 167x167px PNG (iPad Pro)

**Location**: `ios/Runner/Assets.xcassets/AppIcon.appiconset/`

#### Android
- [ ] 512x512px PNG (Play Store)
- [ ] 192x192px PNG (mipmap-xxxhdpi)
- [ ] 144x144px PNG (mipmap-xxhdpi)
- [ ] 96x96px PNG (mipmap-xhdpi)
- [ ] 72x72px PNG (mipmap-hdpi)
- [ ] 48x48px PNG (mipmap-mdpi)

**Location**: `android/app/src/main/res/mipmap-*/ic_launcher.png`

**Requirements**:
- No transparency
- No rounded corners (system will add)
- No text or numbers
- Simple, recognizable design
- High contrast

### Screenshots

#### iOS (Required for each device size)
- [ ] iPhone 6.7" (1290x2796px) - 3-10 screenshots
- [ ] iPhone 6.5" (1242x2688px) - 3-10 screenshots
- [ ] iPhone 5.5" (1242x2208px) - 3-10 screenshots
- [ ] iPad Pro 12.9" (2048x2732px) - 3-10 screenshots (optional)

#### Android
- [ ] Phone (1080x1920px minimum) - 2-8 screenshots
- [ ] Tablet (1200x1920px minimum) - 2-8 screenshots (optional)
- [ ] TV (1920x1080px) - 1-8 screenshots (optional)

**Requirements**:
- Show actual app functionality
- No device frames (system will add)
- No text overlays (unless part of UI)
- High quality, clear images
- Show key features

### App Preview Videos (Optional but Recommended)

#### iOS
- [ ] iPhone 6.7" (886x1920px) - 15-30 seconds
- [ ] iPhone 6.5" (886x1920px) - 15-30 seconds

#### Android
- [ ] Phone (1080x1920px) - 30 seconds minimum

**Requirements**:
- Show app in action
- No audio (or royalty-free music)
- High quality, smooth playback
- Show key features

## Required Information

### App Name
- [ ] iOS: Up to 30 characters
- [ ] Android: Up to 50 characters
- [ ] **Suggested**: "Dream Flow" or "Dream Flow - Sleep Stories"

### Subtitle (iOS only)
- [ ] Up to 30 characters
- [ ] **Suggested**: "AI-Powered Bedtime Stories"

### Description

#### Short Description (Android)
- [ ] Up to 80 characters
- [ ] **Suggested**: "AI-generated visual bedtime stories to help you relax and sleep better."

#### Full Description
- [ ] Up to 4000 characters (iOS) / 4000 characters (Android)
- [ ] Include:
  - What the app does
  - Key features
  - Who it's for
  - Benefits
- [ ] **Template**:

```
Dream Flow creates personalized, AI-generated visual bedtime stories to help you relax and fall asleep faster.

KEY FEATURES:
• AI-Generated Stories: Unique stories created just for you based on your mood and preferences
• Visual Experience: Beautiful, calming visuals synchronized with narration
• Personalization: Stories adapt to your profile, mood, and bedtime routine
• Family Mode: Safe, age-appropriate content for children
• Offline Mode: Download stories for offline listening
• Multiple Themes: Choose from various calming worlds and scenarios

PERFECT FOR:
• Adults struggling with sleep
• Parents looking for bedtime stories
• Anyone seeking relaxation and mindfulness

Start your journey to better sleep tonight with Dream Flow.
```

### Keywords (iOS only)
- [ ] Up to 100 characters, comma-separated
- [ ] **Suggested**: "sleep, bedtime, stories, meditation, relaxation, mindfulness, calm, stories for adults"

### Category
- [ ] iOS Primary: Health & Fitness
- [ ] iOS Secondary: Lifestyle
- [ ] Android: Health & Fitness

### Age Rating
- [ ] iOS: Complete questionnaire in App Store Connect
- [ ] Android: Complete content rating questionnaire
- [ ] **Expected**: 4+ (Everyone) or 9+ (with Family Mode)

### Privacy Policy URL
- [ ] **Required**: Must be publicly accessible
- [ ] **Suggested**: `https://yourdomain.com/privacy-policy`
- [ ] Must cover:
  - Data collection
  - Data usage
  - Third-party services (Supabase, Stripe, RevenueCat)
  - User rights

### Support URL
- [ ] **Required**: Must be publicly accessible
- [ ] **Suggested**: `https://yourdomain.com/support` or email: `support@yourdomain.com`

### Marketing URL (Optional)
- [ ] Website or landing page
- [ ] **Suggested**: `https://yourdomain.com`

## App Store Connect Specific

### App Information
- [ ] Copyright: `© 2025 Your Company Name`
- [ ] Trade Representative Contact: Your contact information
- [ ] App Review Information:
  - [ ] Contact email
  - [ ] Phone number
  - [ ] Demo account credentials (if required)
  - [ ] Notes for reviewer

### Pricing and Availability
- [ ] Price: Free (with in-app purchases)
- [ ] Availability: Select countries
- [ ] Release date: Automatic or scheduled

### App Review Notes
- [ ] Explain any special features
- [ ] Provide test account if needed
- [ ] Note any known issues

## Google Play Console Specific

### Store Listing
- [ ] Graphic assets:
  - [ ] Feature graphic (1024x500px)
  - [ ] TV banner (1280x720px, optional)
- [ ] Contact details:
  - [ ] Email
  - [ ] Phone (optional)
  - [ ] Website

### Content Rating
- [ ] Complete IARC questionnaire
- [ ] Get rating certificate

### Data Safety
- [ ] Complete data safety section:
  - [ ] Data collection practices
  - [ ] Data sharing
  - [ ] Security practices

### Target Audience
- [ ] Age group
- [ ] Content guidelines compliance

## Promotional Assets (Optional)

### iOS
- [ ] Promotional text (up to 170 characters)
- [ ] Promotional image (optional)

### Android
- [ ] Short description (up to 80 characters)
- [ ] Feature graphic (1024x500px)

## Localization (Future)

Consider translating for:
- [ ] Spanish
- [ ] French
- [ ] German
- [ ] Japanese

## Checklist Summary

Before submitting:
- [ ] All required screenshots uploaded
- [ ] App icon meets requirements
- [ ] Description is complete and accurate
- [ ] Privacy policy is live and accessible
- [ ] Support contact information is correct
- [ ] Age rating completed
- [ ] In-app purchases configured
- [ ] Test accounts provided (if needed)
- [ ] App complies with store guidelines

## Resources

- [Apple App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Google Play Developer Policy](https://play.google.com/about/developer-content-policy/)
- [App Icon Design Guidelines](https://developer.apple.com/design/human-interface-guidelines/app-icons)
- [Screenshot Guidelines](https://developer.apple.com/app-store/product-page/)

## Tools

- **Screenshot Tools**:
  - iOS: Xcode Simulator, App Store Connect
  - Android: Android Studio Emulator, Play Console
- **Icon Generators**:
  - [AppIcon.co](https://www.appicon.co)
  - [IconKitchen](https://icon.kitchen)
- **Privacy Policy Generators**:
  - [Privacy Policy Generator](https://www.privacypolicygenerator.info)
  - [Termly](https://termly.io)

