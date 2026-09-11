import assert from 'node:assert/strict'
import { after, test } from 'node:test'
import { mkdirSync, mkdtempSync, readFileSync, rmSync, symlinkSync, writeFileSync } from 'node:fs'
import os from 'node:os'
import { createServer } from 'node:http'
import path from 'node:path'
import { createRequire } from 'node:module'
import { runInThisContext } from 'node:vm'
import ts from 'typescript'

const root = path.resolve(import.meta.dirname, '..')
const fixture = mkdtempSync(path.join(os.tmpdir(), 'yoz-access-'))
const allowed = path.join(fixture, 'repo')
const docs = path.join(allowed, 'docs')
const outside = path.join(fixture, 'repo-private')
for (const directory of [docs, outside]) mkdirSync(directory, { recursive: true })
const article = path.join(docs, '100% # 中文.md')
const privateFile = path.join(outside, 'private.md')
writeFileSync(article, '# Allowed\n')
writeFileSync(privateFile, 'private fixture')
symlinkSync(outside, path.join(allowed, 'escape'))
symlinkSync(docs, path.join(allowed, 'alias'))
after(() => rmSync(fixture, { recursive: true, force: true }))

// Compile source in memory and inject configuration, never loading repository dotenv files.
const cache = new Map()
const testJwtSecret = 'yoz-test-only-jwt-secret'
let state
function load(filename) {
  const filepath = path.resolve(root, filename)
  if (filepath === path.join(root, 'server/state.ts')) return { __esModule: true, default: state }
  if (cache.has(filepath)) return cache.get(filepath).exports
  if (filepath === path.join(root, 'env.ts')) return { ROOT_DIR: fixture }
  if (filepath.includes('/server/plugin/api/h/api/user/')) return {}

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
  runInThisContext(`(function(module, exports, require, process) { ${output}\n })`, {
    filename: filepath,
  })(
    module,
    module.exports,
    id => {
      if (!id.startsWith('.')) return require(id)
      let target = path.resolve(path.dirname(filepath), id)
      if (!path.extname(target)) {
        try {
          readFileSync(`${target}.ts`)
          target += '.ts'
        } catch {
          target = path.join(target, 'index.ts')
        }
      }
      return load(target)
    },
    { env: { YOZ_JWT_SECRET: testJwtSecret } },
  )
  return module.exports
}
const { FileAccess, FileAccessError, configureRoots } = load('server/util/file-access.ts')
const access = new FileAccess([allowed])
state = {
  access,
  defaultWorkspaceRoots: [docs],
  legacyWorkspaces: [{ tag: 'docs', path: docs }],
  watch: filepath => access.resolve(filepath, 'file'),
  reporter: { error() {}, warn() {}, debug() {} },
  fileSwitchArgForce$: {
    next(value) {
      this.value = value
    },
  },
  fileSwitch$: {
    next(value) {
      this.value = value
    },
  },
}
const status = code => error => error instanceof FileAccessError && error.status === code
const params = (filepath, extra = {}) => ({
  searchParams: new URLSearchParams({ filepath }),
  pathname: '/api/file',
  res: { setHeader() {} },
  ...extra,
})

test('workspace subdirectories do not change server authorization', () => {
  assert.equal(access.resolve(docs, 'directory'), docs)
  assert.equal(access.resolve(article, 'file'), article)
  assert.equal(access.resolve(path.join(allowed, 'alias', path.basename(article)), 'file'), article)
  for (const filename of [
    privateFile,
    path.join(allowed, '../repo-private/private.md'),
    path.join(allowed, 'escape/private.md'),
  ]) {
    assert.throws(() => access.resolve(filename), status(403))
  }
  for (const value of ['', 'docs/article.md', '~/article.md', null, 12])
    assert.throws(() => access.resolve(value), status(400))
  assert.throws(() => access.resolve(path.join(allowed, 'missing.md')), status(404))
  assert.throws(() => access.resolve(docs, 'file'), status(400))
})

