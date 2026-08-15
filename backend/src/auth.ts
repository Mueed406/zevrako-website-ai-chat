import { createSecretKey, randomUUID } from 'node:crypto';
import type { NextFunction, Request, Response } from 'express';
import type { Auth } from 'firebase-admin/auth';
import { SignJWT, jwtVerify } from 'jose';
import { AppError } from './errors.js';
import type { VisitorClaims } from './types.js';

declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express { interface Request { visitor?: VisitorClaims; operator?: { uid: string; workspaceIds: string[] }; requestId: string; } }
}

export class SessionService {
  private readonly key;
  constructor(secret: string) { this.key = createSecretKey(Buffer.from(secret)); }
  async issue(claims: VisitorClaims) { return new SignJWT({ ...claims }).setProtectedHeader({ alg: 'HS256' }).setSubject(claims.visitorId).setIssuedAt().setExpirationTime('30m').setJti(randomUUID()).setAudience('zevrako-widget').setIssuer('zevrako-chat-backend').sign(this.key); }
  async verify(token: string): Promise<VisitorClaims> {
    try {
      const { payload } = await jwtVerify(token, this.key, { audience: 'zevrako-widget', issuer: 'zevrako-chat-backend' });
      return { visitorId: String(payload.visitorId), workspaceId: String(payload.workspaceId), siteId: String(payload.siteId), conversationId: payload.conversationId ? String(payload.conversationId) : undefined };
    } catch { throw new AppError('invalid_visitor_session', 'The visitor session is invalid or expired.', 401); }
  }
}

function bearer(req: Request) { const value = req.header('authorization'); return value?.startsWith('Bearer ') ? value.slice(7) : null; }
export function visitorAuth(sessions: SessionService) { return async (req: Request, _res: Response, next: NextFunction) => { try { const token = bearer(req); if (!token) throw new AppError('visitor_session_required', 'A visitor session is required.', 401); req.visitor = await sessions.verify(token); next(); } catch (e) { next(e); } }; }
export function operatorAuth(auth: Auth) { return async (req: Request, _res: Response, next: NextFunction) => { try { const token = bearer(req); if (!token) throw new AppError('operator_session_required', 'An operator session is required.', 401); const decoded = await auth.verifyIdToken(token, true); if (decoded.websiteChatOperator !== true) throw new AppError('operator_permission_denied', 'Operator permission is required.', 403); req.operator = { uid: decoded.uid, workspaceIds: Array.isArray(decoded.websiteChatWorkspaceIds) ? decoded.websiteChatWorkspaceIds.map(String) : [] }; next(); } catch (e) { next(e); } }; }
export function requireWorkspace(req: Request, workspaceId: string) { if (!req.operator?.workspaceIds.includes(workspaceId)) throw new AppError('workspace_permission_denied', 'You do not have access to this workspace.', 403); }
