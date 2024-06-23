---@class fml.types.collection.IDisposable
---@field public  is_disposed           fun(self: fml.types.collection.IDisposable): boolean Check if the disposable disposed.
---@field public  dispose               fun(self: fml.types.collection.IDisposable): boolean Dispose the disposable.

---@class fml.types.collection.IBatchDisposable : fml.types.collection.IDisposable
---@field public  add_disposable        fun(self: fml.types.collection.IBatchDisposable, disposable: fml.types.collection.IDisposable): nil
