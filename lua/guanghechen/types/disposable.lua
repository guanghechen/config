---@class guanghechen.types.IDisposable
---@field public  isDisposed fun(self: guanghechen.types.IDisposable):boolean  Check if the disposable disposed.
---@field public  dispose    fun(self: guanghechen.types.IDisposable):boolean     Dispose the disposable.

---@class guanghechen.types.IBatchDisposable : guanghechen.types.IDisposable
---@field public  registerDisposable fun(self: guanghechen.types.IBatchDisposable, disposable: guanghechen.types.IDisposable):nil
