/**
 * A minimal .env parser with typed value support and variable interpolation.
 *
 * @module @guanghechen/stl/env
 */

/** Primitive value types supported in .env files */
export type IEnvPrimitive = string | number | boolean | null

/** Record of environment variables with typed values */
export type IEnvRecord = Record<string, IEnvPrimitive>

/** Options for stringify */
export interface IStringifyEnvOptions {
  /** Keys to exclude from output */
  exclude?: string[]
}

/**
 * Parse .env content string into an object.
 * Supports comments, export prefix, quoted values, type coercion, and variable interpolation.
 * Returns a new object; does not mutate the input.
 * @param content - .env file content
 * @param env - Optional base object to merge (not mutated)
 * @returns New parsed environment record
 */
export function parse(content: string, env?: IEnvRecord | null): IEnvRecord

/**
 * Convert environment record to .env format string.
 * Values containing spaces, quotes, or newlines are double-quoted.
 * @param env - Environment record to stringify
 * @param options - Stringify options
 * @returns .env format string
 */
export function stringify(env: IEnvRecord, options?: IStringifyEnvOptions): string
