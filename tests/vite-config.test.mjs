import assert from 'node:assert/strict'
import path from 'node:path'
import { test } from 'node:test'
import dotenv from 'dotenv'
import { loadConfigFromFile } from 'vite'

test('Vite config loads with native Node TypeScript support', async t => {
  const originalEnv = process.env
  process.env = { ...originalEnv, YOZ_ALLOWED_ROOTS: '[]', YOZ_DEFAULT_WORKSPACE_ROOTS: '[]' }
  for (const key of Object.keys(process.env)) {
    if (key.startsWith('YOZ_WORKSPACE_')) delete process.env[key]
  }
  t.after(() => {
    process.env = originalEnv
  })
  const config = t.mock.method(dotenv, 'config', () => ({ parsed: {} }))
  const root = path.resolve(import.meta.dirname, '..')
  const result = await loadConfigFromFile(
    { command: 'serve', mode: 'development' },
    path.join(root, 'vite.config.ts'),
    root,
    'silent',
    undefined,
    'native',
  )
  assert.equal(config.mock.callCount(), 1)
  const plugins = result.config.plugins.flat().map(plugin => plugin.name)
  assert(plugins.includes('@guanghechen/api'))
  assert(plugins.includes('@guanghechen/ws'))
})
