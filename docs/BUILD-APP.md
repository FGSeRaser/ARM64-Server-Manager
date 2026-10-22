# Build the app

Requirements: Flutter (stable), Android SDK (cmdline-tools + accepted licenses: `flutter doctor --android-licenses`).

```
flutter create --org com.arm64.servermanager --project-name android_app android_app   # only if you start from scratch
```
Then copy the files from this repo's `android_app/` over your project:
- `lib/main.dart`
- `android/app/src/main/AndroidManifest.xml` (contains INTERNET, foreground-service permissions and the service entry)
- `android/build.gradle.kts`
- `android/app/src/main/res/mipmap-*/ic_launcher.png` (launcher icon)
- `assets/logo.png`

### pubspec.yaml
```yaml
dependencies:
  flutter:
    sdk: flutter
  file_picker: ^13.1.0
  path_provider: ^2.1.0
  flutter_foreground_task: ^11.0.3

flutter:
  uses-material-design: true
  assets:
    - assets/logo.png
```

### android/app/build.gradle.kts
`targetSdk = 28` is deliberate: from Android 10 on, apps targeting API 29+ may not execute files in their data directory, which proot/box64 need. Keep `minSdk` as Flutter's default and add:
```kotlin
lint { disable.add("ExpiredTargetSdkVersion") }
```
(Apps with such a low target SDK cannot be published on Google Play; distribution is via GitHub/APK.)

### Build
```
flutter clean
flutter pub get
flutter build apk --release
```
Output: `build/app/outputs/flutter-apk/app-release.apk`. For public releases sign the APK with your own keystore (https://docs.flutter.dev/deployment/android#sign-the-app).

Set `_defaultBedrockUrl` in `lib/main.dart` to your own release URL before building.
