# App Store Setup Guide

This guide walks you through setting up your app for publication on the Apple App Store and Google Play Store.

## Prerequisites

- Apple Developer Account ($99/year) - [Sign up here](https://developer.apple.com/programs/)
- Google Play Developer Account ($25 one-time) - [Sign up here](https://play.google.com/console/signup)
- App Store Connect access
- Google Play Console access

## Step 1: Update Bundle Identifiers

### iOS Bundle Identifier

1. Open `ios/Runner.xcodeproj` in Xcode
2. Select the Runner target
3. Go to "Signing & Capabilities"
4. Update the Bundle Identifier from `com.example.dreamFlow` to your unique identifier (e.g., `com.yourcompany.dreamflow`)
5. This must match your App ID in Apple Developer Portal

**Current placeholder**: `com.example.dreamFlow`  
**Action required**: Update to your unique bundle ID

### Android Package Name

1. Open `android/app/build.gradle.kts`
2. Update `applicationId` from `com.example.dream_flow` to your unique package name (e.g., `com.yourcompany.dreamflow`)
3. This must match your package name in Google Play Console

**Current placeholder**: `com.example.dream_flow`  
**Action required**: Update to your unique package name

## Step 2: Apple App Store Setup

### 2.1 Create App ID

1. Go to [Apple Developer Portal](https://developer.apple.com/account/)
2. Navigate to Certificates, Identifiers & Profiles
3. Click "+" to create a new App ID
4. Enter your bundle identifier (must match iOS bundle ID)
5. Enable required capabilities:
   - Push Notifications
   - In-App Purchase (for subscriptions)
6. Save the App ID

### 2.2 Create App in App Store Connect

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Click "My Apps" → "+" → "New App"
3. Fill in:
   - Platform: iOS
   - Name: Dream Flow
   - Primary Language: English
   - Bundle ID: Select the App ID you created
   - SKU: A unique identifier (e.g., `dreamflow-ios-001`)
4. Click "Create"

### 2.3 Configure In-App Purchases

1. In App Store Connect, go to your app → Features → In-App Purchases
2. Create two auto-renewable subscriptions:
   - **Premium**: $12/month
     - Product ID: `com.yourcompany.dreamflow.premium`
     - Display Name: Premium
     - Price: $12.00/month
   - **Family**: $18/month
     - Product ID: `com.yourcompany.dreamflow.family`
     - Display Name: Family
     - Price: $18.00/month

### 2.4 Set Up Code Signing

Follow the Fastlane setup guide in `FASTLANE_SETUP_CHECKLIST.md` to configure code signing with Match.

## Step 3: Google Play Store Setup

### 3.1 Create App in Play Console

1. Go to [Google Play Console](https://play.google.com/console)
2. Click "Create app"
3. Fill in:
   - App name: Dream Flow
   - Default language: English (United States)
   - App or game: App
   - Free or paid: Free (with in-app purchases)
   - Declarations: Accept all required declarations
4. Click "Create app"

### 3.2 Configure In-App Products

1. In Play Console, go to your app → Monetize → Products → Subscriptions
2. Create two subscriptions:
   - **Premium**: $12/month
     - Product ID: `premium_monthly`
     - Name: Premium
     - Billing period: 1 month
     - Price: $12.00
   - **Family**: $18/month
     - Product ID: `family_monthly`
     - Name: Family
     - Billing period: 1 month
     - Price: $18.00

### 3.3 Generate Signing Key

1. Run the following command to generate a keystore:
```bash
keytool -genkey -v -keystore ~/dream-flow-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias dream-flow-key \
  -storepass YOUR_KEYSTORE_PASSWORD \
  -keypass YOUR_KEY_PASSWORD
```

2. **IMPORTANT**: Backup the keystore file securely. You cannot recover it if lost!

3. Update `android/app/build.gradle.kts` with signing configuration (see Fastlane setup guide)

## Step 4: Configure RevenueCat

### 4.1 Create RevenueCat Account

1. Go to [RevenueCat](https://www.revenuecat.com) and create an account
2. Create a new project: "Dream Flow"

### 4.2 Configure Products

1. In RevenueCat dashboard, go to Products
2. Add products matching your App Store/Play Store subscriptions:
   - Premium: Link to App Store and Play Store premium products
   - Family: Link to App Store and Play Store family products

### 4.3 Get API Key

1. In RevenueCat dashboard, go to API Keys
2. Copy your public API key
3. Add to Flutter app environment variables:
   ```bash
   flutter run --dart-define=REVENUECAT_API_KEY=your_api_key_here
   ```

## Step 5: Configure Stripe (for Web)

### 5.1 Create Stripe Account

1. Go to [Stripe](https://stripe.com) and create an account
2. Complete business verification

### 5.2 Create Products

1. In Stripe dashboard, go to Products
2. Create two subscription products:
   - **Premium**: $12/month recurring
   - **Family**: $18/month recurring
3. Note the Price IDs (e.g., `price_xxxxx`)

### 5.3 Configure Webhooks

1. In Stripe dashboard, go to Developers → Webhooks
2. Add endpoint: `https://your-backend-url.com/api/v1/webhooks/stripe`
3. Select events:
   - `customer.subscription.created`
   - `customer.subscription.updated`
   - `customer.subscription.deleted`
   - `invoice.payment_succeeded`
   - `invoice.payment_failed`
4. Copy the webhook signing secret
5. Add to backend environment variables:
   ```bash
   STRIPE_SECRET_KEY=sk_...
   STRIPE_WEBHOOK_SECRET=whsec_...
   ```

### 5.4 Get Publishable Key

1. In Stripe dashboard, go to Developers → API keys
2. Copy your publishable key
3. Add to Flutter app environment variables:
   ```bash
   flutter run --dart-define=STRIPE_PUBLISHABLE_KEY=pk_...
   ```

## Step 6: Update Environment Variables

### Flutter App

Create a `.env` file or use `--dart-define` flags:

```bash
# RevenueCat (Mobile)
REVENUECAT_API_KEY=your_revenuecat_api_key

# Stripe (Web)
STRIPE_PUBLISHABLE_KEY=pk_test_...
STRIPE_PREMIUM_PRICE_ID=price_...
STRIPE_FAMILY_PRICE_ID=price_...

# Backend URL
BACKEND_URL=https://your-backend-url.com
```

### Backend

Add to your backend `.env`:

```bash
# Stripe
STRIPE_SECRET_KEY=sk_...
STRIPE_WEBHOOK_SECRET=whsec_...

# RevenueCat
REVENUECAT_API_KEY=your_revenuecat_api_key
```

## Step 7: Test Purchases

### iOS

1. Use sandbox test accounts in App Store Connect
2. Test purchases in TestFlight builds
3. Verify webhooks are received

### Android

1. Use license testing accounts in Play Console
2. Test purchases in internal testing track
3. Verify webhooks are received

### Web

1. Use Stripe test mode
2. Test with test card: `4242 4242 4242 4242`
3. Verify webhooks are received

## Step 8: Prepare Store Assets

See `STORE_ASSETS_CHECKLIST.md` for required assets:
- App icons (multiple sizes)
- Screenshots (various device sizes)
- App description
- Privacy policy URL
- Support URL

## Next Steps

1. Complete all steps above
2. Run Fastlane setup (see `FASTLANE_SETUP_CHECKLIST.md`)
3. Build and test your app
4. Submit for review

## Troubleshooting

### "Bundle ID not found"
- Ensure App ID is created in Apple Developer Portal
- Verify bundle ID matches exactly

### "Package name already exists"
- Choose a unique package name
- Use reverse domain notation (e.g., `com.yourcompany.appname`)

### "Webhook not receiving events"
- Verify webhook URL is publicly accessible
- Check webhook secret matches
- Review Stripe/RevenueCat webhook logs

### "Payment fails"
- Verify API keys are correct
- Check product IDs match between stores and code
- Ensure test accounts are properly configured

## Support

For issues with:
- **Apple App Store**: [Apple Developer Support](https://developer.apple.com/support/)
- **Google Play**: [Play Console Help](https://support.google.com/googleplay/android-developer)
- **RevenueCat**: [RevenueCat Docs](https://docs.revenuecat.com)
- **Stripe**: [Stripe Support](https://support.stripe.com)

