---@class fml.types.ui.ISetting
---@field public bufnr                  integer|nil
---@field public winnr                  integer|nil
---@field public open                   fun(self: fml.types.ui.ISetting, params: fml.types.ui.setting.IOpenParams): nil
---@field public close                  fun(self: fml.types.ui.ISetting): nil

---@class fml.types.ui.setting.IOpenParams
---@field public initial_value          fc.types.T
---@field public row                    ?number
---@field public col                    ?number
---@field public width                  ?number
---@field public height                 ?number
---@field public win_cursor_row         ?integer
---@field public win_cursor_col         ?integer
