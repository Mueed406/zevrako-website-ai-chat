# Zevrako Website AI Chat

Independent, website-chat-only product with a Flutter Windows operator inbox, embeddable JavaScript widget, trusted Node.js API, Firestore synchronization, and backend-only Gemini integration. It does not depend on or modify the existing multi-channel Zevrako source tree.

## Repository

- `windows_app/` — Flutter/Riverpod Windows inbox. Firebase is the default; sample data requires an explicit compile flag.
- `widget/` — responsive, accessible IIFE bundle for customer websites.
- `backend/` — versioned Express API, Firebase Admin storage/auth verification, signed visitor sessions, and Gemini boundary.
- `firebase/` — additive rules, indexes, emulator config, and rules tests.
- `docs/` — deployment, security, installation, and release details.

The development Firebase client points to the existing `zevrako-auto-reply-ai-dev` project. No service-account JSON, administrator private key, backend environment file, Gemini key, access token, or refresh token is stored here.

## Local development

1. Start Firebase emulators: `cd firebase && firebase emulators:start --only auth,firestore`.
2. Copy `backend/.env.example` to an ignored `backend/.env`, replace the visitor signing secret, and use Application Default Credentials or the emulators. The Gemini key is optional until AI is tested.
3. Run `cd backend && npm install && npm run dev`.
4. Run `cd widget && npm install && npm run build`; serve `widget/demo/` from an allowed domain.
5. On Windows, run the Flutter app with the workspace and emulator flags shown in [Firebase setup](docs/firebase_setup.md).

Without `ZEVRAKO_SAMPLE_DATA=true`, Firebase/backend failures remain visible and the app never falls back to fake cloud activity.

## Validation

```sh
cd backend && npm run lint && npm run typecheck && npm test && npm run build
cd widget && npm run lint && npm run typecheck && npm test && npm run build
cd firebase/rules-tests && npm test
cd windows_app && dart format . && flutter analyze && flutter test
# Windows host only:
cd windows_app && flutter build windows --release
```

See [Architecture](docs/architecture.md), [Security boundaries](docs/security_boundaries.md), and [Current limitations](docs/architecture.md#current-limitations).
