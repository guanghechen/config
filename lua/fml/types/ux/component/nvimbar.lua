---@class t.fml.ux.nvimbar.IPresetContext
---@field public winnr                  ?integer

---@class t.fml.ux.nvimbar.IContext
---@field public tabnr                  integer
---@field public winnr                  integer
---@field public bufnr                  integer
---@field public cwd                    string
---@field public filepath               string
---@field public fileicon               string
---@field public filetype               string
---@field public mode                   t.eve.e.VimModeName
---@field public mode_name              string

---@class t.fml.ux.nvimbar.IRawComponent
---@field public name                   string
---@field public render                 fun(context: t.fml.ux.nvimbar.IContext, remain_width: integer): string, integer
---@field public tight                  ?boolean
---@field public condition              ?fun(context: t.fml.ux.nvimbar.IContext, remain_width: integer): boolean
---@field public will_change            ?fun(context: t.fml.ux.nvimbar.IContext, prev_context: t.fml.ux.nvimbar.IContext|nil, remain_width: integer): boolean

---@class t.fml.ux.nvimbar.IComponent
---@field public enabled                boolean
---@field public last_result_text       string
---@field public last_result_width      integer
---@field public tight                  boolean
---@field public render                 fun(context: t.fml.ux.nvimbar.IContext, remain_width: integer): string, integer
---@field public condition              fun(context: t.fml.ux.nvimbar.IContext, remain_width: integer): boolean
---@field public will_change            fun(context: t.fml.ux.nvimbar.IContext, prev_context: t.fml.ux.nvimbar.IContext|nil, remain_width: integer): boolean

---@class t.fml.ux.nvimbar.IItem
---@field public name                   string
---@field public position               t.eve.e.NvimbarCompPosition

---@class t.fml.ux.INvimbar
---@field public disable                fun(self: t.fml.ux.INvimbar, name: string): t.fml.ux.INvimbar
---@field public enable                 fun(self: t.fml.ux.INvimbar, name: string): t.fml.ux.INvimbar
---@field public place                  fun(self: t.fml.ux.INvimbar, name: string, position: t.eve.e.NvimbarCompPosition): t.fml.ux.INvimbar
---@field public register               fun(self: t.fml.ux.INvimbar, name: string, component: t.fml.ux.nvimbar.IRawComponent, enabled?: boolean): t.fml.ux.INvimbar
---@field public render                 fun(self: t.fml.ux.INvimbar, force: boolean): string
