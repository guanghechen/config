type AnyFunction = (this: any, ...args: any[]) => any

export interface IDebounceOptions {
  readonly leading?: boolean
  readonly trailing?: boolean
}

export interface IDebouncedFunction<T extends AnyFunction> {
  (this: ThisParameterType<T>, ...args: Parameters<T>): ReturnType<T> | undefined
  cancel(): void
  flush(): ReturnType<T> | undefined
}

export default function debounce<T extends AnyFunction>(
  func: T,
  wait: number = 0,
  options: IDebounceOptions = {},
): IDebouncedFunction<T> {
  const delay = Number.isFinite(wait) && wait > 0 ? wait : 0
  const leading = options.leading ?? false
  const trailing = options.trailing ?? true

  let lastArgs: Parameters<T> | undefined
  let lastCallTime: number | undefined
  let lastThis: ThisParameterType<T> | undefined
  let result: ReturnType<T> | undefined
  let timer: ReturnType<typeof setTimeout> | undefined

  const invoke = (): ReturnType<T> => {
    const args = lastArgs!
    const thisArg = lastThis
    lastArgs = undefined
    lastThis = undefined
    const value = Reflect.apply(func, thisArg, args) as ReturnType<T>
    result = value
    return value
  }

  const finish = (): ReturnType<T> | undefined => {
    timer = undefined
    if (trailing && lastArgs) return invoke()
    lastArgs = undefined
    lastThis = undefined
    return result
  }

  const shouldInvoke = (time: number): boolean => {
    if (lastCallTime === undefined) return true
    const elapsed = time - lastCallTime
    return elapsed >= delay || elapsed < 0
  }

  const onTimer = (): void => {
    const time = Date.now()
    if (shouldInvoke(time)) {
      finish()
      return
    }
    timer = setTimeout(onTimer, delay - (time - lastCallTime!))
  }

  const debounced = function (
    this: ThisParameterType<T>,
    ...args: Parameters<T>
  ): ReturnType<T> | undefined {
    const time = Date.now()
    const invokeNow = shouldInvoke(time)
    lastArgs = args
    // Preserve the caller receiver until the deferred invocation.
    // eslint-disable-next-line @typescript-eslint/no-this-alias
    lastThis = this
    lastCallTime = time

    if (invokeNow && timer === undefined) {
      timer = setTimeout(onTimer, delay)
      return leading ? invoke() : result
    }
    if (timer === undefined) timer = setTimeout(onTimer, delay)
    return result
  } as IDebouncedFunction<T>

  debounced.cancel = (): void => {
    if (timer !== undefined) clearTimeout(timer)
    lastArgs = undefined
    lastCallTime = undefined
    lastThis = undefined
    timer = undefined
  }
  debounced.flush = (): ReturnType<T> | undefined => {
    if (timer === undefined) return result
    clearTimeout(timer)
    return finish()
  }
  return debounced
}
