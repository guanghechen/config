---@class eve.t.state.data.buf.IMeta
---@field public bufnr                  integer
---@field public filename               string
---@field public filepath               string
---@field public pinned                 boolean

---@class eve.t.state.state.buf.IMeta
---@field public fileicon               string
---@field public fileicon_hl            string
---@field public filename               string
---@field public filepath               string
---@field public filetype               string
---@field public relpath                string
---@field public relpath_pieces         string[]
---@field public pinned                 boolean

---@class eve.t.state.data.tab.IMeta
---@field public tabnr                  integer
---@field public tabtype                string
---@field public bufnrs                 integer[]

---@class eve.t.state.state.tab.IMeta
---@field public tabtype                string
---@field public bufnrs                 integer[]
---@field public winnr_listed           integer

---@class eve.t.state.data.win.IMeta
---@field public winnr                  integer
---@field public filepath_history       eve.lib.collection.history.ISerializedData

---@class eve.t.state.state.win.IMeta
---@field public filepath_history       eve.lib.collection.IAdvanceHistory
---@field public lsp_symbols            eve.t.state.state.lsp.ISymbol[]
---@field public winline                eve.lib.ux.INvimbar|nil

---@class eve.t.state.state.lsp.ISymbol
---@field public kind                   string
---@field public name                   string
---@field public row                    integer
---@field public col                    integer

---@class eve.t.state.session.data
---@field public bufs                   eve.t.state.data.buf.IMeta[]
---@field public tabs                   eve.t.state.data.tab.IMeta[]
---@field public wins                   eve.t.state.data.win.IMeta[]
---@field public tab_history            eve.lib.collection.history.ISerializedData

---@class eve.t.state.session.state
---@field public tab_history            eve.lib.collection.IAdvanceHistory

---@class eve.t.state.session
---@field public state                  eve.t.state.session.state
---@field public defaults               fun(): eve.t.state.session.data
---@field public dump                   fun(): eve.t.state.session.data
---@field public load                   fun(data: eve.t.state.session.data): nil
---@field public normalize              fun(data: any): eve.t.state.session.data
