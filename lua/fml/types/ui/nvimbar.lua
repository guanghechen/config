---@class fml.types.ui.nvimbar.IPresetContext
---@field public winnr                  ?integer

---@class fml.types.ui.nvimbar.IContext
---@field public tabnr                  integer
---@field public winnr                  integer
---@field public bufnr                  integer
---@field public cwd                    string
---@field public filepath               string
---@field public fileicon               string
---@field public filetype               string
---@field public mode                   fml.enums.nvimbar.VimMode
---@field public mode_name              string

---@class fml.types.ui.nvimbar.IRawComponent
---@field public name                   string
---@field public render                 fun(context: fml.types.ui.nvimbar.IContext, remain_width: integer): string, integer
---@field public tight                  ?boolean
---@field public condition              ?fun(context: fml.types.ui.nvimbar.IContext, remain_width: integer): boolean
---@field public will_change            ?fun(context: fml.types.ui.nvimbar.IContext, prev_context: fml.types.ui.nvimbar.IContext|nil, remain_width: integer): boolean

---@class fml.types.ui.nvimbar.IComponent
---@field public enabled                boolean
---@field public last_result_text       string
---@field public last_result_width      integer
---@field public tight                  boolean
---@field public render                 fun(context: fml.types.ui.nvimbar.IContext, remain_width: integer): string, integer
---@field public condition              fun(context: fml.types.ui.nvimbar.IContext, remain_width: integer): boolean
---@field public will_change            fun(context: fml.types.ui.nvimbar.IContext, prev_context: fml.types.ui.nvimbar.IContext|nil, remain_width: integer): boolean

---@class fml.types.ui.nvimbar.IItem
---@field public name                   string
---@field public position               fml.enums.nvimbar.ComponentPosition

---@class fml.types.ui.INvimbar
---@field public disable                fun(self: fml.types.ui.INvimbar, name: string): fml.types.ui.INvimbar
---@field public enable                 fun(self: fml.types.ui.INvimbar, name: string): fml.types.ui.INvimbar
---@field public place                  fun(self: fml.types.ui.INvimbar, name: string, position: fml.enums.nvimbar.ComponentPosition): fml.types.ui.INvimbar
---@field public register               fun(self: fml.types.ui.INvimbar, name: string, component: fml.types.ui.nvimbar.IRawComponent, enabled?: boolean): fml.types.ui.INvimbar
---@field public render                 fun(self: fml.types.ui.INvimbar, force: boolean): string
