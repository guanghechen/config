import fs from 'node:fs/promises'
import path from 'node:path'

import { XDG_CONFIG_HOME } from '#env'
import { exec } from '#util/command'

// The theme CLI owns these options; any other line in the bat config is preserved.
const managed_option_pattern = /^\s*--(?:theme|italic-text)(?:[=\s]|$)/

/**
 * @param {string} content
 * @param {string} theme
 * @return {string}
 */
function update_config(content, theme) {
  const preserved = content.split(/\r?\n/).filter(line => !managed_option_pattern.test(line))
  while (preserved.length > 0 && preserved.at(-1).trim() === '') preserved.pop()
  // Themes style comments, functions and types in italic; bat renders italic only on request.
  return [`--theme=${theme}`, '--italic-text=always', ...preserved].join('\n') + '\n'
}

export default {
  location: path.join(XDG_CONFIG_HOME, 'bat'),
  active: { directory: '.' },
  themes: 'themes/',
  extname: '.tmTheme',
  local: null,
  on_after_apply: async function (app, scheme) {
    const filepath = path.join(app.home, 'config')
    const theme = scheme.variant ? `${scheme.theme}-${scheme.variant}` : scheme.theme
    let content = ''
    try {
      content = await fs.readFile(filepath, 'utf8')
    } catch (error) {
      if (error.code !== 'ENOENT') throw error
    }
    await fs.writeFile(filepath, update_config(content, theme), 'utf8')
  },
  on_after_gen: async function (_app, reporter) {
    try {
      await exec({ reporter, cmd: 'bat', args: ['cache', '--build'], silent: true })
    } catch {
      reporter.error('Failed to rebuild cache. cmd: bat cache --build')
    }
  },
}
