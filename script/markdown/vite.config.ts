import react from '@vitejs/plugin-react'
import path from 'node:path'
import { defineConfig } from 'vite'
import { ROOT_DIR, TARGET_DIR } from './script/env'
import api from './script/server/middleware/api'

// https://vite.dev/config/
export default defineConfig({
  define: {},
  build: {
    outDir: TARGET_DIR,
  },
  plugins: [react(), api()],
  resolve: {
    alias: {
      '@': path.resolve(ROOT_DIR, 'src'),
    },
  },
})
