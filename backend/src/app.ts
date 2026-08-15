import { randomUUID } from 'node:crypto';
import cors from 'cors';
import express from 'express';
import helmet from 'helmet';
import { z } from 'zod';
import type { Auth } from 'firebase-admin/auth';
import { AppError, safeError } from './errors.js';
import { operatorAuth, requireWorkspace, SessionService, visitorAuth } from './auth.js';
import { calculateSuggestion, type GeminiClient } from './gemini.js';
import { rateLimit } from './rate-limit.js';
import type { ChatStore } from './store.js';
import type { AppConfig } from './config.js';

const id = z.string().min(3).max(128).regex(/^[A-Za-z0-9_-]+$/);
const message = z.string().trim().min(1).max(4000);
const sessionSchema = z.object({ workspaceId: id, siteId: id, name: z.string().trim().min(1).max(120), email: z.string().email().max(254).optional(), origin: z.string().url() });
const conversationSchema = z.object({ pageUrl: z.string().url().max(2048).optional(), referrer: z.string().url().max(2048).optional() });
const statusSchema = z.object({ status: z.enum(['open', 'waiting', 'resolved', 'spam']) });

export function createApp(deps: { config: AppConfig; store: ChatStore; auth: Auth; gemini?: GeminiClient }) {
  const { config, store } = deps; const sessions = new SessionService(config.visitorSessionSecret); const app = express();
  app.set('trust proxy', config.trustProxy); app.disable('x-powered-by'); app.use(helmet()); app.use(express.json({ limit: '16kb' }));
  app.use((req, res, next) => { req.requestId = req.header('x-request-id')?.slice(0, 100) || randomUUID(); res.setHeader('x-request-id', req.requestId); if (config.nodeEnv === 'production' && req.protocol !== 'https') return next(new AppError('https_required', 'HTTPS is required.', 400)); next(); });
  app.use((req, res, next) => cors({ origin(origin, callback) { const widgetRoute = req.path.startsWith('/v1/widget/'); callback(null, !origin || widgetRoute || config.allowedOperatorOrigins.has(origin)); }, credentials: false })(req, res, next));
  app.get('/v1/health', (_req, res) => res.json({ status: 'ok', firebaseProjectId: config.firebaseProjectId, geminiConfigured: Boolean(config.geminiApiKey) }));
  app.post('/v1/widget/sessions', rateLimit(20, 60_000), asyncRoute(async (req, res) => { const body = sessionSchema.parse(req.body); validateClaimedOrigin(req, body.origin); const site = await store.getSite(body.workspaceId, body.siteId); if (!site?.enabled) throw new AppError('site_not_found', 'This chat site is unavailable.', 404); const hostname = new URL(body.origin).hostname.toLowerCase(); if (!site.allowedDomains.some((d) => domainMatches(hostname, d))) throw new AppError('origin_not_allowed', 'This website is not allowed to use chat.', 403); const visitorId = randomUUID(); await store.createVisitor(body.workspaceId, body.siteId, visitorId, body.name, body.email); res.status(201).json({ token: await sessions.issue({ visitorId, workspaceId: body.workspaceId, siteId: body.siteId }), visitorId, expiresInSeconds: 1800 }); }));
  app.get('/v1/widget/config', rateLimit(60, 60_000), asyncRoute(async (req, res) => { const workspaceId = id.parse(req.query.workspaceId); const siteId = id.parse(req.query.siteId); const site = await store.getSite(workspaceId, siteId); if (!site?.enabled) throw new AppError('site_not_found', 'This chat site is unavailable.', 404); const origin = z.string().url().parse(req.query.origin); validateClaimedOrigin(req, origin); if (!site.allowedDomains.some((d) => domainMatches(new URL(origin).hostname, d))) throw new AppError('origin_not_allowed', 'This website is not allowed to use chat.', 403); res.json({ businessName: site.businessName, greeting: site.greeting, themeColor: site.themeColor, position: site.position, aiDisclosure: site.aiDisclosure }); }));
  app.post('/v1/widget/conversations', visitorAuth(sessions), rateLimit(10, 60_000), asyncRoute(async (req, res) => { const body = conversationSchema.parse(req.body); const conversationId = randomUUID(); await store.createConversation({ id: conversationId, workspaceId: req.visitor!.workspaceId, siteId: req.visitor!.siteId, visitorId: req.visitor!.visitorId, ...body, userAgent: req.header('user-agent')?.slice(0, 500) }); res.status(201).json({ conversationId, token: await sessions.issue({ ...req.visitor!, conversationId }) }); }));
  app.get('/v1/widget/conversations/:id/messages', visitorAuth(sessions), asyncRoute(async (req, res) => { enforceConversation(req.visitor!, String(req.params.id)); res.json({ messages: sanitizeWidgetMessages(await store.listMessages(String(req.params.id))) }); }));
  app.post('/v1/widget/conversations/:id/messages', visitorAuth(sessions), rateLimit(30, 60_000), asyncRoute(async (req, res) => { const conversationId = String(req.params.id); enforceConversation(req.visitor!, conversationId); const body = z.object({ text: message, clientMessageId: id }).parse(req.body); const result = await store.addMessage(conversationId, { id: randomUUID(), role: 'visitor', text: body.text, senderId: req.visitor!.visitorId }, body.clientMessageId); const ai = result.duplicate ? undefined : await maybeAutoReply({ store, gemini: deps.gemini, conversationId, workspaceId: req.visitor!.workspaceId, siteId: req.visitor!.siteId, visitorMessage: body.text, model: config.geminiModel }); res.status(result.duplicate ? 200 : 201).json({ ...result, ai }); }));
  app.post('/v1/widget/conversations/:id/typing', visitorAuth(sessions), rateLimit(60, 60_000), asyncRoute(async (req, res) => { enforceConversation(req.visitor!, String(req.params.id)); const { typing } = z.object({ typing: z.boolean() }).parse(req.body); await store.updateTyping(String(req.params.id), 'visitor', typing); res.status(204).end(); }));

  const operator = operatorAuth(deps.auth);
  app.get('/v1/operator/conversations', operator, asyncRoute(async (req, res) => { const workspaceId = id.parse(req.query.workspaceId); requireWorkspace(req, workspaceId); const status = statusSchema.shape.status.optional().parse(req.query.status); res.json({ conversations: await store.listConversations(workspaceId, status) }); }));
  app.get('/v1/operator/conversations/:id/messages', operator, asyncRoute(async (req, res) => { const conversation = await requireOperatorConversation(req, store, String(req.params.id)); requireWorkspace(req, String(conversation.workspaceId)); res.json({ messages: await store.listMessages(String(req.params.id)) }); }));
  app.post('/v1/operator/conversations/:id/messages', operator, asyncRoute(async (req, res) => { const conversation = await requireOperatorConversation(req, store, String(req.params.id)); requireWorkspace(req, String(conversation.workspaceId)); const body = z.object({ text: message, clientMessageId: id }).parse(req.body); res.status(201).json(await store.addMessage(String(req.params.id), { id: randomUUID(), role: 'operator', text: body.text, senderId: req.operator!.uid }, body.clientMessageId)); }));
  app.post('/v1/operator/conversations/:id/status', operator, asyncRoute(async (req, res) => { const c = await requireOperatorConversation(req, store, String(req.params.id)); requireWorkspace(req, String(c.workspaceId)); const body = statusSchema.parse(req.body); await store.setStatus(String(req.params.id), body.status); res.status(204).end(); }));
  app.post('/v1/operator/conversations/:id/notes', operator, asyncRoute(async (req, res) => { const c = await requireOperatorConversation(req, store, String(req.params.id)); requireWorkspace(req, String(c.workspaceId)); const body = z.object({ text: message }).parse(req.body); await store.addNote(String(req.params.id), req.operator!.uid, body.text); res.status(201).json({ created: true }); }));
  app.post('/v1/operator/conversations/:id/tags', operator, asyncRoute(async (req, res) => { const c = await requireOperatorConversation(req, store, String(req.params.id)); requireWorkspace(req, String(c.workspaceId)); const body = z.object({ tags: z.array(z.string().trim().min(1).max(40)).max(20) }).parse(req.body); await store.setTags(String(req.params.id), [...new Set(body.tags)]); res.status(204).end(); }));
  app.post('/v1/operator/conversations/:id/ai-suggestion', operator, asyncRoute(async (req, res) => { if (!deps.gemini) throw new AppError('gemini_not_configured', 'The AI integration is not configured.', 503); const c = await requireOperatorConversation(req, store, String(req.params.id)); const workspaceId = String(c.workspaceId); requireWorkspace(req, workspaceId); const body = z.object({ message, tone: z.string().max(80).default('professional and helpful'), languages: z.array(z.string().max(30)).max(10).default(['English']), temperature: z.number().min(0).max(2).default(0.3), maxOutputTokens: z.number().int().min(32).max(2048).default(512), fallbackMessage: z.string().max(500).default('A human teammate will help you shortly.') }).parse(req.body); const knowledge = await store.enabledKnowledge(workspaceId); const history = (await store.listMessages(String(req.params.id))).map((m) => ({ role: String(m.role), text: String(m.text) })); const generated = await retry(() => deps.gemini!.generate({ ...body, history, knowledge }), 2); const suggestion = calculateSuggestion(generated, knowledge, config.geminiModel, body.fallbackMessage); await store.storeSuggestion(String(req.params.id), { ...suggestion, operatorId: req.operator!.uid }); res.json(suggestion); }));
  app.get('/v1/integrations/gemini/status', operator, (_req, res) => res.json({ configured: Boolean(config.geminiApiKey), model: config.geminiModel, secretExposed: false }));
  app.post('/v1/integrations/gemini/test', operator, asyncRoute(async (_req, res) => { if (!deps.gemini) throw new AppError('gemini_not_configured', 'The AI integration is not configured.', 503); await deps.gemini.generate({ message: 'Reply with OK.', history: [], knowledge: [], tone: 'brief', languages: ['English'], maxOutputTokens: 16, temperature: 0 }); res.json({ verified: true, testedAt: new Date().toISOString(), model: config.geminiModel }); }));
  app.use((_req, _res, next) => next(new AppError('not_found', 'Endpoint not found.', 404)));
  app.use((error: unknown, req: express.Request, res: express.Response, next: express.NextFunction) => { void next; const normalized = error instanceof z.ZodError ? new AppError('validation_failed', 'The request contains invalid data.', 400) : safeError(error); if (normalized.status >= 500) console.error(JSON.stringify({ requestId: req.requestId, code: normalized.code })); res.status(normalized.status).json({ error: { code: normalized.code, message: normalized.message, requestId: req.requestId, retryable: normalized.retryable } }); });
  return app;
}

