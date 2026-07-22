#!/usr/bin/env node

/**
 * Sync VSCode keybindings configuration.
 */

import fs from 'node:fs'
import path from 'node:path'

import { F_VSCODE_KEYBINDINGS, PLATFORM, XDG_CONFIG_NODE_ASSET_APP_DIR } from '#env'
import { Command } from '#stl/commander'
import { Reporter } from '#stl/reporter'

const reporter = new Reporter({ prefix: 'sync-config-vscode' })

/**
 * @typedef {Object} IVscodeKeybinding
 * @property {string} key - Key combination (e.g., "ctrl+f1", "cmd+shift+p")
 * @property {string} command - Command identifier to invoke
 * @property {string} [when] - When clause context condition
 * @property {string} [mac] - macOS-specific key override
 * @property {string} [title] - Optional title for the keybinding
 * @property {*} [args] - Optional arguments passed to the command
 */

/** @typedef {Record<string, number>} IKeyRanks */

/** @type {IKeyRanks} */
const ranks = {
  cmd: 10,
  command: 10,
  super: 10,
  win: 10,
  alt: 8,
  option: 8,
  ctrl: 5,
  shift: 3,
  left: 2,
  down: 2,
  right: 2,
  up: 2,
  home: 2,
  enter: 2,
  oem_comma: 2,
  oem_period: 2,
  f1: 1.824,
  f2: 1.823,
  f3: 1.822,
  f4: 1.821,
  f5: 1.82,
  f6: 1.819,
  f7: 1.818,
  f8: 1.817,
  f9: 1.816,
  f10: 1.815,
  f11: 1.814,
  f12: 1.813,
  f13: 1.812,
  f14: 1.811,
  f15: 1.81,
  f16: 1.809,
  f17: 1.808,
  f18: 1.807,
  f19: 1.806,
  f20: 1.805,
  f21: 1.804,
  f22: 1.803,
  f23: 1.802,
  f24: 1.801,
}

/**
 * @param {string} key
 * @returns {string}
 */
function formatKey(key) {
  return key
    .split(/\s+/g)
    .filter(x => !!x)
    .map(text =>
      text
        .split('+')
        .sort((x, y) => {
          const r1 = ranks[x.toLowerCase()] ?? 1
          const r2 = ranks[y.toLowerCase()] ?? 1
          return r2 - r1
        })
        .join('+'),
    )
    .join(' ')
}

/**
 * @param {IVscodeKeybinding[]} keybindings
 * @returns {IVscodeKeybinding[]}
 */
function sortKeybindings(keybindings) {
  return keybindings
    .map(x => {
      const { key, command, when, title, ...rest } = x
      return { key: formatKey(key), command, when, title, ...rest }
    })
    .sort((x, y) => {
      const keys_x = x.key.split('+')
      const keys_y = y.key.split('+')
      const L = Math.min(keys_x.length, keys_y.length)

      for (let i = 0; i < L; ++i) {
        const kx = keys_x[i]
        const ky = keys_y[i]
        const rx = ranks[kx.toLowerCase()] ?? 1
        const ry = ranks[ky.toLowerCase()] ?? 1
        if (rx !== ry) return ry - rx
        if (kx !== ky) return kx < ky ? -1 : 1
      }

      if (keys_x.length !== keys_y.length) return keys_x.length - keys_y.length

      if (x.when === y.when) return 0
      if (!x.when) return -1
      if (!y.when) return 1
      return 0
    })
}

/**
 * @param {string} source
 * @param {IVscodeKeybinding[]} keybindings
 * @param {boolean} unbind
 */
