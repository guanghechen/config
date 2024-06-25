---@class ghc.types.context.theme.IData
---@field public mode                   ghc.enums.theme.Mode
---@field public transparency           boolean

---@class ghc.types.context.theme.IToggleSchemeParams
---@field public mode                   ?ghc.enums.theme.Mode
---@field public transparency           ?boolean
---@field public persistent             ?boolean
---@field public force                  ?boolean

---@class ghc.types.context.theme.IReloadThemeParams
---@field public force                  ?boolean

---@class ghc.types.context.theme : fml.collection.Viewmodel
---@field public mode                   fml.types.collection.IObservable
---@field public transparency           fml.types.collection.IObservable
---@field public toggle_scheme          fun(params: ghc.types.context.theme.IToggleSchemeParams):nil
---@field public reload_theme           fun(params: ghc.types.context.theme.IReloadThemeParams):nil
