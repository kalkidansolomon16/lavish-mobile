# Lavish — client & student app (Flutter)

The mobile app for Lavish Medical Spa clients and Lavish Academy students. It uses the same Laravel API
as the web portal (`../lavish_backend`, guide in `../lavish_backend/docs/API.md`).

## Point it at the server

The API address is set when you build:

```bash
flutter run --dart-define=API_URL=https://api.lavishmedicalspa.com/api/v1
```

Without `API_URL` the app uses your PC's local backend: `http://10.0.2.2:8000/api/v1` on the Android
emulator, `http://127.0.0.1:8000/api/v1` elsewhere. Start that with `php artisan serve` in `lavish_backend`.

## Run and build

```bash
flutter pub get
flutter run                                   # on a connected phone / emulator
flutter build apk --release --dart-define=API_URL=https://…/api/v1        # Android APK
flutter build appbundle --release --dart-define=API_URL=https://…/api/v1  # Play Store
flutter build ipa --release --dart-define=API_URL=https://…/api/v1        # App Store (on a Mac)
```

Before publishing: set a release signing key in `android/app/build.gradle.kts`, replace the default app icon,
and use an `https` API address (Android blocks plain `http` in release builds).

## What is in the app

| Area | Screens |
|---|---|
| Sign-in | Welcome, log in (client / student), sign up with SMS code, forgot password, student's first password |
| Client tabs | Home · Doctors · Lavish Rewards · Shop · Chat · Profile |
| Booking | Clinic or online, treatment, branch, live free times, vouchers & gift cards, review & confirm |
| Payments | Pay any way (Telebirr, CBE, bank, cash) and upload the receipt; reception checks it. Chapa appears automatically when the backend turns online payments on |
| Rewards | Points & tier card, reward catalog, vouchers, ways to earn, points history, refer a friend, tier-up screen |
| Gift cards | My cards, buy a card for someone, add a card by number or by scanning the barcode on a printed card |
| Shop | Products, bag, checkout (pay on delivery or pay and upload a receipt), order tracking |
| Care | Appointments, prescriptions ("order all items"), help & complaints with photos, notifications |
| Student tabs | Home (progress, classes) · Courses · Teacher chat · Profile; my course (5 weekly modules), lessons with video & exercise hand-in, certificate |

Phone fields have a country-code picker (Ethiopia first); numbers are sent in international format.

## Phone notifications

**Medicine reminders** are scheduled on the phone itself, from the times the doctor sets on a prescription,
so they work without internet and without any setup.

**Updates**, such as a booking approved, a payment received, an order on the way, a new message, points earned or an
appointment reminder (the evening before and 2 hours before), reach the phone in two ways:

1. **Without Firebase (works now):** while the app is open it checks every minute, and again whenever it is opened.
   New updates pop up as phone notifications.
2. **With Firebase (recommended for the live app):** updates arrive instantly, even when the app is closed.

### Turning on Firebase (one time)

1. Go to <https://console.firebase.google.com>, choose **Add project** and name it, for example `Lavish`.
2. **Add an Android app.** The package name is `et.lavish.lavish`. You don't need to download `google-services.json`.
3. **Collect four values.** Open **Project settings → General**. Under "Your apps" copy the **App ID**
   (`1:…:android:…`). From the same page copy the **Project ID**, the **Web API key** and, under
   **Cloud Messaging**, the **Sender ID**.
4. **Create a server key.** Open **Project settings → Service accounts → Generate new private key**. A JSON file
   downloads. Put it on the server as `lavish_backend/storage/app/firebase.json`. Never share or commit this file.
5. **Switch the server to Firebase.** In the server's `.env` set:
   ```
   PUSH_DRIVER=fcm
   FIREBASE_CREDENTIALS=storage/app/firebase.json
   ```
   then run `php artisan config:clear`.
6. **Build the app with the four values:**
   ```bash
   flutter build apk --release \
     --dart-define=API_URL=https://…/api/v1 \
     --dart-define=FIREBASE_PROJECT_ID=lavish-xxxx \
     --dart-define=FIREBASE_SENDER_ID=123456789012 \
     --dart-define=FIREBASE_API_KEY=AIza… \
     --dart-define=FIREBASE_ANDROID_APP_ID=1:123456789012:android:abc123
   ```
7. **For iPhone:** also add an iOS app in Firebase (bundle ID from Xcode) and upload an Apple Push Notifications
   key (APNs) under **Project settings → Cloud Messaging**. Then build with `--dart-define=FIREBASE_IOS_APP_ID=…`.

After signing in, the app registers the phone with the server automatically. Signing out removes it.

## Code layout

```
lib/core      api client (Dio, bearer token), session, router (go_router), theme, formatting
lib/widgets   shared UI (buttons, cards, badges, loaders, dialogs, phone field)
lib/features  auth · client (home, doctors, booking, appointments, payments, rewards, gift cards, shop, care)
              common (chat, notifications, profile) · student
```

## Test accounts (demo data only)

Load demo data on a test backend with `php artisan db:seed --class=DemoSeeder` (never on the live server).
Password `password` for all: client `0911223344`, student `0912456789`. SMS codes in development are `123456`.
