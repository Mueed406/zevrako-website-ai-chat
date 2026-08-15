# Security boundaries

- Gemini keys exist only in the deployment secret manager or server process environment. They are never written to Firestore, clients, logs, analytics, error bodies, or build definitions.
- Firebase client configuration identifies the project and is intentionally shipped in the Windows client. Authorization comes from Auth claims, rules, and backend checks.
- Widget sessions are signed, expire after 30 minutes, and bind visitor, site, workspace, and conversation. Public IDs select a site; they do not authorize data access.
- Allowed domains are checked server-side against the site document. Wildcards match subdomains only.
- Widget endpoints expose message-safe fields only. Internal notes, operators, workspace-wide visitors, AI configuration, and integration health are absent.
- Operator endpoints verify Firebase ID tokens and require both the operator flag and a matching workspace claim. Development-device users are not administrators and an unprovisioned anonymous UID has no access.
- Firestore visitors have no direct access. Scoped operators have read-only realtime access; all writes pass through Firebase Admin in the trusted backend.
- Requests have size limits, schema validation, bounded message length, request IDs, rate limits, HTTPS enforcement in production, and typed non-sensitive errors.
- Gemini prompts remove common email/phone patterns and include enabled knowledge only. Diagnostics log request ID and safe error category, not prompt text.

Production hardening should add a managed distributed rate limiter, WAF/bot controls, secret-manager injection, audit retention policy, CSP/SRI hosting strategy, App Check on supported clients, and monitoring alerts.
