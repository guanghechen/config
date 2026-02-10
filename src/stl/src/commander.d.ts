/**
 * A minimal, type-safe command-line interface builder with fluent API.
 *
 * @module @guanghechen/stl/commander
 */

import type { IReporter } from './reporter.d.ts'

export type { IReporter }

// ============================================================
// Option Types
// ============================================================

/** Supported option types */
export type IOptionType = 'boolean' | 'string' | 'number' | 'string[]' | 'number[]'

/** Execution context */
export interface ICommandContext {
  /** Current command node */
  cmd: ICommand
  /** Environment variables passed in */
  envs: Record<string, string | undefined>
  /** Reporter instance */
  reporter: IReporter
  /** Original argv */
  argv: string[]
}

/**
 * Option definition.
 * @template T - The type of the option value
 */
export interface IOption<T = unknown> {
  /** Long option (e.g., 'verbose' for --verbose), also used as merge key */
  long: string
  /** Short option (single character, e.g., 'v' for -v) */
  short?: string
  /** Value type, defaults to 'string' */
  type?: IOptionType
  /** Description for help text */
  description: string
  /** Whether this option is required (cannot be used with default or boolean type) */
  required?: boolean
  /** Default value when not provided */
  default?: T
  /** Allowed values for validation and completion */
  choices?: T extends Array<infer U> ? U[] : T[]
  /** Single value transformation (ignored when resolver is present) */
  coerce?: (rawValue: string) => T extends Array<infer U> ? U : T
  /** Custom resolver that fully replaces builtin parsing (ignores type/coerce) */
  resolver?: (argv: string[]) => { value: T; remaining: string[] }
  /** Callback after parsing, applies value to context */
  apply?: (value: T, ctx: ICommandContext) => void
}

// ============================================================
// Argument Types
// ============================================================

/** Argument kind */
export type IArgumentKind = 'required' | 'optional' | 'variadic'

/** Argument value type */
export type IArgumentType = 'string' | 'number'

/**
 * Positional argument definition.
 * @template T - The type of the argument value
 */
export interface IArgument<T = unknown> {
  /** Argument name */
  name: string
  /** Argument description */
  description: string
  /** Argument kind: required / optional / variadic */
  kind: IArgumentKind
  /** Value type, defaults to 'string' */
  type?: IArgumentType
  /** Default value when not provided (only effective for optional arguments) */
  default?: T
  /** Custom value transformation (takes precedence over type conversion) */
  coerce?: (rawValue: string) => T
}

// ============================================================
// Command Configuration
// ============================================================

/** Command configuration */
export interface ICommandConfig {
  /** Command name (only effective for root command) */
  name?: string
  /** Command description */
  description: string
  /** Version (only effective for root command) */
  version?: string
  /** Enable built-in "help" subcommand (only effective when command has subcommands) */
  help?: boolean
}

// ============================================================
// Forward Declaration
// ============================================================

/** Forward declaration for Command class */
export interface ICommand {
  readonly name: string
  readonly description: string
  readonly version: string | undefined
  readonly options: IOption[]
  readonly arguments: IArgument[]
}

// ============================================================
// Subcommand Types
// ============================================================

/** Subcommand registration entry */
export interface ISubcommandEntry {
  /** Subcommand name */
  name: string
  /** Alias names */
  aliases: string[]
  /** Subcommand instance */
  command: ICommand
}

// ============================================================
// Action Types
// ============================================================

/** Action parameters */
export interface IActionParams {
  /** Execution context */
  ctx: ICommandContext
  /** Parsed options */
  opts: Record<string, unknown>
  /** Parsed positional arguments (keyed by argument name) */
  args: Record<string, unknown>
  /** Raw positional argument strings (before type conversion) */
  rawArgs: string[]
}

/** Action handler function */
export type IAction = (params: IActionParams) => void | Promise<void>

// ============================================================
// Run Parameters
// ============================================================