function asyncRoute(fn: (req: express.Request, res: express.Response) => Promise<void>) { return (req: express.Request, res: express.Response, next: express.NextFunction) => void fn(req, res).catch(next); }
function domainMatches(host: string, allowed: string) { const value = allowed.toLowerCase().replace(/^\*\./, ''); return host === value || (allowed.startsWith('*.') && host.endsWith(`.${value}`)); }
function validateClaimedOrigin(req: express.Request, claimed: string) { const header = req.header('origin'); if (header && new URL(header).origin !== new URL(claimed).origin) throw new AppError('origin_mismatch', 'The request origin does not match the configured website.', 403); }
function enforceConversation(visitor: { conversationId?: string }, idValue: string) { if (!visitor.conversationId || visitor.conversationId !== idValue) throw new AppError('conversation_permission_denied', 'This session cannot access that conversation.', 403); }
function sanitizeWidgetMessages(messages: Record<string, unknown>[]) { return messages.filter((m) => m.role !== 'system').map(({ id: messageId, role, text, deliveryState, createdAt }) => ({ id: messageId, role, text, deliveryState, createdAt })); }
async function requireOperatorConversation(req: express.Request, store: ChatStore, conversationId: string) { const c = await store.getConversation(conversationId); if (!c) throw new AppError('conversation_not_found', 'Conversation was not found.', 404); return c; }
async function retry<T>(fn: () => Promise<T>, retries: number) { let last: unknown; for (let i = 0; i <= retries; i += 1) { try { return await fn(); } catch (e) { last = e; if (!(e instanceof AppError) || !e.retryable || i === retries) throw e; await new Promise((r) => setTimeout(r, 100 * 2 ** i)); } } throw last; }
async function maybeAutoReply(input: { store: ChatStore; gemini?: GeminiClient; conversationId: string; workspaceId: string; siteId: string; visitorMessage: string; model: string }) {
  if (!input.gemini) return { generated: false, reason: 'not_configured' };
  const site = await input.store.getSite(input.workspaceId, input.siteId);
  if (!site?.autoReply) return { generated: false, reason: 'disabled' };
  try {
    const knowledge = await input.store.enabledKnowledge(input.workspaceId);
    const history = (await input.store.listMessages(input.conversationId)).map((m) => ({ role: String(m.role), text: String(m.text) }));
    const text = await retry(() => input.gemini!.generate({ message: input.visitorMessage, history, knowledge, tone: site.tone ?? 'professional and helpful', languages: site.languages ?? ['English'], maxOutputTokens: 512, temperature: 0.3 }), 2);
    const suggestion = calculateSuggestion(text, knowledge, input.model, site.fallbackResponse ?? 'A human teammate will help you shortly.');
    const approved = !site.humanApproval && suggestion.confidence >= site.confidenceThreshold;
    await input.store.storeSuggestion(input.conversationId, { ...suggestion, mode: 'auto', approved });
    if (approved) await input.store.addMessage(input.conversationId, { id: randomUUID(), role: 'assistant', text: suggestion.text, senderId: 'gemini' }, `auto-${randomUUID()}`);
    return { generated: true, sent: approved, confidence: suggestion.confidence };
  } catch (error) {
    const safe = safeError(error);
    return { generated: false, reason: safe.code, retryable: safe.retryable };
  }
}
