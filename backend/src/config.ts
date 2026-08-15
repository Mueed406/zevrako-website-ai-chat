import { z } from 'zod';

const schema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().positive().default(8787),
  FIREBASE_PROJECT_ID: z.string().min(1).default('zevrako-auto-reply-ai-dev'),
  VISITOR_SESSION_SECRET: z.string().min(32),
  GEMINI_API_KEY: z.string().min(1).optional(),
  GEMINI_MODEL: z.string().min(1).default('gemini-2.5-flash'),
  ALLOWED_OPERATOR_ORIGINS: z.string().default('http://localhost:3000'),
  TRUST_PROXY: z.enum(['true', 'false']).default('false'),
});

export type AppConfig = {
  nodeEnv: 'development' | 'test' | 'production';
  port: number;
  firebaseProjectId: string;
  visitorSessionSecret: string;
  geminiApiKey?: string;
  geminiModel: string;
  allowedOperatorOrigins: Set<string>;
  trustProxy: boolean;
};

export function loadConfig(env: NodeJS.ProcessEnv = process.env): AppConfig {
  const parsed = schema.parse(env);
  return {
    nodeEnv: parsed.NODE_ENV,
    port: parsed.PORT,
    firebaseProjectId: parsed.FIREBASE_PROJECT_ID,
    visitorSessionSecret: parsed.VISITOR_SESSION_SECRET,
    geminiApiKey: parsed.GEMINI_API_KEY,
    geminiModel: parsed.GEMINI_MODEL,
    allowedOperatorOrigins: new Set(parsed.ALLOWED_OPERATOR_ORIGINS.split(',').map((v) => v.trim())),
    trustProxy: parsed.TRUST_PROXY === 'true',
  };
}
