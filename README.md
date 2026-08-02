# CloudBox — Flutter Client (Android, iOS, Web)

A complete cross-platform app for the CloudBox backend: Firebase email/password auth, folder
navigation with breadcrumbs, file upload with progress, download/open, rename, move, delete,
search, category filters, and live storage-quota display — all three targets (Android, iOS, Web)
share the exact same Dart code in `lib/`, with platform differences isolated to one small file.

This app is written against the **exact API contract** of the `cloudbox-backend` project — same
auth flow (Firebase ID token → `/api/auth/login` sync), same endpoints, same response shapes
(including the `size`/`storageUsed`/`storageLimit` fields the backend serializes as strings
because they're Prisma `BigInt`s).

## 1. Prerequisites

- Flutter SDK 3.22+ (`flutter --version`) — includes Dart 3.3+
- For Android: Android Studio / SDK, an emulator or device
- For iOS: a Mac with Xcode 15+, CocoaPods (`sudo gem install cocoapods`), a simulator or device
- For Web: any modern browser (Chrome recommended for `flutter run -d chrome`)
- The CloudBox backend running somewhere reachable from your device/browser (see the backend's
  own README)
- A Firebase project — **the same one your backend's `firebase-admin` service account belongs
  to**, since the backend verifies ID tokens against that project

```bash
flutter pub get
```

## 1a. REQUIRED FIRST STEP: generate the Gradle wrapper jar (Android)

`android/gradle-wrapper.jar` is a **compiled binary**, not source code — it can't be authored by
hand, so it isn't included here. Without it, `assembleDebug` (and every other Android Gradle
task) fails immediately, before any of your code even gets compiled. `gradlew`/`gradlew.bat` and
`gradle-wrapper.properties` **are** included and already point at Gradle 8.6, matching this
project's AGP/Kotlin versions — you just need the one binary that goes with them:

```bash
# From the project root - regenerates only what's missing (the jar), leaving
# your build.gradle/settings.gradle/AndroidManifest.xml untouched:
flutter create --platforms=android .
```

