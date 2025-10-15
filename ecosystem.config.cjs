const fs = require('node:fs')
const path = require('node:path')

const ROOT_CONFIG = path.resolve(__dirname, '..')
const ROOT_SOURCECODES = process.env.ROOT_SOURCECODES

const GHC_COPILOT_API_HOST = String(process.env.GHC_COPILOT_API_HOST) || '127.0.0.1'
const GHC_COPILOT_API_PORT = Number.parseInt(String(process.env.GHC_COPILOT_API_PORT || 4343))

let LOCAL_TASKS = {}
const LOCAL_CONFIG_FILEPATH = path.normalize(path.resolve(__dirname, 'local/tasks.cjs'))
if (fs.existsSync(LOCAL_CONFIG_FILEPATH)) {
  LOCAL_TASKS = require(LOCAL_CONFIG_FILEPATH)
}

const repos = {
  skhd: path.normalize(path.resolve(ROOT_CONFIG, 'skhd')),
  yabai: path.normalize(path.resolve(ROOT_CONFIG, 'yabai')),
  yoz: path.normalize(path.resolve(ROOT_CONFIG, 'yoz')),
  copilot_api: path.normalize(path.resolve(ROOT_SOURCECODES, 'github/ericc-ch/copilot-api')),
}

const config = {
  apps: [
    {
      enabled: fs.existsSync(repos.yoz),
      name: 'yoz',
      cwd: repos.yoz,
      script: 'npm',
      args: 'run start',
      watch: true,
      env: {
        NODE_ENV: 'development',
      },
    },
    {
      enabled: !!ROOT_SOURCECODES && fs.existsSync(repos.copilot_api),
      name: 'copilot-api',
      cwd: repos.copilot_api,
      script: 'bun',
      args: `run start start --port=${GHC_COPILOT_API_PORT}`,
      env: {
        NODE_ENV: 'production',
        HOST: GHC_COPILOT_API_HOST,
      },
    },
    ...(LOCAL_TASKS.apps || []),
  ].filter(x => !!x && x.enabled),
}

module.exports = config
