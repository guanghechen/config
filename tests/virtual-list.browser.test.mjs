import assert from 'node:assert/strict'
import { spawn } from 'node:child_process'
import { once } from 'node:events'
import { mkdtemp, rm, symlink, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import path from 'node:path'
import { test } from 'node:test'
import { fileURLToPath } from 'node:url'
import { createServer } from 'vite'

// CHROMIUM_PATH=/path/to/chrome node --test tests/virtual-list.browser.test.mjs
// Uses an existing browser; installs nothing and keeps all generated files in a temporary directory.
test(
  'VirtualList preserves visible rows across layout changes and fast scrolling',
  {
    skip: !process.env.CHROMIUM_PATH && 'Set CHROMIUM_PATH to an installed Chromium executable',
    timeout: 30000,
  },
  async t => {
    const root = fileURLToPath(new URL('../', import.meta.url))
    const temporary = await mkdtemp(path.join(tmpdir(), 'yoz-virtual-list-'))
    t.after(() => rm(temporary, { recursive: true, force: true }))
    await symlink(path.join(root, 'node_modules'), path.join(temporary, 'node_modules'), 'dir')
    await writeFile(
      path.join(temporary, 'index.html'),
      '<div id="root"></div><script type="module" src="/fixture.tsx"></script>',
    )
    await writeFile(
      path.join(temporary, 'fixture.tsx'),
      `
    import React from 'react'
    import { createRoot } from 'react-dom/client'
    import { VirtualList } from ${JSON.stringify(`/@fs/${root}src/common/component/virtual-list/VirtualList.tsx`)}
    const items = Array.from({length: 10000}, (_, i) => i)
    function App() {
      const [config, configure] = React.useState({
        height: 330, paddingTop: 0, paddingBottom: 0, boxSizing: 'content-box',
        count: 10000, className: '', overscan: 0,
      })
      window.configure = update => configure(current => ({...current, ...update}))
      const {count, className, overscan, ...style} = config
      return <VirtualList items={items.slice(0, count)} itemHeight={33}
        overscan={overscan} getItemKey={item => item} className={className}
        renderItem={item => <span data-row={item}>Row {item}</span>}
        style={{width: 360, ...style}} />
    }
    createRoot(document.getElementById('root')).render(<React.StrictMode><App /></React.StrictMode>)
  `,
    )
    const server = await createServer({
      root: temporary,
      configFile: false,
      envDir: false,
      cacheDir: path.join(temporary, 'cache'),
      server: { host: '127.0.0.1', port: 0, fs: { allow: [temporary, root] } },
      optimizeDeps: { include: ['react', 'react-dom/client'] },
    })
    t.after(() => server.close())
    await server.listen()
    const browser = spawn(
      process.env.CHROMIUM_PATH,
      [
        '--headless=new',
        '--no-sandbox',
        '--disable-gpu',
        '--remote-debugging-port=0',
        `--user-data-dir=${path.join(temporary, 'profile')}`,
        'about:blank',
      ],
      { stdio: ['ignore', 'ignore', 'pipe'] },
    )
    const exited = new Promise(resolve => browser.once('exit', resolve))
    t.after(async () => {
      if (browser.exitCode === null && browser.signalCode === null) browser.kill()
      await exited
    })
    const endpoint = await new Promise((resolve, reject) => {
      let output = ''
      browser.once('error', reject)
      browser.once('exit', code => reject(new Error(`Chromium exited before ready: ${code}`)))
      browser.stderr.on('data', chunk => {
        output += chunk
        const match = output.match(/DevTools listening on (ws:\/\/\S+)/)
        if (match) resolve(match[1])
      })
    })
    const socket = new WebSocket(endpoint)
    t.after(() => socket.close())
    await once(socket, 'open')
    let sequence = 0
    const pending = new Map()
    socket.addEventListener('message', event => {
      const message = JSON.parse(event.data)
      const request = pending.get(message.id)
      if (!request) return
      pending.delete(message.id)
      clearTimeout(request.timeout)
      if (message.error) request.reject(new Error(JSON.stringify(message.error)))
      else request.resolve(message.result)
    })
    function send(method, params = {}, sessionId) {
      sequence += 1
      const id = sequence
      return new Promise((resolve, reject) => {
        const timeout = setTimeout(() => {
          pending.delete(id)
          reject(new Error(`CDP timeout: ${method}`))
        }, 5000)
        pending.set(id, { resolve, reject, timeout })
        socket.send(JSON.stringify({ id, method, params, sessionId }))
      })
    }
    const { targetId } = await send('Target.createTarget', { url: 'about:blank' })
    const { sessionId } = await send('Target.attachToTarget', { targetId, flatten: true })
    async function evaluate(expression) {
      const result = await send(
        'Runtime.evaluate',
        {
          expression,
          awaitPromise: true,
          returnByValue: true,
        },
        sessionId,
      )
      assert.equal(result.exceptionDetails, undefined, JSON.stringify(result.exceptionDetails))
      return result.result.value
    }
    await send(
      'Page.navigate',
      { url: `http://127.0.0.1:${server.httpServer.address().port}` },
      sessionId,
    )
    let ready = false
    for (let attempt = 0; attempt < 100 && !ready; attempt += 1) {
      ready = await evaluate('!!window.configure && !!document.querySelector("[data-row]")').catch(
        () => false,
      )
      if (!ready) await new Promise(resolve => setTimeout(resolve, 50))
    }
    assert(ready, 'Fixture failed to mount')
    const settle = () =>
      evaluate('new Promise(r => requestAnimationFrame(() => requestAnimationFrame(r)))')
    async function configure(update) {
      await evaluate(`window.configure(${JSON.stringify(update)})`)
      await settle()
    }
    const readVisibleRows = `() => {
      const box = document.querySelector('#root > div')
      const boundary = box.getBoundingClientRect()
      const spacer = box.firstElementChild.getBoundingClientRect()
      const present = new Set([...box.querySelectorAll('[data-row]')].map(row => +row.dataset.row))
      const missing = []
      for (let index = 0; index < Math.round(spacer.height / 33); index++) {
        const top = spacer.top + index * 33
        if (top < boundary.top + box.clientHeight && top + 33 > boundary.top && !present.has(index)) {
          missing.push(index)
        }
      }
      return {missing, renderedCount: present.size}
    }`
    async function assertVisibleRows() {
      const { missing } = await evaluate(`(${readVisibleRows})()`)
      assert.deepEqual(missing, [], 'Visible rows must all be rendered')
    }
    await settle()
    await evaluate("document.querySelector('#root > div').scrollTop = 330")
    await settle()
    await assertVisibleRows()
    await configure({ paddingTop: 100 })
    await assertVisibleRows()
    await configure({ boxSizing: 'border-box', paddingTop: 0, paddingBottom: 200, overscan: 5 })
    await configure({ paddingTop: 200, paddingBottom: 0 })
    await assertVisibleRows()
    await configure({ paddingTop: 0, paddingBottom: 0, overscan: 0 })
    await evaluate(`document.head.appendChild(Object.assign(document.createElement('style'), {
    textContent: '.padded {padding-top:100px!important; padding-bottom:100px!important}'
  }))`)
    await configure({ className: 'padded' })
    await assertVisibleRows()
    // A stylesheet edit without a React commit is picked up on the next scroll.
    await evaluate("document.head.lastChild.textContent = '.padded {padding-top:200px!important}'")
    await evaluate("document.querySelector('#root > div').scrollTop += 33")
    await settle()
    await assertVisibleRows()
    await configure({ className: '', count: 2 })
    await assertVisibleRows()
    await configure({ count: 10000, height: 660 })
    await assertVisibleRows()
    await configure({
      height: 330,
      boxSizing: 'border-box',
      paddingTop: 8,
      paddingBottom: 8,
      overscan: 5,
    })
    for (const scrollTop of [33000, 165000, 66000, 200000, 0]) {
      // Sample inside the first frame; waiting for another CDP call can hide a blank paint.
      const frame = await evaluate(`new Promise(resolve => {
        const box = document.querySelector('#root > div')
        box.addEventListener('scroll', () => requestAnimationFrame(() => {
          resolve({scrollTop: box.scrollTop, ...(${readVisibleRows})()})
        }), {once: true})
        box.scrollTop = ${scrollTop}
      })`)
      assert.equal(frame.scrollTop, scrollTop)
      assert.deepEqual(
        frame.missing,
        [],
        `First frame after scrolling to ${scrollTop} must be covered`,
      )
      assert(frame.renderedCount < 30, 'Scrolling must keep the rendered row count bounded')
    }
    await send('Browser.close')
    await exited
  },
)
