---@class fml.types.core.statusline.IContext
---@field public tabnr                  number
---@field public winnr                  number
---@field public bufnr                  number
---@field public cwd                    string
---@field public filepath               string
---@field public fileicon               string
---@field public filetype               string
---@field public mode                   fml.enums.statusline.VimMode
---@field public mode_name              string

---@class fml.types.core.statusline.IRawComponentPiece
---@field public hlname                 fun(context: fml.types.core.statusline.IContext): string|nil
---@field public text                   fun(context: fml.types.core.statusline.IContext): string|nil
---@field public on_click               ?fun(): boolean

---@class fml.types.core.statusline.IComponentPiece
---@field public hlname                 fun(context: fml.types.core.statusline.IContext): string
---@field public text                   fun(context: fml.types.core.statusline.IContext): string|nil
---@field public callback_fn            string|nil

---@class fml.types.core.statusline.IRawComponent
---@field public name                   string
---@field public pieces                 fml.types.core.statusline.IRawComponentPiece[]
---@field public condition              ?fun(context: fml.types.core.statusline.IContext): boolean
---@field public will_change            ?fun(context: fml.types.core.statusline.IContext, prev_context: fml.types.core.statusline.IContext|nil): boolean

---@class fml.types.core.statusline.IComponent
---@field public name                   string
---@field public position               fml.enums.statusline.ComponentPosition
---@field public pieces                 fml.types.core.statusline.IComponentPiece[]
---@field public last_result            string
---@field public will_change            fun(context: fml.types.core.statusline.IContext, prev_context: fml.types.core.statusline.IContext|nil): boolean
---@field public condition              fun(context: fml.types.core.statusline.IContext): boolean

---@class fml.types.core.IStatusline
---@field public add                    fun(self: fml.types.core.IStatusline, position: fml.enums.statusline.ComponentPosition, raw_component: fml.types.core.statusline.IRawComponent): fml.types.core.IStatusline
---@field public render                 fun(self: fml.types.core.IStatusline): string
