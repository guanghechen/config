/**
 * A minimal, type-safe command-line interface builder with fluent API.
 *
 * @module @guanghechen/stl/commander
 */

/** Option value types */
export type ICommanderOptionValue = boolean | string | number | string[] | number[]

/** Argument value types */
export type ICommanderArgumentValue = string | string[] | undefined

/** Supported option types */
export type ICommanderOptionType = 'boolean' | 'string' | 'number' | 'string[]' | 'number[]'

/** Log level types */
export type ICommanderLogLevel = 'debug' | 'info' | 'warn' | 'error'

/** Option configuration */
export interface ICommanderOptionConfig {
  /** Option type (inferred from flags if not specified) */
  type?: ICommanderOptionType
  /** Default value */
  default?: ICommanderOptionValue
  /** Environment variable name */
  env?: string
}

/** Diagnostic message from parsing */
export interface ICommanderDiagnostic {
  /** Diagnostic severity */
  type: 'warn' | 'error'
  /** Diagnostic message */
  message: string
}

/** Result of parsing argv */
export interface ICommanderParseResult {
  /** Parsed positional arguments */
  args: Record<string, ICommanderArgumentValue>
  /** Parsed options */
  opts: Record<string, ICommanderOptionValue>
  /** Environment variables passed to parse */
  envs: Record<string, string>
  /** Parsing diagnostics */
  diagnostics: ICommanderDiagnostic[]
}

/** Parameters passed to action handler */
export interface ICommanderExecuteParams {
  /** Command context */
  ctx: Command
  /** Parsed positional arguments */
  args: Record<string, ICommanderArgumentValue>
  /** Parsed options */
  opts: Record<string, ICommanderOptionValue>
  /** Environment variables */
  envs: Record<string, string>
}

/** Action handler function */
export type ICommanderActionHandler = (params: ICommanderExecuteParams) => Promise<void>

/** CLI command builder */
export class Command {
  /** Command name */
  readonly name: string

  /** Reporter instance */
  readonly reporter: import('./reporter.d.ts').Reporter

  /**
   * Create a new Command instance.
   * @param name - Command name
   * @param reporter - Reporter instance for logging
   */
  constructor(name: string, reporter: import('./reporter.d.ts').Reporter)

  /**
   * Set the action handler.
   * @param handler - Action handler function
   * @returns this for chaining
   */
  action(handler: ICommanderActionHandler): this

  /**
   * Add a positional argument.
   * @param spec - Argument spec (e.g., '<file>', '[file]', '<...files>')
   * @param description - Argument description
   * @returns this for chaining
   */
  argument(spec: string, description?: string): this

  /**
   * Set command description.
   * @param text - Description text
   * @returns this for chaining
   */
  description(text: string): this

  /**
   * Add a usage example.
   * @param text - Example text
   * @returns this for chaining
   */
  example(text: string): this

  /**
   * Execute the action handler.
   * @param params - Execute parameters
   */
  execute(params: ICommanderExecuteParams): Promise<void>

  /**
   * Add an option.
   * @param flags - Option flags (e.g., '-f, --force', '--name <name>')
   * @param description - Option description
   * @param config - Option configuration
   * @returns this for chaining
   */
  option(flags: string, description?: string, config?: ICommanderOptionConfig): this

  /**
   * Parse argv and envs, return parse result with diagnostics.
   * @param argv - Command line arguments
   * @param envs - Environment variables
   * @returns Parse result
   */
  parse(argv: string[], envs: Record<string, string>): ICommanderParseResult

  /**
   * Parse + execute. Sets process.exitCode = 1 on error.
   * @param argv - Command line arguments
   * @param envs - Environment variables
   */
  run(argv: string[], envs: Record<string, string>): Promise<void>

  /**
   * Print help message.
   */
  showHelp(): void

  /**
   * Enable/disable strict mode.
   * @param enabled - Whether to enable strict mode (default: true)
   * @returns this for chaining
   */
  strict(enabled?: boolean): this

  /**
   * Set command version (adds --version option).
   * @param ver - Version string
   * @returns this for chaining
   */
  version(ver: string): this
}
