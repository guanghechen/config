---@class era.dressing.ui_attach.ITask
---@field public event                  string
---@field public args                   any[]

---@alias era.dressing.ui_attach.IHandleTask
---| fun(task: era.dressing.ui_attach.ITask): nil

---@class era.dressing.ui_attach.cmdline.IState
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

---@class era.dressing.ui_attach.message.IState
---@field public history_bufnr          integer|nil
---@field public history_winnr          integer|nil
---@field public last_group             string|nil
---@field public confirming_task        era.dressing.ui_attach.ITask|nil

---@class era.dressing.ui_attach.popupmenu.IState
---@field public items                  string[][]
---@field public selected               integer
---@field public row                    integer
---@field public col                    integer
---@field public grid                   integer
---@field public bufnr                  integer|nil
---@field public winnr                  integer|nil

---@class era.dressing.ui_attach.cmdline_block.IState
---@field public lines                  string[]
---@field public highlights             ark.t.IHighlight[]
---@field public bufnr                  integer|nil
---@field public winnr                  integer|nil

---@class era.dressing.ui_attach.state
local M = {}

M.cmdline = {} ---@type era.dressing.ui_attach.cmdline.IState[]
M.message = {} ---@type era.dressing.ui_attach.message.IState
M.popupmenu = nil ---@type era.dressing.ui_attach.popupmenu.IState|nil
M.cmdline_block = { lines = {}, highlights = {} } ---@type era.dressing.ui_attach.cmdline_block.IState

return M
