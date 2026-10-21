// Statistics shared by the benchmark reports.

/** Median of `values`; undefined when empty. */
export function median(values) {
  if (!values.length) return undefined
  const sorted = [...values].sort((a, b) => a - b), middle = Math.floor(sorted.length / 2)
  return sorted.length % 2 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2
}

/** Nearest-rank percentile: the smallest value with at least `fraction` of the values at or below it. */
export function percentile(values, fraction) {
  if (!values.length) return undefined
  const sorted = [...values].sort((a, b) => a - b)
  return sorted[Math.min(sorted.length, Math.max(1, Math.ceil(sorted.length * fraction))) - 1]
}

/** Coefficient of variation (sample standard deviation over mean); undefined below two values. */
export function variation(values) {
  if (values.length < 2) return undefined
  const mean = values.reduce((sum, value) => sum + value, 0) / values.length
  if (mean === 0) return 0
  const deviation = Math.sqrt(values.reduce((sum, value) => sum + (value - mean) ** 2, 0) / (values.length - 1))
  return deviation / mean
}

/** Fewer values than this leave p95 unreported: it would only restate the largest values. */
export const P95_MIN_COUNT = 20

/** Count, median, nearest-rank p95 (null below P95_MIN_COUNT), min and max of `values`; undefined when empty. */
export function summary(values) {
  if (!values.length) return undefined
  const sorted = [...values].sort((a, b) => a - b)
  return {
    n: sorted.length,
    median: median(sorted),
    p95: sorted.length >= P95_MIN_COUNT ? percentile(sorted, 0.95) : null,
    min: sorted[0],
    max: sorted[sorted.length - 1],
  }
}
