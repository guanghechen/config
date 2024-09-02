---@class eve.types.collection.IViewmodel : eve.types.collection.IBatchDisposable
---@field public get_name               fun(self: eve.types.collection.IViewmodel): string
---@field public get_filepath           fun(self: eve.types.collection.IViewmodel): string|nil
---@field public snapshot               fun(self: eve.types.collection.IViewmodel): table
---@field public snapshot_all           fun(self: eve.types.collection.IViewmodel): table
---@field public register               fun(self: eve.types.collection.IViewmodel, name: string, observable: eve.types.collection.IObservable):nil
---@field public save                   fun(self: eve.types.collection.IViewmodel): nil
---@field public load                   fun(self: eve.types.collection.IViewmodel, params: eve.types.collection.viewmodel.ILoadParams): nil

---@class eve.types.collection.viewmodel.ILoadParams
---@field public silent_on_notfound     ?boolean

---@class eve.types.collection.viewmodel.IAutoReloadParams
---@field public on_changed             ?fun(): nil
