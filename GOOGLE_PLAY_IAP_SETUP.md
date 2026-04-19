# Google Play In-App Purchase Setup Guide

Complete guide for setting up Google Play in-app purchases with server verification for the XO Game Flutter app.

## Table of Contents

1. [Overview](#overview)
2. [Google Play Console Setup](#google-play-console-setup)
3. [Service Account Setup](#service-account-setup)
4. [Firebase Cloud Functions Setup](#firebase-cloud-functions-setup)
5. [Flutter App Configuration](#flutter-app-configuration)
6. [Testing Checklist](#testing-checklist)
7. [Troubleshooting](#troubleshooting)
8. [Important Notes](#important-notes)

## Overview

This implementation uses:
- **Flutter**: `in_app_purchase` package (v3.1.11)
- **Backend**: Firebase Cloud Functions with Google Play Developer API
- **Database**: Firestore for coin balance and transaction records
- **Verification**: Server-side verification with idempotency protection
- **Consume Flow**: Manual consumption after server verification

### Purchase Flow

```
User Taps Buy → Google Play Window → Purchase Complete → 
Server Verification → Grant Coins → Consume Purchase → 
Complete Purchase → Show Success
```

### Why `autoConsume: false`?

- Server verification must happen **before** consuming
- Prevents duplicate grants if verification fails
- Allows manual control over consume timing
- Required for proper security in production

### `completePurchase` vs `consume`

- **`completePurchase`**: Acknowledges purchase to Google Play, prevents re-delivery
- **`consume`**: Marks consumable as used, allows re-purchase (done on server)
- **Flow**: Verify → Grant → Consume (server) → Complete Purchase (client)

## Google Play Console Setup

### Play Console Checklist

Follow these steps in order to set up IAP correctly:

#### ✅ Step 1: Create All In-App Products

1. Go to [Google Play Console](https://play.google.com/console)
2. Select your app: **XO Kings** (package: `com.sasa.xogame`)
3. Navigate to **Monetize** → **Products** → **In-app products**
4. Click **Create product** for each of the 10 products
5. **Verify package name matches**: `com.sasa.xogame` (must match `android/app/build.gradle.kts`)

**Product IDs to create:**
- `coins_pack_200`
- `coins_pack_400`
- `coins_pack_600`
- `coins_pack_800`
- `coins_pack_1000`
- `coins_pack_2000`
- `coins_pack_3000`
- `coins_pack_5000`
- `coins_pack_10000`
- `coins_pack_20000`

#### ✅ Step 2: Configure Product Details

For each product:
- **Product ID**: Must match exactly (case-sensitive, no spaces)
- **Name**: User-visible name (e.g., "200 Coins Pack")
- **Description**: User-visible description
- **Price**: Set in Play Console (Google handles currency conversion)
- **Status**: Set to **Active** when ready to test

**Important**: 
- Product IDs **cannot be changed** after publication
- Prices are set in Play Console only (not in code)
- Wait 2-24 hours after creating products for them to sync

#### ✅ Step 3: Activate Products

1. For each product, ensure **Status** is set to **Active**
2. Products must be Active to appear in the app
3. Inactive products will not be returned by `queryProductDetails`

#### ✅ Step 4: Set Up Internal Testing Track

1. Go to **Testing** → **Internal testing**
2. Click **Create new release** (or edit existing)
3. **Upload signed release AAB** (not debug build):
   ```bash
   flutter build appbundle --release
   ```
   Upload from: `build/app/outputs/bundle/release/app-release.aab`
4. Fill in release notes
5. Click **Save**

#### ✅ Step 5: Add License Testers

1. In Internal Testing, go to **Testers** tab
2. Click **Create email list** or use existing list
3. Add email addresses of test accounts
4. **Important**: Testers must accept the invitation email
5. Save the list

#### ✅ Step 6: Install from Play Store

**Critical**: App **must** be installed from Play Store, not APK directly

1. Testers go to: https://play.google.com/apps/internaltest
2. Find your app and click **Download** or **Update**
3. Install from Play Store (not sideload APK)
4. **Why**: Google Play Billing only works with Play Store-installed apps

#### ✅ Step 7: Test Purchase Flow

1. Open app and navigate to coins store
2. Verify all 10 products appear with correct prices
3. Tap "Buy" on a product
4. Complete purchase in Google Play payment window
5. Verify coins are added to balance
6. Verify success message appears
7. Test restore purchases functionality

### Step 1: Create In-App Products (Detailed)

1. Go to [Google Play Console](https://play.google.com/console)
2. Select your app: **XO Kings** (package: `com.sasa.xogame`)
3. Navigate to **Monetize** → **Products** → **In-app products**
4. Click **Create product**
5. Create all 10 consumable products:

| Product ID | Status | Price (Set in Console) |
|------------|--------|------------------------|
| `coins_pack_200` | Active | $0.99 (example) |
| `coins_pack_400` | Active | $1.99 (example) |
| `coins_pack_600` | Active | $2.99 (example) |
| `coins_pack_800` | Active | $3.99 (example) |
| `coins_pack_1000` | Active | $4.99 (example) |
| `coins_pack_2000` | Active | $9.99 (example) |
| `coins_pack_3000` | Active | $14.99 (example) |
| `coins_pack_5000` | Active | $24.99 (example) |
| `coins_pack_10000` | Active | $49.99 (example) |
| `coins_pack_20000` | Active | $99.99 (example) |

**Important:**
- Product IDs must match **exactly** (case-sensitive)
- Prices are set in Google Play Console only
- Prices are automatically converted by Google based on user's country
- **Cannot change product ID after publication** - choose carefully!

### Step 2: Configure Product Details

For each product:
- **Name**: e.g., "200 Coins Pack"
- **Description**: e.g., "Get 200 coins to use in the game"
- **Price**: Set your desired price (Google handles currency conversion)
- **Status**: Set to **Active** when ready

### Step 3: Set Up Internal Testing Track

1. Go to **Testing** → **Internal testing**
2. Click **Create new release**
3. Upload a **signed release build** (not debug)
4. Add testers:
   - Go to **Testers** tab
   - Add email addresses of test accounts
   - Or create a Google Group and add it
5. **Important**: App must be installed from Play Store, not APK

## Service Account Setup

### Step 1: Create Google Cloud Service Account

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create or select a project
3. Enable **Google Play Android Developer API**:
   - Go to **APIs & Services** → **Library**
   - Search for "Google Play Android Developer API"
   - Click **Enable**
4. Create Service Account:
   - Go to **IAM & Admin** → **Service Accounts**
   - Click **Create Service Account**
   - Name: `play-iap-verifier`
   - Description: "Service account for IAP verification"
   - Click **Create and Continue**
   - Grant role: **Service Account User**
   - Click **Done**
5. Create and download JSON key:
   - Click on the created service account
   - Go to **Keys** tab
   - Click **Add Key** → **Create new key**
   - Select **JSON**
   - Click **Create** (file downloads automatically)
   - **Save this file securely** - you'll need it for the backend

### Step 2: Link Service Account to Google Play Console

1. Go to [Google Play Console](https://play.google.com/console)
2. Select your app
3. Go to **Setup** → **API access**
4. Under **Service accounts**, click **Link service account**
5. Select your service account (created in Step 1)
6. Grant permissions:
   - ✅ **View financial data** (optional, for analytics)
   - ✅ **Manage orders and subscriptions** (required)
7. Click **Invite user**
8. Wait for the service account to appear in the list

## Firebase Cloud Functions Setup

### Step 1: Install Firebase CLI

If not already installed:

```bash
npm install -g firebase-tools
firebase login
```

### Step 2: Initialize Firebase Functions (if not already done)

```bash
firebase init functions
```

Select:
- TypeScript
- ESLint (yes)
- Install dependencies (yes)

### Step 3: Install Dependencies

```bash
cd functions
npm install
```

This will install:
- `firebase-admin` (already installed)
- `firebase-functions` (already installed)
- `googleapis` (for Google Play Developer API)

### Step 4: Enable Google Play Android Developer API

**Important**: This API must be enabled before the Cloud Function can verify purchases.

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project (the same one where you created the service account)
3. Go to **APIs & Services** → **Library**
4. Search for "Google Play Android Developer API"
5. Click on it and click **Enable**
6. Wait for the API to be enabled (usually instant)

**Note**: If you're using the same Google Cloud project for both the service account and Firebase, the API will be available to both.

### Step 5: Set Firebase Secret for Google Play Service Account

The Cloud Function needs the Google Play service account key. Store it as a Firebase secret:

```bash
# From the project root directory
firebase functions:secrets:set GOOGLE_SERVICE_ACCOUNT_KEY
```

When prompted, paste the **entire JSON content** of your Google Play service account key file.

**Alternative method (from file):**
```bash
# On Linux/Mac
firebase functions:secrets:set GOOGLE_SERVICE_ACCOUNT_KEY < path/to/service-account-key.json

# On Windows PowerShell
Get-Content path/to/service-account-key.json | firebase functions:secrets:set GOOGLE_SERVICE_ACCOUNT_KEY
```

**Important**: 
- The secret must be the complete JSON content (not a path)
- Firebase automatically handles JSON parsing in the Cloud Function
- Secrets are encrypted and stored securely by Firebase

### Step 6: Build Functions

```bash
cd functions
npm run build
```

This compiles TypeScript to JavaScript in the `lib/` directory.

### Step 7: Deploy Cloud Functions

```bash
# From project root
firebase deploy --only functions
```

This deploys the `verifyGooglePlayPurchase` function to your Firebase project.

### Step 8: Deploy Firestore Rules

```bash
firebase deploy --only firestore:rules
```

This ensures users can read their coin balance but cannot modify it directly.

### Step 9: Verify Deployment

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select project: `xogame-105c9`
3. Go to **Functions** → Verify `verifyGooglePlayPurchase` is listed
4. Go to **Firestore** → **Rules** → Verify rules are deployed

**Note**: No backend URL configuration needed in Flutter app - Cloud Functions are automatically accessible via Firebase SDK.

## Flutter App Configuration

### Step 1: Verify Dependencies

Check `pubspec.yaml` has:
```yaml
dependencies:
  in_app_purchase: ^3.1.11
  cloud_functions: ^6.0.6  # For Cloud Functions calls
  firebase_core: ^4.4.0
  firebase_auth: ^6.1.4
```

Run:
```bash
flutter pub get
```

**Note**: The `http` package is no longer needed - Cloud Functions are called via `cloud_functions` package.

### Step 2: Verify Android Configuration

**AndroidManifest.xml** (`android/app/src/main/AndroidManifest.xml`):
- Billing permission is **not required** - `in_app_purchase` handles it automatically
- Package name must match: `com.sasa.xogame`

**build.gradle.kts**:
- `compileSdk = 36` (required by in_app_purchase)
- `targetSdk = 35` (safe for Play Store)

### Step 3: Build and Test

**Important**: For testing, you **must**:
1. Build a **signed release** build (not debug)
2. Upload to **Internal Testing** track in Play Console
3. Install from **Play Store** (not APK directly)

Build release AAB:
```bash
flutter build appbundle --release
```

Upload to Play Console → Internal Testing track.

## Testing Checklist

### Pre-Testing Setup

- [ ] All 10 products created in Google Play Console
- [ ] Products set to **Active** status
- [ ] Service account linked in Play Console
- [ ] Firebase Cloud Function deployed
- [ ] Google Play service account key set in Firebase Secrets
- [ ] App uploaded to Internal Testing track
- [ ] Test account added to Internal Testing
- [ ] App installed from Play Store (not APK)

### Test Scenarios

#### 1. Basic Purchase Flow
- [ ] Open coins store screen
- [ ] Products load and display correctly
- [ ] Prices show in local currency
- [ ] Tap "Buy" on a product
- [ ] Google Play payment window appears
- [ ] Complete purchase
- [ ] Success message shows: "X Coins Added!"
- [ ] Coin balance updates correctly

#### 2. Idempotency Test
- [ ] Make a purchase
- [ ] Verify coins added
- [ ] Restore purchases (tap "Restore Purchases")
- [ ] Verify coins not added again (idempotency)

#### 3. Restore Purchases
- [ ] Make a purchase
- [ ] Uninstall and reinstall app
- [ ] Open coins store
- [ ] Tap "Restore Purchases"
- [ ] Verify coins are restored

#### 4. Error Handling
- [ ] Cancel purchase in Google Play window
- [ ] Verify no coins added
- [ ] Verify no error crash
- [ ] Test with network disconnected
- [ ] Verify appropriate error message

#### 5. Product Display
- [ ] All 10 products visible
- [ ] Products sorted by coin amount
- [ ] Product titles and descriptions display
- [ ] Prices display in local currency
- [ ] Store unavailable message shows if store not available

### Android 14/15 Compatibility

The `in_app_purchase` package v3.1.11 is compatible with:
- ✅ Android 14 (API 34)
- ✅ Android 15 (API 35)

No special configuration needed.

## Troubleshooting

### "Store not available"
- **Cause**: Google Play Services not available or app not installed from Play Store
- **Fix**: Install app from Play Store Internal Testing track (not APK)

### "No products available"
- **Cause**: Products not created in Play Console or not active
- **Fix**: 
  - Verify products exist in Play Console
  - Ensure products are set to **Active**
  - Wait a few hours after creating products (Google sync delay)

### "Purchase verification failed"
- **Cause**: Cloud Function error or service account not configured
- **Fix**:
  - Check Cloud Function is deployed: `firebase functions:list`
  - Verify Firebase secret is set: `firebase functions:secrets:access GOOGLE_SERVICE_ACCOUNT_KEY`
  - Check service account has Play Console access
  - Check Cloud Function logs: `firebase functions:log`

### "Purchase already processed"
- **Cause**: Idempotency working correctly
- **Fix**: This is expected - purchase was already granted

### "Server verification required in release mode"
- **Cause**: Cloud Function verification failed
- **Fix**:
  - Check Cloud Function logs: `firebase functions:log`
  - Verify Firebase secret is set correctly
  - Check service account has Play Console API access
  - Verify Google Play API is enabled in Google Cloud Console

### Products not showing prices
- **Cause**: Products not fully synced in Play Console
- **Fix**: Wait 2-24 hours after creating products

### "Authentication failed (401)"
- **Cause**: Firebase Auth token expired or invalid
- **Fix**: 
  - Ensure user is logged in
  - Token is automatically refreshed, but check network connectivity
  - Verify Firebase Cloud Function is deployed correctly

### "Invalid package name"
- **Cause**: Package name mismatch between app and Play Console
- **Fix**: 
  - Verify `android/app/build.gradle.kts` has `applicationId = "com.sasa.xogame"`
  - Verify Play Console app package matches
  - Rebuild and re-upload to Play Console

### "Purchase already processed"
- **Cause**: Idempotency working correctly
- **Fix**: This is expected - purchase was already granted. User should see coins in balance.

### "Token verification failed" or "unauthenticated" error
- **Cause**: User not authenticated or Cloud Function cannot verify token
- **Fix**:
  - Ensure user is logged in to Firebase Auth
  - Check Cloud Function logs: `firebase functions:log`
  - Verify Firebase project is correctly configured
  - Re-authenticate user if token expired

### ITEM_ALREADY_OWNED error
- **Cause**: Purchase exists but not consumed/acknowledged
- **Fix**: App automatically handles this by restoring purchases. User should tap "Restore Purchases" if needed.

### ITEM_ALREADY_OWNED error
- **Cause**: Purchase exists but not consumed
- **Fix**: App automatically handles this by restoring purchases

## Real-time Developer Notifications (RTDN) - Optional but Recommended

RTDN provides real-time notifications when purchases are made, refunded, or canceled. This is useful for:
- Handling refunds automatically
- Detecting fraudulent purchases
- Monitoring purchase activity

### Setting Up RTDN

1. **In Google Play Console**:
   - Go to **Monetize** → **Monetization setup** → **Real-time developer notifications**
   - Click **Set up notifications**
   - Enter your Cloud Function URL: `https://us-central1-xogame-105c9.cloudfunctions.net/rtdn` (or create a new function)
   - Select events: Purchase, Refund, Cancel
   - Save

2. **Cloud Function Implementation** (optional):
   - Add endpoint to receive RTDN webhooks
   - Verify webhook signature from Google
   - Process refunds/cancellations automatically

**Note**: RTDN is optional. The current implementation works without it, but it's recommended for production apps handling refunds.

## Security Notes

### Firebase Auth Token Verification

Cloud Functions automatically verify Firebase Auth ID tokens. This prevents security vulnerabilities:

**How it works:**
1. Flutter app calls Cloud Function via `FirebaseFunctions.instance.httpsCallable()`
2. Firebase SDK automatically includes user's ID token in the request
3. Cloud Function receives `context.auth` with verified user info
4. Cloud Function extracts UID from `context.auth.uid` (server-authoritative)
5. Any `userId` in request body is **ignored** for security

**Why this is secure:**
- ✅ Cloud Functions automatically verify tokens (no manual verification needed)
- ✅ Tokens are cryptographically signed by Firebase
- ✅ Tokens expire and must be refreshed
- ✅ Server verifies token authenticity (cannot be spoofed)
- ✅ UID is extracted server-side (client cannot fake it)
- ✅ Prevents users from granting coins to other users

**Security Flow:**
```
Client → Call Cloud Function (auto token inclusion)
Cloud Function → context.auth.uid (verified) → Process Purchase
```

### Package Name Validation

The Cloud Function validates that `packageName` matches `com.sasa.xogame`:
- Prevents purchases from wrong apps
- Hardcoded check in Cloud Function for security
- Rejects mismatched package names with `invalid-argument` error

### Product ID Validation

The Cloud Function has a server-side mapping of valid product IDs:
- Only known product IDs are accepted
- Unknown product IDs are rejected with `invalid-argument` error
- Prevents invalid purchases from being processed

### Idempotency Protection

Purchases are tracked by `purchaseToken`:
- Each purchase token can only grant coins once
- Prevents duplicate grants if purchase is verified multiple times
- Stored in Firestore: `purchases/{userId}_{purchaseToken}`

## Important Notes

### ⚠️ Critical Warnings

1. **Product IDs cannot be changed after publication**
   - Choose product IDs carefully
   - Test thoroughly before production release

2. **Testing requires Play Store installation**
   - Debug builds won't work for IAP testing
   - Must use Internal Testing track
   - Must install from Play Store

3. **Firebase Secrets are sensitive**
   - Never commit secrets to version control
   - Use Firebase Secrets for sensitive data (Google Play service account key)
   - Rotate secrets if compromised: `firebase functions:secrets:destroy GOOGLE_SERVICE_ACCOUNT_KEY`

4. **Cloud Functions are automatically secured**
   - HTTPS is automatic
   - Authentication is automatic (via Firebase Auth)
   - Rate limiting is handled by Firebase

5. **Prices are set in Play Console only**
   - Do not hardcode prices in app
   - Google handles currency conversion
   - Prices update automatically

### Best Practices

1. **Always verify on server** - Never trust client-side purchase data
2. **Use idempotency** - Prevent duplicate grants
3. **Handle all purchase statuses** - Pending, Purchased, Error, Cancelled
4. **Test restore functionality** - Users may reinstall app
5. **Monitor Cloud Function logs** - Track verification failures: `firebase functions:log`
6. **Set up alerts** - Monitor for verification errors in Firebase Console

### Version Compatibility

- **in_app_purchase**: v3.1.11 (latest stable)
- **Flutter SDK**: >=3.4.0
- **Android**: minSdk 21, targetSdk 35, compileSdk 36
- **Node.js**: >=18.0.0 (for Cloud Functions)
- **Firebase CLI**: Latest version

### Android Configuration Verification

**Required Settings:**
- ✅ `applicationId = "com.sasa.xogame"` in `android/app/build.gradle.kts`
- ✅ Package name matches Play Console: `com.sasa.xogame`
- ✅ `enablePendingPurchases()` called in `main()` (already implemented)
- ✅ Signed release AAB for testing (not debug build)

**Build Command:**
```bash
flutter build appbundle --release
```

**Upload Location:**
- Play Console → Internal Testing → Create Release → Upload AAB
- File: `build/app/outputs/bundle/release/app-release.aab`

## Support

For issues or questions:
- Check Firebase Cloud Functions logs: `firebase functions:log`
- Check Flutter logs: `flutter run` or Android logcat
- Verify Play Console: Product status, service account access
- Verify Firebase Secrets: `firebase functions:secrets:access GOOGLE_SERVICE_ACCOUNT_KEY`

## Additional Resources

- [Google Play Billing Documentation](https://developer.android.com/google/play/billing)
- [in_app_purchase Package](https://pub.dev/packages/in_app_purchase)
- [Google Play Developer API](https://developers.google.com/android-publisher)

---

**Last Updated**: 2024
**App Package**: `com.sasa.xogame`
**Cloud Function**: `verifyGooglePlayPurchase` (callable)
