---@class fml.types.context.theme.IData
---@field public mode                   fml.enums.theme.Mode
---@field public transparency           boolean

---@class fml.types.context.theme.IToggleSchemeParams
---@field public mode                   ?fml.enums.theme.Mode
---@field public transparency           ?boolean
---@field public persistent             ?boolean
---@field public force                  ?boolean

---@class fml.types.context.theme.IReloadThemeParams
---@field public force                  ?boolean

---@class fml.types.context.theme : fml.collection.Viewmodel
---@field public mode                   fml.types.collection.IObservable
---@field public transparency           fml.types.collection.IObservable
---@field public toggle_scheme          fun(params: fml.types.context.theme.IToggleSchemeParams):nil
---@field public reload_theme           fun(params: fml.types.context.theme.IReloadThemeParams):nil
