import tailwindcss from '@tailwindcss/vite'
import react from '@vitejs/plugin-react'
import path from 'node:path'
import { defineConfig } from 'vite'
import { ROOT_DIR, TARGET_DIR } from './script/env.mjs'

// https://vite.dev/config/
export default defineConfig({
  define: {},
  build: {
    outDir: TARGET_DIR,
  },
  plugins: [react(), tailwindcss()],
  resolve: {
    alias: {
      '@': path.resolve(ROOT_DIR, 'src'),
    },
  },
  server: {
    cors: false,
    open: true,
    strictPort: true,
    allowedHosts: ['127.0.0.1', 'localhost'],
  },
})
