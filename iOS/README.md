# iOS Platform Setup

This folder is a platform bootstrap helper.

To generate a real Flutter iOS project (compiler-ready):

1. Install Flutter SDK.
2. Use macOS with Xcode installed.
3. From project root (`d:\Cursor\Palm_Reader`) run:
   - `flutter create .`
4. On macOS then run:
   - `cd ios`
   - `pod install`

Flutter will generate required files:
- `ios/Runner.xcodeproj`
- `ios/Runner.xcworkspace`
- `ios/Podfile`
- `ios/Runner/Info.plist`
- `ios/Runner/AppDelegate.swift`

Important:
- iOS compilation cannot be completed on Windows.
- You can still keep Dart UI/frontend code on Windows and build iOS on macOS CI or Mac.
