---@class t.fml.ux.ITerminal : t.eve.ux.IWidget
---@field public close                  fun(self: t.fml.ux.ITerminal): nil
---@field public focus                  fun(self: t.fml.ux.ITerminal): nil
---@field public get_winnr              fun(self: t.fml.ux.ITerminal): integer|nil
---@field public get_bufnr              fun(self: t.fml.ux.ITerminal): integer|nil
---@field public open                   fun(self: t.fml.ux.ITerminal): nil
---@field public toggle                 fun(self: t.fml.ux.ITerminal): nil

---@class t.fml.ux.terminal.IDimension
---@field public height                 ?number
---@field public max_width              number
---@field public max_height             number
---@field public width                  ?number

---@class t.fml.ux.terminal.IRawDimension
---@field public height                 ?number
---@field public max_width              ?number
---@field public max_height             ?number
---@field public width                  ?number
