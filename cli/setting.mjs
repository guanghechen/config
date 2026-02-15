#!/usr/bin/env node

/**
 * Get or set setting values.
 */

/** @import { IAppEdition, ISettingData } from '#setting' */

import { Setting } from '#setting'
import { Command } from '#stl/commander'
import { Reporter } from '#stl/reporter'

const reporter = new Reporter({ prefix: 'setting' })
const setting = new Setting({ reporter })

/**
 * @typedef {Object} ISettingCliOptions
 * @property {string} [set-node-edition]
 * @property {string} [set-nvim-edition]
 * @property {string} [set-python-env]
 * @property {string} [set-theme]
 * @property {string} [set-tmux-edition]
 * @property {boolean} [print-node-edition]
 * @property {boolean} [print-python-env]
 * @property {boolean} [print-theme]
 * @property {boolean} [print]
 */

/**
 * @param {ISettingCliOptions} opts
 * @returns {Promise<void>}
 */
export async function handleSetting(opts) {
  /** @type {Partial<ISettingData>} */
  const patch = {}

  if (typeof opts['set-node-edition'] === 'string') patch.app_edition_node = parseInt(opts['set-node-edition'], 10)
  if (typeof opts['set-nvim-edition'] === 'string') patch.app_edition_nvim = /** @type {IAppEdition} */ (opts['set-nvim-edition'])
  if (typeof opts['set-python-env'] === 'string') patch.app_python_env = opts['set-python-env']
  if (typeof opts['set-theme'] === 'string') patch.theme = opts['set-theme']
  if (typeof opts['set-tmux-edition'] === 'string') patch.app_edition_tmux = /** @type {IAppEdition} */ (opts['set-tmux-edition'])

  if (Object.keys(patch).length > 0) {
    await setting.save(patch)
  }

  if (opts['print-node-edition'] || opts['print-python-env'] || opts['print-theme'] || opts.print) {
    const data = await setting.load()
    if (opts['print-node-edition']) process.stdout.write(`${data.app_edition_node}\n`)
    if (opts['print-python-env']) process.stdout.write(`${data.app_python_env}\n`)
    if (opts['print-theme']) process.stdout.write(`${data.theme}\n`)
    if (opts.print) process.stdout.write(JSON.stringify(data, null, 2) + '\n')
  }
}

if (process.argv[1] === import.meta.filename) {
  const cmd = new Command({ name: 'setting', description: 'Get or set setting values.' })
    .option({ long: 'set-node-edition', type: 'string', description: 'Set preferred Node.js major version' })
    .option({ long: 'set-nvim-edition', type: 'string', description: 'Set nvim edition (latest, nightly, manual)' })
    .option({ long: 'set-python-env', type: 'string', description: 'Set python conda environment name' })
    .option({ long: 'set-theme', type: 'string', description: 'Set theme name' })
    .option({ long: 'set-tmux-edition', type: 'string', description: 'Set tmux edition (latest, nightly, manual)' })
    .option({ long: 'print-node-edition', type: 'boolean', description: 'Print node edition' })
    .option({ long: 'print-python-env', type: 'boolean', description: 'Print python env' })
    .option({ long: 'print-theme', type: 'boolean', description: 'Print theme' })
    .option({ long: 'print', type: 'boolean', description: 'Print all settings' })
    .action(async ({ opts }) => {
      await handleSetting(opts)
    })

  await cmd.run({ argv: process.argv.slice(2), envs: /** @type {Record<string, string>} */ (process.env), reporter })
}
