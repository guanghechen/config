---@class t.eve.ux.IBoxDimension
---@field public row                    integer
---@field public col                    integer
---@field public width                  integer
---@field public height                 integer

---@class t.eve.ux.IBoxRestriction
---@field public position               t.eve.e.BoxPosition
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

---@class t.eve.ux.IWidget
---@field public statusline_items       t.eve.ux.widget.IStatuslineItem[]|nil
---@field public status                 fun(self: t.eve.ux.IWidget): t.eve.e.WidgetStatus
---@field public hide                   fun(self: t.eve.ux.IWidget): nil
---@field public resize                 fun(self: t.eve.ux.IWidget): nil
---@field public show                   fun(self: t.eve.ux.IWidget): nil

---@class t.eve.ux.widget.IStatuslineItem
---@field public type                   t.eve.e.WidgetStatuslineItemType
---@field public state                  t.eve.collection.IObservable
---@field public symbol                 string
---@field public callback_fn            string

---@class t.eve.ux.widget.IRawStatuslineItem
---@field public type                   t.eve.e.WidgetStatuslineItemType
---@field public desc                   string
---@field public state                  t.eve.collection.IObservable
---@field public symbol                 string
---@field public callback               fun(): nil