test('explicit configuration wins over legacy roots and defaults never authorize paths', () => {
  const config = configureRoots(
    {
      YOZ_ALLOWED_ROOTS: JSON.stringify([allowed]),
      YOZ_DEFAULT_WORKSPACE_ROOTS: JSON.stringify([docs]),
      YOZ_WORKSPACE_PRIVATE: outside,
    },
    allowed,
  )
  assert.deepEqual(config.access.allowedRoots, [allowed])
  assert.deepEqual(config.defaultWorkspaceRoots, [docs])
  assert.equal(
    config.legacyWorkspaces.some(item => item.tag === 'private'),
    false,
  )
  assert.throws(
    () =>
      configureRoots(
        {
          YOZ_ALLOWED_ROOTS: JSON.stringify([allowed]),
          YOZ_DEFAULT_WORKSPACE_ROOTS: JSON.stringify([outside]),
        },
        allowed,
      ),
    status(403),
  )
  assert.deepEqual(configureRoots({ YOZ_ALLOWED_ROOTS: '[]' }, allowed).defaultWorkspaceRoots, [])
  assert.throws(() => configureRoots({ YOZ_ALLOWED_ROOTS: '"invalid"' }, allowed))
  assert.throws(() => configureRoots({ YOZ_ALLOWED_ROOTS: '["relative"]' }, allowed))
  assert.deepEqual(
    configureRoots({ YOZ_WORKSPACE_PRIVATE: outside }, allowed).access.allowedRoots,
    [allowed, outside],
  )
})

test('file, raw, save, listing and switch handlers all reject unauthorized paths', async () => {
  const { fetchFile } = load('server/plugin/api/h/api/file.ts')
  const { fetchFileRaw } = load('server/plugin/api/h/api/file/raw.ts')
  const { saveFile } = load('server/plugin/api/h/api/file/save.ts')
  const { switchFile } = load('server/plugin/api/h/api/file-switch.ts')
  const { list_workspace_files } = load('server/plugin/api/h/api/workspace/files.ts')
  for (const filepath of [privateFile, path.join(allowed, 'escape/private.md')]) {
    for (const handle of [fetchFile, fetchFileRaw, switchFile])
      await assert.rejects(handle(params(filepath)), status(403))
    await assert.rejects(
      saveFile(params(filepath, { body: JSON.stringify({ filepath, content: 'changed' }) })),
      status(403),
    )
  }
  await assert.rejects(
    list_workspace_files(params('', { searchParams: new URLSearchParams({ root: outside }) })),
    status(403),
  )
  assert.equal(readFileSync(privateFile, 'utf8'), 'private fixture')
  assert.equal(state.fileSwitch$.value, undefined)
})

test('authorized absolute paths round trip once and listing supports arbitrary child roots', async () => {
  const { fetchFile } = load('server/plugin/api/h/api/file.ts')
  const { saveFile } = load('server/plugin/api/h/api/file/save.ts')
  const { switchFile } = load('server/plugin/api/h/api/file-switch.ts')
  const { list_workspace_files } = load('server/plugin/api/h/api/workspace/files.ts')
  const result = await fetchFile(params(article))
  assert.equal(result.code, 200)
  assert.equal(result.data.error, undefined)
  const files = await list_workspace_files(
    params('', { searchParams: new URLSearchParams({ root: docs }) }),
  )
  assert.ok(files.data.data.files.includes(article))
  assert.ok(files.data.data.files.every(filepath => path.isAbsolute(filepath)))
  assert.equal(
    (
      await saveFile(
        params(article, { body: JSON.stringify({ filepath: article, content: '# Updated' }) }),
      )
    ).code,
    200,
  )
  assert.equal(readFileSync(article, 'utf8'), '# Updated')
  await switchFile(params(article))
  assert.equal(state.fileSwitch$.value, article)
  for (const body of [
    'null',
    '[]',
    '{"filepath":12}',
    JSON.stringify({ filepath: article, content: null }),
  ]) {
    assert.equal((await saveFile(params(article, { body }))).code, 400)
  }
})

test('Markdown sourcefile includes authorize independently, and bare relative resources become absolute API URLs', async () => {
  const parseMarkdown = load('server/util/parseMarkdown.ts').default
  const markdown = path.join(docs, 'references.md')
  writeFileSync(markdown, '```text sourcefile="../../repo-private/private.md"\n```\n')
  await assert.rejects(parseMarkdown(markdown), status(403))
  writeFileSync(
    markdown,
    '![asset](asset%20one.png)\n\n[child](child.md#title)\n\n![remote](https://example.com/image.png)\n',
  )
  const result = await parseMarkdown(markdown)
  const serialized = JSON.stringify(result.ast)
  assert.ok(serialized.includes('/api/file/raw?filepath='))
  assert.ok(
    serialized.includes(
      new URLSearchParams({ filepath: path.join(docs, 'asset one.png') }).toString(),
    ),
  )
  assert.ok(serialized.includes('/file?filepath='))
  assert.ok(serialized.includes('#title'))
  assert.ok(serialized.includes('https://example.com/image.png'))
})

