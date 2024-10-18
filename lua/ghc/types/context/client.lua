---@class ghc.types.context.client.IData
---@field public mode                   fml.enums.theme.Mode
---@field public relativenumber         boolean
---@field public transparency           boolean

---@class ghc.types.context.client.IToggleSchemeParams
---@field public mode                   ?fml.enums.theme.Mode
---@field public transparency           ?boolean
---@field public persistent             ?boolean
---@field public force                  ?boolean

---@class ghc.types.context.client.IReloadThemeParams
---@field public force                  ?boolean

---@class ghc.types.context.client.IReloadPartialThemeParams
---@field public integration            ghc.enum.ui.theme.HighlightIntegration

---@class ghc.types.context.client : eve.collection.Viewmodel
---@field public flight_devmode         eve.types.collection.IObservable
---@field public theme                  eve.types.collection.IObservable
---@field public relativenumber         eve.types.collection.IObservable
---@field public transparency           eve.types.collection.IObservable
