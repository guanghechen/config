---@class fml.t.ux.nvimbar.IPresetContext
---@field public winnr                  ?integer

---@class fml.t.ux.nvimbar.IContext
---@field public tabnr                  integer
---@field public winnr                  integer
---@field public bufnr                  integer
---@field public cwd                    string
---@field public filepath               string
---@field public fileicon               string
---@field public filetype               string
---@field public mode                   eve.e.VimModeName
---@field public mode_name              string

---@class fml.t.ux.nvimbar.IRawComponent
---@field public name                   string
---@field public render                 fun(context: fml.t.ux.nvimbar.IContext, remain_width: integer): string, integer
---@field public tight                  ?boolean
---@field public condition              ?fun(context: fml.t.ux.nvimbar.IContext, remain_width: integer): boolean
---@field public will_change            ?fun(context: fml.t.ux.nvimbar.IContext, prev_context: fml.t.ux.nvimbar.IContext|nil, remain_width: integer): boolean

---@class fml.t.ux.nvimbar.IComponent
---@field public enabled                boolean
---@field public last_result_text       string
---@field public last_result_width      integer
---@field public tight                  boolean
---@field public render                 fun(context: fml.t.ux.nvimbar.IContext, remain_width: integer): string, integer
---@field public condition              fun(context: fml.t.ux.nvimbar.IContext, remain_width: integer): boolean
---@field public will_change            fun(context: fml.t.ux.nvimbar.IContext, prev_context: fml.t.ux.nvimbar.IContext|nil, remain_width: integer): boolean

---@class fml.t.ux.nvimbar.IItem
---@field public name                   string
---@field public position               eve.e.NvimbarCompPosition

---@class fml.t.ux.INvimbar
---@field public cancel_render          fun(self: fml.t.ux.INvimbar): fml.t.ux.INvimbar
---@field public disable                fun(self: fml.t.ux.INvimbar, name: string): fml.t.ux.INvimbar
---@field public enable                 fun(self: fml.t.ux.INvimbar, name: string): fml.t.ux.INvimbar
---@field public place                  fun(self: fml.t.ux.INvimbar, name: string, position: eve.e.NvimbarCompPosition): fml.t.ux.INvimbar
---@field public register               fun(self: fml.t.ux.INvimbar, name: string, component: fml.t.ux.nvimbar.IRawComponent, enabled?: boolean): fml.t.ux.INvimbar
---@field public render                 fun(self: fml.t.ux.INvimbar, force: boolean): string
