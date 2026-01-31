/**
 * A minimal, level-based logging utility with colored output and breadcrumb prefix support.
 *
 * @module @guanghechen/stl/reporter
 */

/** @import { IReporterLevel, IReporterOutput, IReporterProps, IReporterEntry } from './reporter.d.ts' */

/** @type {Record<IReporterLevel, number>} */
const LEVELS = { debug: 0, info: 1, warn: 2, error: 3 }

const ANSI = {
  debug: '\x1b[90m',
  info: '\x1b[36m',
  warn: '\x1b[33m',
  error: '\x1b[31m',
  dim: '\x1b[90m',
  reset: '\x1b[0m',
}

/** @type {IReporterOutput} */
const defaultOutput = (level, parts, args) => {
  const fn = { debug: console.debug, info: console.log, warn: console.warn, error: console.error }
  ;(fn[level] ?? console.log)(...parts, ...args)
}

/**
 * @param {IReporterLevel} level
 * @param {string[]} prefixes
 */
function formatTag(level, prefixes, color) {
  if (!color) return `[${prefixes.join(':')}]`
  const c = ANSI[level]
  const d = ANSI.dim
  const r = ANSI.reset
  return `${d}[${r}${prefixes.map(p => `${c}${p}${r}`).join(`${d}:${r}`)}${d}]${r}`
}

export class Reporter {
  /** @type {string[]} */ #prefixes = []
  /** @type {number} */ #baseLen = 0
  /** @type {number} */ #threshold
  /** @type {IReporterLevel} */ #level
  /** @type {boolean} */ #date
  /** @type {boolean} */ #color
  /** @type {IReporterOutput} */ #output
  /** @type {IReporterEntry[] | null} */ #entries = null

  /** @param {IReporterProps} [props] */
  constructor(props = {}) {
    const { prefix, level = 'info', flight = {}, output = defaultOutput } = props
    if (prefix !== undefined) {
      if (prefix.includes(':')) throw new Error('Prefix cannot contain ":"')
      this.#prefixes.push(prefix)
      this.#baseLen = 1
    }
    this.#level = LEVELS[level] !== undefined ? level : 'info'
    this.#threshold = LEVELS[this.#level]
    this.#date = flight.date ?? true
    this.#color = flight.color ?? true
    this.#output = output
  }

  /** @param {string} prefix */
  attach(prefix) {
    if (prefix.includes(':')) throw new Error('Prefix cannot contain ":"')
    this.#prefixes.push(prefix)
    return this
  }

  detach() {
    if (this.#prefixes.length > this.#baseLen) this.#prefixes.pop()
    return this
  }

  mock() {
    this.#entries = []
    return this
  }

  /** @returns {IReporterEntry[]} */
  collect() {
    const entries = this.#entries ?? []
    this.#entries = null
    return entries
  }

  /**
   * @param {IReporterLevel} level
   * @param {...unknown} args
   */
  log(level, ...args) {
    const lv = LEVELS[level] !== undefined ? level : this.#level
    if (LEVELS[lv] < this.#threshold) return

    const resolved = args.map(a => (typeof a === 'function' ? a() : a))
    const now = new Date()

    if (this.#entries !== null) {
      this.#entries.push({ level: lv, prefixes: [...this.#prefixes], args: resolved, date: now })
      return
    }

    const tags = this.#prefixes.length > 0 ? this.#prefixes : [lv]
    const parts = []
    if (this.#date) {
      const ts = now.toISOString()
      parts.push(this.#color ? `${ANSI.dim}${ts}${ANSI.reset}` : ts)
    }
    parts.push(formatTag(lv, tags, this.#color))
    this.#output(lv, parts, resolved)
  }

  /** @param {...unknown} args */ debug(...args) { this.log('debug', ...args); return this }
  /** @param {...unknown} args */ info(...args) { this.log('info', ...args); return this }
  /** @param {...unknown} args */ warn(...args) { this.log('warn', ...args); return this }
  /** @param {...unknown} args */ error(...args) { this.log('error', ...args); return this }
}
