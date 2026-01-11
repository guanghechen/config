---@meta

---@class era.m.minimap.IMark
---Row of the mark, use `require('era.m.minimap.util').row_to_barpos(winid, lnum)`
---to translate an `lnum` from window `winid` to its respective scrollbar row.
---@field public pos                  integer
---Highlight group of the mark.
---@field public highlight            string
---Symbol of the mark. Must be a single character.
---@field public symbol               string
---By default, for each position in the scrollbar, minimap will only use the
---last mark with that position. This field indicates the mark is special and
---must be rendered even if there is another mark at the same position from the
---handler.
---@field public unique               boolean|nil

---@class era.m.minimap.IHandlerConfig
---Whether the handler is enabled.
---@field public enable               boolean
---If `true` decorations are rendered on top of the scrollbar. If `false` the
---decorations are rendered in a separate column to the right of the scrollbar.
---@field public overlap              boolean
---Priority of the decorations from the handler.
---@field public priority             integer

---@class era.m.minimap.IHandler
---Name of the handler.
---@field public name                 string
---Configuration for this handler.
---@field public config               era.m.minimap.IHandlerConfig
---Namespace ID for extmarks.
---@field public ns                   integer
---Attach the handler to a window (subscribe to updates).
---@field public attach               fun(winnr: integer): nil
---Detach the handler from a window (unsubscribe from updates).
---@field public detach               fun(winnr: integer): nil

---@class era.m.minimap.IViewProps
---@field public col                  integer
---@field public height               integer
---@field public row                  integer
---@field public width                integer

---@class era.m.minimap.mouse.IProps
---@field public char                 string
---@field public col                  integer
---@field public row                  integer
---@field public str_idx              integer
---@field public winid                integer
