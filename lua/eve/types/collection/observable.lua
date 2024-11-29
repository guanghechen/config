---@class eve.t.collection.IObservableNextOptions
---@field public strict                 ?boolean Whether to throw an error if the observable disposed.
---@field public force                  ?boolean  Force trigger the notification of subscribers even the next value is equals to the current value.

---@class eve.t.collection.IObservable: eve.t.collection.IBatchDisposable, eve.t.collection.ISubscribable
---@field public equals                 eve.t.IEquals
---@field public normalize              eve.t.INormalize
---@field public snapshot               fun(self: eve.t.collection.IObservable): eve.t.T
---@field public next                   fun(self: eve.t.collection.IObservable, value: eve.t.T, options?: eve.t.collection.IObservableNextOptions):boolean
