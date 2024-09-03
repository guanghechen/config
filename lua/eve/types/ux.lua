---@class eve.types.ux.IBoxDimension
---@field public row                    integer
---@field public col                    integer
---@field public width                  integer
---@field public height                 integer

---@class eve.types.ux.IBoxRestriction
---@field public position               eve.enums.BoxPosition
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

---@class eve.types.ux.IHighlight
---@field public lnum                   integer
---@field public coll                   integer
---@field public colr                   integer
---@field public hlname                 string

---@class eve.types.ux.IInlineHighlight
---@field public coll                   integer
---@field public colr                   integer
---@field public hlname                 string

---@class eve.types.ux.IWidget
---@field public statusline_items       eve.types.ux.widgets.IStatuslineItem[]|nil
---@field public alive                  fun(self: eve.types.ux.IWidget): boolean
---@field public hide                   fun(self: eve.types.ux.IWidget): nil
---@field public resize                 fun(self: eve.types.ux.IWidget): nil
---@field public show                   fun(self: eve.types.ux.IWidget): nil
---@field public visible                fun(self: eve.types.ux.IWidget): boolean

---@class eve.types.ux.widgets.IStatuslineItem
---@field public type                   eve.enums.WidgetStatuslineItemType
---@field public state                  eve.types.collection.IObservable
---@field public symbol                 string
---@field public callback_fn            string

---@class eve.types.ux.widgets.IRawStatuslineItem
---@field public type                   eve.enums.WidgetStatuslineItemType
---@field public desc                   string
---@field public state                  eve.types.collection.IObservable
---@field public symbol                 string
---@field public callback               fun(): nil
