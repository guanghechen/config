import fs from 'node:fs'
import path from 'node:path'
import { pathToFileURL } from 'node:url'

import { XDG_CONFIG_NODE_ASSET_THEME_TEMPLATE_DIR } from '#env'
import { is_directory, is_file } from '#util/path'

import { render_template } from './util.mjs'

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
const definitionFields = new Set([
  'location',
  'active',
  'themes',
  'extname',
  'local',
  ...lifecycleFields,
])
const conditionFields = new Set(['env', 'file', 'directory', 'all'])
const pathSegmentPattern = /^[a-z0-9]+(?:-[a-z0-9]+)*$/

/** @param {string} [root] @return {Promise<IThemeAppDefinition[]>} */
export async function load_theme_app_definitions(
  root = XDG_CONFIG_NODE_ASSET_THEME_TEMPLATE_DIR,
) {
  const entries = fs.readdirSync(root, { withFileTypes: true })
    .filter(entry => entry.isDirectory())
    .sort((a, b) => a.name.localeCompare(b.name))
  if (entries.length === 0) throw new Error(`No theme app definitions found: ${root}`)

  return Promise.all(entries.map(async entry => {
    const name = entry.name
    if (!pathSegmentPattern.test(name)) {
      throw new Error(`Invalid theme app directory name: ${name}`)
    }

    const appDir = path.join(root, name)
    const definitionPath = path.join(appDir, 'meta.mjs')
    assertFile(definitionPath, `Missing definition for theme app: ${name}`)
    assertFile(path.join(appDir, 'default.hbs'), `Missing default template for theme app: ${name}`)

    let definition
    try {
      definition = (await import(pathToFileURL(definitionPath).href)).default
    } catch (error) {
      throw new Error(`Invalid theme app definition module: ${definitionPath}`, { cause: error })
    }
    return validateDefinition(name, definition)
  }))
}

/** @param {IThemeAppDefinition[]} definitions @return {IAppConfig[]} */
export function create_theme_apps(definitions) {
  return definitions.map(definition => ({
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
  }))
}

/**
 * @param {IThemeAppCondition} condition
 * @param {IAppConfig} app
 * @param {NodeJS.ProcessEnv} [environment]
 */
export function evaluate_theme_app_condition(condition, app, environment = process.env) {
  if ('env' in condition) {
    return Object.hasOwn(environment, condition.env) && !!environment[condition.env]
  }
  if ('file' in condition) return is_file(resolveConditionPath(condition.file, app))
  if ('directory' in condition) {
    return is_directory(resolveConditionPath(condition.directory, app))
  }
  if ('all' in condition) {
    return condition.all.every(entry => evaluate_theme_app_condition(entry, app, environment))
  }
  return false
}

/** @param {string} name @param {unknown} value @return {IThemeAppDefinition} */
function validateDefinition(name, value) {
  if (!isRecord(value)) throw new Error(`Theme app definition must be an object: ${name}`)
  assertKnownFields(value, definitionFields, `theme app definition for ${name}`)

  for (const field of ['location', 'active', 'themes', 'extname', 'local']) {
    if (!Object.hasOwn(value, field)) {
      throw new Error(`Missing required theme app definition field "${field}": ${name}`)
    }
  }
  if (
    typeof value.location !== 'string' ||
    value.location.length === 0 ||
    !isAbsolutePath(value.location)
  ) {
    throw new Error(`Theme app location must be a non-empty absolute path: ${name}`)
  }

  validateCondition(value.active, `${name}.active`)
  validateNullableRelativePath(value.themes, `${name}.themes`)
  if (typeof value.extname !== 'string' || /[\\/\0\r\n]/.test(value.extname)) {
    throw new Error(`Theme app extname must be a path-free string: ${name}`)
  }
  if (value.local !== null) {
    if (typeof value.local !== 'string' || value.local.length === 0) {
      throw new Error(`Theme app local must be a non-empty string or null: ${name}`)
    }
    if (!isAbsolutePath(value.local)) assertRelativePath(value.local, `${name}.local`)
  }
  for (const field of lifecycleFields) {
    if (Object.hasOwn(value, field) && typeof value[field] !== 'function') {
      throw new Error(`Theme app lifecycle field "${field}" must be a function: ${name}`)
    }
  }

  return /** @type {IThemeAppDefinition} */ ({ name, ...value })
}

/** @param {unknown} value @param {string} field */
function validateCondition(value, field) {
  if (!isRecord(value)) throw new Error(`Theme app condition must be an object: ${field}`)
  assertKnownFields(value, conditionFields, field)

  const fields = Object.keys(value)
  if (fields.length !== 1) {
    throw new Error(`Theme app condition must contain exactly one predicate: ${field}`)
  }

  const predicate = fields[0]
  if (predicate === 'env') {
    if (typeof value.env !== 'string' || !/^[A-Za-z_][A-Za-z0-9_]*$/.test(value.env)) {
      throw new Error(`Invalid theme app env condition: ${field}`)
    }
    return
  }
  if (predicate === 'all') {
    if (!Array.isArray(value.all) || value.all.length === 0) {
      throw new Error(`Theme app all condition must be a non-empty array: ${field}`)
    }
    value.all.forEach((condition, index) => validateCondition(condition, `${field}.all[${index}]`))
    return
  }

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
}

/** @param {unknown} value @param {string} field */
function validateNullableRelativePath(value, field) {
  if (value === null) return
  if (typeof value !== 'string' || value.length === 0) {
    throw new Error(`Theme app definition field must be a non-empty string or null: ${field}`)
  }
  assertRelativePath(value, field)
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
  if (!fs.existsSync(filepath) || !fs.statSync(filepath).isFile()) throw new Error(message)
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
function assertKnownFields(value, allowed, label) {
  const unknown = Object.keys(value).filter(field => !allowed.has(field))
  if (unknown.length > 0) throw new Error(`Unknown field in ${label}: ${unknown.join(', ')}`)
}

/** @param {unknown} value @return {value is Record<string, unknown>} */
function isRecord(value) {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
}

export const apps = create_theme_apps(await load_theme_app_definitions())
