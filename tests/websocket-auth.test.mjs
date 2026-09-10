import assert from 'node:assert/strict'
import { test } from 'node:test'
import { readFileSync } from 'node:fs'
import { createRequire } from 'node:module'
import { runInThisContext } from 'node:vm'
import { EventEmitter } from 'node:events'
import path from 'node:path'
import ts from 'typescript'
import jwt from 'jsonwebtoken'

const root = path.resolve(import.meta.dirname, '..')
const secret = 'only-a-test-fixture-secret'
let state
const cache = new Map()
function load(filename) {
  let filepath = path.resolve(root, filename)
  if (!path.extname(filepath)) filepath += '.ts'
  if (filepath === path.join(root, 'env.ts')) return { SERVER_HOST: 'localhost', SERVER_PORT: 7071 }
  if (filepath === path.join(root, 'server/state.ts')) return { __esModule: true, default: state }
  if (filepath === path.join(root, 'server/util/open.ts')) return { openBrowser: async () => {} }
  if (filepath === path.join(root, 'server/util/misc.ts')) return { sleep: async () => {} }
  if (filepath === path.join(root, 'shared/types.ts')) return load('shared/types/api/event.ts')
  if (filepath === path.join(root, 'shared/util.ts')) return load('shared/util/url.ts')
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
  runInThisContext(`(function(module, exports, require, process) { ${output}\n })`)(
    module,
    module.exports,
    id => {
      return id.startsWith('.') ? load(path.resolve(path.dirname(filepath), id)) : require(id)
    },
    { env: { YOZ_JWT_SECRET: secret } },
  )
  return module.exports
}
function signal() {
  const subscriptions = new Set()
  return {
    subscribe(subscriber) {
      subscriptions.add(subscriber)
      return {
        unsubscribe() {
          subscriptions.delete(subscriber)
        },
      }
    },
    next(value) {
      for (const subscriber of subscriptions) subscriber.next(value)
    },
    get size() {
      return subscriptions.size
    },
  }
}

test('file events require JWT, expire with it, and stop after logout or disconnect', async () => {
  state = {
    authLogout$: signal(),
    fileChanged$: signal(),
    fileSwitch$: signal(),
    fileSwitchArgForce$: { getSnapshot: () => false },
    reporter: { error() {} },
  }
  const ws = new EventEmitter()
  ws.clients = new Set()
  ws.send = () => assert.fail('Business events must never use broadcast')
  const httpServer = new EventEmitter()
  load('server/plugin/ws.ts').default().configureServer({ ws, httpServer })
  const token = jwt.sign({ authenticated: true }, secret, { expiresIn: '1h' })
  const expiring = jwt.sign(
    { authenticated: true, exp: Math.floor(Date.now() / 1000) + 10 },
    secret,
  )
  function connect(headers) {
    const messages = []
    const socket = new EventEmitter()
    ws.clients.add({ socket, send: message => messages.push(message) })
    ws.emit('connection', socket, { headers })
    return { messages, socket }
  }
  const anonymous = connect({})
  const invalid = connect({ cookie: 'yoz-auth=invalid' })
  const wrongClaims = connect({
    authorization: `Bearer ${jwt.sign({ authenticated: false }, secret, { expiresIn: '1h' })}`,
  })
  const authenticated = connect({ cookie: `yoz-auth=${token}` })
  const bearer = connect({ authorization: `Bearer ${expiring}` })
  state.fileChanged$.next('/fixture/private/file.md')
  state.fileSwitch$.next('/fixture/private/file.md')
  assert.equal(anonymous.messages.length, 0)
  assert.equal(invalid.messages.length, 0)
  assert.equal(wrongClaims.messages.length, 0)
  assert.equal(authenticated.messages.length, 2)
  assert.equal(bearer.messages.length, 2)
  const originalNow = Date.now
  try {
    Date.now = () => originalNow() + 20000
    state.fileChanged$.next('/fixture/private/another.md')
  } finally {
    Date.now = originalNow
  }
  assert.equal(bearer.messages.length, 2, 'expired JWT stops receiving events')
  assert.equal(authenticated.messages.length, 3)
  const logout = load('server/plugin/api/h/api/user/logout.ts').postUserLogout
  await logout({ req: { headers: { cookie: `yoz-auth=${token}` } } })
  state.fileChanged$.next('/fixture/private/after-logout.md')
  assert.equal(authenticated.messages.length, 3, 'logout removes connection authorization')
  const disconnected = connect({ cookie: `yoz-auth=${token}` })
  disconnected.socket.emit('close')
  state.fileChanged$.next('/fixture/private/closed.md')
  assert.equal(disconnected.messages.length, 0)
  httpServer.emit('close')
  assert.equal(state.authLogout$.size, 0)
  assert.equal(state.fileChanged$.size, 0)
  assert.equal(state.fileSwitch$.size, 0)
})
