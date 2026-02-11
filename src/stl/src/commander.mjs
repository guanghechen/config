/**
 * A minimal, type-safe command-line interface builder with fluent API.
 *
 * @module @guanghechen/stl/commander
 */

/** @import { IReporter, IOptionType, IOption, IArgumentKind, IArgumentType, IArgument, ICommandConfig, ICommand, ICommandContext, ISubcommandEntry, IActionParams, IAction, IRunParams, IParseResult, IShiftResult, ICommanderErrorKind } from './commander.d.ts' */

// ============================================================
// Constants
// ============================================================

/** @type {IOption} */
const BUILTIN_HELP_OPTION = {
  long: 'help',
  short: 'h',
  type: 'boolean',
  description: 'Show help information',
}

/** @type {IOption} */
const BUILTIN_VERSION_OPTION = {
  long: 'version',
  short: 'V',
  type: 'boolean',
  description: 'Show version number',
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

  /** @type {string} */
  #description

  /** @type {string | undefined} */
  #version

  /** @type {boolean} */
  #helpSubcommandEnabled

  /** @type {IReporter | undefined} */
  #reporter

  /** @type {Command | undefined} */
  #parent

  /** @type {IOption[]} */
  #options = []

  /** @type {IArgument[]} */
  #arguments = []

  /** @type {ISubcommandEntry[]} */
  #subcommands = []

  /** @type {IAction | undefined} */
  #action

  // ============================================================
  // Constructor
  // ============================================================

  /**
   * @param {ICommandConfig} config
   */
  constructor(config) {
    this.#name = config.name ?? ''
    this.#description = config.description
    this.#version = config.version
    this.#helpSubcommandEnabled = config.help ?? false
    this.#reporter = config.reporter
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

  /** @returns {Command | undefined} */
  get parent() {
    return this.#parent
  }

  /** @returns {IOption[]} */
  get options() {
    return [...this.#options]
  }

  /** @returns {IArgument[]} */
  get arguments() {
    return [...this.#arguments]
  }

  // ============================================================
  // Definition Methods
  // ============================================================

  /**
   * Add an option.
   * @param {IOption} opt
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
    // Check for reserved name conflict
    if (this.#helpSubcommandEnabled && name === 'help') {
      throw new CommanderError(
        'ConfigurationError',
        '"help" is a reserved subcommand name when help subcommand is enabled',
        this.#getCommandPath(),
      )
    }

    if (cmd.#parent && cmd.#parent !== this) {
      throw new CommanderError(
        'ConfigurationError',
        `command "${cmd.#name}" already has a parent`,
        this.#getCommandPath(),
      )
    }

    // Check if cmd is already registered
    const existing = this.#subcommands.find(e => e.command === cmd)
    if (existing) {
      // Add name as alias
      existing.aliases.push(name)
    } else {
      // New registration
      cmd.#name = name
      cmd.#parent = this
      this.#subcommands.push({ name, aliases: [], command: cmd })
    }
    return this
  }

  // ============================================================
  // Execution Methods
  // ============================================================

  /**
   * Parse argv and execute action.
   * @param {IRunParams} params
   * @returns {Promise<void>}
   */
  async run(params) {
    const { argv, envs, reporter } = params

    try {
      // 0. Handle "help <subcommand>" syntax if enabled
      const processedArgv = this.#processHelpSubcommand(argv)

      // 1. Route: determine command chain
      const { chain, remaining } = this.#routeChain(processedArgv)
      const leafCommand = chain[chain.length - 1]
      const rootCommand = chain[0]
      const includeRootVersion = chain.length === 1

      this.#validateMergedShortOptions(chain, includeRootVersion)

      // 2. Split options and arguments at '--'
      const { optionTokens, restArgs } = this.#splitAtDoubleDash(remaining)

      // 3. Check for built-in --help / --version BEFORE parsing
      const leafOptions = leafCommand.#getMergedOptions(leafCommand === rootCommand)
      const hasUserHelp = leafCommand.#options.some(o => o.long === 'help')
      const hasUserVersion = leafCommand.#options.some(o => o.long === 'version')

      if (!hasUserHelp && leafCommand.#hasHelpFlag(optionTokens, leafOptions)) {
        console.log(leafCommand.formatHelp())
        return
      }

      if (!hasUserVersion && leafCommand === rootCommand) {
        if (leafCommand.#hasVersionFlag(optionTokens, leafOptions)) {
          console.log(leafCommand.version ?? 'unknown')
          return
        }
      }

      // 4. Shift: bottom-up option consumption
      const { optsMap, positionalArgs } = this.#shiftChain(chain, optionTokens, includeRootVersion)

      // 5. Build context
      /** @type {ICommandContext} */
      const ctx = {
        cmd: leafCommand,
        envs,
        reporter: reporter ?? this.#reporter ?? new DefaultReporter(),
        argv,
      }

      // 6. Apply: top-down context building
      this.#applyChain(chain, optsMap, ctx)

      // 7. Merge options (root → leaf, later overwrites earlier)
      const mergedOpts = this.#mergeOpts(chain, optsMap)

      // 8. Parse arguments (combine positional args from before '--' with args after '--')
      const allArgs = [...positionalArgs, ...restArgs]
      const { args, rawArgs } = leafCommand.#parseArguments(allArgs)

      // 9. Execute action
      /** @type {IActionParams} */
      const actionParams = { ctx, opts: mergedOpts, args, rawArgs }

      if (leafCommand.#action) {
        try {
          await leafCommand.#action(actionParams)
        } catch (err) {
          if (err instanceof Error) {
            console.error(`Error: ${err.message}`)
          } else {
            console.error('Error: action failed')
          }
          process.exit(1)
        }
      } else if (leafCommand.#subcommands.length > 0) {
        console.log(leafCommand.formatHelp())
      } else {
        throw new CommanderError(
          'ConfigurationError',
          `no action defined for command "${leafCommand.#getCommandPath()}"`,
          leafCommand.#getCommandPath(),
        )
      }
    } catch (err) {
      if (err instanceof CommanderError) {
        console.error(err.format())
        process.exit(2)
        return
      }
      throw err
    }
  }

  /**
   * Parse argv without executing action.
   * @param {string[]} argv
   * @returns {IParseResult}
   */
  parse(argv) {
    const processedArgv = this.#processHelpSubcommand(argv)
    const { chain, remaining } = this.#routeChain(processedArgv)
    const leafCommand = chain[chain.length - 1]
    const includeRootVersion = chain.length === 1

    this.#validateMergedShortOptions(chain, includeRootVersion)

    // Split options and arguments at '--'
    const { optionTokens, restArgs } = this.#splitAtDoubleDash(remaining)

    // Shift: bottom-up option consumption
    const { optsMap, positionalArgs } = this.#shiftChain(chain, optionTokens, includeRootVersion)

    // Merge options (root → leaf, later overwrites earlier)
    const mergedOpts = this.#mergeOpts(chain, optsMap)

    // Parse arguments (combine positional args from before '--' with args after '--')
    const allArgs = [...positionalArgs, ...restArgs]
    const { args, rawArgs } = leafCommand.#parseArguments(allArgs)

    return { opts: mergedOpts, args, rawArgs }
  }

  /**
   * Shift options from tokens that this command recognizes.
   * Unrecognized tokens are returned in `remaining` for parent commands.
   * @param {string[]} tokens
   * @returns {IShiftResult}
   */
  shift(tokens) {
    return this.#shiftWithShadowed(tokens, new Set())
  }

  /**
   * Shift options with shadowed set support.
   * Options in the shadowed set are excluded from processing.
   * @param {string[]} tokens
   * @param {Set<string>} shadowed
   * @param {boolean} [includeVersion]
   * @returns {IShiftResult}
   */
  #shiftWithShadowed(tokens, shadowed, includeVersion = !this.#parent) {
    const allDirectOptions = this.#getMergedOptions(includeVersion)
    // Filter out shadowed options (already handled by child commands)
    const directOptions = allDirectOptions.filter(o => !shadowed.has(o.long))
    /** @type {Record<string, unknown>} */
    const opts = {}

    // Initialize defaults for effective options only
    for (const opt of directOptions) {
      if (opt.default !== undefined) {
        opts[opt.long] = opt.default
      } else if (opt.type === 'boolean') {
        opts[opt.long] = false
      } else if (opt.type === 'string[]' || opt.type === 'number[]') {
        opts[opt.long] = []
      }
    }

    // Process resolver options first (only non-shadowed)
    let remaining = [...tokens]
    const resolverOptions = directOptions.filter(o => o.resolver)
    for (const opt of resolverOptions) {
      const result = opt.resolver(remaining)
      opts[opt.long] = result.value
      remaining = result.remaining
    }

    // Build option maps (excluding resolver options)
    const { optionByLong, optionByShort, booleanOptions } = this.#buildOptionMaps(directOptions, true)

    // Normalize --no-* to --*=false
    const normalizedTokens = this.#normalizeArgv(remaining, booleanOptions)

    /** @type {string[]} */
    const finalRemaining = []
    let i = 0
    while (i < normalizedTokens.length) {
      const token = normalizedTokens[i]

      // Long option
      if (token.startsWith('--')) {
        const consumed = this.#tryConsumeLongOption(normalizedTokens, i, optionByLong, opts)
        if (consumed > 0) {
          i += consumed
          continue
        }
        // Unknown option - pass to parent
        finalRemaining.push(token)
        i += 1
        continue
      }

      // Short option
      if (token.startsWith('-') && token.length > 1) {
        const result = this.#tryConsumeShortOption(normalizedTokens, i, optionByShort, opts)
        if (result.consumed) {
          i = result.nextIdx
          if (result.remainingToken) {
            finalRemaining.push(result.remainingToken)
          }
          continue
        }
        // Unknown option - pass to parent
        finalRemaining.push(token)
        i += 1
        continue
      }

      // Non-option token
      finalRemaining.push(token)
      i += 1
    }

    // Validate required options (only for non-shadowed options)
    for (const opt of directOptions) {
      if (opt.required && opts[opt.long] === undefined) {
        throw new CommanderError(
          'MissingRequired',
          `missing required option "--${opt.long}" for command "${this.#getCommandPath()}"`,
          this.#getCommandPath(),
        )
      }
    }

    // Validate choices (only for non-shadowed options)
    for (const opt of directOptions) {
      if (opt.choices && opts[opt.long] !== undefined) {
        const value = opts[opt.long]
        const values = Array.isArray(value) ? value : [value]
        /** @type {ReadonlyArray<unknown>} */
        const choices = opt.choices
        for (const v of values) {
          if (!choices.includes(v)) {
            throw new CommanderError(
              'InvalidChoice',
              `invalid value "${v}" for option "--${opt.long}". Allowed: ${opt.choices.join(', ')}`,
              this.#getCommandPath(),
            )
          }
        }
      }
    }

    return { opts, remaining: finalRemaining }
  }

  /**
   * Generate help text.
   * @returns {string}
   */
  formatHelp() {
    const lines = []
    const allOptions = this.#getMergedOptions()

    // Description
    lines.push(this.#description)
    lines.push('')

    // Usage line
    const commandPath = this.#getCommandPath()
    let usage = `Usage: ${commandPath}`
    if (allOptions.length > 0) usage += ' [options]'
    if (this.#subcommands.length > 0) usage += ' [command]'
    for (const arg of this.#arguments) {
      if (arg.kind === 'required') {
        usage += ` <${arg.name}>`
      } else if (arg.kind === 'optional') {
        usage += ` [${arg.name}]`
      } else {
        usage += ` [${arg.name}...]`
      }
    }
    lines.push(usage)
    lines.push('')

    // Options
    if (allOptions.length > 0) {
      lines.push('Options:')
      /** @type {Array<{ sig: string; desc: string }>} */
      const optLines = []

      for (const opt of allOptions) {
        let sig = opt.short ? `-${opt.short}, ` : '    '
        sig += `--${opt.long}`
        // type defaults to 'string' when undefined (per spec)
        const effectiveType = opt.type ?? 'string'
        if (effectiveType !== 'boolean') {
          sig += ' <value>'
        }

        let desc = opt.description
        if (opt.default !== undefined && effectiveType !== 'boolean') {
          desc += ` (default: ${JSON.stringify(opt.default)})`
        }
        if (opt.choices) {
          desc += ` [choices: ${opt.choices.join(', ')}]`
        }

        optLines.push({ sig, desc })

        // Add --no-{long} for boolean options
        if (effectiveType === 'boolean') {
          optLines.push({
            sig: `    --no-${opt.long}`,
            desc: `Negate --${opt.long}`,
          })
        }
      }

      const maxSigLen = Math.max(...optLines.map(l => l.sig.length))
      for (const { sig, desc } of optLines) {
        const padding = ' '.repeat(maxSigLen - sig.length + 2)
        lines.push(`  ${sig}${padding}${desc}`)
      }
      lines.push('')
    }

    // Commands
    const showHelpSubcommand = this.#helpSubcommandEnabled && this.#subcommands.length > 0
    if (this.#subcommands.length > 0) {
      lines.push('Commands:')
      /** @type {Array<{ name: string; desc: string }>} */
      const cmdLines = []

      // Add help subcommand if enabled and has subcommands
      if (showHelpSubcommand) {
        cmdLines.push({ name: 'help', desc: 'Show help for a command' })
      }

      for (const entry of this.#subcommands) {
        let name = entry.name
        if (entry.aliases.length > 0) {
          name += `, ${entry.aliases.join(', ')}`
        }
        cmdLines.push({ name, desc: /** @type {Command} */ (entry.command).#description })
      }
      const maxNameLen = Math.max(...cmdLines.map(l => l.name.length))
      for (const { name, desc } of cmdLines) {
        const padding = ' '.repeat(maxNameLen - name.length + 2)
        lines.push(`  ${name}${padding}${desc}`)
      }
      lines.push('')
    }

    return lines.join('\n')
  }

  // ============================================================
  // Private Methods - Routing
  // ============================================================

  /**
   * Process help subcommand.
   * @param {string[]} argv
   * @returns {string[]}
   */
  #processHelpSubcommand(argv) {
    // Only process if help subcommand is enabled
    if (!this.#helpSubcommandEnabled) return argv
    if (argv.length < 1 || argv[0] !== 'help') return argv

    // "help" alone -> show current command's help
    if (argv.length === 1 || this.#subcommands.length === 0) {
      return ['--help']
    }

    // "help <subcommand>" -> "<subcommand> --help"
    const subName = argv[1]
    const entry = this.#subcommands.find(e => e.name === subName || e.aliases.includes(subName))
    if (entry) {
      return [subName, '--help', ...argv.slice(2)]
    }

    // Unknown subcommand, let normal routing handle the error
    return argv
  }

  /**
   * Route and return the full command chain (root → leaf).
   * @param {string[]} argv
   * @returns {{ chain: Command[]; remaining: string[] }}
   */
  #routeChain(argv) {
    /** @type {Command[]} */
    const chain = [this]
    /** @type {Command} */
    let current = this
    let idx = 0

    while (idx < argv.length) {
      const token = argv[idx]

      // Stop routing on option-like token
      if (token.startsWith('-')) break

      // Try to match subcommand
      const entry = current.#subcommands.find(e => e.name === token || e.aliases.includes(token))
      if (!entry) break

      current = /** @type {Command} */ (entry.command)
      chain.push(current)
      idx += 1
    }

    return { chain, remaining: argv.slice(idx) }
  }

  /**
   * Split tokens at '--' separator.
   * Before '--': options for shift chain
   * After '--': args passed directly to action (not parsed)
   * @param {string[]} tokens
   * @returns {{ optionTokens: string[]; restArgs: string[] }}
   */
  #splitAtDoubleDash(tokens) {
    const ddIdx = tokens.indexOf('--')
    if (ddIdx === -1) {
      // No '--': all tokens are options, no positional args
      return { optionTokens: tokens, restArgs: [] }
    }

    return {
      optionTokens: tokens.slice(0, ddIdx),
      restArgs: tokens.slice(ddIdx + 1),
    }
  }

  /**
   * Shift options bottom-up through the command chain.
   * Returns a map of command → parsed options, plus any remaining positional arguments.
   * @param {Command[]} chain
   * @param {string[]} tokens
   * @param {boolean} includeRootVersion
   * @returns {{ optsMap: Map<Command, Record<string, unknown>>; positionalArgs: string[] }}
   */
  #shiftChain(chain, tokens, includeRootVersion) {
    /** @type {Map<Command, Record<string, unknown>>} */
    const optsMap = new Map()
    let remaining = [...tokens]
    const rootCommand = chain[0]

    // Build shadowed set: options defined by child commands
    // Child options shadow parent options with the same name
    /** @type {Set<string>} */
    const shadowed = new Set()

    // Process from leaf to root
    for (let i = chain.length - 1; i >= 0; i--) {
      const cmd = chain[i]
      const includeVersion = cmd === rootCommand && includeRootVersion
      const result = cmd.#shiftWithShadowed(remaining, shadowed, includeVersion)
      optsMap.set(cmd, result.opts)
      remaining = result.remaining

      // Add this command's options to shadowed set for parent commands
      for (const opt of cmd.#options) {
        shadowed.add(opt.long)
      }
    }

    // Remaining tokens: unknown options are errors, non-options are positional args
    /** @type {string[]} */
    const positionalArgs = []
    for (const token of remaining) {
      if (token.startsWith('-')) {
        const leafCommand = chain[chain.length - 1]
        if (!token.startsWith('--') && token.length > 2) {
          const flag = token[1]
          throw new CommanderError(
            'UnknownOption',
            `unknown option "-${flag}" for command "${leafCommand.#getCommandPath()}"`,
            leafCommand.#getCommandPath(),
          )
        }
        throw new CommanderError(
          'UnknownOption',
          `unknown option "${token}" for command "${leafCommand.#getCommandPath()}"`,
          leafCommand.#getCommandPath(),
        )
      }
      positionalArgs.push(token)
    }

    return { optsMap, positionalArgs }
  }

  /**
   * Apply option callbacks top-down through the command chain.
   * @param {Command[]} chain
   * @param {Map<Command, Record<string, unknown>>} optsMap
   * @param {ICommandContext} ctx
   */
  #applyChain(chain, optsMap, ctx) {
    for (const cmd of chain) {
      const opts = optsMap.get(cmd) ?? {}
      for (const opt of cmd.#getMergedOptions()) {
        if (opt.apply && opts[opt.long] !== undefined) {
          opt.apply(opts[opt.long], ctx)
        }
      }
    }
  }

  /**
   * Merge options from all commands in chain (root → leaf, later overwrites earlier).
   * @param {Command[]} chain
   * @param {Map<Command, Record<string, unknown>>} optsMap
   * @returns {Record<string, unknown>}
   */
  #mergeOpts(chain, optsMap) {
    /** @type {Record<string, unknown>} */
    const merged = {}
    for (const cmd of chain) {
      Object.assign(merged, optsMap.get(cmd) ?? {})
    }
    return merged
  }

  // ============================================================
  // Private Methods - Option Parsing
  // ============================================================

  /**
   * Parse a long option.
   * @param {string[]} argv
   * @param {number} idx
   * @param {Map<string, IOption>} optionByLong
   * @param {Record<string, unknown>} opts
   * @returns {number}
   */
  #parseLongOption(argv, idx, optionByLong, opts) {
    const token = argv[idx]
    const eqIdx = token.indexOf('=')
    /** @type {string} */
    let optName
    /** @type {string | undefined} */
    let inlineValue

    if (eqIdx !== -1) {
      optName = token.slice(2, eqIdx)
      inlineValue = token.slice(eqIdx + 1)
    } else {
      optName = token.slice(2)
    }

    const opt = optionByLong.get(optName)
    if (!opt) {
      throw new CommanderError(
        'UnknownOption',
        `unknown option "--${optName}" for command "${this.#getCommandPath()}"`,
        this.#getCommandPath(),
      )
    }

    // Boolean option
    if (opt.type === 'boolean') {
      if (inlineValue !== undefined) {
        if (inlineValue === 'true') {
          opts[optName] = true
        } else if (inlineValue === 'false') {
          opts[optName] = false
        } else {
          throw new CommanderError(
            'InvalidBooleanValue',
            `invalid value "${inlineValue}" for boolean option "--${optName}". Use "true" or "false"`,
            this.#getCommandPath(),
          )
        }
      } else {
        opts[optName] = true
      }
      return idx + 1
    }

    // Value option
    /** @type {string} */
    let value
    let nextIdx = idx
    if (inlineValue !== undefined) {
      value = inlineValue
    } else if (idx + 1 < argv.length) {
      // Long options can accept values starting with '-' (e.g., --opt -1)
      value = argv[idx + 1]
      nextIdx += 1
    } else {
      throw new CommanderError(
        'MissingValue',
        `option "--${optName}" requires a value`,
        this.#getCommandPath(),
      )
    }

    this.#applyValue(opt, value, opts)
    return nextIdx + 1
  }

  /**
   * Parse a short option.
   * @param {string[]} argv
   * @param {number} idx
   * @param {Map<string, IOption>} optionByShort
   * @param {Record<string, unknown>} opts
   * @returns {number}
   */
  #parseShortOption(argv, idx, optionByShort, opts) {
    const token = argv[idx]

    // Check for unsupported syntax: -o=value
    if (token.includes('=')) {
      throw new CommanderError(
        'UnsupportedShortSyntax',
        `"-${token.slice(1)}" is not supported. Use "-${token[1]} ${token.slice(3)}" instead`,
        this.#getCommandPath(),
      )
    }

    const flags = token.slice(1)

    for (let j = 0; j < flags.length; j++) {
      const flag = flags[j]
      const opt = optionByShort.get(flag)

      if (!opt) {
        throw new CommanderError(
          'UnknownOption',
          `unknown option "-${flag}" for command "${this.#getCommandPath()}"`,
          this.#getCommandPath(),
        )
      }

      // Boolean option
      if (opt.type === 'boolean') {
        opts[opt.long] = true
        continue
      }

      // Value option - must be last in group or followed by space-separated value
      if (j < flags.length - 1) {
        // Not the last flag - this is an error (value attached like -ovalue)
        throw new CommanderError(
          'UnsupportedShortSyntax',
          `"-${flags}" is not supported. Use "-${flags.slice(0, j + 1)} ${flags.slice(j + 1)}" or separate options`,
          this.#getCommandPath(),
        )
      }

      // Last flag, get value from next token
      if (idx + 1 < argv.length && !argv[idx + 1].startsWith('-')) {
        const value = argv[idx + 1]
        this.#applyValue(opt, value, opts)
        return idx + 2
      }

      throw new CommanderError(
        'MissingValue',
        `option "-${flag}" requires a value`,
        this.#getCommandPath(),
      )
    }

    return idx + 1
  }

  /**
   * Apply a value to an option.
   * @param {IOption} opt
   * @param {string} rawValue
   * @param {Record<string, unknown>} opts
   */
  #applyValue(opt, rawValue, opts) {
    const type = opt.type ?? 'string'

    // Apply coerce if present
    /** @type {unknown} */
    let parsedValue = rawValue
    if (opt.coerce) {
      parsedValue = opt.coerce(rawValue)
    } else {
      // Built-in parsing
      switch (type) {
        case 'string':
        case 'string[]':
          parsedValue = rawValue
          break

        case 'number':
        case 'number[]': {
          const num = Number(rawValue)
          if (Number.isNaN(num)) {
            throw new CommanderError(
              'InvalidType',
              `invalid number "${rawValue}" for option "--${opt.long}"`,
              this.#getCommandPath(),
            )
          }
          parsedValue = num
          break
        }
      }
    }

    // Handle array types (append) vs scalar types (overwrite)
    if (type === 'string[]' || type === 'number[]') {
      const currentValue = opts[opt.long]
      /** @type {unknown[]} */
      const current = Array.isArray(currentValue) ? currentValue : []
      opts[opt.long] = [...current, parsedValue]
    } else {
      opts[opt.long] = parsedValue
    }
  }

  // ============================================================
  // Private Methods - Option Merging
  // ============================================================

  /**
   * Get merged options (this command's options + builtins).
   * @param {boolean} [includeVersion]
   * @returns {IOption[]}
   */
  #getMergedOptions(includeVersion = !this.#parent) {
    // No parent inheritance - just return this command's options with builtins
    /** @type {Map<string, IOption>} */
    const optionMap = new Map()

    // Add built-in options first (can be overridden)
    const hasUserHelp = this.#options.some(o => o.long === 'help')
    const hasUserVersion = this.#options.some(o => o.long === 'version')

    if (!hasUserHelp) {
      optionMap.set('help', BUILTIN_HELP_OPTION)
    }
    if (!hasUserVersion && includeVersion) {
      optionMap.set('version', BUILTIN_VERSION_OPTION)
    }

    // Add this command's options
    for (const opt of this.#options) {
      optionMap.set(opt.long, opt)
    }

    return Array.from(optionMap.values())
  }

  /**
   * Validate merged short options for conflicts across command chain.
   * @param {Command[]} chain
   * @param {boolean} includeRootVersion
   */
  #validateMergedShortOptions(chain, includeRootVersion) {
    /** @type {Map<string, IOption>} */
    const mergedByLong = new Map()
    const rootCommand = chain[0]

    for (const cmd of chain) {
      const includeVersion = cmd === rootCommand && includeRootVersion
      for (const opt of cmd.#getMergedOptions(includeVersion)) {
        mergedByLong.set(opt.long, opt)
      }
    }

    /** @type {Map<string, string>} */
    const shortMap = new Map()
    for (const opt of mergedByLong.values()) {
      if (!opt.short) continue
      const existingLong = shortMap.get(opt.short)
      if (existingLong && existingLong !== opt.long) {
        throw new CommanderError(
          'OptionConflict',
          `short option "-${opt.short}" conflicts with "--${existingLong}"`,
          this.#getCommandPath(),
        )
      }
      shortMap.set(opt.short, opt.long)
    }
  }

  // ============================================================
  // Private Methods - Validation
  // ============================================================

  /**
   * Validate option configuration.
   * @param {IOption} opt
   */
  #validateOptionConfig(opt) {
    // Check option has long name
    if (!opt.long) {
      throw new CommanderError(
        'ConfigurationError',
        'option must have a long name',
        this.#getCommandPath(),
      )
    }

    // No no- prefix allowed
    if (opt.long.startsWith('no-')) {
      throw new CommanderError(
        'ConfigurationError',
        `option long name cannot start with "no-": "${opt.long}"`,
        this.#getCommandPath(),
      )
    }

    // required + default conflict
    if (opt.required && opt.default !== undefined) {
      throw new CommanderError(
        'ConfigurationError',
        `option "--${opt.long}" cannot be both required and have a default value`,
        this.#getCommandPath(),
      )
    }

    // boolean + required conflict
    if (opt.type === 'boolean' && opt.required) {
      throw new CommanderError(
        'ConfigurationError',
        `boolean option "--${opt.long}" cannot be required`,
        this.#getCommandPath(),
      )
    }
  }

  /**
   * Check option uniqueness.
   * @param {IOption} opt
   */
  #checkOptionUniqueness(opt) {
    // Check long uniqueness in current command
    if (this.#options.some(o => o.long === opt.long)) {
      throw new CommanderError(
        'OptionConflict',
        `option "--${opt.long}" is already defined`,
        this.#getCommandPath(),
      )
    }

    // Check short uniqueness in current command
    if (opt.short && this.#options.some(o => o.short === opt.short)) {
      throw new CommanderError(
        'OptionConflict',
        `short option "-${opt.short}" is already defined`,
        this.#getCommandPath(),
      )
    }
  }

  /**
   * Validate argument configuration.
   * @param {IArgument} arg
   */
  #validateArgumentConfig(arg) {
    // Check argument has name
    if (!arg.name) {
      throw new CommanderError(
        'ConfigurationError',
        'argument must have a name',
        this.#getCommandPath(),
      )
    }

    // Check required + default conflict
    if (arg.kind === 'required' && arg.default !== undefined) {
      throw new CommanderError(
        'ConfigurationError',
        `required argument "${arg.name}" cannot have a default value`,
        this.#getCommandPath(),
      )
    }

    // Check variadic is last and unique
    if (arg.kind === 'variadic') {
      if (this.#arguments.some(a => a.kind === 'variadic')) {
        throw new CommanderError(
          'ConfigurationError',
          'only one variadic argument is allowed',
          this.#getCommandPath(),
        )
      }
    }

    // Check variadic must be last
    if (this.#arguments.length > 0) {
      const last = this.#arguments[this.#arguments.length - 1]
      if (last.kind === 'variadic') {
        throw new CommanderError(
          'ConfigurationError',
          'variadic argument must be the last argument',
          this.#getCommandPath(),
        )
      }
    }

    // Check required before optional
    if (arg.kind === 'required') {
      const hasOptional = this.#arguments.some(a => a.kind === 'optional' || a.kind === 'variadic')
      if (hasOptional) {
        throw new CommanderError(
          'ConfigurationError',
          `required argument "${arg.name}" cannot come after optional/variadic arguments`,
          this.#getCommandPath(),
        )
      }
    }
  }

  // ============================================================
  // Private Methods - Utilities
  // ============================================================

  /**
   * Parse raw positional arguments into typed values based on argument definitions.
   * @param {string[]} rawArgs
   * @returns {{ args: Record<string, unknown>; rawArgs: string[] }}
   */
  #parseArguments(rawArgs) {
    const argumentDefs = this.#arguments
    /** @type {Record<string, unknown>} */
    const args = {}

    // 1) Required count check
    const requiredCount = argumentDefs.filter(a => a.kind === 'required').length
    if (rawArgs.length < requiredCount) {
      const missing = argumentDefs
        .filter(a => a.kind === 'required')
        .slice(rawArgs.length)
        .map(a => a.name)
      throw new CommanderError(
        'MissingRequiredArgument',
        `missing required argument(s): ${missing.join(', ')}`,
        this.#getCommandPath(),
      )
    }

    let index = 0

    // 2) Consume rawArgs in declaration order
    for (const def of argumentDefs) {
      if (def.kind === 'variadic') {
        const rest = rawArgs.slice(index)
        args[def.name] = rest.map(raw => this.#convertArgument(def, raw))
        index = rawArgs.length
        break
      }

      const raw = rawArgs[index]
      if (raw === undefined) {
        if (def.kind === 'optional') {
          args[def.name] = def.default ?? undefined
          continue
        }
        // Required arguments are already validated above
      } else {
        args[def.name] = this.#convertArgument(def, raw)
        index += 1
      }
    }

    // 3) Too many arguments check (non-variadic)
    const hasVariadic = argumentDefs.some(a => a.kind === 'variadic')
    if (!hasVariadic && index < rawArgs.length) {
      throw new CommanderError(
        'TooManyArguments',
        `too many arguments: expected ${argumentDefs.length}, got ${rawArgs.length}`,
        this.#getCommandPath(),
      )
    }

    return { args, rawArgs }
  }

  /**
   * Convert a single raw argument value based on its definition.
   * @param {IArgument} def
   * @param {string} raw
   * @returns {unknown}
   */
  #convertArgument(def, raw) {
    // Coerce takes precedence
    if (def.coerce) {
      try {
        return def.coerce(raw)
      } catch {
        throw new CommanderError(
          'InvalidType',
          `invalid value "${raw}" for argument "${def.name}"`,
          this.#getCommandPath(),
        )
      }
    }

    // No coerce: use built-in type conversion
    if (def.type === 'number') {
      const n = Number(raw)
      if (Number.isNaN(n)) {
        throw new CommanderError(
          'InvalidType',
          `invalid number "${raw}" for argument "${def.name}"`,
          this.#getCommandPath(),
        )
      }
      return n
    }

    return raw // Default: string
  }

  /**
   * Build option maps.
   * @param {IOption[]} allOptions
   * @param {boolean} [excludeResolver=false]
   * @returns {{ optionByLong: Map<string, IOption>; optionByShort: Map<string, IOption>; booleanOptions: Set<string> }}
   */
  #buildOptionMaps(allOptions, excludeResolver = false) {
    /** @type {Map<string, IOption>} */
    const optionByLong = new Map()
    /** @type {Map<string, IOption>} */
    const optionByShort = new Map()
    /** @type {Set<string>} */
    const booleanOptions = new Set()

    for (const opt of allOptions) {
      if (excludeResolver && opt.resolver) continue

      optionByLong.set(opt.long, opt)
      if (opt.short) {
        optionByShort.set(opt.short, opt)
      }
      if (opt.type === 'boolean') {
        booleanOptions.add(opt.long)
      }
    }

    return { optionByLong, optionByShort, booleanOptions }
  }

  /**
   * Check if argv contains --help or -h.
   * @param {string[]} argv
   * @param {IOption[]} allOptions
   * @returns {boolean}
   */
  #hasHelpFlag(argv, allOptions) {
    return this.#hasBuiltinFlag(argv, 'help', 'h', allOptions)
  }

  /**
   * Check if argv contains --version or -V.
   * @param {string[]} argv
   * @param {IOption[]} allOptions
   * @returns {boolean}
   */
  #hasVersionFlag(argv, allOptions) {
    return this.#hasBuiltinFlag(argv, 'version', 'V', allOptions)
  }

  /**
   * Check if argv contains a builtin flag.
   * @param {string[]} argv
   * @param {string} flagLong
   * @param {string | undefined} flagShort
   * @param {IOption[]} allOptions
   * @returns {boolean}
   */
  #hasBuiltinFlag(argv, flagLong, flagShort, allOptions) {
    const { optionByLong, optionByShort, booleanOptions } = this.#buildOptionMaps(allOptions)
    const normalizedArgv = this.#normalizeArgv(argv, booleanOptions)

    for (let i = 0; i < normalizedArgv.length; i++) {
      const arg = normalizedArgv[i]
      if (arg === '--') {
        break
      }

      if (arg === `--${flagLong}` || (flagShort && arg === `-${flagShort}`)) {
        return true
      }

      if (this.#optionConsumesNextValue(arg, optionByLong, optionByShort)) {
        i += 1
      }
    }

    return false
  }

  /**
   * Check if an option consumes the next value.
   * @param {string} arg
   * @param {Map<string, IOption>} optionByLong
   * @param {Map<string, IOption>} optionByShort
   * @returns {boolean}
   */
  #optionConsumesNextValue(arg, optionByLong, optionByShort) {
    if (arg.startsWith('--')) {
      const eqIdx = arg.indexOf('=')
      if (eqIdx !== -1) {
        return false
      }

      const optName = arg.slice(2)
      const opt = optionByLong.get(optName)
      if (!opt) {
        return false
      }

      const type = opt.type ?? 'string'
      return type !== 'boolean'
    }

    if (arg.startsWith('-') && arg.length === 2) {
      const opt = optionByShort.get(arg[1])
      if (!opt) {
        return false
      }

      const type = opt.type ?? 'string'
      return type !== 'boolean'
    }

    return false
  }

  /**
   * Normalize argv (expand --no-* to --*=false for boolean options).
   * @param {string[]} argv
   * @param {Set<string>} booleanOptions
   * @returns {string[]}
   */
  #normalizeArgv(argv, booleanOptions) {
    /** @type {string[]} */
    const result = []
    let seenDoubleDash = false

    for (const arg of argv) {
      if (arg === '--') {
        seenDoubleDash = true
        result.push(arg)
        continue
      }

      if (!seenDoubleDash && arg.startsWith('--no-')) {
        const eqIdx = arg.indexOf('=')
        if (eqIdx !== -1) {
          // --no-foo=value: check if it's a boolean option and throw error
          const optName = arg.slice(5, eqIdx)
          if (booleanOptions.has(optName)) {
            throw new CommanderError(
              'InvalidBooleanValue',
              `"--no-${optName}" does not accept a value`,
              this.#getCommandPath(),
            )
          }
        } else {
          // --no-foo: normalize to --foo=false if it's a boolean option
          const optName = arg.slice(5)
          if (booleanOptions.has(optName)) {
            result.push(`--${optName}=false`)
            continue
          }
        }
      }

      result.push(arg)
    }

    return result
  }

  /**
   * Get command path for error messages.
   * @returns {string}
   */
  #getCommandPath() {
    /** @type {string[]} */
    const parts = []
    /** @type {Command | undefined} */
    let current = this
    while (current) {
      if (current.#name) {
        parts.unshift(current.#name)
      }
      current = current.#parent
    }
    return parts.join(' ') || this.#name
  }

  /**
   * Try to consume a long option token.
   * Returns the number of tokens consumed (0 if not recognized).
   * @param {string[]} tokens
   * @param {number} idx
   * @param {Map<string, IOption>} optionByLong
   * @param {Record<string, unknown>} opts
   * @returns {number}
   */
  #tryConsumeLongOption(tokens, idx, optionByLong, opts) {
    const token = tokens[idx]
    const eqIdx = token.indexOf('=')
    /** @type {string} */
    let optName
    /** @type {string | undefined} */
    let inlineValue

    if (eqIdx !== -1) {
      optName = token.slice(2, eqIdx)
      inlineValue = token.slice(eqIdx + 1)
    } else {
      optName = token.slice(2)
    }

    const opt = optionByLong.get(optName)
    if (!opt) {
      return 0 // Not recognized
    }

    // Boolean option
    if (opt.type === 'boolean') {
      if (inlineValue !== undefined) {
        if (inlineValue === 'true') {
          opts[optName] = true
        } else if (inlineValue === 'false') {
          opts[optName] = false
        } else {
          throw new CommanderError(
            'InvalidBooleanValue',
            `invalid value "${inlineValue}" for boolean option "--${optName}". Use "true" or "false"`,
            this.#getCommandPath(),
          )
        }
      } else {
        opts[optName] = true
      }
      return 1
    }

    // Value option
    /** @type {string} */
    let value
    let consumed = 1
    if (inlineValue !== undefined) {
      value = inlineValue
    } else if (idx + 1 < tokens.length) {
      value = tokens[idx + 1]
      consumed = 2
    } else {
      throw new CommanderError(
        'MissingValue',
        `option "--${optName}" requires a value`,
        this.#getCommandPath(),
      )
    }

    this.#applyValue(opt, value, opts)
    return consumed
  }

  /**
   * Try to consume a short option token.
   * Returns consumption info including any remaining portion to pass to parent.
   * @param {string[]} tokens
   * @param {number} idx
   * @param {Map<string, IOption>} optionByShort
   * @param {Record<string, unknown>} opts
   * @returns {{ consumed: boolean; nextIdx: number; remainingToken?: string }}
   */
  #tryConsumeShortOption(tokens, idx, optionByShort, opts) {
    const token = tokens[idx]

    // Check for unsupported syntax: -o=value
    if (token.includes('=')) {
      // If we don't recognize the first flag, pass it to parent
      const firstFlag = token[1]
      if (!optionByShort.has(firstFlag)) {
        return { consumed: false, nextIdx: idx + 1 }
      }
      throw new CommanderError(
        'UnsupportedShortSyntax',
        `"-${token.slice(1)}" is not supported. Use "-${token[1]} ${token.slice(3)}" instead`,
        this.#getCommandPath(),
      )
    }

    const flags = token.slice(1)
    let j = 0
    /** @type {string[]} */
    const consumedFlags = []
    /** @type {string[]} */
    const unconsumedFlags = []
    let nextIdx = idx + 1

    while (j < flags.length) {
      const flag = flags[j]
      const opt = optionByShort.get(flag)

      if (!opt) {
        // Unknown flag - collect remaining flags for parent
        unconsumedFlags.push(...flags.slice(j).split(''))
        break
      }

      consumedFlags.push(flag)

      // Boolean option
      if (opt.type === 'boolean') {
        opts[opt.long] = true
        j += 1
        continue
      }

      // Value option - must be last in group
      if (j < flags.length - 1) {
        // Not the last flag - this is an error
        throw new CommanderError(
          'UnsupportedShortSyntax',
          `"-${flags}" is not supported. Use "-${flags.slice(0, j + 1)} ${flags.slice(j + 1)}" or separate options`,
          this.#getCommandPath(),
        )
      }

      // Last flag, get value from next token
      if (idx + 1 < tokens.length && !tokens[idx + 1].startsWith('-')) {
        const value = tokens[idx + 1]
        this.#applyValue(opt, value, opts)
        nextIdx = idx + 2
      } else {
        throw new CommanderError(
          'MissingValue',
          `option "-${flag}" requires a value`,
          this.#getCommandPath(),
        )
      }

      j += 1
    }

    // If we consumed some flags, report success
    if (consumedFlags.length > 0) {
      const remainingToken = unconsumedFlags.length > 0 ? `-${unconsumedFlags.join('')}` : undefined
      return { consumed: true, nextIdx, remainingToken }
    }

    return { consumed: false, nextIdx: idx + 1 }
  }
}
