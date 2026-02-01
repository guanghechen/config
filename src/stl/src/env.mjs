/**
 * A minimal .env parser with typed value support and variable interpolation.
 *
 * @module @guanghechen/stl/env
 */

/** @import { IEnvPrimitive, IEnvRecord, IStringifyEnvOptions } from './env.d.ts' */

const ENV_ENTRY_PATTERN =
  /^\s*(?:export\s+)?([\w.-]+)(?:\s*=\s*?|:\s+?)(\s*'(?:\\'|[^'])*'|\s*"(?:\\"|[^"])*"|\s*`(?:\\`|[^`])*`|[^#\r\n]+)?\s*(?:#.*)?$/gm

/**
 * Parse .env content string into an object.
 * @param {string} content
 * @param {IEnvRecord | null} [inputEnv]
 * @returns {IEnvRecord}
 */
export function parse(content, inputEnv = null) {
  /** @type {IEnvRecord} */
  const env = { ...(inputEnv ?? {}) }
  if (!content) return env

  const text = content.replace(/\r\n?/gm, '\n')
  const pattern = new RegExp(ENV_ENTRY_PATTERN.source, ENV_ENTRY_PATTERN.flags)

  while (true) {
    const match = pattern.exec(text)
    if (!match) break

    const key = match[1]
    let value = (match[2] ?? '').trim()

    if (!value) {
      env[key] = ''
      continue
    }

    const hasQuote = value[0] === '"' || value[0] === "'"

    value = value.replace(/^(['"`])([\s\S]*)\1$/gm, '$2')

    if (hasQuote) {
      value = value.replace(/\\n/g, '\n').replace(/\\r/g, '\r').replace(/\\t/g, '\t')
    } else {
      if (value === 'null') {
        env[key] = null
        continue
      }

      if (value === 'false') {
        env[key] = false
        continue
      }

      if (value === 'true') {
        env[key] = true
        continue
      }

      const numeric = Number(value)
      if (!Number.isNaN(numeric)) {
        env[key] = numeric
        continue
      }
    }

    value = value.replace(/\$\{env:([^}]+)\}/g, (_, envVar) => {
      const envValue = env[envVar] ?? ''
      if (envValue === null) return ''
      return String(envValue)
    })

    env[key] = value
  }

  return env
}

/**
 * Stringify a single value for .env format.
 * @param {IEnvPrimitive} value
 * @returns {string}
 */
function stringifyValue(value) {
  if (value === null) return 'null'
  if (typeof value === 'boolean' || typeof value === 'number') return String(value)
  const str = value ?? ''
  if (str.includes(' ') || str.includes('"') || str.includes("'") || str.includes('\n') || str.includes('\r') || str.includes('\t')) {
    return `"${str.replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\n/g, '\\n').replace(/\r/g, '\\r').replace(/\t/g, '\\t')}"`
  }
  return str
}

/**
 * Convert environment record to .env format string.
 * @param {IEnvRecord} env
 * @param {IStringifyEnvOptions} [options]
 * @returns {string}
 */
export function stringify(env, options) {
  const excludeSet = new Set(options?.exclude ?? [])
  /** @type {string[]} */
  const lines = []
  for (const [key, value] of Object.entries(env)) {
    if (excludeSet.has(key)) continue
    lines.push(`${key}=${stringifyValue(value)}`)
  }
  return lines.length > 0 ? `${lines.join('\n')}\n` : ''
}
