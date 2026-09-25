import assert from 'node:assert/strict'
import fs from 'node:fs/promises'
import os from 'node:os'
import path from 'node:path'
import { test } from 'node:test'

import { XDG_CONFIG_NODE_ASSET_THEMES } from '#env'
import { compositeHex } from '#util/color'
import { apps } from './config.mjs'
import { load_theme_scheme, resolve_app_template_filepath } from './util.mjs'

const reporter = { error(message) { throw new Error(message) } }
const kit = apps.find(app => app.name === 'kit')

function luminance(color) {
  return color.slice(1).match(/../g)
    .map(value => Number.parseInt(value, 16) / 255)
    .map(value => value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4)
    .reduce((result, value, index) => result + value * [0.2126, 0.7152, 0.0722][index], 0)
}

function contrast(foreground, background) {
  const values = [luminance(foreground), luminance(background)].sort((a, b) => a - b)
  return (values[1] + 0.05) / (values[0] + 0.05)
}

test('Kit themes pair every family and keep text readable over either desktop brightness', async () => {
  assert.ok(kit)
  for (const name of XDG_CONFIG_NODE_ASSET_THEMES) {
    const scheme = await load_theme_scheme(reporter, name)
    const template = await fs.readFile(resolve_app_template_filepath(kit, scheme), 'utf8')
    const rendered = await kit.render(kit, template, scheme)
    assert.equal(rendered.includes('{{'), false, name)
    const theme = JSON.parse(rendered)
    assert.deepEqual(Object.keys(theme).sort(), ['dark', 'light', 'version'])
    assert.equal(theme.version, 1)
    assert.equal(theme[scheme.darken ? 'dark' : 'light'].background, scheme.palette.unified.bg0)
    assert.ok(luminance(theme.light.background) > luminance(theme.dark.background), name)
    for (const palette of [theme.light, theme.dark]) {
      for (const behind of ['#000000', '#FFFFFF']) {
        const background = compositeHex(palette.background + 'F5', behind)
        for (const role of ['foreground', 'muted', 'error']) {
          assert.ok(contrast(palette[role], background) >= 4.5, `${name}: ${role} on ${behind}`)
        }
      }
    }
  }
})

test('Kit apply only publishes its generated palette and rejects unknown families', async () => {
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), 'kit-theme-test-'))
  try {
    const app = { ...kit, home: directory }
    await fs.mkdir(path.join(directory, 'stt'))
    await fs.writeFile(path.join(directory, 'stt/config.json'), '{"untouched":true}')
    await app.apply(app, '{"version":1}\n')
    assert.equal(await fs.readFile(path.join(directory, '.theme/local.json'), 'utf8'), '{"version":1}\n')
    assert.equal(await fs.readFile(path.join(directory, 'stt/config.json'), 'utf8'), '{"untouched":true}')
    assert.deepEqual(await fs.readdir(path.join(directory, '.theme')), ['local.json'])
    await assert.rejects(app.render(app, '{}', { theme: 'unknown' }), /No Kit theme pair/)
  } finally {
    await fs.rm(directory, { recursive: true, force: true })
  }
})
