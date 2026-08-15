import { GoogleGenAI } from '@google/genai';
import { AppError } from './errors.js';
import type { AiSuggestion, KnowledgeEntry } from './types.js';

export interface GenerateInput { message: string; history: { role: string; text: string }[]; knowledge: KnowledgeEntry[]; tone: string; languages: string[]; maxOutputTokens: number; temperature: number; }
export interface GeminiClient { generate(input: GenerateInput): Promise<string>; }

export class OfficialGeminiClient implements GeminiClient {
  private readonly client;
  constructor(apiKey: string, private readonly model: string, private readonly timeoutMs = 12_000) { this.client = new GoogleGenAI({ apiKey }); }
  async generate(input: GenerateInput) {
    const controller = new AbortController(); const timer = setTimeout(() => controller.abort(), this.timeoutMs);
    try {
      const knowledge = input.knowledge.map((k) => `[${k.id}] ${k.title}: ${k.content}`).join('\n');
      const response = await this.client.models.generateContent({ model: this.model, contents: input.history.slice(-12).map((m) => `${m.role}: ${stripPii(m.text)}`).concat(`visitor: ${stripPii(input.message)}`).join('\n'), config: { systemInstruction: `You are a website support assistant. Use only approved knowledge. Never invent prices, policies, or customer data. If uncertain, say a human will help. Tone: ${input.tone}. Languages: ${input.languages.join(', ')}.\nApproved knowledge:\n${knowledge}`, temperature: input.temperature, maxOutputTokens: input.maxOutputTokens, abortSignal: controller.signal } });
      const text = response.text?.trim(); if (!text) throw new AppError('gemini_empty_response', 'AI returned no usable response.', 502, true); return text;
    } catch (error) {
      if (error instanceof AppError) throw error;
      if (controller.signal.aborted) throw new AppError('gemini_timeout', 'AI generation timed out.', 504, true);
      const status = Number((error as { status?: number }).status);
      if (status === 401 || status === 403) throw new AppError('gemini_invalid_key', 'The AI integration is not authorized.', 503);
      if (status === 429) throw new AppError('gemini_quota', 'AI capacity is temporarily unavailable.', 503, true);
      throw new AppError('gemini_unavailable', 'AI generation is temporarily unavailable.', 503, true);
    } finally { clearTimeout(timer); }
  }
}

export function stripPii(text: string) { return text.replace(/[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}/g, '[email]').replace(/\+?[\d][\d\s()-]{7,}\d/g, '[phone]'); }
export function calculateSuggestion(text: string, knowledge: KnowledgeEntry[], model: string, fallbackMessage: string): AiSuggestion {
  const lower = text.toLowerCase(); const used = knowledge.filter((k) => lower.includes(k.title.toLowerCase()) || k.tags.some((tag) => lower.includes(tag.toLowerCase())));
  const ambiguity = /(?:maybe|might|not sure|i think)/i.test(text); const fallback = !text.trim() || /human (?:will|can) help/i.test(text);
  const confidence = Math.max(0, Math.min(1, 0.35 + Math.min(used.length, 3) * 0.18 + (ambiguity ? -0.2 : 0.1) + (fallback ? -0.25 : 0)));
  return { text: text.trim() || fallbackMessage, confidence, confidenceSignals: [`knowledgeCoverage:${used.length}`, `ambiguity:${ambiguity}`, `fallback:${fallback}`], knowledgeIds: used.map((k) => k.id), model, generatedAt: new Date().toISOString(), fallback };
}
