type AnyFunction = (this: any, ...args: any[]) => any

export interface IThrottleOptions {
  readonly leading?: boolean
  readonly trailing?: boolean
}

export interface IThrottledFunction<T extends AnyFunction> {
  (this: ThisParameterType<T>, ...args: Parameters<T>): ReturnType<T> | undefined
  cancel(): void
  flush(): ReturnType<T> | undefined
}

/**
 * Limit execution to one call per interval, retaining the latest trailing arguments.
 * flush() invokes pending work early and starts a new interval; cancel() resets it.
 */
export default function throttle<T extends AnyFunction>(
  func: T,
  wait: number = 0,
  options: IThrottleOptions = {},
): IThrottledFunction<T> {
  const delay = Number.isFinite(wait) && wait > 0 ? wait : 0
  const leading = options.leading ?? true
  const trailing = options.trailing ?? true

  let lastArgs: Parameters<T> | undefined
  let lastCallTime: number | undefined
  let lastInvokeTime = 0
  let lastThis: ThisParameterType<T> | undefined
  let result: ReturnType<T> | undefined
  let timer: ReturnType<typeof setTimeout> | undefined

  const invoke = (time: number): ReturnType<T> => {
    const args = lastArgs!
    const thisArg = lastThis
    lastArgs = undefined
    lastThis = undefined
    lastInvokeTime = time
    const value = Reflect.apply(func, thisArg, args) as ReturnType<T>
    result = value
    return value
  }

  const finish = (time: number): ReturnType<T> | undefined => {
    timer = undefined
    if (trailing && lastArgs) return invoke(time)
    lastArgs = undefined
    lastThis = undefined
    return result
  }

  const shouldInvoke = (time: number): boolean => {
    if (lastCallTime === undefined) return true
    const sinceLastCall = time - lastCallTime
    const sinceLastInvoke = time - lastInvokeTime
    return sinceLastCall < 0 || sinceLastInvoke >= delay
  }

  const remainingWait = (time: number): number => {
    return delay - (time - lastInvokeTime)
  }

  const onTimer = (): void => {
    const time = Date.now()
    if (shouldInvoke(time)) {
      finish(time)
      return
    }
    timer = setTimeout(onTimer, remainingWait(time))
  }

  const throttled = function (
    this: ThisParameterType<T>,
    ...args: Parameters<T>
  ): ReturnType<T> | undefined {
    if (!leading && !trailing) return result

    const time = Date.now()
    const invokeNow = shouldInvoke(time)
    lastArgs = args
    // Preserve the caller receiver until the deferred invocation.
    // eslint-disable-next-line @typescript-eslint/no-this-alias
    lastThis = this
    lastCallTime = time

    if (invokeNow) {
      if (timer === undefined) {
        lastInvokeTime = time
        timer = setTimeout(onTimer, delay)
        return leading ? invoke(time) : result
      }
      // With a zero delay and no leading edge, keep every synchronous call
      // deferred until the pending timer and retain only the latest arguments.
      if (delay === 0 && !leading) return result
      clearTimeout(timer)
      timer = setTimeout(onTimer, delay)
      return invoke(time)
    }
    if (timer === undefined) timer = setTimeout(onTimer, remainingWait(time))
    return result
  } as IThrottledFunction<T>

  throttled.cancel = (): void => {
    if (timer !== undefined) clearTimeout(timer)
    lastArgs = undefined
    lastCallTime = undefined
    lastInvokeTime = 0
    lastThis = undefined
    timer = undefined
  }
  throttled.flush = (): ReturnType<T> | undefined => {
    if (timer === undefined || !trailing || !lastArgs) return result
    clearTimeout(timer)
    // Keep the cooldown after flushing so a later call cannot bypass the interval.
    timer = setTimeout(onTimer, delay)
    return invoke(Date.now())
  }
  return throttled
}
