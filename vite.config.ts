import react from '@vitejs/plugin-react'
import path from 'node:path'
import { defineConfig } from 'vite'
import { ROOT_DIR, SERVER_HOST, SERVER_PORT, TARGET_DIR } from './env'
import api from './server/plugin/api'
import ws from './server/plugin/ws'

// https://vite.dev/config/
export default defineConfig({
  define: {},
  build: {
    outDir: TARGET_DIR,
  },
  plugins: [react(), api(), ws()],
  resolve: {
    alias: {
      '@/shared': path.resolve(ROOT_DIR, 'shared'),
      '@': path.resolve(ROOT_DIR, 'src'),
    },
  },
  server: {
    cors: false,
    open: true,
    port: SERVER_PORT,
    host: SERVER_HOST,
  },
})
