import { defineConfig } from 'vite';
export default defineConfig({ build: { lib: { entry: 'src/index.ts', name: 'ZevrakoChat', formats: ['iife'], fileName: () => 'zevrako-chat.js' }, minify: 'esbuild' } });
