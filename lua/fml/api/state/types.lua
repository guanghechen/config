---@class fml.api.state.ILspSymbol
---@field public kind                   string
---@field public name                   string
---@field public row                    integer
---@field public col                    integer

---@class fml.api.state.ILspSymbolPos
---@field public line                   integer
---@field public character              integer

---@class fml.api.state.IBufItem
---@field public filename               string
---@field public filepath               string
---@field public real_paths             string[]
---@field public pinned                 boolean

---@class fml.api.state.IBufItemData
---@field public bufnr                  integer
---@field public filename               string
---@field public filepath               string
---@field public pinned                 boolean

---@class fml.api.state.ITabItem
---@field public name                   string
---@field public bufnrs                 integer[]
---@field public bufnr_set              table<integer, boolean>
---@field public winnr_cur              fml.types.collection.IObservable

---@class fml.api.state.ITabItemData
---@field public tabnr                  integer
---@field public name                   string
---@field public bufnrs                 integer[]

---@class fml.api.state.IWinItem
---@field public tabnr                  integer
---@field public buf_history            fml.types.collection.IHistory
---@field public lsp_symbols            fml.api.state.ILspSymbol[]

---@class fml.api.state.IWinItemData : fml.api.state.IWinItem
---@field public winnr                  integer
---@field public tabnr                  integer
---@field public buf_history            fml.types.collection.history.ISerializedData

---@class fml.api.state.ISerializedData
---@field public bufs                   fml.api.state.IBufItemData[]
---@field public tabs                   fml.api.state.IWinItemData[]
---@field public wins                   fml.api.state.ITabItemData[]
---@field public tab_history            fml.types.collection.history.ISerializedData
---@field public win_history            fml.types.collection.history.ISerializedData

---@alias fml.api.state.TermPosition
---| "bottom"
---| "right"
---| "float"

---@class fml.api.state.ITerm
---@field public name                   string
---@field public position               fml.api.state.TermPosition
---@field public bufnr                  integer
---@field public winnr                  integer|nil
