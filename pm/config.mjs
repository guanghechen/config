import * as fs from 'node:fs'
import * as path from 'node:path'

const XDG_CONFIG_HOME = process.env.XDG_CONFIG_HOME || path.resolve(import.meta.dirname, '../..')
const ROOT_SRC = process.env.ROOT_SOURCECODES

const GHC_COPILOT_API_HOST = String(process.env.GHC_COPILOT_API_HOST) || '127.0.0.1'
const GHC_COPILOT_API_PORT = Number.parseInt(String(process.env.GHC_COPILOT_API_PORT || 4343))

let LOCAL_TASKS = {}
const LOCAL_CONFIG_FILEPATH = path.normalize(path.resolve(import.meta.dirname, 'local/tasks.mjs'))
if (fs.existsSync(LOCAL_CONFIG_FILEPATH)) {
  LOCAL_TASKS = (await import(LOCAL_CONFIG_FILEPATH)).default
}

const repos = {
  copilot_api: path.normalize(path.resolve(ROOT_SRC, 'github/ericc-ch/copilot-api')),
  copilot_api_codex: path.normalize(path.resolve(ROOT_SRC, 'github/caozhiyuan/copilot-api')),
  yoz: path.normalize(path.resolve(XDG_CONFIG_HOME, 'yoz')),
}

const enabled = {
  copilot_api: fs.existsSync(path.join(repos.copilot_api, '.git')),
  copilot_api_default: fs.existsSync(path.join(repos.copilot_api, '.git')),
  copilot_api_codex: fs.existsSync(path.join(repos.copilot_api_codex, '.git')),
  yoz: fs.existsSync(path.join(repos.yoz, '.git')),
}

/** @type {import('@guanghechen/kit-pm').IPmAppConfig[]} */
const apps = [
  {
    enabled: true,
    autostart: true,
    name: 'kit-copilot',
    cmd: 'kit',
    args: ['copilot', 'start', '--port=4747'],
  },
  {
    enabled: enabled.copilot_api,
    autostart: false,
    name: 'copilot-api',
    cwd: repos.copilot_api,
    cmd: 'bun',
    args: ['run', 'start', 'start', `--port=${GHC_COPILOT_API_PORT}`],
    env: {
      NODE_ENV: 'production',
      PWD: repos.copilot_api,
      HOST: GHC_COPILOT_API_HOST,
    },
  },
  {
    enabled: enabled.copilot_api_default,
    autostart: false,
    name: 'copilot-api-default',
    cwd: repos.copilot_api,
    cmd: 'bun',
    args: ['run', 'start', 'start'],
    env: {
      NODE_ENV: 'production',
      PWD: repos.copilot_api,
      HOST: GHC_COPILOT_API_HOST,
    },
  },
  {
    enabled: enabled.copilot_api_codex,
    autostart: false,
    name: 'copilot-api-codex',
    cwd: repos.copilot_api_codex,
    cmd: 'bun',
    args: ['run', 'start', 'start', '--port=4848'],
    env: {
      NODE_ENV: 'production',
      PWD: repos.copilot_api_codex,
      HOST: GHC_COPILOT_API_HOST,
    },
  },
  {
    enabled: enabled.yoz,
    autostart: true,
    name: 'yoz',
    cwd: repos.yoz,
    cmd: 'npm',
    args: ['run', 'start'],
    env: {
      NODE_ENV: 'development',
      PWD: repos.yoz,
    },
  },
  ...(LOCAL_TASKS.apps || []),
].filter(x => !!x && x.enabled)

/** @type {import('@guanghechen/kit-pm').IPmConfig} */
const config = { apps }

export default config
