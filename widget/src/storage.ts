export type RestorableSession = { token: string; conversationId: string; expiresAt: number };
export class SessionStorage {
  constructor(private readonly key: string) {}
  load(): RestorableSession | null { try { const raw = window.localStorage.getItem(this.key); if (!raw) return null; const value = JSON.parse(raw) as RestorableSession; if (!value.token || !value.conversationId || value.expiresAt <= Date.now()) { this.clear(); return null; } return value; } catch { this.clear(); return null; } }
  save(value: RestorableSession) { window.localStorage.setItem(this.key, JSON.stringify(value)); }
  clear() { window.localStorage.removeItem(this.key); }
}
