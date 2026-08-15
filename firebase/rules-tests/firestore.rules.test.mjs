import { readFile } from 'node:fs/promises';
import { afterAll, afterEach, beforeAll, describe, expect, it } from 'vitest';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc } from 'firebase/firestore';

let env;
beforeAll(async () => { env = await initializeTestEnvironment({ projectId: 'zevrako-auto-reply-ai-dev', firestore: { rules: await readFile(new URL('../firestore.rules', import.meta.url), 'utf8'), host: '127.0.0.1', port: 8080 } }); });
afterEach(async () => env.clearFirestore());
afterAll(async () => env.cleanup());
async function seed() { await env.withSecurityRulesDisabled(async (context) => { const db = context.firestore(); await setDoc(doc(db, 'websiteChatConversations/conversation-a'), { workspaceId: 'workspace-a', visitorId: 'visitor-a' }); await setDoc(doc(db, 'websiteChatConversations/conversation-a/messages/message-a'), { role: 'visitor', text: 'Hello' }); await setDoc(doc(db, 'websiteChatConversations/conversation-b'), { workspaceId: 'workspace-b', visitorId: 'visitor-b' }); await setDoc(doc(db, 'websiteChatVisitors/visitor-a'), { workspaceId: 'workspace-a' }); await setDoc(doc(db, 'users/existing-user'), { uid: 'existing-user' }); }); }

describe('website chat isolation', () => {
  it('denies unauthenticated visitor access to every conversation', async () => { await seed(); const db = env.unauthenticatedContext().firestore(); await assertFails(getDoc(doc(db, 'websiteChatConversations/conversation-a'))); await assertFails(getDoc(doc(db, 'websiteChatConversations/conversation-a/messages/message-a'))); });
  it('allows a scoped operator to read only its workspace', async () => { await seed(); const db = env.authenticatedContext('operator-a', { websiteChatOperator: true, websiteChatWorkspaceIds: ['workspace-a'] }).firestore(); await assertSucceeds(getDoc(doc(db, 'websiteChatConversations/conversation-a'))); await assertSucceeds(getDoc(doc(db, 'websiteChatConversations/conversation-a/messages/message-a'))); await assertFails(getDoc(doc(db, 'websiteChatConversations/conversation-b'))); });
  it('denies all client writes including scoped operators', async () => { await seed(); const db = env.authenticatedContext('operator-a', { websiteChatOperator: true, websiteChatWorkspaceIds: ['workspace-a'] }).firestore(); await assertFails(setDoc(doc(db, 'websiteChatConversations/new'), { workspaceId: 'workspace-a' })); await assertFails(setDoc(doc(db, 'websiteChatKnowledge/new'), { workspaceId: 'workspace-a', enabled: true })); });
});

describe('existing Zevrako rules remain enforced', () => {
  it('preserves owner-only user reads', async () => { await seed(); await assertSucceeds(getDoc(doc(env.authenticatedContext('existing-user').firestore(), 'users/existing-user'))); await assertFails(getDoc(doc(env.authenticatedContext('different-user').firestore(), 'users/existing-user'))); });
  it('keeps private legacy credentials default-denied', async () => { const db = env.authenticatedContext('existing-user').firestore(); await assertFails(getDoc(doc(db, 'providerCredentials/secret'))); await assertFails(getDoc(doc(db, 'workspaceVaults/secret'))); });
});
