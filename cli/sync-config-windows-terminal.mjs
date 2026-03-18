#!/usr/bin/env node

/**
 * Sync Windows Terminal settings configuration.
 */

import fs from 'node:fs'
import path from 'node:path'

import { F_WINDOWS_TERMINAL_SETTINGS, XDG_CONFIG_NODE_ASSET_APP_DIR } from '#env'
import { Command } from '#stl/commander'
import { Reporter } from '#stl/reporter'

const reporter = new Reporter({ prefix: 'sync-config-windows-terminal' })

const DEFAULT_BELL_STYLE = ['taskbar']
const DEFAULT_SUPPRESS_APPLICATION_TITLE = false

/**
 * Ensure bell notifications are always configured after sync.
 * @param {Record<string, any>} settings
 */
function ensureBellStyle(settings) {
  if (!settings || typeof settings !== 'object') return

  if (!settings.profiles || typeof settings.profiles !== 'object' || Array.isArray(settings.profiles)) {
    settings.profiles = {}
  }

  if (
    !settings.profiles.defaults ||
    typeof settings.profiles.defaults !== 'object' ||
    Array.isArray(settings.profiles.defaults)
  ) {
    settings.profiles.defaults = {}
  }

  settings.profiles.defaults.bellStyle = [...DEFAULT_BELL_STYLE]
  settings.profiles.defaults.suppressApplicationTitle = DEFAULT_SUPPRESS_APPLICATION_TITLE

  if (Array.isArray(settings.profiles.list)) {
    for (const profile of settings.profiles.list) {
      if (!profile || typeof profile !== 'object') continue
      if (profile.source === 'Microsoft.WSL') {
        profile.suppressApplicationTitle = DEFAULT_SUPPRESS_APPLICATION_TITLE
      }
    }
  }
}

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

  ensureBellStyle(raw)

  const content = JSON.stringify(raw, null, 2) + '\n'
  fs.writeFileSync(targetSettingsPath, content, encoding)

  reporter.info('Windows Terminal settings synced successfully')
}

if (process.argv[1] === import.meta.filename) {
  const cmd = new Command({ name: 'sync-config-windows-terminal', description: 'Sync Windows Terminal settings configuration.' })
    .argument({ name: 'target-path', kind: 'optional', description: 'Target settings.json path' })
    .action(async ({ args }) => {
      const targetPath =
        /** @type {string | undefined} */ (args['target-path']) || F_WINDOWS_TERMINAL_SETTINGS
      if (targetPath) {
        handleSyncConfigWindowsTerminal(targetPath)
      }
    })

  await cmd.run({ argv: process.argv.slice(2), envs: /** @type {Record<string, string>} */ (process.env), reporter })
}