If that reports any conflicts, keep **your** existing files (this project's) when prompted — it
should only need to *add* the missing wrapper jar, not replace anything.

Alternative, if you have Gradle installed locally (`gradle -v`):

```bash
cd android
gradle wrapper --gradle-version 8.6
cd ..
```

Opening the project in Android Studio and letting it sync will also regenerate this file
automatically.

If you skip this step, expect exactly the failure this project shipped with:
`Gradle task assembleDebug failed with exit code 1`, with the real cause (something like
"Error: Unable to access jarfile .../gradle-wrapper.jar" or "Could not find or load main class
org.gradle.wrapper.GradleWrapperMain") visible if you run
`cd android && ./gradlew assembleDebug --stacktrace` directly instead of through `flutter run`.

## 2. Firebase setup (shared across all three platforms)

1. In the [Firebase Console](https://console.firebase.google.com), open the **same project**
   your backend's service account JSON belongs to.
2. **Authentication → Sign-in method** → enable **Email/Password**.
3. Register each platform you plan to build for (see per-platform notes below).
4. Generate `lib/firebase_options.dart` for real (the checked-in one is a non-functional
   placeholder covering all three platforms with dummy values):
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure --platforms=android,ios,web
   ```
   This walks you through registering/selecting each platform's Firebase app and overwrites
   `lib/firebase_options.dart` with real values. It also writes/updates
   `android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist` for you.

Without this step, every sign-in/sign-up call fails immediately with a Firebase configuration
error — on every platform.

## 3. Point the app at your backend

The API base URL is a compile-time constant (`lib/core/config/app_config.dart`), overridable
with `--dart-define`:

```bash
# Android emulator reaching a backend on your host machine's localhost:
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000/api

# iOS simulator reaching a backend on your host machine's localhost:
flutter run --dart-define=API_BASE_URL=http://localhost:5000/api

# Physical device (Android or iOS) on the same Wi-Fi as your backend:
flutter run --dart-define=API_BASE_URL=http://192.168.1.50:5000/api

# Web (flutter run -d chrome), backend on localhost:
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:5000/api

# Deployed backend:
flutter run --dart-define=API_BASE_URL=https://api.yourdomain.com/api
```

If you omit `--dart-define`, it defaults to `http://10.0.2.2:5000/api` (Android emulator only) —
override it for iOS/Web/physical devices.

**Web + CORS:** the backend's `cors` middleware only allows the origin(s) in its `CLIENT_ORIGIN`
env var. Set that to wherever `flutter run -d chrome` / your deployed web build is served from
(e.g. `http://localhost:PORT` in dev), or requests will fail with a CORS error the browser
console will show clearly.

**Web + S3/MinIO downloads:** if the backend is running `STORAGE_DRIVER=s3`, file downloads
302-redirect to a presigned bucket URL. On mobile that's transparent; in a browser, the bucket
itself also needs CORS configured to allow `GET` from your web app's origin, or the download
will fail after the redirect. Not an issue with the default local-disk driver, since that streams
through the API directly.

## 4. Android

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000/api
flutter build apk --release --dart-define=API_BASE_URL=https://api.yourdomain.com/api
```

Package name / `applicationId`: `com.cloudbox.app` (`android/app/build.gradle`). The release
build config signs with the **debug** keystore so `flutter build apk --release` works out of the
box — replace `signingConfigs.release` with a real keystore before publishing.

`AndroidManifest.xml` sets `android:usesCleartextTraffic="true"` so you can hit a plain `http://`
backend during development. Remove that (or scope it to a network security config for your dev
host only) before shipping a release build against a non-HTTPS backend.

## 5. iOS

The `ios/` folder here ships the three files that need custom content (`Info.plist`,
`AppDelegate.swift`, `Podfile`) but **not** `Runner.xcodeproj` itself — hand-writing a `.pbxproj`
is fragile and error-prone even for experienced iOS devs; it's meant to be generated by tooling.
On a Mac, from the project root:

```bash
flutter create --platforms=ios .
```

This generates `ios/Runner.xcodeproj` and the rest of the standard scaffold **without touching
`lib/`**. It will *not* overwrite the `Info.plist`, `AppDelegate.swift`, or `Podfile` already in
this project — if it does prompt to overwrite, keep the ones from this project (they're
pre-configured with the app name and a dev-mode HTTP allowance).

Then:

1. Open `ios/Runner.xcworkspace` in Xcode (after `pod install`, see below).
2. Replace `ios/Runner/GoogleService-Info.plist.example` with your real
   `GoogleService-Info.plist` from Firebase Console (bundle ID `com.cloudbox.app`) — **add it via
   Xcode** (right-click `Runner` → *Add Files to "Runner"...*), not just by copying the file on
   disk, so it's actually registered in the project and bundled into the app.
3. Install pods:
   ```bash
   cd ios && pod install && cd ..
   ```
4. Run:
   ```bash
   flutter run --dart-define=API_BASE_URL=http://localhost:5000/api
   ```

`Info.plist` includes an `NSAppTransportSecurity` / `NSAllowsArbitraryLoads` entry so plain
`http://` works against a dev backend — remove it before shipping a release build against a
non-HTTPS backend.

Minimum iOS version is 13.0 (`ios/Podfile`), which is what current Firebase iOS SDKs require.

## 6. Web

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:5000/api
flutter build web --release --dart-define=API_BASE_URL=https://api.yourdomain.com/api
```

Firebase Web setup: register a **Web app** in Firebase Console (Project settings → Your apps →
</> icon) — `flutterfire configure --platforms=web` does this for you and writes the `web`
section of `firebase_options.dart`. No manual `<script>` tags are needed in `web/index.html`;
`firebase_core`'s web implementation injects the Firebase JS SDK itself.

See the CORS notes in section 3 — Web is the one platform where the browser enforces
cross-origin rules, so both the backend's `CLIENT_ORIGIN` and (if using the S3 driver) the
bucket's CORS config need to allow your web app's origin.

## 7. What's implemented

- **Auth:** email/password sign up, sign in, sign out, password reset — all via Firebase, synced
  to the backend's `User` table via `POST /auth/login` on every sign-in (per the backend's
  contract, since every other endpoint requires that row to exist)
- **Browsing:** breadcrumb folder navigation, folders shown as horizontal cards, files as a
  paginated list (infinite scroll against the backend's `page`/`limit`/`totalPages`)
- **Search & filter:** text search and category filter (`IMAGE`/`VIDEO`/`PDF`/`DOCUMENT`/`OTHERS`),
  both passed straight through as query params
- **Upload:** multi-file picker → multipart upload (bytes-based, so it works identically on
  Android/iOS/Web — see "Cross-platform notes" below) with a live progress banner; works against
  either the backend's local-disk or S3/MinIO storage driver transparently
- **Download:** fetched into memory, then handed to a small platform-specific "save" step (see
  below) — writes to the app's sandboxed storage and opens with the system viewer on
  Android/iOS, triggers a normal browser download on Web
- **Image preview:** in-app pinch-to-zoom viewer for image files (full-resolution fetch; the
  backend has no thumbnail endpoint)
- **CRUD:** rename/move/delete for both files and folders, including a dedicated folder-picker
  screen for "Move"
- **Quota:** live storage-used/limit bar on the home screen and profile screen, refreshed after
  every upload

## 8. Cross-platform notes (why the code is structured this way)

Two things Android/iOS can do that a browser fundamentally cannot: read a picked file by its
filesystem **path**, and write an arbitrary file to disk. The app avoids ever depending on
either:

- **Uploads** always request file **bytes** from the picker (`FilePicker.platform.pickFiles(withData: true)`)
  and send them with `MultipartFile.fromBytes(...)`, never `.fromFile(path)`. `PlatformFile.path`
  is always `null` on Web, so this is the one implementation that works everywhere.
- **Downloads** always fetch into memory (`FileService.downloadBytes`), then hand the bytes to
  `lib/core/utils/save_file/save_file.dart`, which resolves to a different implementation per
  platform **at compile time** via conditional imports:
  - `save_file_io.dart` (`dart.library.io`, i.e. Android/iOS/desktop): writes to the app's
    sandboxed documents directory (no runtime storage permission needed) and opens it with
    `open_filex`.
  - `save_file_web.dart` (`dart.library.html`, i.e. Web): creates a `Blob` and clicks a
    programmatic anchor tag to trigger the browser's native download — there's no filesystem to
    write to and nothing to "open" separately.

  Every call site (`home_screen.dart`, `image_preview_screen.dart`) just calls
  `saveAndOpenBytes(bytes, fileName, mimeType: ...)` and never branches on platform itself.

This is also why `permission_handler` isn't a dependency here: writing to the app's own
sandboxed directory doesn't need a storage permission on modern Android/iOS, so there was nothing
for it to do.

## 9. Project structure

```
lib/
  core/
    config/       # API base URL, timeouts
    network/      # Dio client (auth header injection, 401 retry, error mapping)
    theme/        # Material 3 theme
    utils/        # byte/date formatting, form validators, save_file/ (platform-conditional)
  models/         # AppUser, CloudFolder, CloudFile, FileCategory, PaginatedFiles
  services/       # AuthService, FolderService, FileService — one method per backend endpoint
  providers/      # AuthProvider, BrowserProvider (navigation/CRUD state), UploadProvider
  screens/
    splash/       auth/        home/ (+ widgets/, folder_picker_screen)
    preview/      profile/
  widgets/        # EmptyState, ErrorState, LoadingView, confirm/prompt dialogs
  app.dart        # MultiProvider + auth-based routing
  main.dart       # Firebase init + runApp
  firebase_options.dart   # placeholder — regenerate with flutterfire configure
android/          # Gradle project (Firebase via google-services.json)
ios/              # Info.plist / AppDelegate.swift / Podfile only — see section 5
web/              # index.html, manifest.json, icons
```

## 10. Known limitations / good next steps

- **Email/password only.** Google Sign-In is a natural add-on (`google_sign_in` package +
  enabling the provider in Firebase Console + wiring `FirebaseAuth.signInWithCredential`) but
  isn't included here to keep the Firebase setup to a single provider across three platforms.
- **No thumbnails.** The backend doesn't generate them, so image previews fetch the full file.
- **No offline cache.** Every screen re-fetches from the API; there's no local persistence layer.
- **No shared/link-based access** — matches the backend, which doesn't have that feature yet
  either.
- **Move-into-descendant is only prevented server-side.** The folder picker doesn't pre-filter
  out descendants of the folder being moved (only the folder itself); an invalid move just
  surfaces the backend's validation error in a SnackBar rather than being disabled up front.
- **Whole file loaded into memory** for both upload and download (see section 8). Fine given the
  backend's 100MB default max file size; would need a streaming rework for much larger files.

## 11. Troubleshooting

- **`Gradle task assembleDebug failed with exit code 1` (Android, right after unzipping)** → see
  section 1a — you're almost certainly missing `android/gradle/wrapper/gradle-wrapper.jar`. Run
  `cd android && ./gradlew assembleDebug --stacktrace` directly (instead of through `flutter run`)
  to see the real underlying error if this doesn't fix it.
- **Same error, but section 1a is already done** → next most likely cause is
  `android/app/google-services.json` still being the `.example` placeholder. The build is set up
  to warn (not fail) about this — check the Gradle output for a `[CloudBox] ... is missing`
  warning to confirm, then see section 2.
- **"DefaultFirebaseOptions have not been configured..."** → you skipped `flutterfire configure`;
  see section 2.
- **Every request 401s** → check the Firebase project used by `flutterfire configure` matches the
  one your backend's service account JSON belongs to.
- **Connection refused / timeout from the Android emulator** → use `10.0.2.2`, not `localhost`;
  the iOS simulator, by contrast, can use `localhost` directly since it shares the host's network.
- **CORS error in the browser console (Web only)** → see section 3.
- **Gradle sync fails on `google-services.json`** → you're still on the placeholder `.example`
  file; copy your real one to `android/app/google-services.json`.
- **Xcode can't find `GoogleService-Info.plist`** → you copied the file on disk but didn't add it
  via Xcode's "Add Files to Runner..."; see section 5, step 2.
