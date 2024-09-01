---@class fc.types.collection.IDisposable
---@field public is_disposed            fun(self: fc.types.collection.IDisposable): boolean Check if the disposable disposed.
---@field public dispose                fun(self: fc.types.collection.IDisposable): boolean Dispose the disposable.

---@class fc.types.collection.IBatchDisposable : fc.types.collection.IDisposable
---@field public dispose_all            fun(disposables: fc.types.collection.IDisposable[]): nil
---@field public add_disposable         fun(self: fc.types.collection.IBatchDisposable, disposable: fc.types.collection.IDisposable): nil
