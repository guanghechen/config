---@class fml.t.ux.ITerminal : eve.t.ux.IWidget
---@field public focus                  fun(self: fml.t.ux.ITerminal): nil
---@field public get_winnr              fun(self: fml.t.ux.ITerminal): integer|nil
---@field public get_bufnr              fun(self: fml.t.ux.ITerminal): integer|nil
---@field public open                   fun(self: fml.t.ux.ITerminal): nil
---@field public toggle                 fun(self: fml.t.ux.ITerminal): nil

---@class fml.t.ux.terminal.IDimension
---@field public height                 ?number
---@field public max_width              number
---@field public max_height             number
---@field public width                  ?number

---@class fml.t.ux.terminal.IRawDimension
---@field public height                 ?number
---@field public max_width              ?number
---@field public max_height             ?number
---@field public width                  ?number
