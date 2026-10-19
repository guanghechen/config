import assert from 'node:assert/strict'
import fs from 'node:fs/promises'
import os from 'node:os'
import path from 'node:path'
import { describe, it } from 'node:test'

import definition from '../../asset/theme/template/bat/meta.mjs'

/** @param {import('node:test').TestContext} t */
async function createFixture(t) {
  const home = await fs.realpath(await fs.mkdtemp(path.join(os.tmpdir(), 'bat-config-')))
  t.after(() => fs.rm(home, { recursive: true, force: true }))
  return { app: { home }, config: path.join(home, 'config') }
}

describe('Bat config updates', () => {
  it('creates the managed options when the config is missing', async t => {
    const { app, config } = await createFixture(t)
    await definition.on_after_apply(app, { theme: 'rosepine', variant: 'main' })
    assert.equal(await fs.readFile(config, 'utf8'), '--theme=rosepine-main\n--italic-text=always\n')
  })

  it('replaces managed options and preserves personal options', async t => {
    const { app, config } = await createFixture(t)
    await fs.writeFile(config, '# personal\n--style=numbers\n--theme gruvbox-dark\n--italic-text=never\n--map-syntax=*.conf:INI\n\n')
    await definition.on_after_apply(app, { theme: 'vsc', variant: 'dark-modern' })
    const expected = '--theme=vsc-dark-modern\n--italic-text=always\n# personal\n--style=numbers\n--map-syntax=*.conf:INI\n'
    assert.equal(await fs.readFile(config, 'utf8'), expected)

    await definition.on_after_apply(app, { theme: 'vsc', variant: 'dark-modern' })
    assert.equal(await fs.readFile(config, 'utf8'), expected)
  })

  it('keeps related options that only share the managed prefix', async t => {
    const { app, config } = await createFixture(t)
    await fs.writeFile(config, '--theme=old\n--theme-dark=gruvbox-dark\n')
    await definition.on_after_apply(app, { theme: 'kanagawa', variant: 'wave' })
    assert.equal(
      await fs.readFile(config, 'utf8'),
      '--theme=kanagawa-wave\n--italic-text=always\n--theme-dark=gruvbox-dark\n',
    )
  })
})
