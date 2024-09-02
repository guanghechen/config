---@class eve.types.collection.IObservableNextOptions
---@field public strict                 ?boolean Whether to throw an error if the observable disposed.
---@field public force                  ?boolean  Force trigger the notification of subscribers even the next value is equals to the current value.

---@class eve.types.collection.IObservable: eve.types.collection.IBatchDisposable, eve.types.collection.ISubscribable
---@field public equals                 eve.types.IEquals
---@field public normalize              eve.types.INormalize
---@field public snapshot               fun(self: eve.types.collection.IObservable): eve.types.T
---@field public next                   fun(self: eve.types.collection.IObservable, value: eve.types.T, options?: eve.types.collection.IObservableNextOptions):boolean
