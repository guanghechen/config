/**
 * A minimal, type-safe command-line interface builder with fluent API.
 *
 * @module @guanghechen/stl/commander
 */

/** @import { IReporter, IOptionType, IOptionValue, IOption, IArgumentKind, IArgumentValue, IArgument, ICommandConfig, ISubcommandEntry, IActionParams, IAction, IRunParams, IParseResult, ICommanderErrorKind } from './commander.d.ts' */

// ============================================================
// Constants
// ============================================================

/** @type {IOption<'boolean'>} */
const BUILTIN_HELP_OPTION = {
  long: 'help',
  short: 'h',
  type: 'boolean',
  description: 'Show help information',
}

/** @type {IOption<'boolean'>} */
const BUILTIN_VERSION_OPTION = {
  long: 'version',
  short: 'V',
  type: 'boolean',
  description: 'Show version number',
}

// ============================================================
// Utilities
// ============================================================

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

// ============================================================
// DefaultReporter
// ============================================================

export class DefaultReporter {
  /**
   * @param {string} message
   * @param {...unknown} args
   */
  debug(message, ...args) {
    console.debug(message, ...args)
  }

  /**
   * @param {string} message
   * @param {...unknown} args
   */
  info(message, ...args) {
    console.info(message, ...args)
  }

  /**
   * @param {string} message
   * @param {...unknown} args
   */
  warn(message, ...args) {
    console.warn(message, ...args)
  }

  /**
   * @param {string} message
   * @param {...unknown} args
   */
  error(message, ...args) {
    console.error(message, ...args)
  }
}

// ============================================================
// CommanderError
// ============================================================

export class CommanderError extends Error {
  /** @type {ICommanderErrorKind} */
  kind

  /** @type {string} */
  commandPath

  /**
   * @param {ICommanderErrorKind} kind
   * @param {string} message
   * @param {string} commandPath
   */
  constructor(kind, message, commandPath) {
    super(message)
    this.name = 'CommanderError'
    this.kind = kind
    this.commandPath = commandPath
  }

  /**
   * Format error message with hint.
   * @returns {string}
   */
  format() {
    return `Error: ${this.message}\nRun "${this.commandPath} --help" for usage.`
  }
}

// ============================================================
// Command
// ============================================================

export class Command {
  // ============================================================
  // Private Fields
  // ============================================================

  /** @type {string} */
  #name

  /** @type {string | undefined} */
  #description

  /** @type {string | undefined} */
  #version

  /** @type {boolean} */
  #helpSubcommandEnabled

  /** @type {IOption[]} */
  #options = []

  /** @type {IArgument[]} */
  #arguments = []

  /** @type {ISubcommandEntry[]} */
  #subcommands = []

  /** @type {IAction | null} */
  #action = null

  // ============================================================
  // Constructor
  // ============================================================

  /**
   * @param {ICommandConfig} config
   */
  constructor(config) {
    this.#name = config.name
    this.#description = config.description
    this.#version = config.version
    this.#helpSubcommandEnabled = config.helpSubcommand ?? false
  }

  // ============================================================
  // Public Properties
  // ============================================================

  get name() {
    return this.#name
  }

  get description() {
    return this.#description
  }

  get version() {
    return this.#version
  }

  /** @returns {ReadonlyArray<IOption>} */
  get options() {
    return this.#options
  }

  /** @returns {ReadonlyArray<IArgument>} */
  get arguments() {
    return this.#arguments
  }

  // ============================================================
  // Definition Methods
  // ============================================================

  /**
   * Add an option.
   * @template {IOptionType} T
   * @param {IOption<T>} opt
   * @returns {this}
   */
  option(opt) {
    this.#validateOptionConfig(opt)
    this.#checkOptionUniqueness(opt)
    this.#options.push(opt)
    return this
  }

  /**
   * Add a positional argument.
   * @param {IArgument} arg
   * @returns {this}
   */
  argument(arg) {
    this.#validateArgumentConfig(arg)
    this.#arguments.push(arg)
    return this
  }

  /**
   * Set the action handler.
   * @param {IAction} fn
   * @returns {this}
   */
  action(fn) {
    this.#action = fn
    return this
  }

  // ============================================================
  // Assembly Methods
  // ============================================================

  /**
   * Register a subcommand.
   * @param {string} name
   * @param {Command} cmd
   * @returns {this}
   */
  subcommand(name, cmd) {
    this.#subcommands.push({ name, command: cmd })
    return this
  }

  // ============================================================
  // Execution Methods
  // ============================================================

