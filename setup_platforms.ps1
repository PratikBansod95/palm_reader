param(
  [switch]$PubGet
)

Write-Host "Generating platform folders with Flutter..."
flutter create .

if ($PubGet) {
  flutter pub get
}

Write-Host "Done. Use 'flutter run' for Android." 
Write-Host "For iOS: open on macOS and run pod install in ios/."
