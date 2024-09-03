---@class fml.types.ui.ITerminal : eve.types.ux.IWidget
---@field public close                  fun(self: fml.types.ui.ITerminal): nil
---@field public focus                  fun(self: fml.types.ui.ITerminal): nil
---@field public get_winnr              fun(self: fml.types.ui.ITerminal): integer|nil
---@field public get_bufnr              fun(self: fml.types.ui.ITerminal): integer|nil
---@field public open                   fun(self: fml.types.ui.ITerminal): nil
---@field public toggle                 fun(self: fml.types.ui.ITerminal): nil

---@class fml.types.ui.terminal.IDimension
---@field public height                 ?number
---@field public max_width              number
---@field public max_height             number
---@field public width                  ?number

---@class fml.types.ui.terminal.IRawDimension
---@field public height                 ?number
---@field public max_width              ?number
---@field public max_height             ?number
---@field public width                  ?number
