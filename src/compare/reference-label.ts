const RESOLVED_COMMIT_PATTERN = /^[0-9a-f]{40,64}$/i

export function formatReferenceLabel(value: string): string {
  if (RESOLVED_COMMIT_PATTERN.test(value)) return value.slice(0, 9)
  return value.length > 24 ? `${value.slice(0, 21)}…` : value
}
