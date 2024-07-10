---@class fml.types.collection.IObservableNextOptions
---@field public strict                 ?boolean Whether to throw an error if the observable disposed.
---@field public force                  ?boolean  Force trigger the notification of subscribers even the next value is equals to the current value.

---@class fml.types.collection.IObservable: fml.types.collection.IBatchDisposable, fml.types.collection.ISubscribable
---@field public equals                 fml.types.IEquals
---@field public normalize              fml.types.INormalize
---@field public snapshot               fun(self: fml.types.collection.IObservable): fml.types.T
---@field public next                   fun(self: fml.types.collection.IObservable, value: fml.types.T, options?: fml.types.collection.IObservableNextOptions):boolean
