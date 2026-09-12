import { readFileSync } from 'node:fs'
import { mkdtemp, rm, symlink, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import path from 'node:path'
import { createRequire } from 'node:module'
import { runInThisContext } from 'node:vm'
import { createServer } from 'vite'
import react from '@vitejs/plugin-react'
import tailwind from '@tailwindcss/vite'
import ts from 'typescript'

// Isolated browser fixture. Real file handlers run against a task-owned directory, with no dotenv.
export async function createWhiteboardServer() {
  const root = path.resolve(import.meta.dirname, '../..')
  const directory = await mkdtemp(path.join(tmpdir(), 'yoz-whiteboard-browser-'))
  const filepath = path.join(directory, 'reference.md')
  await writeFile(
    filepath,
    '# Referenced notes\n\nOriginal source content.\n\n$$E = mc^2$$\n\n| Layer | Role |\n| --- | --- |\n| Canvas | Shapes |\n| DOM | Markdown |\n\n```typescript\nconst node = { x: 1, y: 2 }\n```\n\n```mermaid\nflowchart LR\n A --> B\n```\n',
  )
  await symlink(path.join(root, 'node_modules'), path.join(directory, 'node_modules'), 'dir')
  const cache = new Map()
  let state
  function load(filename) {
    const filepath = path.resolve(root, filename)
    if (filepath === path.join(root, 'server/state.ts')) return { __esModule: true, default: state }
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
    runInThisContext(`(function(module,exports,require){${output}\n})`, { filename: filepath })(
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
    )
    return module.exports
  }
  const { FileAccess } = load('server/util/file-access.ts')
  state = {
    access: new FileAccess([directory]),
    defaultWorkspaceRoots: [directory],
    legacyWorkspaces: [],
    watch() {},
    reporter: { error() {}, warn() {}, debug() {} },
  }
  const handles = {
    '/api/file/text': load('server/plugin/api/h/api/file/text.ts').fetchFileText,
    '/api/file/save': load('server/plugin/api/h/api/file/save.ts').saveFile,
    '/api/file/raw': load('server/plugin/api/h/api/file/raw.ts').fetchFileRaw,
    '/api/whiteboard/create': load('server/plugin/api/h/api/whiteboard/create.ts').createWhiteboard,
    '/api/workspaces': load('server/plugin/api/h/api/workspaces.ts').list_workspaces,
    '/api/workspace/files': load('server/plugin/api/h/api/workspace/files.ts').list_workspace_files,
  }
  await writeFile(
    path.join(directory, 'index.html'),
    '<div id="root"></div><script type="module" src="/fixture.tsx"></script>',
  )
  await writeFile(
    path.join(directory, 'fixture.css'),
    `@import "${root}/src/common/style/index.css";\n@source "${root}/src";\n`,
  )
  await writeFile(
    path.join(directory, 'fixture.tsx'),
    `
    import React from 'react'
    import { createRoot } from 'react-dom/client'
    import { MathJaxProvider } from '@yozora/react-mathjax'
    import { SiteContextProvider } from '${root}/src/context/site/Provider.tsx'
    import { WhiteboardBoard } from '${root}/src/view/whiteboard/View.tsx'
    import { createBenchmarkScene } from '${root}/tests/fixtures/whiteboard-scene.ts'
    import './fixture.css'
    const query = new URLSearchParams(location.search)
    const initialDocument = query.has('benchmark') ? createBenchmarkScene(query.has('connectors'), query.has('typography'), query.has('transforms')) : undefined
    createRoot(document.getElementById('root')).render(<React.StrictMode><SiteContextProvider><MathJaxProvider>
      <WhiteboardBoard initialDocument={initialDocument} filepath={query.get('filepath') ?? undefined} />
    </MathJaxProvider></SiteContextProvider></React.StrictMode>)
  `,
  )
  await writeFile(
    path.join(directory, 'standalone.html'),
    '<style>html,body,#root{height:100%;margin:0}</style><div id="root"></div><script type="module" src="/standalone.tsx"></script>',
  )
  await writeFile(
    path.join(directory, 'standalone.tsx'),
    `
    import React from 'react'
    import { createRoot } from 'react-dom/client'
    import { Whiteboard } from '${root}/src/view/whiteboard/Whiteboard.tsx'
    import { createDocument } from '${root}/shared/whiteboard/model.ts'
    createRoot(document.getElementById('root')).render(<React.StrictMode><Whiteboard initialDocument={createDocument()} style={new URLSearchParams(location.search).has('embedded') ? {width:480,height:600} : undefined} /></React.StrictMode>)
  `,
  )
  await writeFile(
    path.join(directory, 'regression.html'),
    `<style>html,body,#root{margin:0;height:100%}</style><div id="root"></div><script type="module">import {runWhiteboardRegression} from ${JSON.stringify(`/@fs${path.join(root, 'tests/fixtures/whiteboard-regression.tsx')}`)}; window.runRegression = runWhiteboardRegression</script>`,
  )
  const server = await createServer({
    root: directory,
    configFile: false,
    envDir: false,
    cacheDir: path.join(directory, 'cache'),
    resolve: {
      alias: [
        { find: '@/shared', replacement: path.join(root, 'shared') },
        { find: '@', replacement: path.join(root, 'src') },
      ],
    },
    plugins: [
      react(),
      tailwind(),
      {
        name: 'whiteboard-fixture-api',
        configureServer(server) {
          server.middlewares.use((req, res, next) => {
            const url = new URL(req.url, 'http://localhost')
            const handle = handles[url.pathname]
            if (!handle) return next()
            void (async () => {
              const chunks = []
              for await (const chunk of req) chunks.push(chunk)
              try {
                const result = await handle({
                  req,
                  res,
                  searchParams: url.searchParams,
                  pathname: url.pathname,
                  body: Buffer.concat(chunks).toString('utf8'),
                })
                if (result === true) return
                res.writeHead(result.code, { 'content-type': 'application/json' })
                res.end(JSON.stringify(result.data))
              } catch (error) {
                res.writeHead(error.status ?? 500, { 'content-type': 'application/json' })
                res.end(JSON.stringify({ error: error.message }))
              }
            })()
          })
        },
      },
    ],
    server: {
      host: '127.0.0.1',
      port: 0,
      fs: { allow: [root, directory] },
      watch: {
        ignored: ['**/*.md', '**/*.whiteboard'],
        awaitWriteFinish: { stabilityThreshold: 200, pollInterval: 50 },
      },
    },
    optimizeDeps: {
      include: ['react', 'react-dom', 'react-dom/client', 'monaco-editor', '@monaco-editor/react'],
    },
  })
  await server.listen()
  return {
    directory,
    filepath,
    url: `http://127.0.0.1:${server.httpServer.address().port}`,
    close: async () => {
      await server.close()
      await rm(directory, { recursive: true, force: true })
    },
  }
}

if (process.argv[1] === import.meta.filename) {
  const fixture = await createWhiteboardServer()
  console.log(
    JSON.stringify({ url: fixture.url, filepath: fixture.filepath, directory: fixture.directory }),
  )
  for (const signal of ['SIGINT', 'SIGTERM'])
    process.once(signal, () => {
      void fixture.close().then(() => process.exit())
    })
}
