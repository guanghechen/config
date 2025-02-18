import fs from 'node:fs'
import path from 'node:path'
import url from 'node:url'
import { F_VSCODE_SETTINGS, platform } from '../../../_shared/env.mjs'

const __dirname = path.dirname(url.fileURLToPath(import.meta.url))

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
  f1: 1.9,
  f2: 1.9,
  f3: 1.9,
  f4: 1.9,
  f5: 1.9,
  f6: 1.9,
  f7: 1.9,
  f8: 1.9,
  f9: 1.9,
  f10: 1.8,
  f11: 1.8,
  f12: 1.8,
  f13: 1.8,
  f14: 1.8,
  f15: 1.8,
  f16: 1.8,
  f17: 1.8,
  f18: 1.8,
  f19: 1.8,
  f20: 1.7,
  f21: 1.7,
  f22: 1.7,
  f23: 1.7,
  f24: 1.7,
}

export function formatKey(key) {
  return key
    .split(/\s+/g)
    .filter(x => !!x)
    .map(text => text.split('+')
      .sort((x, y) => {
        const r1 = ranks[x] ?? 1
        const r2 = ranks[y] ?? 1
        return r2 - r1
      })
      .join('+')
    ).join(' ')
}

export function sortKeybindings(keybindings) {
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
        const rx = ranks[kx] ?? 1
        const ry = ranks[ky] ?? 1
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

export function resolve() {
  const encoding = 'utf8'
  const middle = platform === 'wsl' ? 'win' : platform
  const CONFIG_DIR = path.join(__dirname, middle)
  if (!fs.existsSync(CONFIG_DIR)) return

  const fp_customize = path.join(CONFIG_DIR, 'customize.json')
  const fp_unbind = path.join(CONFIG_DIR, 'unbind.json')
  const fp_keybindings = path.join(CONFIG_DIR, 'keybindings.json')

  const raw_customize = JSON.parse(fs.readFileSync(fp_customize, encoding))
  const raw_unbind = JSON.parse(fs.readFileSync(fp_unbind, encoding))

  const resolved_customize = sortKeybindings(raw_customize).filter(x => !x.command.startsWith('-'))

  const existed_keys = new Set(resolved_customize.map(x => [x.key, ('-' + x.command), x.when ?? 'undefined'].join('#.#')))
  const resolved_unbind = sortKeybindings(raw_unbind)
    .filter(x => {
      if (!x.command.startsWith('-')) return false
      const key = [x.key, x.command, x.when ?? 'undefined'].join('#.#')
      return !existed_keys.has(key)
    })
  const resolved_items = [...resolved_unbind, ...resolved_customize]

  const content_customize = JSON.stringify(resolved_customize, null, 2) + '\n'
  const content_unbind = JSON.stringify(resolved_unbind, null, 2) + '\n'
  const content_all = JSON.stringify(resolved_items, null, 2) + '\n'

  fs.writeFileSync(fp_customize, content_customize, encoding)
  fs.writeFileSync(fp_unbind, content_unbind, encoding)
  fs.writeFileSync(fp_keybindings, content_all, encoding)
  if (F_VSCODE_SETTINGS) fs.writeFileSync(F_VSCODE_SETTINGS, content_all, encoding)
}

resolve()
