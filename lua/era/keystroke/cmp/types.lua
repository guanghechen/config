---@meta

---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.keystroke.cmp.types" ---@type string

---@class era.keystroke.cmp.IContext Editor input; native command completion owns cmdline state.
---@field public bufnr                  integer
---@field public winnr                  integer
---@field public row                    integer
---@field public col                    integer
---@field public line                   string
---@field public start_col              integer
---@field public keyword                string
---@field public filetype               string
---@field public changedtick            integer
---@field public modified               boolean
---@field public buffer_version         integer
---@field public trigger                string

---@class era.keystroke.cmp.IItem
---@field public raw                    lsp.CompletionItem Protocol payload; Item.optional reads JSON null as absent without changing opaque data.
---@field public context                era.keystroke.cmp.IContext
---@field public source                 string
---@field public id                     string
---@field public frecency_key           string
---@field public start_col              integer
---@field public client_id              ?integer
---@field public filter_start_col       ?integer
---@field public encoding               string
---@field public score_offset           number
---@field public resolved               ?lsp.CompletionItem
---@field public score                  ?number
---@field public preview_word           ?string Static snippet prefix cached only for displayed items; raw payloads are immutable.
---@field public expansion              ?{ body: string, text: string, context: era.keystroke.cmp.IContext }

---@class era.keystroke.cmp.IResponse
---@field public items                  era.keystroke.cmp.IItem[]
---@field public incomplete             boolean
---@field public pending                ?boolean More upstream responses are still awaited before fallback.

---@alias era.keystroke.cmp.RequestDispatch fun(submit: fun(): nil): nil Synchronously submit against the owned logical input, or discard stale work.

---@class era.keystroke.cmp.ISource
---@field public complete               fun(context: era.keystroke.cmp.IContext, callback: (fun(response: era.keystroke.cmp.IResponse): nil), dispatch?: era.keystroke.cmp.RequestDispatch): (fun(keep_transport?: boolean): nil)|nil
---@field public resolve                ?fun(item: era.keystroke.cmp.IItem, callback: fun(raw: lsp.CompletionItem): nil): (fun(): nil)|nil

---@class era.keystroke.cmp.IEditPlan
---@field public main                   lsp.TextEdit
---@field public additional             lsp.TextEdit[]
---@field public snippet                boolean
---@field public create_undo_point      boolean
---@field public cursor_offset          integer
---@field public semantic_brackets      boolean

return {}
