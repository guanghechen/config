/** @typedef {'debug'|'info'|'warn'|'error'} ILogLevel */

const LEVELS = /** @type {const} */ ({ debug: 0, info: 1, warn: 2, error: 3 })

const COLORS = {
  debug: '\x1b[90m',
  info: '\x1b[36m',
  warn: '\x1b[33m',
  error: '\x1b[31m',
  reset: '\x1b[0m',
}

/**
 * @param {string[]} [argv]
 * @return {ILogLevel}
 */
function parse_log_level(argv = process.argv) {
  const arg = argv.find(a => a.startsWith('--log-level='))
  if (!arg) return 'info'
  const level = arg.split('=')[1]?.toLowerCase()
  return level in LEVELS ? /** @type {ILogLevel} */ (level) : 'info'
}

export class Reporter {
  /** @type {string|undefined} */
  #prefix
  /** @type {number} */
  #threshold

  /**
   * @param {string} [prefix]
   * @param {ILogLevel} [level]
   */
  constructor(prefix, level = parse_log_level()) {
    this.#prefix = prefix
    this.#threshold = LEVELS[level]
  }

  /**
   * @param {ILogLevel} lvl
   * @param {...unknown} args
   */
  #log(lvl, ...args) {
    if (LEVELS[lvl] < this.#threshold) return
    const color = COLORS[lvl]
    const tag = this.#prefix ? `[${this.#prefix}]` : `[${lvl}]`
    const out = lvl === 'error' ? console.error : console.log
    out(`${color}${tag}${COLORS.reset}`, ...args)
  }

  /** @param {...unknown} args */
  debug(...args) {
    this.#log('debug', ...args)
  }

  /** @param {...unknown} args */
  info(...args) {
    this.#log('info', ...args)
  }

  /** @param {...unknown} args */
  warn(...args) {
    this.#log('warn', ...args)
  }

  /** @param {...unknown} args */
  error(...args) {
    this.#log('error', ...args)
  }
}
