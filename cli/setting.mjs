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
  const cmd = new Command('setting', reporter)
    .description('Get or set setting values.')
    .option('--set-edition <edition>', 'Set edition (nix, nix-remote, osx, win)')
    .option('--set-theme <theme>', 'Set theme name')
    .option('--set-tmux-edition <edition>', 'Set tmux edition (latest, nightly, manual)')
    .option('--set-nvim-edition <edition>', 'Set nvim edition (latest, nightly, manual)')
    .option('--set-node-edition <edition>', 'Set preferred Node.js major version')
    .option('--print-edition', 'Print edition')
    .option('--print-theme', 'Print theme')
    .option('--print-node-edition', 'Print node edition')
    .option('--print', 'Print all settings')
    .example('setting --print')
    .example('setting --set-edition nix')
    .example('setting --set-node-edition 24')
    .action(async ({ opts }) => {
      await handleSetting(opts)
    })

  await cmd.run(process.argv.slice(2), /** @type {Record<string, string>} */ (process.env))
}
