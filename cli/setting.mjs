#!/usr/bin/env node

/**
 * Get or set setting values.
 */

import { XDG_CONFIG_NODE_SETTING } from '#env'
import { Setting } from '#setting'
import { Command } from '#stl/commander'
import { Reporter } from '#stl/reporter'

const reporter = new Reporter({ prefix: 'setting' })
const setting = new Setting({ filepath: XDG_CONFIG_NODE_SETTING, reporter })

/**
 * @typedef {Object} ISettingCliOptions
 * @property {string} [setEdition]
 * @property {string} [setTheme]
 * @property {string} [setTmuxEdition]
 * @property {string} [setNvimEdition]
 * @property {string} [setNodeEdition]
 * @property {boolean} [printEdition]
 * @property {boolean} [printTheme]
 * @property {boolean} [printNodeEdition]
 * @property {boolean} [print]
 */

/**
 * @typedef {Object} ISettingPatch
 * @property {string} [edition]
 * @property {string} [theme]
 * @property {string} [tmux_edition]
 * @property {string} [nvim_edition]
 * @property {number} [node_edition]
 */

/**
 * @param {ISettingCliOptions} opts
 * @returns {Promise<void>}
 */
export async function handleSetting(opts) {
  /** @type {ISettingPatch} */
  const patch = {}

  if (typeof opts.setEdition === 'string') patch.edition = opts.setEdition
  if (typeof opts.setTheme === 'string') patch.theme = opts.setTheme
  if (typeof opts.setTmuxEdition === 'string') patch.tmux_edition = opts.setTmuxEdition
  if (typeof opts.setNvimEdition === 'string') patch.nvim_edition = opts.setNvimEdition
  if (typeof opts.setNodeEdition === 'string') patch.node_edition = parseInt(opts.setNodeEdition, 10)

  if (Object.keys(patch).length > 0) {
    await setting.save(patch)
  }

  if (opts.printEdition || opts.printTheme || opts.printNodeEdition || opts.print) {
    const data = await setting.load()
    if (opts.printEdition) process.stdout.write(`${data.edition}\n`)
    if (opts.printTheme) process.stdout.write(`${data.theme}\n`)
    if (opts.printNodeEdition) process.stdout.write(`${data.node_edition}\n`)
    if (opts.print) process.stdout.write(JSON.stringify(data, null, 2) + '\n')
  }
}

if (process.argv[1] === import.meta.filename) {
  const cmd = new Command({ name: 'setting', description: 'Get or set setting values.' })
    .option({ long: 'set-edition', type: 'string', description: 'Set edition (nix, nix-remote, osx, win)' })
    .option({ long: 'set-theme', type: 'string', description: 'Set theme name' })
    .option({ long: 'set-tmux-edition', type: 'string', description: 'Set tmux edition (latest, nightly, manual)' })
    .option({ long: 'set-nvim-edition', type: 'string', description: 'Set nvim edition (latest, nightly, manual)' })
    .option({ long: 'set-node-edition', type: 'string', description: 'Set preferred Node.js major version' })
    .option({ long: 'print-edition', type: 'boolean', description: 'Print edition' })
    .option({ long: 'print-theme', type: 'boolean', description: 'Print theme' })
    .option({ long: 'print-node-edition', type: 'boolean', description: 'Print node edition' })
    .option({ long: 'print', type: 'boolean', description: 'Print all settings' })
    .action(async ({ opts }) => {
      await handleSetting(opts)
    })

  await cmd.run({ argv: process.argv.slice(2), envs: /** @type {Record<string, string>} */ (process.env), reporter })
}
