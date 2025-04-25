---@class fml.dressing.ui_attach.ITask
---@field public event                  string
---@field public args                   any[]

---@alias fml.dressing.ui_attach.IHandleTask
---| fun(task: fml.dressing.ui_attach.ITask): nil

---@class fml.dressing.ui_attach.cmdline.IState
---@field public pos                    integer
---@field public firstc                 string
---@field public prompt                 string
---@field public indent                 integer
---@field public level                  integer
---@field public hlid                   integer
---@field public icon                   string
---@field public type                   string
---@field public language               string|nil
---@field public concealable            boolean
---@field public first                  string
---@field public second                 string
---@field public bufnr                  integer|nil
---@field public winnr                  integer|nil

---@class fml.dressing.ui_attach.message.IState
---@field public history_bufnr          integer|nil
---@field public history_winnr          integer|nil
---@field public last_group             string|nil
---@field public confirming_task        fml.dressing.ui_attach.ITask|nil

---@class fml.dressing.ui_attach.popupmenu.IState
---@field public items                  string[][]
---@field public selected               integer
---@field public row                    integer
---@field public col                    integer
---@field public grid                   integer
---@field public bufnr                  integer|nil
---@field public winnr                  integer|nil

---@class fml.dressing.ui_attach.state
local M = {}

M.cmdline = {} ---@type fml.dressing.ui_attach.cmdline.IState[]
M.message = {} ---@type fml.dressing.ui_attach.message.IState
M.popupmenu = nil ---@type fml.dressing.ui_attach.popupmenu.IState|nil

return M
