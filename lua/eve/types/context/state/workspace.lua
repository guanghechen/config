---@class eve.t.context.state.lsp.ISymbol
---@field public kind                   string
---@field public name                   string
---@field public row                    integer
---@field public col                    integer

---@class eve.t.context.state.buf.IItem
---@field public fileicon               string
---@field public fileicon_hl            string
---@field public filename               string
---@field public filepath               string
---@field public filetype               string
---@field public relpath             string[]
---@field public pinned                 boolean

---@class eve.t.context.state.tab.IItem
---@field public name                   string
---@field public bufnrs                 integer[]
---@field public bufnr_set              table<integer, boolean>
---@field public winnr_cur              eve.t.collection.IObservable

---@class eve.t.context.state.win.IItem
---@field public lsp_symbols            eve.t.context.state.lsp.ISymbol[]
---@field public filepath_history       eve.t.collection.IAdvanceHistory

---@class eve.t.context.state.status
---@field public lsp_msg                eve.t.collection.IObservable
---@field public tmux_zen_mode          eve.t.collection.IObservable
---@field public winline_dirty_nr       eve.t.collection.IObservable

---@class eve.t.context.state.frecency
---@field public files                  eve.t.collection.IFrecency

---@class eve.t.context.state.input_history
---@field public find_files             eve.t.collection.IHistory
---@field public search_in_files        eve.t.collection.IHistory

---@class eve.t.context.workspace.state
---@field public bufs                   table<integer, eve.t.context.state.buf.IItem>
---@field public tabs                   table<integer, eve.t.context.state.tab.IItem>
---@field public wins                   table<integer, eve.t.context.state.win.IItem>
---@field public status                 eve.t.context.state.status
---@field public frecency               eve.t.context.state.frecency
---@field public input_history          eve.t.context.state.input_history
---@field public tab_history            eve.t.collection.IAdvanceHistory

---@class eve.t.context.workspace
---@field public state                  eve.t.context.workspace.state
---@field public defaults               fun(): eve.t.context.workspace.data
---@field public dump                   fun(): eve.t.context.workspace.data
---@field public load                   fun(data: eve.t.context.workspace.data): nil
---@field public normalize              fun(data: any): eve.t.context.workspace.data
