import fs from 'node:fs'
import path from 'node:path'
import url from 'node:url'
import { F_VSCODE_SETTINGS, platform } from '../../../_shared/env.mjs'

const __dirname = path.dirname(url.fileURLToPath(import.meta.url))

const ranks = {
  command: 10,
  super: 10,
  win: 10,
  alt: 8,
  ctrl: 5,
  shift: 3,
  left: 2,
  down: 2,
  right: 2,
  up: 2,
  home: 2,
  f1: 2,
  f2: 2,
  f3: 2,
  f4: 2,
  f5: 2,
  f6: 2,
  f7: 2,
  f8: 2,
  f9: 2,
  f10: 2,
  f11: 2,
  f12: 2,
  f13: 2,
  f14: 2,
  f15: 2,
  f16: 2,
  f17: 2,
  f18: 2,
  f19: 2,
  f20: 2,
  f21: 2,
  f22: 2,
  f23: 2,
  f24: 2,
}

export function formatKey(key) {
  return key
    .split('+')
    .sort((x, y) => {
      const r1 = ranks[x] ?? 1
      const r2 = ranks[y] ?? 1
      return r2 - r1
    })
    .join('+')
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
        if (kx !== ky) return kx < ky ? -1 : 1
      }

      return keys_x.length - keys_y.length
    })
}

export function resolve() {
  const encoding = 'utf8'
  const middle = platform === 'wsl' ? 'win' : platform
  const fp_customize = path.join(__dirname, middle, 'customize.json')
  const fp_unbind = path.join(__dirname, middle, 'unbind.json')
  const fp_keybindings = path.join(__dirname, middle, 'keybindings.json')

  const raw_customize = JSON.parse(fs.readFileSync(fp_customize, encoding))
  const raw_unbind = JSON.parse(fs.readFileSync(fp_unbind, encoding))

  const resolved_customize = sortKeybindings(raw_customize)
  const resolved_unbind = sortKeybindings(raw_unbind)
  const resolved_items = [...resolved_customize, ...resolved_unbind]

  fs.writeFileSync(fp_customize, JSON.stringify(resolved_customize, null, 2), encoding)
  fs.writeFileSync(fp_unbind, JSON.stringify(resolved_unbind, null, 2), encoding)
  fs.writeFileSync(fp_keybindings, JSON.stringify(resolved_items, null, 2), encoding)
  if (F_VSCODE_SETTINGS) fs.writeFileSync(F_VSCODE_SETTINGS, JSON.stringify(resolved_items, null, 2), encoding)
}

resolve()
