#!/usr/bin/env node

/**
 * Sync Windows Terminal settings configuration.
 */

import fs from 'node:fs'
import path from 'node:path'
import { Command } from '#stl/commander'
import { Reporter } from '#stl/reporter'
import { F_WINDOWS_TERMINAL_SETTINGS, XDG_CONFIG_NODE_ASSET_APP_DIR } from '#env/path'

const reporter = new Reporter({ prefix: 'sync-config-windows-terminal' })

/**
 * @param {string} targetSettingsPath - Path to the Windows Terminal settings.json file
 */
export function handleSyncConfigWindowsTerminal(targetSettingsPath) {
  if (!targetSettingsPath || !fs.existsSync(targetSettingsPath)) return

  reporter.info('Syncing Windows Terminal settings to:', targetSettingsPath)

  const encoding = 'utf8'
  const customizedPath = path.join(XDG_CONFIG_NODE_ASSET_APP_DIR, 'windows-terminal/settings.json')
  if (!fs.existsSync(customizedPath)) {
    reporter.error('Customized settings not found:', customizedPath)
    return
  }

  const customizedContent = fs.readFileSync(customizedPath, encoding)
  const customized = JSON.parse(customizedContent)

  const rawContent = fs.readFileSync(targetSettingsPath, encoding)
  const raw = JSON.parse(rawContent)

  for (const [key, val] of Object.entries(customized)) {
    raw[key] = val
  }

  const content = JSON.stringify(raw, null, 2) + '\n'
  fs.writeFileSync(targetSettingsPath, content, encoding)

  reporter.info('Windows Terminal settings synced successfully')
}

if (process.argv[1] === import.meta.filename) {
  const cmd = new Command('sync-config-windows-terminal', reporter)
    .description('Sync Windows Terminal settings configuration.')
    .argument('[target-path]', 'Target settings.json path')
    .example('sync-config-windows-terminal')
    .example('sync-config-windows-terminal /mnt/c/Users/.../settings.json')
    .action(async ({ args }) => {
      const targetPath =
        /** @type {string | undefined} */ (args['target-path']) || F_WINDOWS_TERMINAL_SETTINGS
      if (targetPath) {
        handleSyncConfigWindowsTerminal(targetPath)
      }
    })

  await cmd.run(process.argv.slice(2), /** @type {Record<string, string>} */ (process.env))
}
