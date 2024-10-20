---@class t.eve.context.state.lsp.ISymbol
---@field public kind                   string
---@field public name                   string
---@field public row                    integer
---@field public col                    integer

---@class t.eve.context.state.buf.IItem
---@field public fileicon               string
---@field public fileicon_hl            string
---@field public filename               string
---@field public filepath               string
---@field public filetype               string
---@field public relpath             string[]
---@field public pinned                 boolean

---@class t.eve.context.state.tab.IItem
---@field public name                   string
---@field public bufnrs                 integer[]
---@field public bufnr_set              table<integer, boolean>
---@field public winnr_cur              t.eve.collection.IObservable

---@class t.eve.context.state.win.IItem
---@field public lsp_symbols            t.eve.context.state.lsp.ISymbol[]
---@field public filepath_history       t.eve.collection.IAdvanceHistory

---@class t.eve.context.state.status
---@field public lsp_msg                t.eve.collection.IObservable
---@field public tmux_zen_mode          t.eve.collection.IObservable

---@class t.eve.context.state.frecency
---@field public files                  t.eve.collection.IFrecency

---@class t.eve.context.state.input_history
---@field public find_files             t.eve.collection.IHistory
---@field public search_in_files        t.eve.collection.IHistory

---@class t.eve.context.workspace.state
---@field public bufs                   table<integer, t.eve.context.state.buf.IItem>
---@field public tabs                   table<integer, t.eve.context.state.tab.IItem>
---@field public wins                   table<integer, t.eve.context.state.win.IItem>
---@field public status                 t.eve.context.state.status
---@field public frecency               t.eve.context.state.frecency
---@field public input_history          t.eve.context.state.input_history
---@field public tab_history            t.eve.collection.IAdvanceHistory
---@field public winline_dirty_nr       t.eve.collection.IObservable

---@class t.eve.context.workspace
---@field public state                  t.eve.context.workspace.state
---@field public defaults               fun(): t.eve.context.workspace.data
---@field public dump                   fun(): t.eve.context.workspace.data
---@field public load                   fun(data: t.eve.context.workspace.data): nil
---@field public normalize              fun(data: any): t.eve.context.workspace.data
