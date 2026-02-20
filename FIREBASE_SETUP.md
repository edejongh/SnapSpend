# Firebase Setup Guide

Before running SnapSpend, you need to create a Firebase project and add the required configuration files.

## 1. Create a Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click **Add project** and follow the setup wizard
3. Enable **Google Analytics** when prompted (recommended)

## 2. Enable Firebase Services

In the Firebase Console, enable the following services:

- **Authentication** → Sign-in methods: Email/Password, Google
- **Firestore Database** → Start in production mode (rules are in `firebase/firestore.rules`)
- **Storage** → Start in production mode (rules are in `firebase/storage.rules`)
- **Cloud Messaging** (FCM) — enabled by default
- **Analytics** — enabled by default
- **Crashlytics** — enable in the console

## 3. Required Configuration Files

### Android (`apps/mobile`)

1. In Firebase Console → Project Settings → Your apps → Add app → Android
2. Package name: `com.snapspend.snapspend_mobile`
3. Download `google-services.json`
4. Place it at: `apps/mobile/android/app/google-services.json`

### iOS (`apps/mobile`)

1. In Firebase Console → Project Settings → Your apps → Add app → iOS
2. Bundle ID: `com.snapspend.snapspendMobile`
3. Download `GoogleService-Info.plist`
4. Place it at: `apps/mobile/ios/Runner/GoogleService-Info.plist`

### Web — Mobile App (`apps/mobile`)

1. In Firebase Console → Project Settings → Your apps → Add app → Web
2. Register the app with nickname "SnapSpend Mobile Web"
3. Create `apps/mobile/lib/firebase_options.dart` using FlutterFire CLI (see below)

### Web — Admin App (`apps/admin`)

1. In Firebase Console → Project Settings → Your apps → Add app → Web
2. Register the app with nickname "SnapSpend Admin"
3. Create `apps/admin/lib/firebase_options.dart` using FlutterFire CLI (see below)

## 4. Generate firebase_options.dart (Recommended Method)

Install the FlutterFire CLI:
```bash
dart pub global activate flutterfire_cli
```

For the mobile app:
```bash
cd apps/mobile
flutterfire configure --project=<your-firebase-project-id>
```

For the admin app:
```bash
cd apps/admin
flutterfire configure --project=<your-firebase-project-id>
```

This will generate `lib/firebase_options.dart` in each app, which is already imported in `main.dart`.

## 5. Deploy Firestore and Storage Rules

```bash
firebase deploy --only firestore:rules,storage
```

## 6. Deploy Cloud Functions

```bash
cd firebase/functions
npm run build
firebase deploy --only functions
```

## 7. Set Admin Custom Claims

To grant admin access to a user, use the Firebase Admin SDK or a Cloud Function:

```typescript
// Example: Set admin claim via Firebase Admin SDK
await admin.auth().setCustomUserClaims(uid, { admin: true });
```

Or use the Firebase Console's **Custom Claims** feature via a helper script.

## 8. Configure Stripe (for billing)

1. Create a [Stripe](https://stripe.com/) account
2. Add your Stripe secret key to Firebase Functions config:
   ```bash
   firebase functions:config:set stripe.secret="sk_live_..."
   firebase functions:config:set stripe.webhook_secret="whsec_..."
   ```
3. Create a Stripe webhook pointing to your `stripeWebhook` Cloud Function URL

## 9. Configure Exchange Rate API

The `exchangeRateSync` function fetches live FX rates. Set your API key:
```bash
firebase functions:config:set exchangerate.api_key="your-api-key"
```

Recommended provider: [ExchangeRate-API](https://www.exchangerate-api.com/) (free tier available).

## File Summary

| File | Location | Source |
|------|----------|--------|
| `google-services.json` | `apps/mobile/android/app/` | Firebase Console → Android app |
| `GoogleService-Info.plist` | `apps/mobile/ios/Runner/` | Firebase Console → iOS app |
| `firebase_options.dart` (mobile) | `apps/mobile/lib/` | FlutterFire CLI |
| `firebase_options.dart` (admin) | `apps/admin/lib/` | FlutterFire CLI |

**None of these files should be committed to version control.** They are already in `.gitignore`.