/** run() method parameters */
export interface IRunParams {
  /** Command line arguments (usually process.argv.slice(2)) */
  argv: string[]
  /** Environment variables (usually process.env) */
  envs: Record<string, string | undefined>
  /** Optional reporter for logging (defaults to console reporter) */
  reporter?: IReporter
}

// ============================================================
// Parse Result
// ============================================================

/** parse() method result */
export interface IParseResult {
  /** Parsed options */
  opts: Record<string, unknown>
  /** Parsed positional arguments (keyed by argument name) */
  args: Record<string, unknown>
  /** Raw positional argument strings (before type conversion) */
  rawArgs: string[]
}

/** shift() method result */
export interface IShiftResult {
  /** Options consumed by this command */
  opts: Record<string, unknown>
  /** Tokens not consumed, to be passed to parent */
  remaining: string[]
}

// ============================================================
// Error Types
// ============================================================

/** Error kinds for command parsing */
export type ICommanderErrorKind =
  | 'UnknownOption'
  | 'UnexpectedArgument'
  | 'MissingValue'
  | 'InvalidType'
  | 'UnsupportedShortSyntax'
  | 'OptionConflict'
  | 'MissingRequired'
  | 'InvalidChoice'
  | 'InvalidBooleanValue'
  | 'MissingRequiredArgument'
  | 'TooManyArguments'
  | 'ConfigurationError'

/** Commander error with structured information */
export class CommanderError extends Error {
  /** Error kind */
  readonly kind: ICommanderErrorKind
  /** Command path (e.g., 'cli subcmd') */
  readonly commandPath: string

  constructor(kind: ICommanderErrorKind, message: string, commandPath: string)

  /** Format error with help hint */
  format(): string
}

// ============================================================
// Default Reporter
// ============================================================

/** Default reporter implementation */
export class DefaultReporter implements IReporter {
  debug(message: string, ...args: unknown[]): void
  info(message: string, ...args: unknown[]): void
  warn(message: string, ...args: unknown[]): void
  error(message: string, ...args: unknown[]): void
}

// ============================================================
// Command Class
// ============================================================

/** CLI command builder */
export class Command implements ICommand {
  /** Command name */
  readonly name: string
  /** Command description */
  readonly description: string
  /** Command version */
  readonly version: string | undefined
  /** Defined options (excluding builtins) */
  readonly options: IOption[]
  /** Defined arguments */
  readonly arguments: IArgument[]

  /**
   * Create a new Command instance.
   * @param config - Command configuration
   */
  constructor(config: ICommandConfig)

  // ============================================================
  // Definition Methods
  // ============================================================

  /**
   * Add an option.
   * @param opt - Option configuration
   * @returns this for chaining
   */
  option(opt: IOption): this

  /**
   * Add a positional argument.
   * @param arg - Argument configuration
   * @returns this for chaining
   */
  argument(arg: IArgument): this

  /**
   * Set the action handler.
   * @param fn - Action handler function
   * @returns this for chaining
   */
  action(fn: IAction): this

  // ============================================================
  // Assembly Methods
  // ============================================================

  /**
   * Register a subcommand.
   * When the same command is registered multiple times, subsequent names become aliases.
   * @param name - Subcommand name
   * @param cmd - Subcommand instance
   * @returns this for chaining
   */
  subcommand(name: string, cmd: Command): this

  // ============================================================
  // Execution Methods
  // ============================================================

  /**
   * Parse argv and execute action.
   * @param params - Run parameters
   */
  run(params: IRunParams): Promise<void>

  /**
   * Parse argv without executing action.
   * @param argv - Command line arguments
   * @returns Parse result
   * @throws {CommanderError} on parsing errors
   */
  parse(argv: string[]): IParseResult

  /**
   * Shift options from tokens that this command recognizes.
   * Unrecognized tokens are returned in `remaining` for parent commands.
   * @param tokens - Option tokens to process
   * @returns Shift result with consumed options and remaining tokens
   */
  shift(tokens: string[]): IShiftResult

  /**
   * Generate help text.
   * @returns Formatted help text
   */
  formatHelp(): string
}
