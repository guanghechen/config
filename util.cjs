const { execSync } = require('node:child_process')
const fs = require('node:fs')

function iswsl() {
  return (
    'WSL_DISTRO_NAME' in process.env ||
    (fs.existsSync('/proc/version') &&
      fs.readFileSync('/proc/version', 'utf8').toLowerCase().includes('microsoft'))
  )
}

function platform() {
  const p = process.platform
  if (p === 'darwin') return 'mac'
  if (p === 'win32') return iswsl() ? 'wsl' : 'win'
  if (p === 'linux') return iswsl() ? 'wsl' : 'nix'
  return 'nix'
}

function command_exist(command) {
  try {
    const result = execSync(`which ${command}`, { stdio: 'pipe' }).toString().trim()
    return !!result
  } catch (e) {
    return false
  }
}

module.exports = {
  PLATFORM: platform(),
  command_exist,
}
