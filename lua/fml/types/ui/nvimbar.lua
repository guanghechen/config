---@class fml.types.ui.nvimbar.IContext
---@field public tabnr                  number
---@field public winnr                  number
---@field public bufnr                  number
---@field public cwd                    string
---@field public filepath               string
---@field public fileicon               string
---@field public filetype               string
---@field public mode                   fml.enums.nvimbar.VimMode
---@field public mode_name              string

---@class fml.types.ui.nvimbar.IRawComponent
---@field public name                   string
---@field public render                 fun(context: fml.types.ui.nvimbar.IContext): string
---@field public condition              ?fun(context: fml.types.ui.nvimbar.IContext): boolean
---@field public will_change            ?fun(context: fml.types.ui.nvimbar.IContext, prev_context: fml.types.ui.nvimbar.IContext|nil): boolean

---@class fml.types.ui.nvimbar.IComponent
---@field public name                   string
---@field public last_result            string
---@field public render                 fun(context: fml.types.ui.nvimbar.IContext): string
---@field public condition              fun(context: fml.types.ui.nvimbar.IContext): boolean
---@field public will_change            fun(context: fml.types.ui.nvimbar.IContext, prev_context: fml.types.ui.nvimbar.IContext|nil): boolean

---@class fml.types.ui.INvimbar
---@field public add                    fun(self: fml.types.ui.INvimbar, position: fml.enums.nvimbar.ComponentPosition, component: fml.types.ui.nvimbar.IRawComponent): fml.types.ui.INvimbar
---@field public render                 fun(self: fml.types.ui.INvimbar): string
