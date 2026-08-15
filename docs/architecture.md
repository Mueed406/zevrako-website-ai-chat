# Architecture

```text
Customer website -> Widget -> HTTPS backend -> Firestore
                              |             -> Gemini API
                              |                 (secret manager key)
Windows inbox -> Firebase Auth + Firestore snapshots
              -> HTTPS backend for all writes and AI actions
```

The widget obtains public display configuration, then exchanges public workspace/site IDs plus its verified origin for a 30-minute backend-signed visitor token. A conversation token is additionally bound to one visitor, workspace, site, and conversation. The browser never receives a Firebase operator credential or a Gemini credential.

The Windows app silently creates a Firebase development-device session behind `DeviceSessionRepository`. A backend administrator must provision that UID with the narrow `websiteChatOperator: true` and `websiteChatWorkspaceIds: [...]` custom claims. Anonymous identity alone grants nothing. Reads use Firestore snapshots; writes use the backend for validation, idempotency, and audit boundaries.

Firestore documents use stable IDs and server timestamps. Message creation and its idempotency receipt are committed in one transaction. Internal notes and AI suggestions are private subcollections and are not returned by widget endpoints.

## Current limitations

- A Windows release build must be produced and smoke-tested on a Windows host; Flutter does not cross-compile Windows desktop binaries from macOS.
- Desktop notifications, business-hours editing, assignment, visitor blocking, and full knowledge-management screens are represented in the domain/API boundary but need operational UI completion before production launch.
- The in-process API rate limiter must be replaced by a distributed store or gateway limiter for horizontally scaled deployment.
- Visitor message delivery is polled every four seconds. A production deployment may replace polling with a backend-authorized realtime channel.
- The provided backend is a deployment-ready service shape, not an already-deployed endpoint. End-to-end cloud behavior requires site/workspace provisioning, operator claims, indexes, rules deployment, and secrets.
