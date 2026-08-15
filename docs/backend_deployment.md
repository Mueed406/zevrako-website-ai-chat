# Backend deployment

Use a Node 22+ managed platform with HTTPS, a non-root runtime, Application Default Credentials scoped to the reused Firebase project, and an encrypted secret manager.

Required runtime values are documented in `backend/.env.example`. Set a high-entropy `VISITOR_SESSION_SECRET`; inject `GEMINI_API_KEY` from the platform secret manager; configure `ALLOWED_OPERATOR_ORIGINS`; and set `TRUST_PROXY=true` only behind a trusted proxy. Never bake `.env` into an image.

Build with `npm ci && npm run build`, run `node dist/server.js`, and probe `/v1/health`. The health response reports configured state but never returns secrets. Rotate the visitor secret with an overlap strategy if uninterrupted visitor sessions matter.

The runtime identity needs only the Firestore/Auth permissions required for website-chat operations. Do not ship a service-account JSON file. Configure logs to redact authorization headers and request bodies at the ingress layer.
