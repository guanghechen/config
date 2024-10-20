---@class t.eve.collection.IDisposable
---@field public is_disposed            fun(self: t.eve.collection.IDisposable): boolean Check if the disposable disposed.
---@field public dispose                fun(self: t.eve.collection.IDisposable): boolean Dispose the disposable.

---@class t.eve.collection.IBatchDisposable : t.eve.collection.IDisposable
---@field public dispose_all            fun(disposables: t.eve.collection.IDisposable[]): nil
---@field public add_disposable         fun(self: t.eve.collection.IBatchDisposable, disposable: t.eve.collection.IDisposable): nil