  /**
   * Parse argv and execute action. Sets process.exitCode = 1 on error.
   * @param {IRunParams} params
   * @returns {Promise<void>}
   */
  async run(params) {
    const { argv, envs, reporter = new DefaultReporter() } = params
    const commandPath = this.#getCommandPath([])

    try {
      // Handle help subcommand (e.g., `cli help <subcommand>`)
      if (this.#helpSubcommandEnabled && argv[0] === 'help') {
        const result = this.#processHelpSubcommand(argv.slice(1), reporter)
        if (result) return
      }

      // Route to subcommand if matched (BEFORE checking --help on parent)
      // This ensures `cli sub --help` shows subcommand help, not parent help
      const routeResult = this.#route(argv, envs, reporter)
      if (routeResult.handled) return

      // Check for help flag (only if not routed to subcommand)
      if (this.#hasHelpFlag(argv)) {
        reporter.info(this.formatHelp())
        return
      }

      // Check for version flag
      if (this.#version && this.#hasVersionFlag(argv)) {
        reporter.info(this.#version)
        return
      }

      // Parse arguments
      const { args, opts } = this.parse(routeResult.remainingArgv)

      // Apply environment variables
      this.#applyEnvValues(opts, envs)

      // Validate required arguments
      this.#validateArguments(args, commandPath)

      // Execute action
      if (this.#action) {
        await this.#action({ ctx: this, opts, args })
      }
    } catch (err) {
      if (err instanceof CommanderError) {
        reporter.error(err.format())
      } else {
        reporter.error(`Error: ${err instanceof Error ? err.message : String(err)}`)
      }
      process.exitCode = 1
    }
  }

  /**
   * Parse argv without executing action.
   * @param {string[]} argv
   * @returns {IParseResult}
   */
  parse(argv) {
    const normalizedArgv = this.#normalizeArgv(argv)
    const commandPath = this.#getCommandPath([])

    /** @type {Record<string, IOptionValue>} */
    const opts = {}
    /** @type {string[]} */
    const positionals = []

    // Build option maps
    const { shortMap, longMap, negatedMap } = this.#buildOptionMaps()

    // Initialize defaults
    for (const opt of this.#getMergedOptions()) {
      const key = toCamelCase(opt.long)
      if (opt.default !== undefined) {
        opts[key] = opt.default
      } else if (opt.type === 'string[]' || opt.type === 'number[]') {
        opts[key] = []
      }
    }

    // Parse argv
    let terminated = false
    for (let i = 0; i < normalizedArgv.length; i++) {
      const arg = normalizedArgv[i]

      if (terminated) {
        positionals.push(arg)
        continue
      }

      if (arg === '--') {
        terminated = true
        continue
      }

      if (arg.startsWith('--')) {
        i = this.#parseLongOption(arg, normalizedArgv, i, opts, longMap, negatedMap, commandPath)
      } else if (arg.startsWith('-') && arg.length > 1) {
        i = this.#parseShortOption(arg, normalizedArgv, i, opts, shortMap, commandPath)
      } else {
        // Check for subcommand
        const subEntry = this.#subcommands.find(s => s.name === arg)
        if (subEntry) {
          return {
            args: {},
            opts,
            remaining: normalizedArgv.slice(i + 1),
            subcommand: arg,
          }
        }
        positionals.push(arg)
      }
    }

    // Map positionals to arguments
    /** @type {Record<string, IArgumentValue>} */
    const args = {}
    let posIdx = 0
    for (const argDef of this.#arguments) {
      if (argDef.kind === 'variadic') {
        args[argDef.name] = positionals.slice(posIdx)
        posIdx = positionals.length
      } else {
        const value = positionals[posIdx]
        args[argDef.name] = value ?? argDef.default
        posIdx++
      }
    }

    return { args, opts, remaining: [] }
  }

  /**
   * Generate help text.
   * @returns {string}
   */
  formatHelp() {
    const lines = []

    if (this.#description) {
      lines.push(this.#description, '')
    }

    // Usage line
    const usageParts = [this.#name]

    if (this.#subcommands.length > 0) {
      usageParts.push('[command]')
    }

    usageParts.push('[options]')

    for (const arg of this.#arguments) {
      if (arg.kind === 'variadic') {
        usageParts.push(`[...${arg.name}]`)
      } else if (arg.kind === 'required') {
        usageParts.push(`<${arg.name}>`)
      } else {
        usageParts.push(`[${arg.name}]`)
      }
    }
    lines.push(`Usage: ${usageParts.join(' ')}`, '')

    // Subcommands
    if (this.#subcommands.length > 0) {
      lines.push('Commands:')
      const maxLen = Math.max(...this.#subcommands.map(s => s.name.length))
      for (const sub of this.#subcommands) {
        const desc = sub.command.description || ''
        lines.push(`  ${sub.name.padEnd(maxLen + 2)}${desc}`)
      }
      lines.push('')
    }

    // Arguments
    if (this.#arguments.length > 0) {
      lines.push('Arguments:')
      const maxLen = Math.max(...this.#arguments.map(a => a.name.length + (a.kind === 'variadic' ? 3 : 0)))
      for (const arg of this.#arguments) {
        const name = arg.kind === 'variadic' ? `...${arg.name}` : arg.name
        const defaultStr = arg.default !== undefined ? ` (default: ${arg.default})` : ''
        lines.push(`  ${name.padEnd(maxLen + 2)}${arg.description || ''}${defaultStr}`)
      }
      lines.push('')
    }

    // Options
    lines.push('Options:')
    const allOpts = this.#getMergedOptions()

    const flagStrs = allOpts.map(o => {
      const parts = []
      if (o.short) parts.push(`-${o.short}`)
      const longPart =
        o.type === 'boolean' ? `--${o.long}` : `--${o.long} <${o.type.replace('[]', '')}>`
      parts.push(longPart)
      return parts.join(', ')
    })
    const maxFlagLen = Math.max(...flagStrs.map(s => s.length))

    for (let i = 0; i < allOpts.length; i++) {
      const opt = allOpts[i]
      const suffixes = []
      if (opt.env) suffixes.push(`env: ${opt.env}`)
      if (opt.default !== undefined && opt.default !== false) {
        suffixes.push(`default: ${opt.default}`)
      }
      const suffix = suffixes.length > 0 ? ` (${suffixes.join(') (')})` : ''
      lines.push(`  ${flagStrs[i].padEnd(maxFlagLen + 2)}${opt.description || ''}${suffix}`)
    }
    lines.push('')

    return lines.join('\n')
  }

  // ============================================================
  // Private Methods - Routing
  // ============================================================

  /**
   * Process help subcommand.
   * @param {string[]} argv
   * @param {IReporter} reporter
   * @returns {boolean} - Whether help was handled
   */
  #processHelpSubcommand(argv, reporter) {
    if (argv.length === 0) {
      reporter.info(this.formatHelp())
      return true
    }

    const subName = argv[0]
    const subEntry = this.#subcommands.find(s => s.name === subName)
    if (subEntry) {
      reporter.info(subEntry.command.formatHelp())
      return true
    }

    return false
  }

  /**
   * Route to subcommand if matched.
   * @param {string[]} argv
   * @param {Record<string, string | undefined>} envs
   * @param {IReporter} reporter
   * @returns {{ handled: boolean, remainingArgv: string[] }}
   */
  #route(argv, envs, reporter) {
    if (argv.length === 0 || this.#subcommands.length === 0) {
      return { handled: false, remainingArgv: argv }
    }

    const firstArg = argv[0]

    // Check if it's an option (starts with -)
    if (firstArg.startsWith('-')) {
      return { handled: false, remainingArgv: argv }
    }

    const subEntry = this.#subcommands.find(s => s.name === firstArg)
    if (subEntry) {
      subEntry.command.run({ argv: argv.slice(1), envs, reporter })
      return { handled: true, remainingArgv: [] }
    }

    return { handled: false, remainingArgv: argv }
  }

  // ============================================================
  // Private Methods - Option Parsing
  // ============================================================

  /**
   * Parse a long option.
   * @param {string} arg
   * @param {string[]} argv
   * @param {number} idx
   * @param {Record<string, IOptionValue>} opts
   * @param {Map<string, IOption>} longMap
   * @param {Map<string, IOption>} negatedMap
   * @param {string} commandPath
   * @returns {number}
   */
  #parseLongOption(arg, argv, idx, opts, longMap, negatedMap, commandPath) {
    const eqIdx = arg.indexOf('=')
    const flag = eqIdx !== -1 ? arg.slice(2, eqIdx) : arg.slice(2)
    const eqValue = eqIdx !== -1 ? arg.slice(eqIdx + 1) : undefined

    // Check negated first (--no-xxx)
    if (flag.startsWith('no-')) {
      const baseName = flag.slice(3)
      const negatedOpt = negatedMap.get(baseName)
      if (negatedOpt) {
        const key = toCamelCase(negatedOpt.long)
        opts[key] = false
        return idx
      }
    }

    const opt = longMap.get(flag)
    if (!opt) {
      // Check if it's a builtin option
      if (this.#isBuiltinOption(flag)) {
        return idx
      }
      throw new CommanderError('unknown_option', `Unknown option '--${flag}'`, commandPath)
    }

    return this.#applyValue(opt, opts, argv, idx, eqValue, commandPath)
  }

  /**
   * Parse a short option.
   * @param {string} arg
   * @param {string[]} argv
   * @param {number} idx
   * @param {Record<string, IOptionValue>} opts
   * @param {Map<string, IOption>} shortMap
   * @param {string} commandPath
   * @returns {number}
   */
  #parseShortOption(arg, argv, idx, opts, shortMap, commandPath) {
    const chars = arg.slice(1)

    // Handle combined short options: -abc
    for (let j = 0; j < chars.length; j++) {
      const shortChar = chars[j]
      const opt = shortMap.get(shortChar)

      if (!opt) {
        // Check if it's a builtin option
        if (this.#isBuiltinOption(shortChar, true)) {
          continue
        }
        throw new CommanderError('unknown_option', `Unknown option '-${shortChar}'`, commandPath)
      }

      const isLast = j === chars.length - 1
      if (opt.type === 'boolean') {
        const key = toCamelCase(opt.long)
        opts[key] = true
      } else if (isLast) {
        idx = this.#applyValue(opt, opts, argv, idx, undefined, commandPath)
      } else {
        throw new CommanderError(
          'missing_option_value',
          `Option '-${shortChar}' requires a value`,
          commandPath,
        )
      }
    }

    return idx
  }

  /**
   * Apply a value to an option.
   * @param {IOption} opt
   * @param {Record<string, IOptionValue>} opts
   * @param {string[]} argv
   * @param {number} idx
   * @param {string | undefined} eqValue
   * @param {string} commandPath
   * @returns {number}
   */
  #applyValue(opt, opts, argv, idx, eqValue, commandPath) {
    const key = toCamelCase(opt.long)

    if (opt.type === 'boolean') {
      opts[key] = true
      return idx
    }

    const rawValue = eqValue ?? argv[idx + 1]
    if (rawValue === undefined || (eqValue === undefined && rawValue.startsWith('-'))) {
      throw new CommanderError(
        'missing_option_value',
        `Option '--${opt.long}' requires a value`,
        commandPath,
      )
    }

    const coerced = this.#coerceValue(rawValue, opt.type, opt.long, commandPath)

    if (opt.type === 'string[]' || opt.type === 'number[]') {
      /** @type {Array<string | number>} */ (opts[key]).push(/** @type {string | number} */ (coerced))
    } else {
      opts[key] = coerced
    }

    return eqValue === undefined ? idx + 1 : idx
  }

