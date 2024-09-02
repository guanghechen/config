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
---@field public show                   fun(self: eve.types.ux.IWidget): nil
---@field public hidden                 fun(self: eve.types.ux.IWidget): nil
---@field public resize                 fun(self: eve.types.ux.IWidget): nil
