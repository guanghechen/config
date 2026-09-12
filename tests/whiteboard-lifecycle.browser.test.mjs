import assert from 'node:assert/strict'
import { spawn } from 'node:child_process'
import { once } from 'node:events'
import { mkdtemp, rm } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import path from 'node:path'
import { test } from 'node:test'
import { createWhiteboardServer } from './fixtures/whiteboard-server.mjs'

// Uses the same installed-Chromium/CDP approach as virtual-list.browser.test.mjs.
test(
  'whiteboard host lifecycle, instance isolation and embedded overlays',
  {
    skip: !process.env.CHROMIUM_PATH && 'Set CHROMIUM_PATH to an installed Chromium executable',
    timeout: 60000,
  },
  async t => {
    const fixture = await createWhiteboardServer()
    const profile = await mkdtemp(path.join(tmpdir(), 'yoz-whiteboard-profile-'))
    let browser, socket, exited
    const pending = new Map()
    t.after(async () => {
      for (const request of pending.values()) clearTimeout(request.timer)
      socket?.close()
      if (browser && browser.exitCode === null && browser.signalCode === null) {
        browser.kill()
        const force = setTimeout(() => browser.kill('SIGKILL'), 2000)
        await exited
        clearTimeout(force)
      } else if (exited) await exited
      await fixture.close()
      await rm(profile, { recursive: true, force: true })
    })
    browser = spawn(
      process.env.CHROMIUM_PATH,
      [
        '--headless=new',
        '--no-sandbox',
        '--disable-gpu',
        '--disable-extensions',
        '--disable-background-networking',
        '--remote-debugging-port=0',
        `--user-data-dir=${profile}`,
        'about:blank',
      ],
      { stdio: ['ignore', 'ignore', 'pipe'] },
    )
    exited = new Promise(resolve => browser.once('exit', resolve))
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
    socket = new WebSocket(endpoint)
    await once(socket, 'open')
    let sequence = 0
    socket.addEventListener('message', event => {
      const message = JSON.parse(event.data)
      const request = pending.get(message.id)
      if (!request) return
      pending.delete(message.id)
      clearTimeout(request.timer)
      if (message.error) request.reject(new Error(JSON.stringify(message.error)))
      else request.resolve(message.result)
    })
    const send = (method, params = {}, sessionId) =>
      new Promise((resolve, reject) => {
        sequence += 1
        const id = sequence
        const timer = setTimeout(() => {
          pending.delete(id)
          reject(new Error(`CDP timeout: ${method}`))
        }, 45000)
        pending.set(id, { resolve, reject, timer })
        socket.send(JSON.stringify({ id, method, params, sessionId }))
      })
    const { targetId } = await send('Target.createTarget', { url: 'about:blank' })
    const { sessionId } = await send('Target.attachToTarget', { targetId, flatten: true })
    await send('Page.enable', {}, sessionId)
    const loaded = new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        socket.removeEventListener('message', listener)
        reject(new Error('Fixture navigation timed out'))
      }, 20000)
      const listener = event => {
        const message = JSON.parse(event.data)
        if (message.sessionId === sessionId && message.method === 'Page.loadEventFired') {
          clearTimeout(timer)
          socket.removeEventListener('message', listener)
          resolve()
        }
      }
      socket.addEventListener('message', listener)
    })
    await send('Page.navigate', { url: `${fixture.url}/regression.html` }, sessionId)
    await loaded
    const result = await send(
      'Runtime.evaluate',
      {
        expression: `(async()=>{const deadline=Date.now()+20000;while(!window.runRegression){if(Date.now()>deadline)throw Error('Regression fixture did not load');await new Promise(r=>setTimeout(r,20))}return window.runRegression()})()`,
        awaitPromise: true,
        returnByValue: true,
      },
      sessionId,
    )
    assert.equal(result.exceptionDetails, undefined, JSON.stringify(result.exceptionDetails))
    assert.deepEqual(result.result.value, [
      'keyboard ownership',
      'clipboard and dialog ownership',
      'presentation ownership',
      'save/import race and unload protection',
      'reload cancellation',
      'host failure recovery',
      'notification fallback',
      'embedded overlays',
    ])
  },
)
