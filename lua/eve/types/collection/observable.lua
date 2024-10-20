---@class t.eve.collection.IObservableNextOptions
---@field public strict                 ?boolean Whether to throw an error if the observable disposed.
---@field public force                  ?boolean  Force trigger the notification of subscribers even the next value is equals to the current value.

---@class t.eve.collection.IObservable: t.eve.collection.IBatchDisposable, t.eve.collection.ISubscribable
---@field public equals                 t.eve.IEquals
---@field public normalize              t.eve.INormalize
---@field public snapshot               fun(self: t.eve.collection.IObservable): t.eve.T
---@field public next                   fun(self: t.eve.collection.IObservable, value: t.eve.T, options?: t.eve.collection.IObservableNextOptions):boolean
