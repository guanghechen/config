export function isAbortError(cause: unknown): boolean {
  if (!(cause instanceof Error)) return false
  const code = 'code' in cause ? cause.code : undefined
  return cause.name === 'AbortError' || code === 'ABORT_ERR'
}