function validateKeybindings(source, keybindings, unbind) {
  const seen = new Map()

  keybindings.forEach((keybinding, index) => {
    if (typeof keybinding.key !== 'string' || typeof keybinding.command !== 'string') {
      throw new Error(`${source}[${index}] must contain string key and command fields`)
    }

    const isUnbind = keybinding.command.startsWith('-')
    if (isUnbind !== unbind) {
      const expected = unbind ? 'an unbind command prefixed with -' : 'a positive command'
      throw new Error(`${source}[${index}] must contain ${expected}: ${keybinding.command}`)
    }

    const normalized = sortKeybindings([keybinding])[0]
    const fingerprint = JSON.stringify(normalized)
    const previousIndex = seen.get(fingerprint)
    if (previousIndex !== undefined) {
      throw new Error(`${source}[${index}] duplicates ${source}[${previousIndex}]`)
    }
    seen.set(fingerprint, index)
  })
}

/**
 * @param {string} targetKeybindingsPath - Path to the VSCode keybindings.json file
 */
export function handleSyncConfigVscode(targetKeybindingsPath) {
  if (!targetKeybindingsPath || !fs.existsSync(path.dirname(targetKeybindingsPath))) return

  reporter.info('Syncing VSCode keybindings to:', targetKeybindingsPath)

  const encoding = 'utf8'
  const middle = PLATFORM === 'wsl' ? 'win' : PLATFORM
  const CONFIG_DIR = path.join(XDG_CONFIG_NODE_ASSET_APP_DIR, 'vscode/keybinding', middle)
  if (!fs.existsSync(CONFIG_DIR)) return

  const fp_rebind = path.join(CONFIG_DIR, 'rebind.json')
  const fp_customize = path.join(CONFIG_DIR, 'customize.json')
  const fp_unbind = path.join(CONFIG_DIR, 'unbind.json')
  const fp_keybindings = path.join(CONFIG_DIR, 'keybindings.json')

  const raw_rebind = JSON.parse(fs.readFileSync(fp_rebind, encoding))
  const raw_customize = JSON.parse(fs.readFileSync(fp_customize, encoding))
  const raw_unbind = JSON.parse(fs.readFileSync(fp_unbind, encoding))

  validateKeybindings('rebind', raw_rebind, false)
  validateKeybindings('customize', raw_customize, false)
  validateKeybindings('unbind', raw_unbind, true)

  const resolved_rebind = sortKeybindings(raw_rebind)
  const resolved_customize = sortKeybindings(raw_customize)

  const existed_keys = new Set(
    resolved_customize.map(x => [x.key, '-' + x.command, x.when ?? 'undefined'].join('#.#')),
  )
  const resolved_unbind = sortKeybindings(raw_unbind).filter(x => {
    const key = [x.key, x.command, x.when ?? 'undefined'].join('#.#')
    return !existed_keys.has(key)
  })
  const resolved_items = [...resolved_unbind, ...resolved_customize, ...resolved_rebind]

  const content_rebind = JSON.stringify(resolved_rebind, null, 2) + '\n'
  const content_customize = JSON.stringify(resolved_customize, null, 2) + '\n'
  const content_unbind = JSON.stringify(resolved_unbind, null, 2) + '\n'
  const content_all = JSON.stringify(resolved_items, null, 2) + '\n'

  fs.writeFileSync(fp_rebind, content_rebind, encoding)
  fs.writeFileSync(fp_customize, content_customize, encoding)
  fs.writeFileSync(fp_unbind, content_unbind, encoding)
  fs.writeFileSync(fp_keybindings, content_all, encoding)
  fs.writeFileSync(targetKeybindingsPath, content_all, encoding)

  reporter.info('VSCode keybindings synced successfully')
}

if (process.argv[1] === import.meta.filename) {
  const cmd = new Command({ name: 'sync-config-vscode', description: 'Sync VSCode keybindings configuration.' })
    .argument({ name: 'target-path', kind: 'optional', description: 'Target keybindings.json path' })
    .action(async ({ args }) => {
      const targetPath = /** @type {string | undefined} */ (args['target-path']) || F_VSCODE_KEYBINDINGS
      if (targetPath) {
        handleSyncConfigVscode(targetPath)
      }
    })

  await cmd.run({ argv: process.argv.slice(2), envs: /** @type {Record<string, string>} */ (process.env), reporter })
}
