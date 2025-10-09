import fs from 'node:fs'
import path from 'node:path'
import url from 'node:url'
import { F_VSCODE_KEYBINDINGS, platform } from '../../../_shared/env.mjs'

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

export function formatKey(key) {
  return key
    .split(/\s+/g)
    .filter(x => !!x)
    .map(text =>
      text
        .split('+')
        .sort((x, y) => {
          const r1 = ranks[x] ?? 1
          const r2 = ranks[y] ?? 1
          return r2 - r1
        })
        .join('+'),
    )
    .join(' ')
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

export function resolve() {
  const encoding = 'utf8'
  const middle = platform === 'wsl' ? 'win' : platform
  const CONFIG_DIR = path.join(__dirname, middle)
  if (!fs.existsSync(CONFIG_DIR)) return

  const fp_rebind = path.join(CONFIG_DIR, 'rebind.json')
  const fp_customize = path.join(CONFIG_DIR, 'customize.json')
  const fp_unbind = path.join(CONFIG_DIR, 'unbind.json')
  const fp_keybindings = path.join(CONFIG_DIR, 'keybindings.json')

  const raw_rebind = JSON.parse(fs.readFileSync(fp_rebind, encoding))
  const raw_customize = JSON.parse(fs.readFileSync(fp_customize, encoding))
  const raw_unbind = JSON.parse(fs.readFileSync(fp_unbind, encoding))

  const resolved_rebind = sortKeybindings(raw_rebind)
  const resolved_customize = sortKeybindings(raw_customize).filter(x => !x.command.startsWith('-'))

  const existed_keys = new Set(
    resolved_customize.map(x => [x.key, '-' + x.command, x.when ?? 'undefined'].join('#.#')),
  )
  const resolved_unbind = sortKeybindings(raw_unbind).filter(x => {
    if (!x.command.startsWith('-')) return false
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
  if (F_VSCODE_KEYBINDINGS) fs.writeFileSync(F_VSCODE_KEYBINDINGS, content_all, encoding)
}

resolve()
