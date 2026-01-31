/**
 * A minimal, type-safe command-line interface builder with fluent API.
 *
 * @module stl/commander
 */

/**
 * @typedef {boolean | string | number | string[] | number[]} ICommanderOptionValue
 * @typedef {string | string[] | undefined} ICommanderArgumentValue
 * @typedef {'boolean' | 'string' | 'number' | 'string[]' | 'number[]'} ICommanderOptionType
 * @typedef {'debug' | 'info' | 'warn' | 'error'} ICommanderLogLevel
 */

/**
 * @typedef {Object} ICommanderOptionConfig
 * @property {ICommanderOptionType} [type]
 * @property {ICommanderOptionValue} [default]
 * @property {string} [env]
 */

/**
 * @typedef {Object} ICommanderDiagnostic
 * @property {'warn' | 'error'} type
 * @property {string} message
 */

/**
 * @typedef {Object} ICommanderParseResult
 * @property {Record<string, ICommanderArgumentValue>} args
 * @property {Record<string, ICommanderOptionValue>} opts
 * @property {Record<string, string>} envs
 * @property {ICommanderDiagnostic[]} diagnostics
 */

/**
 * @typedef {Object} ICommanderExecuteParams
 * @property {Command} ctx
 * @property {Record<string, ICommanderArgumentValue>} args
 * @property {Record<string, ICommanderOptionValue>} opts
 * @property {Record<string, string>} envs
 */

/**
 * @typedef {(params: ICommanderExecuteParams) => Promise<void>} ICommanderActionHandler
 */

/**
 * @typedef {Object} IOptionDef
 * @property {string} short
 * @property {string} long
 * @property {string} description
 * @property {string} valueName
 * @property {ICommanderOptionType} type
 * @property {ICommanderOptionValue} [defaultValue]
 * @property {string} [env]
 * @property {boolean} isBuiltin
 */

/**
 * @typedef {Object} IArgumentDef
 * @property {string} name
 * @property {string} description
 * @property {boolean} required
 * @property {boolean} variadic
 * @property {string} [defaultValue]
 */

const LOG_LEVELS = /** @type {const} */ (['debug', 'info', 'warn', 'error'])

/**
 * Convert kebab-case to camelCase.
 * @param {string} str
 * @returns {string}
 */
function toCamelCase(str) {
  return str.replace(/-([a-z])/g, (_, c) => c.toUpperCase())
}

/**
 * Check if a string represents a valid number.
 * @param {string} value
 * @returns {boolean}
 */
function isValidNumber(value) {
  const n = Number(value)
  return !Number.isNaN(n) && Number.isFinite(n)
}

export class Command {
  // ============================================================
  // Private Fields (alphabetical)
  // ============================================================

  /** @type {IArgumentDef[]} */
  #arguments = []

  /** @type {string} */
  #desc = ''

  /** @type {string[]} */
  #examples = []

  /** @type {ICommanderActionHandler | null} */
  #handler = null

  /** @type {string} */
  #name

  /** @type {IOptionDef[]} */
  #options = []

  /** @type {boolean} */
  #strictMode = true

  /** @type {string} */
  #ver = ''

  // ============================================================
  // Constructor
  // ============================================================

  /**
   * @param {string} name
   */
  constructor(name) {
    this.#name = name
    this.#addBuiltinOptions()
  }

  // ============================================================
  // Public Properties (alphabetical)
  // ============================================================

  get name() {
    return this.#name
  }

  // ============================================================
  // Public Methods (alphabetical)
  // ============================================================

  /**
   * Set the action handler.
   * @param {ICommanderActionHandler} handler
   * @returns {this}
   */
  action(handler) {
    this.#handler = handler
    return this
  }

  /**
   * Add a positional argument.
   * @param {string} spec
   * @param {string} [description='']
   * @returns {this}
   */
  argument(spec, description = '') {
    const match = spec.match(/^([<\[])(\.\.\.)?([\w-]+)(?:=([^\]>]+))?([>\]])$/)
    if (!match) {
      throw new Error(`Invalid argument spec: ${spec}`)
    }

    const [, open, dots, name, defaultValue, close] = match
    const required = open === '<' && close === '>'
    const variadic = !!dots

    if (variadic && this.#arguments.some(a => a.variadic)) {
      throw new Error('Only one variadic argument is allowed')
    }

