---@class guanghechen.types.IDisposable
---@field isDisposed fun(self: guanghechen.types.IDisposable):boolean  Check if the disposable disposed.
---@field dispose fun(self: guanghechen.types.IDisposable):boolean     Dispose the disposable.

---@class guanghechen.types.IBatchDisposable : guanghechen.types.IDisposable
---@field registerDisposable fun(self: guanghechen.types.IBatchDisposable, disposable: guanghechen.types.IDisposable):nil
