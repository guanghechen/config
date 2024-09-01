---@class fc.types.collection.IObservableNextOptions
---@field public strict                 ?boolean Whether to throw an error if the observable disposed.
---@field public force                  ?boolean  Force trigger the notification of subscribers even the next value is equals to the current value.

---@class fc.types.collection.IObservable: fc.types.collection.IBatchDisposable, fc.types.collection.ISubscribable
---@field public equals                 fc.types.IEquals
---@field public normalize              fc.types.INormalize
---@field public snapshot               fun(self: fc.types.collection.IObservable): fc.types.T
---@field public next                   fun(self: fc.types.collection.IObservable, value: fc.types.T, options?: fc.types.collection.IObservableNextOptions):boolean
