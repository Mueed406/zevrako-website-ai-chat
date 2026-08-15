import { describe, expect, it, vi } from 'vitest';
import { calculateSuggestion, OfficialGeminiClient, stripPii } from '../src/gemini.js';
import { SessionService } from '../src/auth.js';

describe('visitor session isolation', () => {
  it('keeps workspace, site, visitor, and conversation bindings signed', async () => { const sessions = new SessionService('a-secure-test-secret-with-at-least-32-characters'); const token = await sessions.issue({ visitorId: 'visitor-a', workspaceId: 'workspace-a', siteId: 'site-a', conversationId: 'conversation-a' }); await expect(sessions.verify(token)).resolves.toMatchObject({ visitorId: 'visitor-a', workspaceId: 'workspace-a', siteId: 'site-a', conversationId: 'conversation-a' }); const parts = token.split('.'); const tampered = `${parts[0]}.${parts[1]}x.${parts[2]}`; await expect(sessions.verify(tampered)).rejects.toMatchObject({ code: 'invalid_visitor_session' }); });
});

describe('Gemini boundary', () => {
  it('redacts common email and phone patterns before prompt construction', () => { expect(stripPii('Email me at person@example.com or +92 300 1234567')).toBe('Email me at [email] or [phone]'); });
  it('calculates an application indicator instead of claiming native confidence', () => { const value = calculateSuggestion('Delivery usually takes two days.', [{ id: 'delivery', title: 'Delivery', category: 'policy', content: 'Two days', summary: '', tags: ['shipping'], priority: 1, enabled: true, completenessScore: 1, createdAt: '', updatedAt: '' }], 'test-model', 'Fallback'); expect(value.confidence).toBeGreaterThan(.5); expect(value.confidenceSignals).toContain('knowledgeCoverage:1'); expect(value.knowledgeIds).toEqual(['delivery']); });
  it('normalizes timeout without exposing a key', async () => { vi.useFakeTimers(); const client = new OfficialGeminiClient('secret-never-rendered', 'test-model', 5); const promise = client.generate({ message: 'hello', history: [], knowledge: [], tone: 'brief', languages: ['English'], maxOutputTokens: 20, temperature: 0 }); const rejection = expect(promise).rejects.toMatchObject({ code: expect.stringMatching(/^gemini_/) }); await vi.advanceTimersByTimeAsync(10); await rejection; vi.useRealTimers(); });
});
