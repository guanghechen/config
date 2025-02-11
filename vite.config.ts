import react from '@vitejs/plugin-react'
import path from 'node:path'
import { defineConfig } from 'vite'
import { ROOT_DIR, TARGET_DIR } from './script/env'
import api from './script/server/plugin/api'
import ws from './script/server/plugin/ws'

// https://vite.dev/config/
export default defineConfig({
  define: {},
  build: {
    outDir: TARGET_DIR,
  },
  plugins: [react(), api(), ws()],
  resolve: {
    alias: {
      '@': path.resolve(ROOT_DIR, 'src'),
    },
  },
  server: {
    port: 9527,
    host: 'localhost',
  },
})
