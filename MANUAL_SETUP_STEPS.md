# Manual Setup Steps - Complete Checklist

This document outlines all manual steps required to complete the app setup and prepare for publication. Follow these steps in order.

## Prerequisites

- [ ] GitHub repository access
- [ ] Development machine with Flutter SDK installed
- [ ] Backend server access (for environment variables)
- [ ] Email accounts for app store registrations
- [ ] Python 3.7+ installed (for automation script)

---

## Quick Start: Automated Setup

**💡 Time Saver**: Many configuration steps can be automated! See `README_SETUP_AUTOMATION.md` for details.

### ✅ Already Automated (If You Ran the Script)

If you've already run `python setup_automation.py`, the following steps are **COMPLETE**:

- ✅ **Bundle ID/Package Name Updates** (Section 2.2, 3.3)
- ✅ **AdMob Configuration** (Section 1.3, steps 5-6)
- ✅ **Backend .env File Generation** (Section 4.1)
- ✅ **Build Script Generation** (Section 4.2)
- ✅ **Localization Generation** (Section 5.1) - if not skipped

**Generated Files:**

- `backend_fastapi/.env` - Backend environment variables (review and update with real values)
- `frontend_flutter/build.sh` - Flutter build script with all flags (review and update with real values)
- `ios/Runner/Info.plist` - Updated with AdMob App ID
- `android/app/src/main/AndroidManifest.xml` - Updated with AdMob App ID
- `ios/Runner.xcodeproj/project.pbxproj` - Updated bundle ID
- `android/app/build.gradle.kts` - Updated package name

### To Use Automation (If Not Done Yet)

1. **Copy the configuration template:**

   ```bash
   cp config.template.json config.json
   ```

2. **Edit `config.json`** with your actual values (API keys, bundle IDs, etc.)

3. **Run the automation script:**
   ```bash
   python setup_automation.py --config config.json
   ```

This will automatically:

- ✅ Update bundle IDs and package names
- ✅ Configure AdMob in native files
- ✅ Generate `.env` and build scripts
- ✅ Generate Android keystore (optional)
- ✅ Generate localization files

**⚠️ Important**: The automation script handles code/configuration changes. You still need to manually create accounts, configure dashboards, and complete business verification (see sections below).

**📖 For detailed automation guide**: See `README_SETUP_AUTOMATION.md`

---

## Phase 1: Payment Provider Setup

### 1.1 Stripe Setup (for Web Payments)

