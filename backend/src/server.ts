import { applicationDefault, getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { createApp } from './app.js';
import { loadConfig } from './config.js';
import { OfficialGeminiClient } from './gemini.js';
import { FirestoreChatStore } from './store.js';

const config = loadConfig();
const firebase = getApps()[0] ?? initializeApp({ credential: applicationDefault(), projectId: config.firebaseProjectId });
const gemini = config.geminiApiKey ? new OfficialGeminiClient(config.geminiApiKey, config.geminiModel) : undefined;
createApp({ config, store: new FirestoreChatStore(getFirestore(firebase)), auth: getAuth(firebase), gemini }).listen(config.port, () => console.log(JSON.stringify({ event: 'server_started', port: config.port, projectId: config.firebaseProjectId, geminiConfigured: Boolean(gemini) })));
