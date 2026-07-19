import assert from 'node:assert/strict'
import test from 'node:test'
import { HighlightOverlay, isBoundsInViewport } from '../src/agent/content/highlight.ts'

test('highlight viewport policy and overlay tracking remain aligned', t => {
  const browser = installFakeBrowser()
  t.after(browser.restore)

  const highlight = new HighlightOverlay()
  const target = new browser.FakeElement({ x: 900, y: 20, width: 100, height: 40 })
  assert.equal(isBoundsInViewport(target.bounds, 800, 600), false)

  target.bounds = { x: 30, y: 40, width: 100, height: 50 }
  assert.equal(isBoundsInViewport(target.bounds, 800, 600), true)
  highlight.show(target, target.bounds, 1_500)
  assert.match(browser.overlay.style.cssText, /position:fixed/)
  assert.equal(browser.overlay.style.values.left, '30px')
  assert.equal(browser.overlay.style.values.top, '40px')

  target.bounds = { x: 45, y: 70, width: 120, height: 60 }
  browser.emit('scroll')
  browser.flushAnimationFrames()
  assert.equal(browser.overlay.style.values.left, '45px')
  assert.equal(browser.overlay.style.values.top, '70px')
  assert.equal(browser.overlay.style.values.width, '120px')

  highlight.dispose()
  assert.equal(browser.overlay.removed, true)
  assert.equal(browser.listenerCount('scroll'), 0)
  assert.equal(browser.listenerCount('resize'), 0)
})

function installFakeBrowser() {
  const previous = {
    document: globalThis.document,
    Element: globalThis.Element,
    window: globalThis.window,
  }
  const animationFrames = new Map()
  const listeners = new Map()
  let nextAnimationFrameId = 1
  let nextTimerId = 1
  let overlay

  class FakeElement {
    constructor(bounds = { x: 0, y: 0, width: 0, height: 0 }) {
      this.bounds = bounds
      this.isConnected = true
    }

    getBoundingClientRect() {
      return this.bounds
    }
  }

  class FakeOverlay extends FakeElement {
    constructor() {
      super()
      this.removed = false
      this.style = {
        cssText: '',
        values: {},
        setProperty(name, value) {
          this.values[name] = value
        },
      }
    }

    remove() {
      this.removed = true
    }

    setAttribute() {}
  }

  globalThis.Element = FakeElement
  globalThis.document = {
    createElement() {
      overlay = new FakeOverlay()
      return overlay
    },
    documentElement: {
      appendChild() {},
    },
  }
  globalThis.window = {
    innerHeight: 600,
    innerWidth: 800,
    addEventListener(type, listener) {
      const entries = listeners.get(type) ?? new Set()
      entries.add(listener)
      listeners.set(type, entries)
    },
    removeEventListener(type, listener) {
      listeners.get(type)?.delete(listener)
    },
    requestAnimationFrame(callback) {
      const id = nextAnimationFrameId
      nextAnimationFrameId += 1
      animationFrames.set(id, callback)
      return id
    },
    cancelAnimationFrame(id) {
      animationFrames.delete(id)
    },
    setTimeout() {
      const id = nextTimerId
      nextTimerId += 1
      return id
    },
    clearTimeout() {},
  }

  return {
    FakeElement,
    get overlay() {
      return overlay
    },
    emit(type) {
      for (const listener of listeners.get(type) ?? []) listener()
    },
    flushAnimationFrames() {
      const callbacks = [...animationFrames.values()]
      animationFrames.clear()
      for (const callback of callbacks) callback(0)
    },
    listenerCount(type) {
      return listeners.get(type)?.size ?? 0
    },
    restore() {
      globalThis.document = previous.document
      globalThis.Element = previous.Element
      globalThis.window = previous.window
    },
  }
}
