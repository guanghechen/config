---@class eve.t.collection.IDisposable
---@field public is_disposed            fun(self: eve.t.collection.IDisposable): boolean Check if the disposable disposed.
---@field public dispose                fun(self: eve.t.collection.IDisposable): boolean Dispose the disposable.

---@class eve.t.collection.IBatchDisposable : eve.t.collection.IDisposable
---@field public dispose_all            fun(disposables: eve.t.collection.IDisposable[]): nil
---@field public add_disposable         fun(self: eve.t.collection.IBatchDisposable, disposable: eve.t.collection.IDisposable): nil