test('versioned Markdown reads and saves preserve canonical paths, rich AST and conflicts', async () => {
  const { fetchFileText } = load('server/plugin/api/h/api/file/text.ts')
  const { saveFile } = load('server/plugin/api/h/api/file/save.ts')
  const filepath = path.join(docs, 'versioned.md')
  writeFileSync(filepath, '# Versioned\n\n![asset](asset.png)\n')
  const result = await fetchFileText(params(filepath, { req: { method: 'GET' } }))
  assert.equal(result.code, 200)
  assert.equal(result.data.data.filepath, filepath)
  assert.match(result.data.data.revision, /^[a-f0-9]{64}$/)
  assert.match(JSON.stringify(result.data.data.markdown.ast), /api\/file\/raw/)
  const revision = result.data.data.revision
  const unchanged = await fetchFileText(
    params(filepath, {
      req: { method: 'GET' },
      searchParams: new URLSearchParams({ filepath, revision }),
    }),
  )
  assert.equal(unchanged.data.data.unchanged, true)
  assert.equal(unchanged.data.data.content, undefined)
  writeFileSync(filepath, '# Changed elsewhere')
  const conflict = await saveFile(
    params(filepath, {
      body: JSON.stringify({ filepath, content: '# My draft', expectedRevision: revision }),
    }),
  )
  assert.equal(conflict.code, 409)
  assert.equal(readFileSync(filepath, 'utf8'), '# Changed elsewhere')
  await assert.rejects(fetchFileText(params(privateFile, { req: { method: 'GET' } })), status(403))
  assert.equal((await fetchFileText(params(filepath, { req: { method: 'POST' } }))).code, 405)
})

test('HTTP middleware preserves authentication and returns authorization status for all file routes', async () => {
  const api = load('server/plugin/api/index.ts').default
  let middleware
  api().configureServer({
    middlewares: {
      use(handle) {
        middleware = handle
      },
    },
  })
  const server = createServer((req, res) =>
    middleware(req, res, () => {
      res.writeHead(404)
      res.end()
    }),
  )
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve))
  const origin = `http://127.0.0.1:${server.address().port}`
  try {
    const fileQuery = new URLSearchParams({ filepath: article })
    assert.equal((await fetch(`${origin}/api/file?${fileQuery}`)).status, 401)
    const jwt = createRequire(import.meta.url)('jsonwebtoken')
    const headers = {
      authorization: `Bearer ${jwt.sign({ authenticated: true }, testJwtSecret, { expiresIn: '1h' })}`,
    }
    const raw = await fetch(`${origin}/api/file/raw?${fileQuery}`, { headers })
    assert.equal(raw.status, 200)
    assert.equal(await raw.text(), readFileSync(article, 'utf8'))
    for (const endpoint of ['/api/file', '/api/file/raw', '/api/file/text', '/api/file/switch']) {
      const response = await fetch(
        `${origin}${endpoint}?${new URLSearchParams({ filepath: privateFile })}`,
        { headers },
      )
      assert.equal(response.status, 403)
      assert.equal((await response.json()).error, 'Path is outside allowed roots')
    }
    const save = await fetch(`${origin}/api/file/save`, {
      method: 'POST',
      headers: { ...headers, 'content-type': 'application/json' },
      body: JSON.stringify({ filepath: privateFile, content: 'no' }),
    })
    assert.equal(save.status, 403)
    assert.equal(
      (
        await fetch(`${origin}/api/workspace/files?${new URLSearchParams({ root: outside })}`, {
          headers,
        })
      ).status,
      403,
    )
    assert.equal(
      (
        await fetch(
          `${origin}/api/file?${new URLSearchParams({ filepath: path.join(docs, 'absent.md') })}`,
          { headers },
        )
      ).status,
      404,
    )
    assert.equal((await fetch(`${origin}/api/file?filepath=relative.md`, { headers })).status, 400)
    const defaults = await fetch(`${origin}/api/workspaces`, { headers })
    assert.deepEqual((await defaults.json()).data.defaultWorkspaceRoots, [docs])
  } finally {
    server.closeAllConnections()
    await new Promise(resolve => server.close(resolve))
  }
})
