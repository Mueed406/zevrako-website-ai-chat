# Windows release

Install the current stable Flutter SDK plus Visual Studio with Desktop development with C++. From a Windows terminal:

```powershell
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter build windows --release `
  --dart-define=ZEVRAKO_ENV=production `
  --dart-define=ZEVRAKO_FIREBASE_ENVIRONMENT=production `
  --dart-define=ZEVRAKO_WEBSITE_CHAT_WORKSPACE_ID=workspace-id `
  --dart-define=ZEVRAKO_BACKEND_URL=https://api.example.com `
  --dart-define-from-file=ignored-production-firebase.json
```

The define file contains only Firebase client identifiers, must be ignored, and must never contain the Gemini key. Package `build/windows/x64/runner/Release` with an MSIX or signed installer in the deployment pipeline. Sign the executable/installer, test upgrade and uninstall behavior, then smoke-test real Firebase sync on a physical Windows device. A successful build alone is not installed-device validation.
