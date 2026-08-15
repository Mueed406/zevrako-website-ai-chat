export type ChatConfig = { businessName: string; greeting: string; themeColor: string; position: 'left' | 'right'; aiDisclosure: string };
export type ChatMessage = { id: string; role: 'visitor' | 'operator' | 'assistant'; text: string; deliveryState: 'sending' | 'delivered' | 'failed'; createdAt?: string };

export class ChatApi {
  constructor(private readonly baseUrl: string, readonly workspaceId: string, readonly siteId: string) {}
  async config(): Promise<ChatConfig> { return this.request(`/v1/widget/config?workspaceId=${encodeURIComponent(this.workspaceId)}&siteId=${encodeURIComponent(this.siteId)}&origin=${encodeURIComponent(location.origin)}`); }
  async session(name: string, email?: string) { return this.request<{ token: string; visitorId: string }>('/v1/widget/sessions', { method: 'POST', body: JSON.stringify({ workspaceId: this.workspaceId, siteId: this.siteId, name, email: email || undefined, origin: location.origin }) }); }
  async conversation(token: string) { return this.request<{ conversationId: string; token: string }>('/v1/widget/conversations', { method: 'POST', token, body: JSON.stringify({ pageUrl: location.href, referrer: document.referrer || undefined }) }); }
  async messages(token: string, conversationId: string) { return this.request<{ messages: ChatMessage[] }>(`/v1/widget/conversations/${conversationId}/messages`, { token }); }
  async send(token: string, conversationId: string, text: string, clientMessageId: string) { return this.request<{ id: string; duplicate: boolean }>(`/v1/widget/conversations/${conversationId}/messages`, { method: 'POST', token, body: JSON.stringify({ text, clientMessageId }) }); }
  private async request<T>(path: string, init: RequestInit & { token?: string } = {}): Promise<T> {
    const controller = new AbortController(); const timeout = setTimeout(() => controller.abort(), 10_000); const headers = new Headers(init.headers); headers.set('content-type', 'application/json'); if (init.token) headers.set('authorization', `Bearer ${init.token}`);
    try { const response = await fetch(`${this.baseUrl}${path}`, { ...init, headers, signal: controller.signal, credentials: 'omit' }); const data = await response.json().catch(() => ({})); if (!response.ok) throw new ApiError(data?.error?.code ?? 'request_failed', data?.error?.message ?? 'Chat is temporarily unavailable.', response.status); return data as T; }
    finally { clearTimeout(timeout); }
  }
}
export class ApiError extends Error { constructor(readonly code: string, message: string, readonly status: number) { super(message); } }
