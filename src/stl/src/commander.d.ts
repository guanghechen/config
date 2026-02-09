/**
 * A minimal, type-safe command-line interface builder with fluent API.
 *
 * @module @guanghechen/stl/commander
 */

// ============================================================
// Reporter Interface
// ============================================================

/** Reporter interface for logging */
export interface IReporter {
  debug(message: string, ...args: unknown[]): void
  info(message: string, ...args: unknown[]): void
  warn(message: string, ...args: unknown[]): void
  error(message: string, ...args: unknown[]): void
}

// ============================================================
// Option Types
// ============================================================

/** Supported option types */
export type IOptionType = 'boolean' | 'string' | 'number' | 'string[]' | 'number[]'

/** Option value types */
export type IOptionValue = boolean | string | number | string[] | number[]

/** Option definition (object configuration) */
export interface IOption<T extends IOptionType = IOptionType> {
  /** Long option name without -- prefix (e.g., 'config', 'dry-run') */
  long: string
  /** Short option name without - prefix (e.g., 'c', 'n'). Optional. */
  short?: string
  /** Option type */
  type: T
  /** Option description */
  description?: string
  /** Default value */
  default?: T extends 'boolean'
    ? boolean
    : T extends 'string'
      ? string
      : T extends 'number'
        ? number
        : T extends 'string[]'
          ? string[]
          : T extends 'number[]'
            ? number[]
            : never
  /** Environment variable name to read value from */
  env?: string
}

// ============================================================
// Argument Types
// ============================================================

/** Argument kind */
export type IArgumentKind = 'required' | 'optional' | 'variadic'

/** Argument value types */
export type IArgumentValue = string | string[] | undefined

/** Argument definition (object configuration) */
export interface IArgument {
  /** Argument name */
  name: string
  /** Argument kind */
  kind: IArgumentKind
  /** Argument description */
  description?: string
  /** Default value (only for optional arguments) */
  default?: string
}

// ============================================================
// Command Configuration
// ============================================================

/** Command configuration */
export interface ICommandConfig {
  /** Command name */
  name: string
  /** Command description */
  description?: string
  /** Command version (enables --version option) */
  version?: string
  /** Enable help subcommand (default: false) */
  helpSubcommand?: boolean
}

// ============================================================
// Subcommand Types
// ============================================================

/** Subcommand entry */
export interface ISubcommandEntry {
  /** Subcommand name */
  name: string
  /** Subcommand instance */
  command: Command
}

// ============================================================
// Action Types
// ============================================================

/** Action parameters */
export interface IActionParams {
  /** Command context */
  ctx: Command
  /** Parsed options */
  opts: Record<string, IOptionValue>
  /** Parsed positional arguments */
  args: Record<string, IArgumentValue>
}

/** Action handler function */
export type IAction = (params: IActionParams) => Promise<void>

// ============================================================
// Run Parameters
// ============================================================

/** Run parameters */
export interface IRunParams {
  /** Command line arguments */
  argv: string[]
  /** Environment variables */
  envs: Record<string, string | undefined>
  /** Optional reporter (uses DefaultReporter if not provided) */
  reporter?: IReporter
}

// ============================================================
// Parse Result
// ============================================================

/** Result of parsing argv */
export interface IParseResult {
  /** Parsed positional arguments */
  args: Record<string, IArgumentValue>
  /** Parsed options */
  opts: Record<string, IOptionValue>
  /** Remaining arguments after subcommand routing */
  remaining: string[]
  /** Matched subcommand name (if any) */
  subcommand?: string
}

// ============================================================
// Error Types
// ============================================================

/** Commander error kinds */
export type ICommanderErrorKind =
  | 'unknown_option'
  | 'missing_option_value'
  | 'invalid_option_value'
  | 'missing_argument'
  | 'unknown_subcommand'
  | 'validation_error'

/** Commander error class */
export class CommanderError extends Error {
  /** Error kind */
  readonly kind: ICommanderErrorKind
  /** Command path (e.g., 'cli subcmd') */
  readonly commandPath: string

  constructor(kind: ICommanderErrorKind, message: string, commandPath: string)

  /** Format error message with hint */
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
export class Command {
  /** Command name */
  readonly name: string
  /** Command description */
  readonly description: string | undefined
  /** Command version */
  readonly version: string | undefined
  /** Defined options (excluding builtins) */
  readonly options: ReadonlyArray<IOption>
  /** Defined arguments */
  readonly arguments: ReadonlyArray<IArgument>

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
  option<T extends IOptionType>(opt: IOption<T>): this

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
   * @param name - Subcommand name
   * @param cmd - Subcommand instance
   * @returns this for chaining
   */
  subcommand(name: string, cmd: Command): this

  // ============================================================
  // Execution Methods
  // ============================================================

  /**
   * Parse argv and execute action. Sets process.exitCode = 1 on error.
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
   * Generate help text.
   * @returns Formatted help text
   */
  formatHelp(): string
}
