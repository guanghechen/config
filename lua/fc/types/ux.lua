---@class fc.types.ux.IBoxDimension
---@field public row                    integer
---@field public col                    integer
---@field public width                  integer
---@field public height                 integer

---@class fc.types.ux.IBoxRestriction
---@field public position               fc.enums.BoxPosition
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

---@class fc.types.ux.IHighlight
---@field public lnum                   integer
---@field public coll                   integer
---@field public colr                   integer
---@field public hlname                 string

---@class fc.types.ux.IInlineHighlight
---@field public coll                   integer
---@field public colr                   integer
---@field public hlname                 string
