---@class eve.types.collection.IDisposable
---@field public is_disposed            fun(self: eve.types.collection.IDisposable): boolean Check if the disposable disposed.
---@field public dispose                fun(self: eve.types.collection.IDisposable): boolean Dispose the disposable.

---@class eve.types.collection.IBatchDisposable : eve.types.collection.IDisposable
---@field public dispose_all            fun(disposables: eve.types.collection.IDisposable[]): nil
---@field public add_disposable         fun(self: eve.types.collection.IBatchDisposable, disposable: eve.types.collection.IDisposable): nil
