import tailwindcss from '@tailwindcss/vite'
import react from '@vitejs/plugin-react'
import fs from 'node:fs'
import path from 'node:path'
import type { Plugin } from 'vite'
import { defineConfig } from 'vite'
import { AGENT_BRIDGE_PORT, ROOT_DIR, TARGET_DIR, YOZ_SERVER_PORT } from './script/env.mjs'

function manifestPlugin(): Plugin {
  return {
    name: 'manifest-transform',
    writeBundle() {
      const manifestPath = path.resolve(TARGET_DIR, 'manifest.json')
      const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf-8'))

      const dynamicHostPermissions = [
        `https://localhost:${YOZ_SERVER_PORT}/*`,
        `http://127.0.0.1:${AGENT_BRIDGE_PORT}/*`,
      ]
      for (const permission of dynamicHostPermissions) {
        if (!manifest.host_permissions.includes(permission)) {
          manifest.host_permissions.push(permission)
        }
      }

      fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2) + '\n')
    },
  }
}

// https://vite.dev/config/
export default defineConfig({
  define: {
    __YOZ_SERVER_PORT__: JSON.stringify(YOZ_SERVER_PORT),
  },
  build: {
    outDir: TARGET_DIR,
  },
  plugins: [react(), tailwindcss(), manifestPlugin()],
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
