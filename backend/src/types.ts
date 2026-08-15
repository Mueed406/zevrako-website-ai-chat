export type MessageRole = 'visitor' | 'operator' | 'assistant' | 'system';
export type ConversationStatus = 'open' | 'waiting' | 'resolved' | 'spam';

export interface VisitorClaims {
  visitorId: string;
  workspaceId: string;
  siteId: string;
  conversationId?: string;
}

export interface SafeFailure {
  error: { code: string; message: string; requestId: string; retryable: boolean };
}

export interface KnowledgeEntry {
  id: string;
  title: string;
  category: string;
  content: string;
  summary: string;
  tags: string[];
  priority: number;
  enabled: boolean;
  completenessScore: number;
  createdAt: string;
  updatedAt: string;
}

export interface AiSuggestion {
  text: string;
  confidence: number;
  confidenceSignals: string[];
  knowledgeIds: string[];
  model: string;
  generatedAt: string;
  fallback: boolean;
}
