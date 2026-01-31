/**
 * A minimal, level-based logging utility with colored output and breadcrumb prefix support.
 *
 * @module @guanghechen/stl/reporter
 */

/** Log level types */
export type IReporterLevel = 'debug' | 'info' | 'warn' | 'error'

/** Custom output function signature */
export type IReporterOutput = (level: IReporterLevel, parts: string[], args: unknown[]) => void

/** Flight options for output control */
export interface IReporterFlight {
  /** Include ISO timestamp in output (default: true) */
  date?: boolean
  /** Use ANSI color codes (default: true) */
  color?: boolean
}

/** Constructor options */
export interface IReporterProps {
  /** Initial prefix, cannot contain ':' (e.g., 'app') */
  prefix?: string
  /** Minimum log level (default: 'info') */
  level?: IReporterLevel
  /** Output control options */
  flight?: IReporterFlight
  /** Custom output function (default: console) */
  output?: IReporterOutput
}

/** Log entry captured in mock mode */
export interface IReporterEntry {
  level: IReporterLevel
  prefixes: string[]
  args: unknown[]
  date: Date
}

/** Colored console logger with breadcrumb prefix support */
export class Reporter {
  /**
   * Create a new Reporter instance.
   * @param props - Configuration options
   * @throws Error if prefix contains ':'
   */
  constructor(props?: IReporterProps)

  /**
   * Push prefix to breadcrumb stack.
   * @param prefix - Prefix to append (cannot contain ':')
   * @returns this for chaining
   * @throws Error if prefix contains ':'
   */
  attach(prefix: string): this

  /**
   * Pop prefix from breadcrumb stack.
   * Initial prefix (from constructor) is protected and cannot be removed.
   * @returns this for chaining
   */
  detach(): this

  /**
   * Enable mock mode. Logs are captured instead of printed.
   * @returns this for chaining
   */
  mock(): this

  /**
   * Disable mock mode and return captured logs.
   * @returns Array of captured log entries
   */
  collect(): IReporterEntry[]

  /**
   * Core logging method.
   * Invalid level falls back to constructor's default level.
   * @param level - Log level
   * @param args - Arguments to log (functions are called lazily)
   */
  log(level: IReporterLevel, ...args: unknown[]): void

  /**
   * Log at debug level (console.debug).
   * @param args - Arguments to log (functions are called lazily)
   */
  debug(...args: unknown[]): void

  /**
   * Log at info level (console.log).
   * @param args - Arguments to log (functions are called lazily)
   */
  info(...args: unknown[]): void

  /**
   * Log at warn level (console.warn).
   * @param args - Arguments to log (functions are called lazily)
   */
  warn(...args: unknown[]): void

  /**
   * Log at error level (console.error).
   * @param args - Arguments to log (functions are called lazily)
   */
  error(...args: unknown[]): void
}
