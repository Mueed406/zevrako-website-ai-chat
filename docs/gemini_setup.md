# Gemini setup

Create the Gemini credential in the provider console and store it only in the backend platform's encrypted secret manager as `GEMINI_API_KEY`. The backend uses Google's official `@google/genai` SDK. Model selection is the safe `GEMINI_MODEL` environment value; temperature and output length are bounded per request.

The app's confidence percentage is explicitly application-calculated from knowledge coverage, ambiguity, validation, and fallback detection. It is not represented as a native Gemini confidence score.

To rotate the key, create a replacement, update the secret-manager version, deploy/restart backend instances, call the authenticated integration test endpoint, confirm safe integration health metadata, then revoke the old key. Never paste the key into source, Firestore, the widget, Windows build flags, logs, or support tickets.

Automated tests use mocks or invalid local clients and never make a paid successful generation request.
