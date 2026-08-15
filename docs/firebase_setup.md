# Firebase setup

## Reused development configuration

The existing project is `zevrako-auto-reply-ai-dev`. The generated Windows FlutterFire client values from the existing Zevrako app were reused in `windows_app/lib/firebase_options.dart`. Android and Apple files were deliberately not copied because this product currently targets Windows only. If those platforms are added, copy only the existing client files (`google-services.json` or `GoogleService-Info.plist`) for the matching environment—not backend credentials.

Emulator ports remain Auth `9099`, Firestore `8080`, UI `4000`, with single-project mode. App Check is not activated on Windows because FlutterFire App Check does not provide a compatible Windows provider. Enforce App Check at supported future clients and keep backend token/domain/rate-limit controls in place.

## New namespaces

`websiteChatWorkspaces`, `websiteChatSites`, `websiteChatVisitors`, `websiteChatConversations` (with `messages`), `websiteChatKnowledge`, `websiteChatOperators`, `websiteChatUsage`, and `websiteChatIntegrationHealth` are additive. The backend also owns private conversation subcollections such as `internalNotes`, `aiSuggestions`, and `idempotency`; client rules deny them.

## Existing collections documented before extension

The inspected rules contain `users`, `accounts`, `activationRequests`, `onboarding`, `workspaceSettings`, `migrations`, `oauthStates`, `workspaceVaults`, `whatsappPhoneMappings`, `providerCredentials`, `providerAuthorizationSessions`, `integrationAuditPrivate`, and `workspaces/{workspaceId}/members|integrations`. The final catch-all remains deny-all. None were renamed or overwritten.

## Run and deploy

```sh
cd firebase
firebase emulators:start --only auth,firestore
firebase deploy --only firestore:rules,firestore:indexes --project zevrako-auto-reply-ai-dev
```

Deploy rules only after both the website-chat emulator tests and the existing Zevrako Flutter/rules tests pass. For the Windows emulator build:

```powershell
flutter run -d windows `
  --dart-define=ZEVRAKO_WEBSITE_CHAT_WORKSPACE_ID=workspace-id `
  --dart-define=ZEVRAKO_USE_FIREBASE_EMULATORS=true `
  --dart-define=ZEVRAKO_BACKEND_URL=http://127.0.0.1:8787
```

Staging/production require `ZEVRAKO_FIREBASE_*` compile-time client values and a matching `ZEVRAKO_FIREBASE_ENVIRONMENT`. Mismatches stop startup; they never fall back to development or sample data.
