import fs from 'node:fs'
import path from 'node:path'
import { pathToFileURL } from 'node:url'

import { XDG_CONFIG_NODE_ASSET_THEME_TEMPLATE_DIR } from '#env'
import { is_directory, is_file } from '#util/path'

import { render_template } from './_util.mjs'

/** @typedef {import('./types.d.ts').IAppConfig} IAppConfig */
/** @typedef {import('./types.d.ts').IThemeAppCondition} IThemeAppCondition */
/** @typedef {import('./types.d.ts').IThemeAppDefinition} IThemeAppDefinition */

const lifecycleFields = [
  'on_render',
  'on_prepare',
  'on_apply',
  'on_after_apply',
  'on_after_gen',
]
const allowedDefinitionKeys = new Set([
  'location',
  'active',
  'themes',
  'extname',
  'local',
  ...lifecycleFields,
])
const allowedConditionKeys = new Set(['env', 'file', 'directory', 'all'])
const templateSegmentPattern = /^[a-z0-9]+(?:-[a-z0-9]+)*$/

/**
 * @param {string} templateRoot
 * @return {Promise<IThemeAppDefinition[]>}
 */
export async function load_theme_app_definitions(
  templateRoot = XDG_CONFIG_NODE_ASSET_THEME_TEMPLATE_DIR,
) {
  const entries = fs.readdirSync(templateRoot, { withFileTypes: true })
    .filter(entry => entry.isDirectory())
    .sort((a, b) => a.name.localeCompare(b.name))
  if (entries.length === 0) {
    throw new Error(`No theme app definitions found: ${templateRoot}`)
  }

  return Promise.all(entries.map(async entry => {
    const name = entry.name
    if (!templateSegmentPattern.test(name)) {
      throw new Error(`Invalid theme app directory name: ${name}`)
    }

    const appDir = path.join(templateRoot, name)
    const definitionPath = path.join(appDir, 'meta.mjs')
    const defaultTemplatePath = path.join(appDir, 'default.hbs')
    assertFile(definitionPath, `Missing definition for theme app: ${name}`)
    assertFile(defaultTemplatePath, `Missing default template for theme app: ${name}`)

    let definitionModule
    try {
      definitionModule = await import(pathToFileURL(definitionPath).href)
    } catch (error) {
      throw new Error(`Invalid theme app definition module: ${definitionPath}`, { cause: error })
    }
    return parseDefinition(name, definitionModule.default)
  }))
}

/**
 * @param {IThemeAppDefinition[]} definitions
 * @return {IAppConfig[]}
 */
export function create_theme_apps(definitions) {
  return definitions.map(definition => {
    /** @type {IAppConfig} */
    const app = {
      name: definition.name,
      home: definition.location,
      themes: definition.themes,
      extname: definition.extname,
      local: definition.local,
      active: app => evaluate_theme_app_condition(definition.active, app),
      render: definition.on_render ?? (async (_app, template, scheme) =>
        render_template(template, scheme)),
      prepare: definition.on_prepare,
      apply: definition.on_apply,
      after_apply: definition.on_after_apply,
      after_gen: definition.on_after_gen,
    }
    return app
  })
}

/**
 * @param {IThemeAppCondition} condition
 * @param {IAppConfig} app
 * @param {NodeJS.ProcessEnv} [environment]
 * @return {boolean}
 */
export function evaluate_theme_app_condition(
  condition,
  app,
  environment = process.env,
) {
  if ('env' in condition) {
    return Object.hasOwn(environment, condition.env) && !!environment[condition.env]
  }
  if ('file' in condition) return is_file(resolveConditionPath(condition.file, app))
  if ('directory' in condition) {
    return is_directory(resolveConditionPath(condition.directory, app))
  }
  if ('all' in condition) {
    return condition.all.every(entry =>
      evaluate_theme_app_condition(entry, app, environment))
  }
  return false
}

/**
 * @param {string} name
 * @param {unknown} raw
 * @return {IThemeAppDefinition}
 */
function parseDefinition(name, raw) {
  if (!isRecord(raw)) throw new Error(`Theme app definition must be an object: ${name}`)
  assertKnownKeys(raw, allowedDefinitionKeys, `theme app definition for ${name}`)
  for (const key of ['location', 'active', 'themes', 'extname', 'local']) {
    if (!Object.hasOwn(raw, key)) {
      throw new Error(`Missing required theme app definition field "${key}": ${name}`)
    }
  }

  if (
    typeof raw.location !== 'string' ||
    raw.location.length === 0 ||
    !isAbsolutePath(raw.location)
  ) {
    throw new Error(`Theme app location must be a non-empty absolute path: ${name}`)
  }
  const location = raw.location
  const active = parseCondition(raw.active, `${name}.active`)
  const themes = parseNullableRelativePath(raw.themes, `${name}.themes`)

  if (typeof raw.extname !== 'string' || /[\\/\0\r\n]/.test(raw.extname)) {
    throw new Error(`Theme app extname must be a path-free string: ${name}`)
  }

  let local = null
  if (raw.local !== null) {
    if (typeof raw.local !== 'string' || raw.local.length === 0) {
      throw new Error(`Theme app local must be a non-empty string or null: ${name}`)
    }
    if (!isAbsolutePath(raw.local)) assertRelativePath(raw.local, `${name}.local`)
    local = raw.local
  }

  return {
    name,
    location,
    active,
    themes,
    extname: raw.extname,
    local,
    ...parseLifecycle(raw, name),
  }
}

