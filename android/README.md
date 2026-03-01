# Android Platform Setup

This folder is a platform bootstrap helper.

To generate a real Flutter Android project (compiler-ready):

1. Install Flutter SDK.
2. From project root (`d:\Cursor\Palm_Reader`) run:
   - `flutter create .`
3. Flutter will generate the required `android/` folder with Gradle files:
   - `android/build.gradle.kts` or `android/build.gradle`
   - `android/settings.gradle.kts` or `android/settings.gradle`
   - `android/app/build.gradle.kts` or `android/app/build.gradle`
   - `android/app/src/main/AndroidManifest.xml`
   - `android/app/src/main/kotlin/.../MainActivity.kt`
   - Gradle wrapper and plugin config

Why this is required:
- Android compiler support depends on generated Gradle + Flutter plugin wiring.
- Hand-creating partial files is unreliable and usually fails at build time.