1. **Create Stripe Account**

   - [ ] Go to [stripe.com](https://stripe.com) and create an account
   - [ ] Complete business verification
   - [ ] Note your account email and business details

2. **Create Subscription Products**

   - [ ] Log into Stripe Dashboard
   - [ ] Navigate to Products → Create Product
   - [ ] Create "Premium" subscription (Monthly):
     - **Name (required)**: Premium
     - **Description**: No ads, unlimited AI-generated bedtime stories, all 20+ themes, offline mode, priority support, and advanced personalization. Perfect for families who want the full Dream Flow experience.
     - **Image**: Upload a high-quality image (JPEG, PNG, or WEBP under 2MB) - App icon or premium tier badge recommended
     - **Product tax code**: Use preset: General - Electronically Supplied Services
     - **Recurring/One-off**: Select Recurring
     - **Amount (required)**: 9.99
     - **Currency**: USD
     - **Include tax in price**: Leave unchecked (tax calculated separately)
     - **Tax behavior**: Auto
     - **Billing period / Price recurring interval**: Monthly
     - Copy the **Price ID** (starts with `price_`)
   - [ ] Create "Premium" subscription (Annual):
     - **Name (required)**: Premium (Annual)
     - **Description**: No ads, unlimited AI-generated bedtime stories, all 20+ themes, offline mode, priority support, and advanced personalization. Save 33% with annual billing - only $6.67/month!
     - **Image**: Same as Premium Monthly (or use annual badge variant)
     - **Product tax code**: Use preset: General - Electronically Supplied Services
     - **Recurring/One-off**: Select Recurring
     - **Amount (required)**: 79.99
     - **Currency**: USD
     - **Include tax in price**: Leave unchecked (tax calculated separately)
     - **Tax behavior**: Auto
     - **Billing period / Price recurring interval**: Yearly (or Annual)
     - Copy the **Price ID** (starts with `price_`)
   - [ ] Create "Family" subscription (Monthly):
     - **Name (required)**: Family
     - **Description**: No ads, everything in Premium, plus up to 5 family members, child profiles with age-appropriate content, family-friendly filters, and family analytics dashboard. Perfect for multi-child households.
     - **Image**: Upload a family-themed image (JPEG, PNG, or WEBP under 2MB) - Family illustration or multi-user badge recommended
     - **Product tax code**: Use preset: General - Electronically Supplied Services
     - **Recurring/One-off**: Select Recurring
     - **Amount (required)**: 14.99
     - **Currency**: USD
     - **Include tax in price**: Leave unchecked (tax calculated separately)
     - **Tax behavior**: Auto
     - **Billing period / Price recurring interval**: Monthly
     - Copy the **Price ID** (starts with `price_`)
   - [ ] Create "Family" subscription (Annual):
     - **Name (required)**: Family (Annual)
     - **Description**: No ads, everything in Premium, plus up to 5 family members, child profiles with age-appropriate content, family-friendly filters, and family analytics dashboard. Save 33% with annual billing - only $10/month!
     - **Image**: Same as Family Monthly (or use annual badge variant)
     - **Product tax code**: Use preset: General - Electronically Supplied Services
     - **Recurring/One-off**: Select Recurring
     - **Amount (required)**: 119.99
     - **Currency**: USD
     - **Include tax in price**: Leave unchecked (tax calculated separately)
     - **Tax behavior**: Auto
     - **Billing period / Price recurring interval**: Yearly (or Annual)
     - Copy the **Price ID** (starts with `price_`)

3. **Get API Keys**

   - [ ] Go to Developers → API keys
   - [ ] Copy your **Publishable key** (starts with `pk_test_` or `pk_live_`)
   - [ ] Copy your **Secret key** (starts with `sk_test_` or `sk_live_`)
   - [ ] **Important**: Use test keys for development, live keys for production

4. **Configure Webhooks**

   - [ ] Go to Developers → Webhooks
   - [ ] Click "Add endpoint"
   - [ ] Endpoint URL: `https://your-backend-url.com/api/v1/webhooks/stripe` (use your Render service URL after deployment - see Section 4.3)
   - [ ] Select events:
     - [ ] `customer.subscription.created`
     - [ ] `customer.subscription.updated`
     - [ ] `customer.subscription.deleted`
     - [ ] `invoice.payment_succeeded`
     - [ ] `invoice.payment_failed`
   - [ ] Click "Add endpoint"
   - [ ] Copy the **Webhook signing secret** (starts with `whsec_`)

5. **Store Stripe Credentials**
   - [ ] Add to backend `.env`:
     ```
     STRIPE_SECRET_KEY=sk_test_...
     STRIPE_WEBHOOK_SECRET=whsec_...
     ```
   - [ ] Add to Flutter build command or CI/CD:
     ```
     --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_...
     --dart-define=STRIPE_PREMIUM_MONTHLY_PRICE_ID=price_...
     --dart-define=STRIPE_PREMIUM_ANNUAL_PRICE_ID=price_...
     --dart-define=STRIPE_FAMILY_MONTHLY_PRICE_ID=price_...
     --dart-define=STRIPE_FAMILY_ANNUAL_PRICE_ID=price_...
     ```

### 1.2 RevenueCat Setup (for Mobile Payments)

1. **Create RevenueCat Account**

   - [ ] Go to [revenuecat.com](https://www.revenuecat.com) and sign up
   - [ ] Complete account setup
   - [ ] Create a new project: "Dream Flow"

2. **Link App Store Connect**

   - [ ] In RevenueCat dashboard, go to Project Settings → Integrations
   - [ ] Click "Connect" for App Store Connect
   - [ ] Follow OAuth flow to authorize RevenueCat
   - [ ] Verify connection is successful

3. **Link Google Play Console**

   - [ ] In RevenueCat dashboard, go to Project Settings → Integrations
   - [ ] Click "Connect" for Google Play
   - [ ] Upload service account JSON key (see Google Play setup section)
   - [ ] Verify connection is successful

4. **Create Products in RevenueCat**

   - [ ] Go to Products in RevenueCat dashboard
   - [ ] Click "Create Product"
   - [ ] Create "Premium" product:
     - Identifier: `premium`
     - Type: Subscription
     - Link to App Store product ID (create in App Store Connect first)
     - Link to Google Play product ID (create in Play Console first)
   - [ ] Create "Family" product:
     - Identifier: `family`
     - Type: Subscription
     - Link to App Store product ID
     - Link to Google Play product ID

5. **Get RevenueCat API Key**

   - [ ] Go to Project Settings → API Keys
   - [ ] Copy your **Public API Key** (starts with `appl_` or `goog_`)
   - [ ] Add to Flutter build command:
     ```
     --dart-define=REVENUECAT_API_KEY=appl_...
     ```

6. **Configure RevenueCat Webhooks**
   - [ ] Go to Project Settings → Integrations → Webhooks
   - [ ] Add webhook URL: `https://your-backend-url.com/api/v1/webhooks/revenuecat` (use your Render service URL after deployment - see Section 4.3)
   - [ ] Select events:
     - [ ] `INITIAL_PURCHASE`
     - [ ] `RENEWAL`
     - [ ] `CANCELLATION`
     - [ ] `UNCANCELLATION`
     - [ ] `BILLING_ISSUE`

### 1.3 AdMob Setup (for Mobile Ads)

1. **Create AdMob Account**

   - [ ] Go to [admob.google.com](https://admob.google.com) and sign in with Google account
   - [ ] Complete account setup and accept terms
   - [ ] Verify payment information (for revenue collection)
   - [ ] Note your AdMob account email

2. **Create App in AdMob**

   - [ ] Go to Apps → Add App
   - [ ] Select "Add your app manually"
   - [ ] App name: Dream Flow
   - [ ] Platform: Select both iOS and Android
   - [ ] App ID (iOS): `com.yourcompany.dreamflow` (must match bundle ID)
   - [ ] Package name (Android): `com.yourcompany.dreamflow` (must match package name)
   - [ ] Click "Add"

3. **Create Ad Units**

   - [ ] Go to Apps → Select your app → Ad units
   - [ ] Create Banner Ad Unit:
     - Name: Dream Flow Banner
     - Format: Banner
     - Copy the **Ad Unit ID** (starts with `ca-app-pub-`)
   - [ ] Create Interstitial Ad Unit:
     - Name: Dream Flow Interstitial
     - Format: Interstitial
     - Copy the **Ad Unit ID** (starts with `ca-app-pub-`)

4. **Get App IDs**

   - [ ] Go to Apps → Select your app
   - [ ] Copy **iOS App ID** (starts with `ca-app-pub-`)
   - [ ] Copy **Android App ID** (starts with `ca-app-pub-`)

5. **Configure iOS App ID**

   **Option A: Automated (Recommended)**

   - [ ] Add iOS App ID to `config.json` under `admob.ios_app_id`
   - [ ] Run `python setup_automation.py` to automatically inject into `Info.plist`

   **Option B: Manual**

   - [ ] Open `ios/Runner/Info.plist`
   - [ ] Add:
     ```xml
     <key>GADApplicationIdentifier</key>
     <string>ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX</string>
     ```
   - [ ] Replace with your iOS App ID

6. **Configure Android App ID**

   **Option A: Automated (Recommended) - ✅ COMPLETE if script was run**

   - [x] Android App ID added to `config.json` under `admob.android_app_id`
   - [x] Script automatically injected into `AndroidManifest.xml`

   **Option B: Manual (Skip if automation was used)**

   - [ ] Open `android/app/src/main/AndroidManifest.xml`
   - [ ] Add inside `<application>` tag:
     ```xml
     <meta-data
         android:name="com.google.android.gms.ads.APPLICATION_ID"
         android:value="ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX"/>
     ```
   - [ ] Replace with your Android App ID

7. **Store Ad Unit IDs**

   - [ ] Add to Flutter build command or CI/CD:
     ```
     --dart-define=ADMOB_BANNER_AD_UNIT_ID=ca-app-pub-...
     --dart-define=ADMOB_INTERSTITIAL_AD_UNIT_ID=ca-app-pub-...
     --dart-define=ADMOB_IOS_APP_ID=ca-app-pub-...
     --dart-define=ADMOB_ANDROID_APP_ID=ca-app-pub-...
     ```

8. **Test Ad Units (Important)**
   - [ ] Use test ad unit IDs during development:
     - iOS Banner: `ca-app-pub-3940256099942544/2934735716`
     - iOS Interstitial: `ca-app-pub-3940256099942544/4411468910`
     - Android Banner: `ca-app-pub-3940256099942544/6300978111`
     - Android Interstitial: `ca-app-pub-3940256099942544/1033173712`
   - [ ] Replace with real ad unit IDs only in production builds

### 1.4 Google AdSense Setup (for Web Ads)

1. **Create AdSense Account**

   - [ ] Go to [adsense.google.com](https://www.google.com/adsense) and sign in
   - [ ] Complete account setup
   - [ ] Verify website ownership (if required)
   - [ ] Wait for account approval (can take 1-2 weeks)

2. **Create Ad Units**

   - [ ] Go to Ads → By ad unit
   - [ ] Click "Create ad unit"
   - [ ] Create Banner Ad:
     - Name: Dream Flow Web Banner
     - Size: Responsive
     - Copy the ad code snippet
   - [ ] Create Display Ad (for interstitial):
     - Name: Dream Flow Web Display
     - Size: Responsive
     - Copy the ad code snippet

3. **Get Publisher ID**

   - [ ] Go to Account → Account information
   - [ ] Copy your **Publisher ID** (starts with `pub-`)

4. **Store AdSense Configuration**
   - [ ] Add to Flutter build command or CI/CD:
     ```
     --dart-define=ADSENSE_PUBLISHER_ID=pub-...
     ```
   - [ ] Store ad code snippets for web implementation

**Note**: AdSense integration for Flutter web requires custom JavaScript implementation in `web/index.html`. This will be handled in the code implementation.

---

## Phase 2: Apple App Store Setup

### 2.1 Apple Developer Account

1. **Enroll in Apple Developer Program**
   - [ ] Go to [developer.apple.com](https://developer.apple.com/programs/)
   - [ ] Click "Enroll"
   - [ ] Complete enrollment process ($99/year)
   - [ ] Wait for approval (usually 24-48 hours)
   - [ ] Note your Apple ID email

### 2.2 Create App ID

1. **Create App Identifier**

   - [ ] Log into [Apple Developer Portal](https://developer.apple.com/account/)
   - [ ] Go to Certificates, Identifiers & Profiles
   - [ ] Click Identifiers → "+" button
   - [ ] Select "App IDs" → Continue
   - [ ] Description: "Dream Flow"
   - [ ] Bundle ID: `com.yourcompany.dreamflow` (replace with your domain)
   - [ ] Enable capabilities:
     - [ ] Push Notifications
     - [ ] In-App Purchase
   - [ ] Click Continue → Register

2. **Update Flutter Bundle ID**

   **Option A: Automated (Recommended) - ✅ COMPLETE if script was run**

   - [x] Bundle ID added to `config.json` and script was run
   - [x] Script automatically updated `project.pbxproj`

   **Option B: Manual (Skip if automation was used)**

   - [ ] Open `ios/Runner.xcodeproj` in Xcode
   - [ ] Select Runner target
   - [ ] Go to "Signing & Capabilities"
   - [ ] Update Bundle Identifier to match App ID created above
   - [ ] Or update in `ios/Runner.xcodeproj/project.pbxproj`:
     ```
     PRODUCT_BUNDLE_IDENTIFIER = com.yourcompany.dreamflow;
     ```

### 2.3 App Store Connect Setup

1. **Create App in App Store Connect**

   - [ ] Go to [App Store Connect](https://appstoreconnect.apple.com)
   - [ ] Click "My Apps" → "+" → "New App"
   - [ ] Fill in:
     - Platform: iOS
     - Name: Dream Flow
     - Primary Language: English (U.S.)
     - Bundle ID: Select the App ID you created
     - SKU: `dreamflow-ios-001` (unique identifier)
   - [ ] Click "Create"

2. **Configure App Information**

   - [ ] Go to App Information
   - [ ] Category: Health & Fitness (Primary), Lifestyle (Secondary)
   - [ ] Content Rights: Check "I have the rights to use this content"
   - [ ] Age Rating: Complete questionnaire (expected: 4+)
   - [ ] Privacy Policy URL: `https://yourdomain.com/privacy-policy`

3. **Create In-App Purchases**
   - [ ] Go to Features → In-App Purchases
   - [ ] Click "+" → Create "Auto-Renewable Subscription"
   - [ ] Create Premium subscription (Monthly):
     - Product ID: `com.yourcompany.dreamflow.premium.monthly`
     - Reference Name: Premium Monthly
     - Subscription Group: Create new group "Dream Flow Subscriptions"
     - Subscription Duration: 1 Month
     - Price: $9.99
     - Localizations: Add English description: "No ads, unlimited AI-generated bedtime stories, all 20+ themes, offline mode, priority support, and advanced personalization."
   - [ ] Create Premium subscription (Annual):
     - Product ID: `com.yourcompany.dreamflow.premium.annual`
     - Reference Name: Premium Annual
     - Subscription Group: Same as Premium Monthly
     - Subscription Duration: 1 Year
     - Price: $79.99
     - Localizations: Add English description: "No ads, unlimited AI-generated bedtime stories, all 20+ themes, offline mode, priority support, and advanced personalization. Save 33% with annual billing!"
   - [ ] Create Family subscription (Monthly):
     - Product ID: `com.yourcompany.dreamflow.family.monthly`
     - Reference Name: Family Monthly
     - Subscription Group: Same as Premium
     - Subscription Duration: 1 Month
     - Price: $14.99
     - Localizations: Add English description: "No ads, everything in Premium, plus up to 5 family members, child profiles with age-appropriate content, family-friendly filters, and family analytics dashboard."
   - [ ] Create Family subscription (Annual):
     - Product ID: `com.yourcompany.dreamflow.family.annual`
     - Reference Name: Family Annual
     - Subscription Group: Same as Premium
     - Subscription Duration: 1 Year
     - Price: $119.99
     - Localizations: Add English description: "No ads, everything in Premium, plus up to 5 family members, child profiles with age-appropriate content, family-friendly filters, and family analytics dashboard. Save 33% with annual billing!"
   - [ ] Submit for review (after app is ready)

### 2.4 Code Signing Setup

1. **Set Up Fastlane Match**

   - [ ] Create a private Git repository for certificates (e.g., `certificates` repo on GitHub)
   - [ ] Update `ios/fastlane/Matchfile`:
     ```ruby
     git_url("https://github.com/your-org/certificates")
     app_identifier("com.yourcompany.dreamflow")
     username("your-apple-id@example.com")
     ```
   - [ ] Run: `cd frontend_flutter/ios && bundle install`
   - [ ] Run: `fastlane match_init`
   - [ ] Enter passphrase (save securely!)
   - [ ] Certificates will be created and stored in Git repo

2. **App Store Connect API Key (Optional but Recommended)**
   - [ ] Go to App Store Connect → Users and Access → Keys
   - [ ] Click "+" to create new key
   - [ ] Name: "Fastlane CI/CD"
   - [ ] Access: App Manager
   - [ ] Download `.p8` key file (can only download once!)
   - [ ] Note Key ID and Issuer ID
   - [ ] Store in CI/CD secrets:
     - `APP_STORE_CONNECT_API_KEY_ID`
     - `APP_STORE_CONNECT_ISSUER_ID`
     - `APP_STORE_CONNECT_API_KEY_CONTENT` (contents of .p8 file)

---

## Phase 3: Google Play Store Setup

### 3.1 Google Play Developer Account

1. **Create Developer Account**
   - [ ] Go to [play.google.com/console](https://play.google.com/console)
   - [ ] Click "Get Started"
   - [ ] Pay one-time $25 registration fee
   - [ ] Complete account setup
   - [ ] Wait for approval (usually 24-48 hours)

### 3.2 Create App in Play Console

1. **Create New App**

   - [ ] Log into Google Play Console
   - [ ] Click "Create app"
   - [ ] Fill in:
     - App name: Dream Flow
     - Default language: English (United States)
     - App or game: App
     - Free or paid: Free (with in-app purchases)
   - [ ] Accept declarations
   - [ ] Click "Create app"

2. **Configure App Details**

   - [ ] Go to Store listing
   - [ ] Complete required fields:
     - [ ] App name
     - [ ] Short description (80 characters max)
     - [ ] Full description (4000 characters max)
     - [ ] App icon (512x512px)
     - [ ] Feature graphic (1024x500px)
     - [ ] Screenshots (at least 2, up to 8)
   - [ ] Category: Health & Fitness
   - [ ] Content rating: Complete questionnaire
   - [ ] Privacy policy URL: `https://yourdomain.com/privacy-policy`

3. **Create In-App Products**
   - [ ] Go to Monetize → Products → Subscriptions
   - [ ] Click "Create subscription"
   - [ ] Create Premium subscription (Monthly):
     - Product ID: `premium_monthly`
     - Name: Premium Monthly
     - Description: "No ads, unlimited stories, all themes, premium features"
     - Billing period: 1 month
     - Price: $9.99
     - Free trial: Optional
   - [ ] Create Premium subscription (Annual):
     - Product ID: `premium_annual`
     - Name: Premium Annual
     - Description: "No ads, unlimited stories, all themes, premium features - Save 33%"
     - Billing period: 1 year
     - Price: $79.99
     - Free trial: Optional
   - [ ] Create Family subscription (Monthly):
     - Product ID: `family_monthly`
     - Name: Family Monthly
     - Description: "No ads, unlimited stories for up to 5 family members"
     - Billing period: 1 month
     - Price: $14.99
   - [ ] Create Family subscription (Annual):
     - Product ID: `family_annual`
     - Name: Family Annual
     - Description: "No ads, unlimited stories for up to 5 family members - Save 33%"
     - Billing period: 1 year
     - Price: $119.99
   - [ ] Activate all subscriptions

### 3.3 Generate Signing Key

1. **Create Keystore**

   **Option A: Automated (Recommended)**

   - [ ] Add keystore configuration to `config.json` under `android_keystore`
   - [ ] Set `generate: true` and provide passwords
   - [ ] Run `python setup_automation.py` to generate keystore and `key.properties`
   - [ ] **CRITICAL**: Save keystore password and key password securely
   - [ ] **CRITICAL**: Backup keystore file to secure location (cannot recover if lost!)

   **Option B: Manual**

   ```bash
   keytool -genkey -v -keystore ~/dream-flow-keystore.jks \
     -keyalg RSA -keysize 2048 -validity 10000 \
     -alias dream-flow-key \
     -storepass YOUR_KEYSTORE_PASSWORD \
     -keypass YOUR_KEY_PASSWORD
   ```

   - [ ] Run the command above
   - [ ] Enter your information when prompted
   - [ ] **CRITICAL**: Save keystore password and key password securely
   - [ ] **CRITICAL**: Backup keystore file to secure location (cannot recover if lost!)

2. **Update Android Build Configuration**

   - [ ] Create `android/key.properties`:
     ```properties
     storePassword=YOUR_KEYSTORE_PASSWORD
     keyPassword=YOUR_KEY_PASSWORD
     keyAlias=dream-flow-key
     storeFile=/path/to/dream-flow-keystore.jks
     ```
   - [ ] Update `android/app/build.gradle.kts` to use signing config (see Fastlane docs)

3. **Update Package Name**

   **Option A: Automated (Recommended)**

   - [ ] Add package name to `config.json` under `app.package_name`
   - [ ] Run `python setup_automation.py` to automatically update `build.gradle.kts`

   **Option B: Manual**

   - [ ] Open `android/app/build.gradle.kts`
   - [ ] Update `applicationId` from `com.example.dream_flow` to `com.yourcompany.dreamflow`
   - [ ] Must match package name in Play Console

### 3.4 Google Play Service Account

1. **Create Service Account**

   - [ ] Go to [Google Cloud Console](https://console.cloud.google.com)
   - [ ] Create new project or select existing
   - [ ] Enable "Google Play Android Developer API"
   - [ ] Go to IAM & Admin → Service Accounts
   - [ ] Click "Create Service Account"
   - [ ] Name: "Play Console API"
   - [ ] Grant role: "Editor" (or custom role with API access)
   - [ ] Click "Create and Continue"
   - [ ] Skip grant access, click "Done"

2. **Create and Download Key**

   - [ ] Click on the service account you created
   - [ ] Go to "Keys" tab
   - [ ] Click "Add Key" → "Create new key"
   - [ ] Select JSON format
   - [ ] Download the JSON key file
   - [ ] **Secure**: Store this file securely (contains private key)

3. **Link Service Account in Play Console**

   - [ ] Go to Play Console → Setup → API access
   - [ ] Under "Service accounts", click "Link service account"
   - [ ] Enter the service account email (from JSON file)
   - [ ] Grant "Release Manager" role
   - [ ] Click "Invite user"

4. **Store Service Account JSON**
   - [ ] Add to CI/CD secrets as `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`
   - [ ] Or store securely for local builds

---

## Phase 4: Environment Configuration

### 4.1 Backend Environment Variables

1. **Create/Update `.env` file in `backend_fastapi/`**

   **Option A: Automated (Recommended)**

   - [ ] Fill in values in `config.json`
   - [ ] Run `python setup_automation.py` to generate `.env` file automatically

   **Option B: Manual**

   ```bash
   # Supabase (already configured)
   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_ANON_KEY=your-anon-key
   SUPABASE_SERVICE_ROLE_KEY=your-service-role-key

   # Stripe
   STRIPE_SECRET_KEY=sk_test_...
   STRIPE_WEBHOOK_SECRET=whsec_...

   # RevenueCat
   REVENUECAT_API_KEY=your-revenuecat-api-key

   # HuggingFace (already configured)
   HUGGINGFACE_API_TOKEN=hf_...

   # Backend URL
   BACKEND_URL=https://your-backend-url.com
   ```

2. **Verify Environment Variables**
   - [ ] Test backend starts: `cd backend_fastapi && uvicorn app.main:app --reload`
   - [ ] Check health endpoint: `curl http://localhost:8080/health`
   - [ ] Verify no missing environment variable errors

### 4.2 Flutter Environment Variables

1. **Create Build Script or CI/CD Configuration**

   **Option A: Automated (Recommended) - ✅ COMPLETE if script was run**

   - [x] Values filled in `config.json`
   - [x] Script generated `build.sh` automatically
   - [ ] **Review and update** `build.sh` with actual production values when ready

   **Option B: Manual (Skip if automation was used)**

   - [ ] Create `build.sh` or update CI/CD workflow
   - [ ] Include all required `--dart-define` flags:
     ```bash
     flutter build apk --release \
       --dart-define=SUPABASE_URL=https://your-project.supabase.co \
       --dart-define=SUPABASE_ANON_KEY=your-anon-key \
       --dart-define=BACKEND_URL=https://your-backend-url.com \
       --dart-define=REVENUECAT_API_KEY=appl_... \
       --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_... \
       --dart-define=STRIPE_PREMIUM_MONTHLY_PRICE_ID=price_... \
       --dart-define=STRIPE_PREMIUM_ANNUAL_PRICE_ID=price_... \
       --dart-define=STRIPE_FAMILY_MONTHLY_PRICE_ID=price_... \
       --dart-define=STRIPE_FAMILY_ANNUAL_PRICE_ID=price_... \
       --dart-define=ADMOB_BANNER_AD_UNIT_ID=ca-app-pub-... \
       --dart-define=ADMOB_INTERSTITIAL_AD_UNIT_ID=ca-app-pub-... \
       --dart-define=ADMOB_IOS_APP_ID=ca-app-pub-... \
       --dart-define=ADMOB_ANDROID_APP_ID=ca-app-pub-... \
       --dart-define=ADSENSE_PUBLISHER_ID=pub-...
     ```

2. **For Local Development**
   - [ ] Create `.env` file or use IDE run configurations
   - [ ] Or use `flutter run` with `--dart-define` flags

### 4.3 Backend Deployment to Render

**Recommended for Early Stage**: Render offers a free tier and simple deployment, making it ideal for Phase 1 (0-1,000 users) with costs around $7-25/month.

#### Prerequisites

- [ ] GitHub repository with backend code pushed
- [ ] Render account (sign up at https://render.com)
- [ ] All environment variables ready (from Section 4.1)

#### Step 1: Prepare Repository

1. **Verify Configuration Files**

   - [ ] Ensure `render.yaml` exists in root directory (already created)
   - [ ] Ensure `backend_fastapi/Dockerfile` exists and is correct
   - [ ] Ensure `backend_fastapi/.renderignore` exists (already created)
   - [ ] Commit all changes to your repository

#### Step 2: Create Render Service

1. **Create Blueprint from Repository**

   - [ ] Go to https://render.com and sign in
   - [ ] Click "New +" → "Blueprint"
   - [ ] Connect your GitHub/GitLab account (if not already connected)
   - [ ] Select the repository containing the Dream Flow backend
   - [ ] Render will automatically detect `render.yaml`
   - [ ] Review the service configuration:
     - Service name: `dream-flow-backend`
     - Plan: `starter` ($7/month) - can upgrade later
     - Region: Choose closest to your users (default: `oregon`)
     - Branch: `main` (or your production branch)
   - [ ] Click "Apply" to create the service

2. **Wait for Initial Deployment**

   - [ ] Render will build and deploy automatically
   - [ ] Monitor build logs in Render dashboard
   - [ ] Note the service URL (e.g., `https://dream-flow-backend.onrender.com`)

#### Step 3: Configure Environment Variables

**Important**: Sensitive variables must be added via Render dashboard, not in `render.yaml`.

1. **Navigate to Environment Tab**

   - [ ] In Render dashboard, go to your service
   - [ ] Click "Environment" tab

2. **Add Required Environment Variables**

   Add each of the following variables:

   **Supabase (Required)**:

   - [ ] `SUPABASE_URL` = `https://your-project.supabase.co`
   - [ ] `SUPABASE_ANON_KEY` = `your-anon-key-here`
   - [ ] `SUPABASE_SERVICE_ROLE_KEY` = `your-service-role-key-here` (CRITICAL - never commit)

   **HuggingFace (Required)**:

   - [ ] `HUGGINGFACE_API_TOKEN` = `hf_...`

   **Stripe (Required if using Stripe)**:

   - [ ] `STRIPE_SECRET_KEY` = `sk_live_...` (or `sk_test_...` for testing)
   - [ ] `STRIPE_WEBHOOK_SECRET` = `whsec_...` (get from Stripe dashboard after configuring webhook)

   **RevenueCat (Required if using RevenueCat)**:

   - [ ] `REVENUECAT_API_KEY` = `your-revenuecat-api-key`

   **Backend URL (Required)**:

   - [ ] `BACKEND_URL` = `https://your-service-name.onrender.com` (use the URL Render provided)

   **Optional Variables** (with defaults):

   - [ ] `STORY_MODEL` = `meta-llama/Llama-3.2-1B-Instruct` (optional)
   - [ ] `TTS_MODEL` = `suno/bark-small` (optional)
   - [ ] `IMAGE_MODEL` = `black-forest-labs/FLUX.1-schnell` (optional)
   - [ ] `MAX_NEW_TOKENS` = `512` (optional)
   - [ ] `SENTRY_DSN` = `your-sentry-dsn` (optional, for error tracking)
   - [ ] `SENTRY_ENVIRONMENT` = `production` (already set in render.yaml)
   - [ ] `SENTRY_TRACES_SAMPLE_RATE` = `0.2` (optional)
   - [ ] `ASSET_RETENTION_DAYS` = `7` (optional)
   - [ ] `ADMIN_USER_IDS` = `user-id-1,user-id-2` (optional, comma-separated)
   - [ ] `CDN_URL` = `https://cdn.example.com` (optional)
   - [ ] `CDN_ENABLED` = `false` (optional, set to `true` if using CDN)

3. **Save and Redeploy**

   - [ ] Click "Save Changes"
   - [ ] Render will automatically redeploy with new environment variables
   - [ ] Wait for deployment to complete

#### Step 4: Configure Webhook Endpoints

After deployment, update webhook URLs in payment provider dashboards:

1. **Stripe Webhook Configuration**

   - [ ] Go to Stripe Dashboard → Developers → Webhooks
   - [ ] Click "Add endpoint" (or edit existing)
   - [ ] Endpoint URL: `https://your-service-name.onrender.com/api/v1/webhooks/stripe`
   - [ ] Select events to listen to:
     - `customer.subscription.created`
     - `customer.subscription.updated`
     - `customer.subscription.deleted`
     - `invoice.payment_succeeded`
     - `invoice.payment_failed`
   - [ ] Click "Add endpoint"
   - [ ] Copy the **Signing secret** (starts with `whsec_`)
   - [ ] Add `STRIPE_WEBHOOK_SECRET` to Render environment variables with this value
   - [ ] Redeploy service in Render (or it will auto-redeploy)

2. **RevenueCat Webhook Configuration**

   - [ ] Go to RevenueCat Dashboard → Project Settings → Webhooks
   - [ ] Click "Add webhook"
   - [ ] Webhook URL: `https://your-service-name.onrender.com/api/v1/webhooks/revenuecat`
   - [ ] Select all subscription events
   - [ ] Click "Save"
   - [ ] Verify webhook is active

#### Step 5: Update Frontend Configuration

1. **Update Flutter App Backend URL**

   - [ ] Update `BACKEND_URL` in your Flutter app configuration
   - [ ] For production builds, use: `https://your-service-name.onrender.com`
   - [ ] Update build scripts or CI/CD configuration

#### Step 6: Test Deployment

1. **Health Check**

   - [ ] Visit: `https://your-service-name.onrender.com/health`
   - [ ] Should return JSON with status and model information
   - [ ] Verify no errors in response

2. **API Endpoint Test**

   - [ ] Test story generation: `POST https://your-service-name.onrender.com/api/v1/story`
   - [ ] Verify authentication works
   - [ ] Check Render logs for any errors

3. **Webhook Test**

   - [ ] Use Stripe CLI or dashboard to send test webhook
   - [ ] Verify webhook endpoint receives and processes events
   - [ ] Check Render logs for webhook processing

#### Step 7: Configure Custom Domain (Optional)

1. **Add Custom Domain in Render**

   - [ ] Go to Settings → Custom Domains
   - [ ] Click "Add Custom Domain"
   - [ ] Enter your domain (e.g., `api.dreamflow.ai`)
   - [ ] Follow DNS configuration instructions
   - [ ] Update DNS records at your domain registrar
   - [ ] Wait for DNS propagation (can take up to 48 hours)

2. **Update Environment Variables**

   - [ ] Update `BACKEND_URL` in Render to use custom domain
   - [ ] Update `BACKEND_URL` in Flutter app configuration
   - [ ] Update webhook URLs in Stripe and RevenueCat dashboards

#### Render-Specific Considerations

**Auto-Deploy**:

- Render automatically deploys on push to configured branch (default: `main`)
- Manual deploys can be triggered from dashboard

**Scaling Plans**:

- **Starter Plan** ($7/month): 512MB RAM, 0.5 CPU - Good for early stage
- **Standard Plan** ($25/month): 2GB RAM, 1 CPU - For growth stage
- **Pro Plan** ($85/month): 4GB RAM, 2 CPU - For scale stage

**Persistent Storage**:

- Assets are stored in Supabase Storage, not local filesystem
- Ephemeral storage is sufficient for temporary processing files
- No persistent disk needed

**Health Checks**:

- Render uses `/health` endpoint for health checks
- Ensure endpoint returns 200 OK

**Monitoring**:

- View logs in Render dashboard
- Set up alerts for deployment failures
- Monitor resource usage in dashboard

**Cost Optimization Tips**:

1. Start with Starter Plan ($7/month) - sufficient for early stage
2. Monitor usage and upgrade only when needed
3. Use async processing to reduce request time
4. Implement caching to reduce compute costs

#### Troubleshooting

**Build Fails**:

- Check Dockerfile syntax
- Verify all dependencies in requirements.txt
- Check build logs in Render dashboard

**Service Crashes**:

- Check environment variables are set correctly
- Verify `SUPABASE_SERVICE_ROLE_KEY` is set
- Check application logs in Render dashboard

**Webhooks Not Working**:

- Verify `BACKEND_URL` is set correctly
- Check webhook endpoint is accessible
- Verify webhook secret matches in Render and Stripe/RevenueCat

**Out of Memory**:

- Upgrade to Standard or Pro plan
- Optimize AI model usage
- Implement request queuing

---

## Phase 5: Localization Setup

1. **Generate Localization Files**

   **Option A: Automated (Recommended)**

   - [ ] Run `python setup_automation.py` (includes localization generation)

   **Option B: Manual**

   ```bash
   cd frontend_flutter
   flutter gen-l10n
   ```

   - [ ] Run the command above
   - [ ] Verify files generated in `lib/generated/`
   - [ ] Check for `app_localizations.dart` and locale files

2. **Test Localization**

   - [ ] Change device language to Spanish
   - [ ] Run app and verify Spanish translations appear
   - [ ] Test story generation with language parameter

3. **Add More Languages (Optional)**
   - [ ] Create `lib/l10n/app_fr.arb` for French
   - [ ] Create `lib/l10n/app_de.arb` for German
   - [ ] Run `flutter gen-l10n` again
   - [ ] Update `main.dart` supportedLocales

---

## Phase 6: Testing

### 6.1 Local Testing

1. **Backend Testing**

   - [ ] Start backend: `cd backend_fastapi && uvicorn app.main:app --reload`
   - [ ] Test health endpoint
   - [ ] Test story generation endpoint
   - [ ] Test subscription endpoints
   - [ ] Test webhook endpoints (use Stripe CLI for local testing)

2. **Flutter App Testing**

   - [ ] Run on iOS simulator: `flutter run -d ios`
   - [ ] Run on Android emulator: `flutter run -d android`
   - [ ] Test all user flows:
     - [ ] Sign up / Sign in
     - [ ] Profile setup
     - [ ] Story generation
     - [ ] Video/audio playback
     - [ ] Offline mode
     - [ ] Subscription purchase (test mode)
     - [ ] Social sharing
     - [ ] Analytics dashboard
     - [ ] Ad display (free tier only)
     - [ ] Ad-free experience (premium/family tiers)

3. **Accessibility Testing**
   - [ ] Enable VoiceOver (iOS) or TalkBack (Android)
   - [ ] Navigate through app using screen reader
   - [ ] Test high contrast mode
   - [ ] Test font scaling
   - [ ] Verify all buttons have semantic labels

### 6.2 Ad Testing

1. **AdMob Test Mode**

   - [ ] Use test ad unit IDs during development
   - [ ] Verify banner ads appear at bottom of home screen (free tier only)
   - [ ] Verify interstitial ads show after story completion (free tier only)
   - [ ] Verify no ads show for premium/family users
   - [ ] Test ad loading failures gracefully

2. **AdSense Test Mode (Web)**
   - [ ] Verify ads appear on web version (free tier only)
   - [ ] Test responsive ad sizing
   - [ ] Verify no ads for premium/family users

### 6.3 Payment Testing

1. **Stripe Test Mode**

   - [ ] Use test card: `4242 4242 4242 4242`
   - [ ] Test subscription creation
   - [ ] Verify webhook receives events
   - [ ] Check subscription status in backend

2. **RevenueCat Test Mode**
   - [ ] Use sandbox test accounts
   - [ ] Test purchase flow on iOS
   - [ ] Test purchase flow on Android
   - [ ] Verify restore purchases works
   - [ ] Check entitlements in RevenueCat dashboard

### 6.4 Integration Testing

1. **Run Automated Tests**

   ```bash
   cd backend_fastapi
   pytest tests/ -v

   cd frontend_flutter
   flutter test
   flutter test integration_test/
   ```

   - [ ] Run backend tests
   - [ ] Run Flutter unit tests
   - [ ] Run Flutter integration tests
   - [ ] Fix any failing tests

---

## Phase 7: Store Assets Preparation

### 7.1 App Icons

1. **Create App Icon**
   - [ ] Design 1024x1024px master icon
   - [ ] Generate all required sizes:
     - iOS: 1024x1024, 180x180, 120x120, 152x152, 167x167
     - Android: 512x512, 192x192, 144x144, 96x96, 72x72, 48x48
   - [ ] Use tool: [AppIcon.co](https://www.appicon.co) or [IconKitchen](https://icon.kitchen)
   - [ ] Place in appropriate directories:
     - iOS: `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
     - Android: `android/app/src/main/res/mipmap-*/ic_launcher.png`

### 7.2 Screenshots

1. **Take Screenshots**

   - [ ] iOS screenshots:
     - iPhone 6.7" (1290x2796px) - 3-10 screenshots
     - iPhone 6.5" (1242x2688px) - 3-10 screenshots
     - iPad Pro 12.9" (2048x2732px) - Optional
   - [ ] Android screenshots:
     - Phone (1080x1920px minimum) - 2-8 screenshots
     - Tablet (1200x1920px minimum) - Optional
   - [ ] Show key features:
     - [ ] Home screen with story generation
     - [ ] Story playback screen
     - [ ] Subscription screen
     - [ ] Analytics dashboard
     - [ ] Settings/accessibility

2. **Edit Screenshots**
   - [ ] Remove device frames (system will add)
   - [ ] Ensure high quality
   - [ ] No text overlays (unless part of UI)
   - [ ] Save in appropriate formats (PNG recommended)

### 7.3 App Preview Videos (Optional)

1. **Record Videos**
   - [ ] iOS: 886x1920px, 15-30 seconds
   - [ ] Android: 1080x1920px, 30 seconds minimum
   - [ ] Show app in action
   - [ ] No audio or royalty-free music only
   - [ ] Export in required format

### 7.4 App Store Listing Content

1. **Write App Description**

   - [ ] Short description (iOS: 30 chars, Android: 80 chars)
   - [ ] Full description (4000 chars)
   - [ ] Include key features, benefits, target audience
   - [ ] Use template from `STORE_ASSETS_CHECKLIST.md`

2. **Keywords (iOS)**

   - [ ] Up to 100 characters, comma-separated
   - [ ] Suggested: "sleep, bedtime, stories, meditation, relaxation"

3. **Privacy Policy**

   - [ ] Create privacy policy page
   - [ ] Host at `https://yourdomain.com/privacy-policy`
   - [ ] Must cover:
     - Data collection practices
     - Third-party services (Supabase, Stripe, RevenueCat)
     - User rights
     - Contact information
   - [ ] Use generator: [Privacy Policy Generator](https://www.privacypolicygenerator.info)

4. **Support URL**
   - [ ] Create support page or email
   - [ ] URL: `https://yourdomain.com/support` or `mailto:support@yourdomain.com`

---

## Phase 8: Beta Testing

### 8.1 iOS TestFlight

1. **Build for TestFlight**

   ```bash
   cd frontend_flutter/ios
   fastlane beta
   ```

   - [ ] Run Fastlane beta command
   - [ ] Wait for build to process in App Store Connect
   - [ ] Add internal testers (up to 100)
   - [ ] Add external testers (requires review)
   - [ ] Send test invitations

2. **TestFlight Testing**
   - [ ] Install TestFlight app on test devices
   - [ ] Accept invitation
   - [ ] Install and test app
   - [ ] Collect feedback
   - [ ] Fix critical issues

### 8.2 Android Internal Testing

1. **Build APK/AAB**

   ```bash
   cd frontend_flutter/android
   fastlane internal
   ```

   - [ ] Run Fastlane internal command
   - [ ] Upload to Play Console Internal Testing track

2. **Internal Testing**
   - [ ] Add testers via email
   - [ ] Testers install from Play Store
   - [ ] Collect feedback
   - [ ] Fix critical issues

---

## Phase 9: Final Pre-Launch Checklist

### 9.1 Code Review

- [ ] Review all code changes
- [ ] Remove debug code and console logs
- [ ] Verify no hardcoded credentials
- [ ] Check error handling
- [ ] Verify logging is appropriate

### 9.2 Configuration Verification

- [ ] All environment variables set correctly
- [ ] API keys are production keys (not test)
- [ ] Bundle IDs match across all platforms
- [ ] Package names are correct
- [ ] Webhook URLs are production URLs
- [ ] CDN configured (if using)

### 9.3 Store Listing Verification

- [ ] All required screenshots uploaded
- [ ] App description is complete and accurate
- [ ] Privacy policy is live and accessible
- [ ] Support contact information is correct
- [ ] Age rating is appropriate
- [ ] In-app purchases are configured
- [ ] Pricing is correct

### 9.4 Legal Compliance

- [ ] Privacy policy is complete
- [ ] Terms of service (if required)
- [ ] GDPR compliance (if applicable)
- [ ] COPPA compliance (if targeting children)
- [ ] Content rating is accurate

---

## Phase 10: Launch

### 10.1 iOS Launch

1. **Submit for Review**

   - [ ] Go to App Store Connect
   - [ ] Complete all required information
   - [ ] Upload build
   - [ ] Submit for review
   - [ ] Wait for review (typically 24-48 hours)

2. **After Approval**
   - [ ] Set release date (automatic or scheduled)
   - [ ] Monitor for any issues
   - [ ] Respond to user reviews

### 10.2 Android Launch

1. **Submit for Review**

   - [ ] Go to Play Console
   - [ ] Complete all required sections
   - [ ] Upload release build
   - [ ] Submit for review
   - [ ] Wait for review (typically 1-3 days)

2. **After Approval**
   - [ ] App goes live automatically
   - [ ] Monitor for any issues
   - [ ] Respond to user reviews

---

## Phase 11: Post-Launch

### 11.1 Monitoring

- [ ] Set up error monitoring (Sentry already configured)
- [ ] Monitor app store reviews
- [ ] Track analytics
- [ ] Monitor payment processing
- [ ] Check webhook logs

### 11.2 Support

- [ ] Set up support email/ticket system
- [ ] Create FAQ page
- [ ] Prepare response templates
- [ ] Monitor user feedback

### 11.3 Marketing

- [ ] Prepare launch announcement
- [ ] Share on social media
- [ ] Submit to Product Hunt (optional)
- [ ] Reach out to press/bloggers (optional)

---

## Quick Reference: All Required Credentials

Keep this list secure and update as you complete each step:

### Stripe

- [ ] Publishable Key: `pk_...`
- [ ] Secret Key: `sk_...`
- [ ] Webhook Secret: `whsec_...`
- [ ] Premium Monthly Price ID: `price_...`
- [ ] Premium Annual Price ID: `price_...`
- [ ] Family Monthly Price ID: `price_...`
- [ ] Family Annual Price ID: `price_...`

### RevenueCat

- [ ] Public API Key: `appl_...` or `goog_...`

### AdMob

- [ ] iOS App ID: `ca-app-pub-...~...`
- [ ] Android App ID: `ca-app-pub-...~...`
- [ ] Banner Ad Unit ID: `ca-app-pub-.../...`
- [ ] Interstitial Ad Unit ID: `ca-app-pub-.../...`

### AdSense (Web)

- [ ] Publisher ID: `pub-...`
- [ ] Banner Ad Code: (stored for web implementation)
- [ ] Display Ad Code: (stored for web implementation)

### Apple

- [ ] Apple ID: `your-email@example.com`
- [ ] App ID: `com.yourcompany.dreamflow`
- [ ] App Store Connect API Key ID: `...`
- [ ] App Store Connect Issuer ID: `...`
- [ ] App Store Connect API Key (.p8 file)

### Google Play

- [ ] Package Name: `com.yourcompany.dreamflow`
- [ ] Keystore Password: `...`
- [ ] Key Password: `...`
- [ ] Key Alias: `dream-flow-key`
- [ ] Service Account JSON: `...`

### Supabase

- [ ] Project URL: `https://...supabase.co`
- [ ] Anon Key: `...`
- [ ] Service Role Key: `...`

### Backend

- [ ] Backend URL: `https://your-backend-url.com`
- [ ] HuggingFace Token: `hf_...`

---

## Troubleshooting

### Common Issues

1. **Payment not working**

   - Verify API keys are correct
   - Check product IDs match between stores and code
   - Verify webhooks are receiving events
   - Check RevenueCat/Stripe dashboards for errors

2. **Build fails**

   - Check all environment variables are set
   - Verify bundle IDs match
   - Check signing certificates are valid
   - Review build logs for specific errors

3. **Webhooks not receiving events**

   - Verify webhook URL is publicly accessible
   - Check webhook secret matches
   - Review Stripe/RevenueCat webhook logs
   - Test with Stripe CLI locally

4. **App rejected from store**
   - Review rejection reason carefully
   - Address all issues mentioned
   - Update app and resubmit
   - Contact support if needed

---

## Estimated Timeline

- **Payment Setup**: 2-4 hours
- **AdMob/AdSense Setup**: 1-2 hours
- **App Store Setup**: 4-6 hours
- **Play Store Setup**: 3-5 hours
- **Environment Config**: 1-2 hours
- **Localization**: 1 hour
- **Testing**: 8-16 hours
- **Asset Preparation**: 4-8 hours
- **Beta Testing**: 1-2 weeks
- **Store Review**: 1-3 days

**Total Estimated Time**: 2-4 weeks (depending on review times and iterations)

---

## Support Resources

- **Stripe Docs**: https://stripe.com/docs
- **RevenueCat Docs**: https://docs.revenuecat.com
- **Apple Developer**: https://developer.apple.com/support/
- **Google Play Help**: https://support.google.com/googleplay/android-developer
- **Flutter Docs**: https://docs.flutter.dev

---

## Notes

- Save all credentials securely (use password manager)
- Keep backups of signing keys
- Document any custom configurations
- Test thoroughly before submitting
- Be patient with store review process

Good luck with your launch! 🚀
