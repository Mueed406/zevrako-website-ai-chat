import { randomUUID } from 'node:crypto';
import { FieldValue, Firestore } from 'firebase-admin/firestore';
import { AppError } from './errors.js';
import type { ConversationStatus, KnowledgeEntry, MessageRole } from './types.js';

export interface SiteConfig {
  id: string; workspaceId: string; allowedDomains: string[]; enabled: boolean;
  businessName: string; greeting: string; themeColor: string; position: 'left' | 'right';
  aiDisclosure: string; autoReply: boolean; confidenceThreshold: number;
  humanApproval?: boolean; fallbackResponse?: string; tone?: string; languages?: string[];
}
export interface MessageInput { id: string; role: MessageRole; text: string; senderId: string; }

export interface ChatStore {
  getSite(workspaceId: string, siteId: string): Promise<SiteConfig | null>;
  createVisitor(workspaceId: string, siteId: string, visitorId: string, name: string, email?: string): Promise<void>;
  createConversation(input: { id: string; workspaceId: string; siteId: string; visitorId: string; pageUrl?: string; referrer?: string; userAgent?: string }): Promise<void>;
  getConversation(id: string): Promise<Record<string, unknown> | null>;
  listConversations(workspaceId: string, status?: ConversationStatus): Promise<Record<string, unknown>[]>;
  listMessages(conversationId: string): Promise<Record<string, unknown>[]>;
  addMessage(conversationId: string, input: MessageInput, idempotencyKey: string): Promise<{ id: string; duplicate: boolean }>;
  setStatus(conversationId: string, status: ConversationStatus): Promise<void>;
  addNote(conversationId: string, operatorId: string, text: string): Promise<void>;
  setTags(conversationId: string, tags: string[]): Promise<void>;
  enabledKnowledge(workspaceId: string): Promise<KnowledgeEntry[]>;
  storeSuggestion(conversationId: string, data: Record<string, unknown>): Promise<void>;
  updateTyping(conversationId: string, actor: MessageRole, typing: boolean): Promise<void>;
}

export class FirestoreChatStore implements ChatStore {
  constructor(private readonly db: Firestore) {}
  async getSite(workspaceId: string, siteId: string): Promise<SiteConfig | null> {
    const snap = await this.db.collection('websiteChatSites').doc(siteId).get();
    if (!snap.exists || snap.data()?.workspaceId !== workspaceId) return null;
    return { id: snap.id, ...snap.data() } as SiteConfig;
  }
  async createVisitor(workspaceId: string, siteId: string, visitorId: string, name: string, email?: string) {
    await this.db.collection('websiteChatVisitors').doc(visitorId).set({ workspaceId, siteId, name, email: email ?? null, firstSeenAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp() }, { merge: true });
  }
  async createConversation(input: { id: string; workspaceId: string; siteId: string; visitorId: string; pageUrl?: string; referrer?: string; userAgent?: string }) {
    await this.db.collection('websiteChatConversations').doc(input.id).create({ ...input, status: 'open', assignedOperatorId: null, tags: [], unreadOperator: 0, blocked: false, createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp() });
  }
  async getConversation(id: string) { const s = await this.db.collection('websiteChatConversations').doc(id).get(); return s.exists ? { id: s.id, ...s.data() } : null; }
  async listConversations(workspaceId: string, status?: ConversationStatus) {
    let query: FirebaseFirestore.Query = this.db.collection('websiteChatConversations').where('workspaceId', '==', workspaceId);
    if (status) query = query.where('status', '==', status);
    const result = await query.orderBy('updatedAt', 'desc').limit(100).get();
    return result.docs.map((d) => ({ id: d.id, ...d.data() }));
  }
  async listMessages(conversationId: string) { const s = await this.db.collection('websiteChatConversations').doc(conversationId).collection('messages').orderBy('createdAt').limit(200).get(); return s.docs.map((d) => ({ id: d.id, ...d.data() })); }
  async addMessage(conversationId: string, input: MessageInput, idempotencyKey: string) {
    const conversation = this.db.collection('websiteChatConversations').doc(conversationId);
    const receipt = conversation.collection('idempotency').doc(idempotencyKey);
    const message = conversation.collection('messages').doc(input.id || randomUUID());
    return this.db.runTransaction(async (tx) => {
      if (!(await tx.get(conversation)).exists) throw new AppError('conversation_not_found', 'Conversation was not found.', 404);
      const prior = await tx.get(receipt);
      if (prior.exists) return { id: String(prior.data()?.messageId), duplicate: true };
      tx.create(message, { ...input, deliveryState: 'delivered', createdAt: FieldValue.serverTimestamp() });
      tx.create(receipt, { messageId: message.id, createdAt: FieldValue.serverTimestamp() });
      tx.update(conversation, { updatedAt: FieldValue.serverTimestamp(), lastMessagePreview: input.text.slice(0, 160), ...(input.role === 'visitor' ? { unreadOperator: FieldValue.increment(1) } : {}) });
      return { id: message.id, duplicate: false };
    });
  }
  async setStatus(id: string, status: ConversationStatus) { await this.db.collection('websiteChatConversations').doc(id).update({ status, updatedAt: FieldValue.serverTimestamp() }); }
  async addNote(id: string, operatorId: string, text: string) { await this.db.collection('websiteChatConversations').doc(id).collection('internalNotes').add({ operatorId, text, createdAt: FieldValue.serverTimestamp() }); }
  async setTags(id: string, tags: string[]) { await this.db.collection('websiteChatConversations').doc(id).update({ tags, updatedAt: FieldValue.serverTimestamp() }); }
  async enabledKnowledge(workspaceId: string) { const s = await this.db.collection('websiteChatKnowledge').where('workspaceId', '==', workspaceId).where('enabled', '==', true).orderBy('priority', 'desc').limit(30).get(); return s.docs.map((d) => ({ id: d.id, ...d.data() }) as KnowledgeEntry); }
  async storeSuggestion(id: string, data: Record<string, unknown>) { await this.db.collection('websiteChatConversations').doc(id).collection('aiSuggestions').add({ ...data, createdAt: FieldValue.serverTimestamp() }); }
  async updateTyping(id: string, actor: MessageRole, typing: boolean) { await this.db.collection('websiteChatConversations').doc(id).set({ typing: { [actor]: typing }, updatedAt: FieldValue.serverTimestamp() }, { merge: true }); }
}