    this.#arguments.push({ name, description, required, variadic, defaultValue })
    return this
  }

  /**
   * Set command description.
   * @param {string} text
   * @returns {this}
   */
  description(text) {
    this.#desc = text
    return this
  }

  /**
   * Add a usage example.
   * @param {string} text
   * @returns {this}
   */
  example(text) {
    this.#examples.push(text)
    return this
  }

  /**
   * Execute the action handler.
   * @param {ICommanderExecuteParams} params
   * @returns {Promise<void>}
   */
  async execute(params) {
    if (this.#handler) {
      await this.#handler(params)
    }
  }

  /**
   * Add an option.
   * @param {string} flags
   * @param {string} [description='']
   * @param {ICommanderOptionConfig} [config={}]
   * @returns {this}
   */
  option(flags, description = '', config = {}) {
    const def = this.#parseOptionFlags(flags, description, config)
    this.#options.push(def)
    return this
  }

  /**
   * Parse argv and envs, return parse result with diagnostics.
   * @param {string[]} argv
   * @param {Record<string, string>} envs
   * @returns {ICommanderParseResult}
   */
  parse(argv, envs) {
    /** @type {ICommanderDiagnostic[]} */
    const diagnostics = []
    /** @type {Record<string, ICommanderOptionValue>} */
    const opts = {}
    /** @type {string[]} */
    const positionals = []
    /** @type {string[]} */
    const unknownOptions = []

    // Build lookup maps
    /** @type {Map<string, IOptionDef>} */
    const shortMap = new Map()
    /** @type {Map<string, IOptionDef>} */
    const longMap = new Map()
    /** @type {Map<string, IOptionDef>} */
    const negatedMap = new Map()

    for (const opt of this.#options) {
      if (opt.short) shortMap.set(opt.short, opt)
      if (opt.long) longMap.set(opt.long, opt)
      // Negatable: boolean options support --no-xxx
      if (opt.type === 'boolean' && opt.long && !opt.long.startsWith('--no-')) {
        const negated = opt.long.replace(/^--/, '--no-')
        negatedMap.set(negated, opt)
      }
    }

    // Initialize defaults from config.default, then envs[config.env]
    for (const opt of this.#options) {
      const key = this.#optionKey(opt.long)

      // config.default
      if (opt.defaultValue !== undefined) {
        opts[key] = opt.defaultValue
      } else if (opt.type === 'string[]' || opt.type === 'number[]') {
        opts[key] = []
      }

      // envs[config.env] overrides default
      if (opt.env && envs[opt.env] !== undefined) {
        const envValue = envs[opt.env]
        const coerced = this.#coerceValue(envValue, opt.type, opt.long, diagnostics)
        if (coerced !== undefined) {
          opts[key] = coerced
        }
      }
    }

    // Parse argv
    let terminated = false
    for (let i = 0; i < argv.length; i++) {
      const arg = argv[i]

      if (terminated) {
        positionals.push(arg)
        continue
      }

      if (arg === '--') {
        terminated = true
        continue
      }

      if (arg.startsWith('--')) {
        // Long option
        const eqIdx = arg.indexOf('=')
        const flag = eqIdx !== -1 ? arg.slice(0, eqIdx) : arg
        const eqValue = eqIdx !== -1 ? arg.slice(eqIdx + 1) : undefined

        // Check negated first
        const negatedOpt = negatedMap.get(flag)
        if (negatedOpt) {
          const key = this.#optionKey(negatedOpt.long)
          opts[key] = false
          continue
        }

        const opt = longMap.get(flag)
        if (!opt) {
          unknownOptions.push(flag)
          continue
        }

        this.#handleOptionValue(opt, opts, argv, i, eqValue, diagnostics)
        if (opt.type !== 'boolean' && eqValue === undefined && argv[i + 1] && !argv[i + 1].startsWith('-')) {
          i++
        }
      } else if (arg.startsWith('-') && arg.length > 1) {
        // Short option(s)
        const chars = arg.slice(1)

        // Check if it's a known short option directly
        const directOpt = shortMap.get(arg)
        if (directOpt) {
          this.#handleOptionValue(directOpt, opts, argv, i, undefined, diagnostics)
          if (directOpt.type !== 'boolean' && argv[i + 1] && !argv[i + 1].startsWith('-')) {
            i++
          }
          continue
        }

        // Handle combined short options: -abc
        for (let j = 0; j < chars.length; j++) {
          const shortFlag = `-${chars[j]}`
          const opt = shortMap.get(shortFlag)

          if (!opt) {
            unknownOptions.push(shortFlag)
            continue
          }

          const isLast = j === chars.length - 1
          if (opt.type === 'boolean') {
            const key = this.#optionKey(opt.long)
            opts[key] = true
          } else if (isLast) {
            // Last char can take a value
            this.#handleOptionValue(opt, opts, argv, i, undefined, diagnostics)
            if (argv[i + 1] && !argv[i + 1].startsWith('-')) {
              i++
            }
          } else {
            // Non-boolean in middle of combination - error
            diagnostics.push({
              type: 'error',
              message: `Option '${shortFlag}' requires a value`,
            })
          }
        }
      } else {
        positionals.push(arg)
      }
    }

    // Strict mode: unknown options
    if (this.#strictMode) {
      for (const flag of unknownOptions) {
        diagnostics.push({ type: 'error', message: `Unknown option '${flag}'` })
      }
    }

    // Handle --silent: override logLevel
    if (opts.silent === true) {
      opts.logLevel = 'error'
    }

    // Validate --log-level
    if (typeof opts.logLevel === 'string' && !LOG_LEVELS.includes(/** @type {ICommanderLogLevel} */ (opts.logLevel))) {
      diagnostics.push({ type: 'error', message: `Invalid log level '${opts.logLevel}'` })
    }

    // Map positionals to arguments
    /** @type {Record<string, ICommanderArgumentValue>} */
    const args = {}
    let posIdx = 0
    for (const argDef of this.#arguments) {
      if (argDef.variadic) {
        const remaining = positionals.slice(posIdx)
        if (argDef.required && remaining.length === 0) {
          diagnostics.push({ type: 'error', message: `Missing required argument '<...${argDef.name}>'` })
        }
        args[argDef.name] = remaining
        posIdx = positionals.length
      } else {
        const value = positionals[posIdx]
        if (argDef.required && value === undefined) {
          diagnostics.push({ type: 'error', message: `Missing required argument '<${argDef.name}>'` })
        }
        args[argDef.name] = value ?? argDef.defaultValue
        posIdx++
      }
    }

    return { args, opts, envs, diagnostics }
  }

  /**
   * Parse + execute. Exit with code 1 on error.
   * @param {string[]} argv
   * @param {Record<string, string>} envs
   * @returns {Promise<void>}
   */
  async run(argv, envs) {
    const { args, opts, diagnostics } = this.parse(argv, envs)

    // Handle --help
    if (opts.help === true) {
      this.showHelp()
      return
    }

    // Handle --version
    if (opts.version === true && this.#ver) {
      console.log(this.#ver)
      return
    }

    // Check for errors
    const errors = diagnostics.filter(d => d.type === 'error')
    if (errors.length > 0) {
      for (const e of errors) {
        console.error(`Error: ${e.message}`)
      }
      console.error(`Run '${this.#name} --help' for usage.`)
      process.exitCode = 1
      return
    }

    await this.execute({ ctx: this, args, opts, envs })
  }

  /**
   * Print help message.
   */
  showHelp() {
    console.log(this.#buildHelpText())
  }

  /**
   * Enable/disable strict mode.
   * @param {boolean} [enabled=true]
   * @returns {this}
   */
  strict(enabled = true) {
    this.#strictMode = enabled
    return this
  }

  /**
   * Set command version (adds --version option).
   * @param {string} ver
   * @returns {this}
   */
  version(ver) {
    this.#ver = ver
    if (!this.#options.some(o => o.long === '--version')) {
      this.#options.splice(1, 0, {
        short: '',
        long: '--version',
        description: 'Display version number',
        valueName: '',
        type: 'boolean',
        defaultValue: false,
        isBuiltin: true,
      })
    }
    return this
  }

  // ============================================================
  // Private Methods (alphabetical)
  // ============================================================

  #addBuiltinOptions() {
    this.#options.push({
      short: '',
      long: '--help',
      description: 'Display this help message',
      valueName: '',
      type: 'boolean',
      defaultValue: false,
      isBuiltin: true,
    })
    this.#options.push({
      short: '',
      long: '--log-level',
      description: 'Set log level (debug|info|warn|error)',
      valueName: '<level>',
      type: 'string',
      defaultValue: 'info',
      isBuiltin: true,
    })
    this.#options.push({
      short: '',
      long: '--silent',
      description: 'Suppress all output except errors',
      valueName: '',
      type: 'boolean',
      defaultValue: false,
      isBuiltin: true,
    })
  }

  /**
   * @returns {string}
   */
  #buildHelpText() {
    const lines = []

    if (this.#desc) {
      lines.push(this.#desc, '')
    }

    // Usage line
    const usageParts = [this.#name, '[options]']
    for (const arg of this.#arguments) {
      if (arg.variadic) {
        usageParts.push(arg.required ? `<...${arg.name}>` : `[...${arg.name}]`)
      } else {
        usageParts.push(arg.required ? `<${arg.name}>` : `[${arg.name}]`)
      }
    }
    lines.push(`Usage: ${usageParts.join(' ')}`, '')

    // Arguments
    if (this.#arguments.length > 0) {
      lines.push('Arguments:')
      const maxLen = Math.max(...this.#arguments.map(a => a.name.length + (a.variadic ? 3 : 0)))
      for (const arg of this.#arguments) {
        const name = arg.variadic ? `...${arg.name}` : arg.name
        const defaultStr = arg.defaultValue !== undefined ? ` (default: ${arg.defaultValue})` : ''
        lines.push(`  ${name.padEnd(maxLen + 2)}${arg.description}${defaultStr}`)
      }
      lines.push('')
    }

    // Options
    lines.push('Options:')
    const builtinOpts = this.#options.filter(o => o.isBuiltin)
    const userOpts = this.#options.filter(o => !o.isBuiltin)
    const allOpts = [...builtinOpts, ...userOpts]

    const flagStrs = allOpts.map(o => {
      const parts = []
      if (o.short) parts.push(o.short)
      if (o.long) parts.push(o.long + (o.valueName ? ` ${o.valueName}` : ''))
      return parts.join(', ')
    })
    const maxFlagLen = Math.max(...flagStrs.map(s => s.length))

    for (let i = 0; i < allOpts.length; i++) {
      const opt = allOpts[i]
      const suffixes = []
      if (opt.env) suffixes.push(`env: ${opt.env}`)
      if (opt.defaultValue !== undefined && opt.defaultValue !== false) {
        suffixes.push(`default: ${opt.defaultValue}`)
      }
      const suffix = suffixes.length > 0 ? ` (${suffixes.join(') (')})` : ''
      lines.push(`  ${flagStrs[i].padEnd(maxFlagLen + 2)}${opt.description}${suffix}`)
    }
    lines.push('')

    // Examples
    if (this.#examples.length > 0) {
      lines.push('Examples:')
      for (const ex of this.#examples) {
        lines.push(`  $ ${ex}`)
      }
      lines.push('')
    }

    return lines.join('\n')
  }

  /**
   * @param {string} value
   * @param {ICommanderOptionType} type
   * @param {string} optLong
   * @param {ICommanderDiagnostic[]} diagnostics
   * @returns {ICommanderOptionValue | undefined}
   */
  #coerceValue(value, type, optLong, diagnostics) {
    switch (type) {
      case 'boolean':
        return value === 'true' || value === '1'
      case 'string':
        return value
      case 'number':
        if (!isValidNumber(value)) {
          diagnostics.push({ type: 'error', message: `Invalid value '${value}' for option '${optLong}'` })
          return undefined
        }
        return Number(value)
      case 'string[]':
        return value
      case 'number[]':
        if (!isValidNumber(value)) {
          diagnostics.push({ type: 'error', message: `Invalid value '${value}' for option '${optLong}'` })
          return undefined
        }
        return Number(value)
    }
  }

  /**
   * @param {IOptionDef} opt
   * @param {Record<string, ICommanderOptionValue>} opts
   * @param {string[]} argv
   * @param {number} idx
   * @param {string | undefined} eqValue
   * @param {ICommanderDiagnostic[]} diagnostics
   */
  #handleOptionValue(opt, opts, argv, idx, eqValue, diagnostics) {
    const key = this.#optionKey(opt.long)

    if (opt.type === 'boolean') {
      opts[key] = true
      return
    }

    const rawValue = eqValue ?? argv[idx + 1]
    if (rawValue === undefined || (eqValue === undefined && rawValue.startsWith('-'))) {
      diagnostics.push({ type: 'error', message: `Option '${opt.long}' requires a value` })
      return
    }

    const coerced = this.#coerceValue(rawValue, opt.type, opt.long, diagnostics)
    if (coerced === undefined) return

    if (opt.type === 'string[]' || opt.type === 'number[]') {
      // Array: accumulate (array is always initialized to [] in parse)
      /** @type {Array<string | number>} */ (opts[key]).push(/** @type {string | number} */ (coerced))
    } else {
      // Scalar: override
      opts[key] = coerced
    }
  }

  /**
   * @param {string} long
   * @returns {string}
   */
  #optionKey(long) {
    return toCamelCase(long.replace(/^--(?:no-)?/, ''))
  }

  /**
   * @param {string} flags
   * @param {string} description
   * @param {ICommanderOptionConfig} config
   * @returns {IOptionDef}
   */
  #parseOptionFlags(flags, description, config) {
    let short = ''
    let long = ''
    let valueName = ''

    const parts = flags.split(/,\s*/)
    for (const part of parts) {
      const trimmed = part.trim()
      if (trimmed.startsWith('--')) {
        const spaceIdx = trimmed.indexOf(' ')
        if (spaceIdx !== -1) {
          long = trimmed.slice(0, spaceIdx)
          valueName = trimmed.slice(spaceIdx + 1).trim()
        } else {
          long = trimmed
        }
      } else if (trimmed.startsWith('-')) {
        short = trimmed.split(/\s/)[0]
      }
    }

    const isBoolean = !valueName

    /** @type {ICommanderOptionType} */
    let type = 'string'
    if (config.type) {
      type = config.type
    } else if (isBoolean) {
      type = 'boolean'
    }

    return {
      short,
      long,
      description,
      valueName,
      type,
      defaultValue: config.default,
      env: config.env,
      isBuiltin: false,
    }
  }
}
