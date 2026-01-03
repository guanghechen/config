export type IMutable<T> = {
  -readonly [K in keyof T]: T[K]
}
