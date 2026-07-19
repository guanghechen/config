import assert from 'node:assert/strict'
import test from 'node:test'
import { subscribeActivePageChanges } from '../src/popup/service/active-page-events.ts'

test('active page subscriptions refresh on relevant tab and window changes', t => {
  const activated = createEvent()
  const updated = createEvent()
  const focused = createEvent()
  globalThis.chrome = {
    tabs: { onActivated: activated, onUpdated: updated },
    windows: { WINDOW_ID_NONE: -1, onFocusChanged: focused },
  }
  t.after(() => delete globalThis.chrome)

  let refreshCount = 0
  const unsubscribe = subscribeActivePageChanges(() => {
    refreshCount += 1
  })

  activated.emit({ tabId: 1, windowId: 1 })
  updated.emit(1, {}, { active: true })
  updated.emit(1, { title: 'ignored' }, { active: true })
  updated.emit(1, { status: 'loading' }, { active: false })
  updated.emit(1, { url: 'https://example.com' }, { active: true })
  focused.emit(-1)
  focused.emit(1)
  assert.equal(refreshCount, 3)

  unsubscribe()
  activated.emit({ tabId: 2, windowId: 1 })
  updated.emit(2, { status: 'complete' }, { active: true })
  focused.emit(1)
  assert.equal(refreshCount, 3)
})

function createEvent() {
  const listeners = new Set()
  return {
    addListener(listener) {
      listeners.add(listener)
    },
    removeListener(listener) {
      listeners.delete(listener)
    },
    emit(...args) {
      for (const listener of listeners) listener(...args)
    },
  }
}
