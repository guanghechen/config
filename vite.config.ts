import { builtinModules } from 'node:module'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { defineConfig } from 'vite'

const rootDir = path.dirname(fileURLToPath(import.meta.url))

export default defineConfig({
  build: {
    emptyOutDir: true,
    lib: {
      entry: path.resolve(rootDir, 'src/extension.ts'),
      formats: ['cjs'],
      fileName: () => 'extension.cjs',
    },
    minify: false,
    outDir: path.resolve(rootDir, 'dist'),
    rollupOptions: {
      external: id => id === 'vscode' || id.startsWith('node:') || builtinModules.includes(id),
      output: {
        exports: 'named',
      },
    },
    sourcemap: true,
    target: 'node20',
  },
})