  /**
   * Coerce a string value to the appropriate type.
   * @param {string} value
   * @param {IOptionType} type
   * @param {string} optLong
   * @param {string} commandPath
   * @returns {IOptionValue}
   */
  #coerceValue(value, type, optLong, commandPath) {
    switch (type) {
      case 'boolean':
        return value === 'true' || value === '1'
      case 'string':
        return value
      case 'number':
        if (!isValidNumber(value)) {
          throw new CommanderError(
            'invalid_option_value',
            `Invalid value '${value}' for option '--${optLong}'`,
            commandPath,
          )
        }
        return Number(value)
      case 'string[]':
        return value
      case 'number[]':
        if (!isValidNumber(value)) {
          throw new CommanderError(
            'invalid_option_value',
            `Invalid value '${value}' for option '--${optLong}'`,
            commandPath,
          )
        }
        return Number(value)
    }
  }

  // ============================================================
  // Private Methods - Option Merging
  // ============================================================

  /**
   * Get merged options (user options + builtins).
   * @returns {IOption[]}
   */
  #getMergedOptions() {
    const builtins = [BUILTIN_HELP_OPTION]
    if (this.#version) {
      builtins.push(BUILTIN_VERSION_OPTION)
    }
    return [...builtins, ...this.#options]
  }

  // ============================================================
  // Private Methods - Validation
  // ============================================================

  /**
   * Validate option configuration.
   * @param {IOption} opt
   */
  #validateOptionConfig(opt) {
    if (!opt.long) {
      throw new Error('Option must have a long name')
    }
    if (!opt.type) {
      throw new Error(`Option '--${opt.long}' must have a type`)
    }
  }

  /**
   * Check option uniqueness.
   * @param {IOption} opt
   */
  #checkOptionUniqueness(opt) {
    const existing = this.#options.find(o => o.long === opt.long || (o.short && o.short === opt.short))
    if (existing) {
      throw new Error(`Duplicate option: --${opt.long}`)
    }
  }

  /**
   * Validate argument configuration.
   * @param {IArgument} arg
   */
  #validateArgumentConfig(arg) {
    if (!arg.name) {
      throw new Error('Argument must have a name')
    }
    if (!arg.kind) {
      throw new Error(`Argument '${arg.name}' must have a kind`)
    }

    // Variadic must be last
    if (arg.kind === 'variadic' && this.#arguments.some(a => a.kind === 'variadic')) {
      throw new Error('Only one variadic argument is allowed')
    }

    // Optional cannot come before required
    if (arg.kind === 'required' && this.#arguments.some(a => a.kind === 'optional')) {
      throw new Error('Required arguments cannot come after optional arguments')
    }
  }

  /**
   * Validate required arguments are present.
   * @param {Record<string, IArgumentValue>} args
   * @param {string} commandPath
   */
  #validateArguments(args, commandPath) {
    for (const argDef of this.#arguments) {
      if (argDef.kind === 'required') {
        const value = args[argDef.name]
        if (value === undefined) {
          throw new CommanderError(
            'missing_argument',
            `Missing required argument '<${argDef.name}>'`,
            commandPath,
          )
        }
      } else if (argDef.kind === 'variadic') {
        const value = args[argDef.name]
        if (Array.isArray(value) && value.length === 0 && argDef.default === undefined) {
          // Variadic with no values is OK unless explicitly required in some other way
        }
      }
    }
  }

  // ============================================================
  // Private Methods - Utilities
  // ============================================================

  /**
   * Check if an option is a builtin.
   * @param {string} flag
   * @param {boolean} [isShort=false]
   * @returns {boolean}
   */
  #isBuiltinOption(flag, isShort = false) {
    if (isShort) {
      return flag === 'h' || flag === 'V'
    }
    return flag === 'help' || flag === 'version'
  }

  /**
   * Build option lookup maps.
   * @returns {{ shortMap: Map<string, IOption>, longMap: Map<string, IOption>, negatedMap: Map<string, IOption> }}
   */
  #buildOptionMaps() {
    /** @type {Map<string, IOption>} */
    const shortMap = new Map()
    /** @type {Map<string, IOption>} */
    const longMap = new Map()
    /** @type {Map<string, IOption>} */
    const negatedMap = new Map()

    for (const opt of this.#getMergedOptions()) {
      if (opt.short) shortMap.set(opt.short, opt)
      if (opt.long) longMap.set(opt.long, opt)
      if (opt.type === 'boolean' && opt.long) {
        negatedMap.set(opt.long, opt)
      }
    }

    return { shortMap, longMap, negatedMap }
  }

  /**
   * Check if argv contains --help or -h.
   * @param {string[]} argv
   * @returns {boolean}
   */
  #hasHelpFlag(argv) {
    return argv.includes('--help') || argv.includes('-h')
  }

  /**
   * Check if argv contains --version or -V.
   * @param {string[]} argv
   * @returns {boolean}
   */
  #hasVersionFlag(argv) {
    return argv.includes('--version') || argv.includes('-V')
  }

  /**
   * Normalize argv (expand --opt=value to separate args).
   * @param {string[]} argv
   * @returns {string[]}
   */
  #normalizeArgv(argv) {
    return argv
  }

  /**
   * Get command path for error messages.
   * @param {string[]} parents
   * @returns {string}
   */
  #getCommandPath(parents) {
    return [...parents, this.#name].join(' ')
  }

  /**
   * Apply environment variable values.
   * @param {Record<string, IOptionValue>} opts
   * @param {Record<string, string | undefined>} envs
   */
  #applyEnvValues(opts, envs) {
    const commandPath = this.#getCommandPath([])
    for (const opt of this.#options) {
      if (opt.env && envs[opt.env] !== undefined) {
        const key = toCamelCase(opt.long)
        // Only apply if not already set from argv
        if (opts[key] === undefined || opts[key] === opt.default) {
          const envValue = envs[opt.env]
          if (envValue !== undefined) {
            opts[key] = this.#coerceValue(envValue, opt.type, opt.long, commandPath)
          }
        }
      }
    }
  }
}
