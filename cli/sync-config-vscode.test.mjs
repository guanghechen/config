import assert from 'node:assert/strict'
import { describe, it } from 'node:test'

import { composeKeybindings, formatKey, sortKeybindings } from './sync-config-vscode.mjs'

describe('sync-config-vscode keybinding order', () => {
  it('normalizes modifier order', () => {
    assert.equal(formatKey('shift+ctrl+cmd+f10'), 'cmd+ctrl+shift+f10')
  })

  it('sorts keys alphabetically with natural numeric order', () => {
    const keybindings = [
      { key: 'f10', command: 'f10' },
      { key: 'cmd+a', command: 'a' },
      { key: 'f2', command: 'f2' },
      { key: 'cmd+0', command: 'zero' },
      { key: 'cmd+/', command: 'slash' },
      { key: 'f1', command: 'f1' },
    ]

    assert.deepEqual(sortKeybindings(keybindings).map(x => x.key), [
      'cmd+/',
      'cmd+0',
      'cmd+a',
      'f1',
      'f2',
      'f10',
    ])
  })

  it('keeps equal-key rules in low-to-high priority order', () => {
    const keybindings = [
      { key: 'cmd+k', command: 'specific-low', when: 'firstContext' },
      { key: 'cmd+k', command: 'fallback' },
      { key: 'cmd+k', command: 'specific-high', when: 'secondContext' },
    ]

    assert.deepEqual(sortKeybindings(keybindings).map(x => x.command), [
      'fallback',
      'specific-low',
      'specific-high',
    ])
  })

  it('puts removals first and terminal rebinds last for equal keys', () => {
    const keybindings = composeKeybindings(
      [
        { key: 'cmd+k', command: '-default.command' },
        { key: 'cmd+j', command: '-other-default.command' },
      ],
      [
        { key: 'cmd+k', command: 'fallback' },
        { key: 'cmd+k', command: 'contextual', when: 'editorFocus' },
      ],
      [{ key: 'cmd+k', command: 'terminal', when: 'terminalFocus' }],
    )

    assert.deepEqual(keybindings.map(x => x.command), [
      '-other-default.command',
      '-default.command',
      'fallback',
      'contextual',
      'terminal',
    ])
  })
})
