---@class fml.types.api.state.ILspSymbol
---@field public kind                   string
---@field public name                   string
---@field public row                    integer
---@field public col                    integer

---@class fml.types.api.state.ILspSymbolPos
---@field public line                   integer
---@field public character              integer

---@class fml.types.api.state.IBufItem
---@field public filename               string
---@field public filepath               string
---@field public real_paths             string[]
---@field public pinned                 boolean

---@class fml.types.api.state.IBufItemData
---@field public bufnr                  integer
---@field public filename               string
---@field public filepath               string
---@field public pinned                 boolean

---@class fml.types.api.state.ITabItem
---@field public name                   string
---@field public bufnrs                 integer[]
---@field public bufnr_set              table<integer, boolean>
---@field public winnr_cur              fml.types.collection.IObservable

---@class fml.types.api.state.ITabItemData
---@field public tabnr                  integer
---@field public name                   string
---@field public bufnrs                 integer[]

---@class fml.types.api.state.IWinItem
---@field public buf_history            fml.types.collection.IHistory
---@field public lsp_symbols            fml.types.api.state.ILspSymbol[]

---@class fml.types.api.state.IWinItemData
---@field public winnr                  integer
---@field public buf_history            fml.types.collection.history.ISerializedData

---@class fml.types.api.state.ISerializedData
---@field public bufs                   fml.types.api.state.IBufItemData[]
---@field public tabs                   fml.types.api.state.ITabItemData[]
---@field public wins                   fml.types.api.state.IWinItemData[]
---@field public tab_history            fml.types.collection.history.ISerializedData
---@field public win_history            fml.types.collection.history.ISerializedData

---@class fml.types.api.state.ITerm
---@field public name                   string
---@field public position               fml.enums.api.TermPosition
---@field public bufnr                  integer
---@field public winnr                  integer|nil