/**
 * @param {Record<string, unknown>} raw
 * @param {string} name
 * @return {Partial<IThemeAppDefinition>}
 */
function parseLifecycle(raw, name) {
  /** @type {Partial<IThemeAppDefinition> & Record<string, unknown>} */
  const lifecycle = {}
  for (const field of lifecycleFields) {
    if (!Object.hasOwn(raw, field)) continue
    const value = raw[field]
    if (typeof value !== 'function') {
      throw new Error(`Theme app lifecycle field "${field}" must be a function: ${name}`)
    }
    lifecycle[field] = value
  }
  return lifecycle
}

/**
 * @param {unknown} value
 * @param {string} field
 * @return {string | null}
 */
function parseNullableRelativePath(value, field) {
  if (value === null) return null
  if (typeof value !== 'string' || value.length === 0) {
    throw new Error(`Theme app definition field must be a non-empty string or null: ${field}`)
  }
  assertRelativePath(value, field)
  return value
}

/**
 * @param {unknown} value
 * @param {string} field
 * @return {IThemeAppCondition}
 */
function parseCondition(value, field) {
  if (!isRecord(value)) {
    throw new Error(`Theme app condition must be an object: ${field}`)
  }
  assertKnownKeys(value, allowedConditionKeys, field)
  const keys = Object.keys(value)
  if (keys.length !== 1) {
    throw new Error(`Theme app condition must contain exactly one predicate: ${field}`)
  }

  if (Object.hasOwn(value, 'env')) {
    if (typeof value.env !== 'string' || !/^[A-Za-z_][A-Za-z0-9_]*$/.test(value.env)) {
      throw new Error(`Invalid theme app env condition: ${field}`)
    }
    return { env: value.env }
  }

  for (const predicate of ['file', 'directory']) {
    if (!Object.hasOwn(value, predicate)) continue
    const conditionPath = value[predicate]
    if (typeof conditionPath !== 'string' || conditionPath.length === 0) {
      throw new Error(`Invalid theme app path condition: ${field}`)
    }
    if (conditionPath !== '${local}' && conditionPath !== '${location}') {
      if (conditionPath.includes('${')) {
        throw new Error(`Unknown theme app condition path variable: ${field}`)
      }
      assertRelativePath(conditionPath, field)
    }
    return predicate === 'file'
      ? { file: conditionPath }
      : { directory: conditionPath }
  }

  if (!Array.isArray(value.all) || value.all.length === 0) {
    throw new Error(`Theme app all condition must be a non-empty array: ${field}`)
  }
  return {
    all: value.all.map((entry, index) =>
      parseCondition(entry, `${field}.all[${index}]`)),
  }
}

/** @param {string} value @param {IAppConfig} app */
function resolveConditionPath(value, app) {
  if (value === '${location}') return app.home
  if (value === '${local}') {
    if (!app.local) return null
    return isAbsolutePath(app.local) ? app.local : path.join(app.home, app.local)
  }
  return path.join(app.home, value)
}

/** @param {string} filepath @param {string} message */
function assertFile(filepath, message) {
  if (!fs.existsSync(filepath) || !fs.statSync(filepath).isFile()) {
    throw new Error(message)
  }
}

/** @param {string} value @param {string} field */
function assertRelativePath(value, field) {
  if (isAbsolutePath(value) || value.split(/[\\/]+/).includes('..')) {
    throw new Error(`Theme app definition path must be relative without traversal: ${field}`)
  }
}

/** @param {string} value */
function isAbsolutePath(value) {
  return path.posix.isAbsolute(value) || path.win32.isAbsolute(value)
}

/** @param {Record<string, unknown>} value @param {Set<string>} allowed @param {string} label */
function assertKnownKeys(value, allowed, label) {
  const unknown = Object.keys(value).filter(key => !allowed.has(key))
  if (unknown.length > 0) {
    throw new Error(`Unknown field in ${label}: ${unknown.join(', ')}`)
  }
}

/** @param {unknown} value @return {value is Record<string, unknown>} */
function isRecord(value) {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
}

export const apps = create_theme_apps(await load_theme_app_definitions())
