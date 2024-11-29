---@class eve.t.ux.IBoxDimension
---@field public row                    integer
---@field public col                    integer
---@field public width                  integer
---@field public height                 integer

---@class eve.t.ux.IBoxRestriction
---@field public position               eve.e.BoxPosition
---@field public rows                   integer
---@field public cols                   integer
---@field public row                    ?number
---@field public col                    ?number
---@field public cursor_row             ?integer
---@field public cursor_col             ?integer
---@field public max_width              ?number
---@field public max_height             ?number
---@field public min_width              ?number
---@field public min_height             ?number

---@class eve.t.ux.IWidget
---@field public name                   string|nil
---@field public statusline_items       eve.t.ux.widget.IStatuslineItem[]|nil
---@field public status                 fun(self: eve.t.ux.IWidget): eve.e.WidgetStatus
---@field public close                  fun(self: eve.t.ux.IWidget): nil
---@field public hide                   fun(self: eve.t.ux.IWidget): nil
---@field public show                   fun(self: eve.t.ux.IWidget): nil
---@field public resize                 fun(self: eve.t.ux.IWidget): nil

---@class eve.t.ux.widget.IStatuslineItem
---@field public type                   eve.e.WidgetStatuslineItemType
---@field public state                  eve.t.collection.IObservable
---@field public symbol                 string
---@field public callback_fn            string

---@class eve.t.ux.widget.IRawStatuslineItem
---@field public type                   eve.e.WidgetStatuslineItemType
---@field public desc                   string
---@field public state                  eve.t.collection.IObservable
---@field public symbol                 string
---@field public callback               fun(): nil
