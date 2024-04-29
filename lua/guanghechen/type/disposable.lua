---@class guanghechen.types.IDisposable
---@field isDisposed fun():boolean  Check if the disposable disposed.
---@field dispose fun():boolean     Dispose the disposable.

---@class guanghechen.types.IBatchDisposable : guanghechen.types.IDisposable
---@field registerDisposable fun(disposable: guanghechen.types.IDisposable):nil
