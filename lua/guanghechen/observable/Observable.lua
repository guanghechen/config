local BatchDisposable = require("guanghechen.disposable.BatchDisposable")
local Subscribers = require("guanghechen.subscriber.Subscribers")
local comparator = require("guanghechen.util.comparator")

---@class guanghechen.observable.Observable : guanghechen.types.IObservable
local Observable = setmetatable({}, BatchDisposable)

---@class guanghechen.observable.Observable.IOptions
---@field public delay? number  Delay before notifying subscribers. (milliseconds)
---@field public equals? guanghechen.types.IEquals  Determine whether the two values are equal.

---@param o guanghechen.types.IBatchDisposable
---@param default_value guanghechen.types.T
---@param options? guanghechen.observable.Observable.IOptions
---@return guanghechen.observable.Observable
function Observable:new(o, default_value, options)
  o = o or BatchDisposable:new()

  options = options or options
  ---@cast options guanghechen.observable.Observable.IOptions

  setmetatable(o, self)

  ---@type guanghechen.types.IEquals
  local equals = options.equals and options.equals or comparator.shallow_equals

  local delay = math.max(0, options and options.delay or 0)

  ---@type number
  self._delay = delay

  ---@type guanghechen.types.ISubscribers
  self._subscribers = Subscribers:new()

  ---@type guanghechen.types.T
  self._value = default_value

  ---@type number
  self._updateTick = 0

  ---@type number
  self._notifyTick = 0

  ---@type guanghechen.types.T|nil
  self._lastNotifiedValue = nil

  self._timer = vim.loop.new_timer()

  ---@type guanghechen.types.IEquals
  self.equals = equals

  ---@cast o guanghechen.observable.Observable
  return o
end

return Observable

-- import { BatchDisposable } from '@guanghechen/disposable'
-- import type { ISubscriber, ISubscribers, IUnsubscribable } from '@guanghechen/subscriber'
-- import { Subscribers } from '@guanghechen/subscriber'
-- import type {
--   IEquals,
--   IObservable,
--   IObservableNextOptions,
--   IObservableOptions,
-- } from './types/observable'
-- import { noopUnsubscribable } from './util'
--
-- const defaultEquals = <T>(x: T, y: T): boolean => Object.is(x, y)
--
-- export class Observable<T> extends BatchDisposable implements IObservable<T> {
--   public readonly equals: IEquals<T>
--   protected readonly _delay: number
--   protected readonly _subscribers: ISubscribers<T>
--   protected _value: T
--   protected _updateTick: number
--   protected _notifyTick: number
--   protected _lastNotifiedValue: T | undefined
--   protected _timer: ReturnType<typeof setTimeout> | undefined
--
--   constructor(defaultValue: T, options: IObservableOptions<T> = {}) {
--     super()
--
--     const { equals = defaultEquals } = options
--     this._delay = Math.max(0, Number(options.delay) || 0)
--     this._subscribers = new Subscribers()
--     this._value = defaultValue
--     this._updateTick = 0
--     this._notifyTick = 0
--     this._lastNotifiedValue = undefined
--     this._timer = undefined
--     this.equals = equals
--   }
--
--   public override dispose(): void {
--     if (this.disposed) return
--     super.dispose()
--
--     // Notify subscribers if has changes not notified.
--     this._flush()
--
--     // Dispose subscribers.
--     this._subscribers.dispose()
--   }
--
--   public getSnapshot(): T {
--     return this._value
--   }
--
--   public next(value: T, options?: IObservableNextOptions): void {
--     if (this.disposed) {
--       const strict: boolean = options?.strict ?? true
--       if (strict) {
--         throw new RangeError(`Don't update a disposed observable. value: ${String(value)}.`)
--       }
--       return
--     }
--
--     const force: boolean = options?.force ?? false
--     if (!force && this.equals(value, this._value)) return
--
--     this._value = value
--     this._updateTick += 1
--     this._notify()
--   }
--
--   public subscribe(subscriber: ISubscriber<T>): IUnsubscribable {
--     if (subscriber.disposed) return noopUnsubscribable
--
--     const prevValue: T | undefined = this._lastNotifiedValue
--     const value: T = this._value
--
--     if (this.disposed) {
--       subscriber.next(value, prevValue)
--       subscriber.dispose()
--       return noopUnsubscribable
--     }
--
--     this._flush()
--     subscriber.next(value, prevValue)
--     return this._subscribers.subscribe(subscriber)
--   }
--
--   protected _flush(): void {
--     if (this._notifyTick < this._updateTick) {
--       if (this._timer !== undefined) {
--         clearTimeout(this._timer)
--         this._timer = undefined
--       }
--       this._notifyImmediate()
--     }
--   }
--
--   protected _notify(): void {
--     if (this._notifyTick < this._updateTick) {
--       if (this._delay <= 0) {
--         this._notifyImmediate()
--         return
--       }
--
--       if (this._timer === undefined) {
--         this._timer = setTimeout(() => {
--           try {
--             this._notifyImmediate()
--           } finally {
--             this._timer = undefined
--           }
--
--           // Recursive to handle candidate changes.
--           this._notify()
--         }, this._delay)
--       }
--     }
--   }
--
--   protected _notifyImmediate(): void {
--     const prevValue: T | undefined = this._lastNotifiedValue
--     const value: T = this._value
--     this._lastNotifiedValue = value
--     this._notifyTick = this._updateTick
--     this._subscribers.notify(value, prevValue)
--   }
-- }
