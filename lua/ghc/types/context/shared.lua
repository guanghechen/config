---@class ghc.types.context.shared.IData
---@field public mode                   fml.enums.theme.Mode
---@field public relativenumber         boolean
---@field public transparency           boolean

---@class ghc.types.context.shared.IToggleSchemeParams
---@field public mode                   ?fml.enums.theme.Mode
---@field public transparency           ?boolean
---@field public persistent             ?boolean
---@field public force                  ?boolean

---@class ghc.types.context.shared.IReloadThemeParams
---@field public force                  ?boolean

---@class ghc.types.context.shared.IReloadPartialThemeParams
---@field public integration            ghc.enum.ui.theme.HighlightIntegration
---@field public force                  ?boolean

---@class ghc.types.context.shared : fml.collection.Viewmodel
---@field public mode                   fml.types.collection.IObservable
---@field public relativenumber         fml.types.collection.IObservable
---@field public transparency           fml.types.collection.IObservable
---@field public toggle_scheme          fun(params: ghc.types.context.shared.IToggleSchemeParams):nil
---@field public reload_theme           fun(params: ghc.types.context.shared.IReloadThemeParams):nil
