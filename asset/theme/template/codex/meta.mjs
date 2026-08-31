import { CODEX_CONFIG_DIR } from '#env'

export default {
  location: CODEX_CONFIG_DIR,
  active: { directory: '.' },
  themes: 'themes/',
  extname: '-ghc.tmTheme',
  local: 'themes/local.tmTheme',
}
