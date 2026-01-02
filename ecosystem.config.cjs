const fs = require('node:fs')
const path = require('node:path')

const ROOT_CONFIG = path.resolve(__dirname, '..')
const ROOT_SRC = process.env.ROOT_SOURCECODES

const GHC_COPILOT_API_HOST = String(process.env.GHC_COPILOT_API_HOST) || '127.0.0.1'
const GHC_COPILOT_API_PORT = Number.parseInt(String(process.env.GHC_COPILOT_API_PORT || 4343))

let LOCAL_TASKS = {}
const LOCAL_CONFIG_FILEPATH = path.normalize(path.resolve(__dirname, 'local/tasks.cjs'))
if (fs.existsSync(LOCAL_CONFIG_FILEPATH)) {
  LOCAL_TASKS = require(LOCAL_CONFIG_FILEPATH)
}

const repos = {
  agent_api: path.normalize(path.resolve(ROOT_CONFIG, 'agent-api')),
  copilot_api: path.normalize(path.resolve(ROOT_SRC, 'github/ericc-ch/copilot-api')),
  copilot_api_codex: path.normalize(path.resolve(ROOT_SRC, 'github/caozhiyuan/copilot-api')),
  skhd: path.normalize(path.resolve(ROOT_CONFIG, 'skhd')),
  yabai: path.normalize(path.resolve(ROOT_CONFIG, 'yabai')),
  yoz: path.normalize(path.resolve(ROOT_CONFIG, 'yoz')),
}

const enabled = {}
enabled.agent_api = fs.existsSync(path.join(repos.agent_api, '.git'))
enabled.yoz = fs.existsSync(path.join(repos.yoz, '.git'))
enabled.copilot_api = !enabled.agent_api && fs.existsSync(path.join(repos.copilot_api, '.git'))
enabled.copilot_api_default = enabled.copilot_api
enabled.copilot_api_codex =
  !enabled.agent_api && fs.existsSync(path.join(repos.copilot_api_codex, '.git'))

const config = {
  apps: [
    {
      enabled: enabled.agent_api,
      name: 'agent-api',
      cwd: repos.agent_api,
      script: 'yarn',
      args: `run start:copilot --host=${GHC_COPILOT_API_HOST} --port=${GHC_COPILOT_API_PORT} --no-colorful`,
      env: {
        NODE_ENV: 'production',
        PWD: repos.agent_api,
      },
    },
    {
      enabled: enabled.copilot_api,
      name: 'copilot-api',
      cwd: repos.copilot_api,
      script: 'bun',
      args: `run start start --port=${GHC_COPILOT_API_PORT}`,
      env: {
        NODE_ENV: 'production',
        PWD: repos.copilot_api,
        HOST: GHC_COPILOT_API_HOST,
      },
    },
    {
      enabled: enabled.copilot_api_default,
      name: 'copilot-api-default',
      cwd: repos.copilot_api,
      script: 'bun',
      args: `run start start`,
      // args: `run start start -v`,
      env: {
        NODE_ENV: 'production',
        PWD: repos.copilot_api,
        HOST: GHC_COPILOT_API_HOST,
      },
    },
    {
      enabled: enabled.copilot_api_codex,
      name: 'copilot-api-codex',
      cwd: repos.copilot_api_codex,
      script: 'bun',
      args: `run start start --port=4848`,
      env: {
        NODE_ENV: 'production',
        PWD: repos.copilot_api_codex,
        HOST: GHC_COPILOT_API_HOST,
      },
    },
    {
      enabled: enabled.yoz,
      name: 'yoz',
      cwd: repos.yoz,
      script: 'npm',
      args: 'run start',
      watch: true,
      env: {
        NODE_ENV: 'development',
        PWD: repos.yoz,
      },
    },
    ...(LOCAL_TASKS.apps || []),
  ].filter(x => !!x && x.enabled),
}

module.exports = config
