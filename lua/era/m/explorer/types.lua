---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.explorer.types" ---@type string

---@class era.m.explorer.IInputRange
---@field frame                         yoz.ux.treeview.Frame
---@field first                         integer
---@field last                          integer

---@class era.m.explorer.widget.IProps
---@field name                          string
---@field root                          ?string
---@field data                          ?ux.filetree.Data Share resources with an independent state.
---@field session                       ?era.m.explorer.Session Share complete interaction state and jobs.
---@field o_width                       ?stl.c.Observable
---@field o_flag_selected               ?stl.c.Observable
---@field o_flag_viewtype               ?stl.c.Observable
---@field o_flag_foldempty              ?stl.c.Observable
---@field o_flag_hidden                 ?stl.c.Observable
---@field on_disposed                   ?fun(): nil
