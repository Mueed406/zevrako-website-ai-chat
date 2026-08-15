import { applicationDefault, cert, getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { createApp } from '../src/app.js';
import { loadConfig } from '../src/config.js';
import { OfficialGeminiClient } from '../src/gemini.js';
import { FirestoreChatStore } from '../src/store.js';

const config = loadConfig();

const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;

const credential = serviceAccountJson
  ? cert(JSON.parse(serviceAccountJson))
  : applicationDefault();

const firebase =
  getApps()[0] ??
  initializeApp({
    credential,
    projectId: config.firebaseProjectId,
  });

const gemini = config.geminiApiKey
  ? new OfficialGeminiClient(config.geminiApiKey, config.geminiModel)
  : undefined;

const app = createApp({
  config,
  store: new FirestoreChatStore(getFirestore(firebase)),
  auth: getAuth(firebase),
  gemini,
});

export default app;