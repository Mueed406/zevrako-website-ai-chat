import { ZevrakoWidget } from './widget.js';

export { ZevrakoWidget };
function boot() { const script = document.currentScript as HTMLScriptElement | null; if (!script) return; const workspaceId = script.dataset.workspaceId; const siteId = script.dataset.siteId; const apiUrl = script.dataset.apiUrl ?? new URL(script.src).origin; if (!workspaceId || !siteId) { console.error('Zevrako Chat requires data-workspace-id and data-site-id.'); return; } void new ZevrakoWidget({ workspaceId, siteId, apiUrl }).initialize(); }
if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot, { once: true }); else boot();
