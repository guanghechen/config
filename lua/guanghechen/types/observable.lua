---@class guanghechen.types.IObservableNextOptions
---@field public  strict? boolean Whether to throw an error if the observable disposed.
---@field public  force? boolean  Force trigger the notification of subscribers even the next value is equals to the current value.

---@class guanghechen.types.IObservable: guanghechen.types.IBatchDisposable, guanghechen.types.ISubscribable
---@field public  equals guanghechen.types.IEquals
---@field public  gentSnapshot fun():guanghechen.types.T
---@field public  next fun(value: guanghechen.types.T, options?: guanghechen.types.IObservableNextOptions):nil
