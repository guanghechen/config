---@meta

---@class dot.theme.hlgroup.IIntegration
---@field public gen_hlgroup_map        fun(context: stl.t.theme.IContext): table<string, stl.t.theme.IHlgroup>

---@class dot.theme.hlgroup.basic.IModesColorMap
---@field public command                string
---@field public confirm                string
---@field public insert                 string
---@field public normal                 string
---@field public nterminal              string
---@field public replace                string
---@field public select                 string
---@field public terminal               string
---@field public visual                 string

---@class dot.theme.hlgroup.basic.IIntegration : dot.theme.hlgroup.IIntegration
---@field public gen_modes_color_map    fun(context: stl.t.theme.IContext): dot.theme.hlgroup.basic.IModesColorMap

---@class dot.theme.hlgroup.nvimbar.IHlgroupMap : table<string, stl.t.theme.IHlgroup>
---@field public f_sl_bg                stl.t.theme.IHlgroup
---@field public f_tl_bg                stl.t.theme.IHlgroup
---@field public f_wl_bg                stl.t.theme.IHlgroup
---@field public f_sl_buf               stl.t.theme.IHlgroup
---@field public f_tl_buf               stl.t.theme.IHlgroup
---@field public f_wl_buf               stl.t.theme.IHlgroup
---@field public f_sl_bufc              stl.t.theme.IHlgroup
---@field public f_tl_bufc              stl.t.theme.IHlgroup
---@field public f_wl_bufc              stl.t.theme.IHlgroup
