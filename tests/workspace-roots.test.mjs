import assert from 'node:assert/strict'
import { test } from 'node:test'
import { existsSync, readFileSync } from 'node:fs'
import { createRequire } from 'node:module'
import { runInThisContext } from 'node:vm'
import path from 'node:path'
import ts from 'typescript'

const root = path.resolve(import.meta.dirname, '..')
const cache = new Map()
function load(filename) {
  let filepath = path.resolve(root, filename)
  if (!path.extname(filepath))
    filepath = existsSync(`${filepath}.ts`) ? `${filepath}.ts` : path.join(filepath, 'index.ts')
  if (cache.has(filepath)) return cache.get(filepath).exports
  const output = ts.transpileModule(readFileSync(filepath, 'utf8'), {
    compilerOptions: {
      module: ts.ModuleKind.CommonJS,
      target: ts.ScriptTarget.ES2022,
      esModuleInterop: true,
    },
  }).outputText
  const module = { exports: {} }
  cache.set(filepath, module)
  const require = createRequire(filepath)
  runInThisContext(`(function(module, exports, require) { ${output}\n })`, { filename: filepath })(
    module,
    module.exports,
    id => {
      if (id.startsWith('@/shared/')) return load(`shared/${id.slice('@/shared/'.length)}`)
      if (id.startsWith('@/')) return load(`src/${id.slice(2)}`)
      if (id.startsWith('.')) return load(path.resolve(path.dirname(filepath), id))
      return require(id)
    },
  )
  return module.exports
}
const paths = load('src/common/util/path.ts')
const { toSearch } = load('shared/util/url.ts')
const { WorkspaceViewViewModel } = load('src/view/workspace/context/viewmodel.ts')

test('workspace matching uses directory boundaries and prefers the deepest matching root', () => {
  assert.equal(paths.isFilepathWithinRoot('/repo/docs/guide.md', '/repo'), true)
  assert.equal(paths.isFilepathWithinRoot('/repo-private/guide.md', '/repo'), false)
  assert.equal(
    paths.selectWorkspaceRoot('/repo/docs/guide.md', ['/repo', '/repo/docs']),
    '/repo/docs',
  )
  assert.equal(paths.selectWorkspaceRoot('/outside/guide.md', ['/repo']), null)
  assert.equal(paths.relativeWorkspaceFilepath('/repo/docs/guide.md', '/repo/docs'), 'guide.md')
  assert.equal(paths.relativeWorkspaceFilepath('/guide.md', '/'), 'guide.md')
  assert.equal(paths.isFilepathWithinRoot('C:/docs/guide.md', 'C:/'), true)
})

test('absolute file URLs encode once and preserve literal percent, whitespace and Unix backslashes', () => {
  for (const filepath of ['/repo/100% # 中文.md', '/repo/%2F.md', '/repo/file ', '/repo/a\\b.md']) {
    const params = new URLSearchParams(toSearch({ filepath }))
    assert.equal(params.get('filepath'), filepath)
    assert.equal(paths.readAbsoluteSearchParam(params.get('filepath')), filepath)
  }
  assert.equal(paths.readAbsoluteSearchParam(encodeURIComponent('/repo/old.md')), '/repo/old.md')
  assert.equal(paths.readAbsoluteSearchParam('relative.md'), null)
  assert.equal(paths.normalizeAbsoluteFilepath('~/docs'), null)
})

test('browser root list survives persistence, deduplicates entries and preserves intentionally empty lists', () => {
  const model = new WorkspaceViewViewModel({
    workspaceRoot: '/repo',
    workspaceRoots: ['/repo'],
    workspaceRootsInitialized: true,
  })
  model.addWorkspaceRoot('/repo/docs')
  model.addWorkspaceRoot('/repo/docs/')
  model.addWorkspaceRoot('relative')
  assert.deepEqual(model.dump().workspaceRoots, ['/repo', '/repo/docs'])
  const restored = new WorkspaceViewViewModel(WorkspaceViewViewModel.normalize(model.dump()))
  assert.deepEqual(restored.dump().workspaceRoots, ['/repo', '/repo/docs'])
  restored.removeWorkspaceRoot('/repo')
  restored.removeWorkspaceRoot('/repo/docs')
  const empty = WorkspaceViewViewModel.normalize(restored.dump())
  assert.deepEqual(empty.workspaceRoots, [])
  assert.equal(empty.workspaceRootsInitialized, true)
  model.dispose()
  restored.dispose()
})

test('permission failures do not trigger login, while missing authentication does', async () => {
  const { Requester, setAuthenticationRequiredHandler } = load('shared/api/requester.ts')
  const originalFetch = globalThis.fetch
  let prompts = 0
  setAuthenticationRequiredHandler(() => {
    prompts += 1
  })
  try {
    globalThis.fetch = async () =>
      new Response(JSON.stringify({ error: 'Path is outside allowed roots' }), { status: 403 })
    assert.equal((await new Requester().get('/api/workspace/files')).status, 403)
    assert.equal(prompts, 0)
    globalThis.fetch = async () => new Response(null, { status: 401 })
    await assert.rejects(new Requester().get('/api/workspace/files'), /Authentication required/)
    assert.equal(prompts, 1)
  } finally {
    globalThis.fetch = originalFetch
  }
})

test('Markdown file links stay in the current workspace without crossing directory boundaries', () => {
  const { resolveWorkspaceLink } = load('src/view/workspace/util/link.ts')
  const fileUrl = filepath => `/file?${new URLSearchParams({ filepath })}#section`
  for (const filepath of ['/repo/docs/guide.md', '/repo/100% # 中文.md', '/repo/a\\b.md']) {
    const result = new URL(resolveWorkspaceLink(fileUrl(filepath), '/repo'), 'http://localhost')
    assert.equal(result.pathname, '/ws')
    assert.equal(result.searchParams.get('root'), '/repo')
    assert.equal(result.searchParams.get('filepath'), filepath)
    assert.equal(result.hash, '#section')
  }
  for (const filepath of ['/repo-private/guide.md', '/repo/../outside.md', 'relative.md']) {
    const url = fileUrl(filepath)
    assert.equal(resolveWorkspaceLink(url, '/repo'), url)
  }
  const normalized = new URL(
    resolveWorkspaceLink(fileUrl('/repo/docs/../guide.md'), '/repo'),
    'http://localhost',
  )
  assert.equal(normalized.searchParams.get('filepath'), '/repo/guide.md')
  for (const url of [
    '#section',
    'https://example.com/file?filepath=/repo/a.md',
    '//example.com/file?filepath=/repo/a.md',
    '/api/file/raw?filepath=/repo/a.png',
  ]) {
    assert.equal(resolveWorkspaceLink(url, '/repo'), url)
  }
  assert.equal(resolveWorkspaceLink(fileUrl('/repo/a.md'), null), fileUrl('/repo/a.md'))
  for (const [workspaceRoot, filepath] of [
    ['C:/repo', 'C:/repo/guide.md'],
    ['//server/share', '//server/share/guide.md'],
  ]) {
    const result = new URL(
      resolveWorkspaceLink(fileUrl(filepath), workspaceRoot),
      'http://localhost',
    )
    assert.equal(result.searchParams.get('root'), workspaceRoot)
    assert.equal(result.searchParams.get('filepath'), filepath)
  }
})
