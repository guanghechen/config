---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.dressing.ui_attach.state" ---@type string

---@class era.dressing.ui_attach.ITask
---@field public event                  string
---@field public args                   any[]

---@alias era.dressing.ui_attach.IContentChunk [integer, string, integer]
---@alias era.dressing.ui_attach.IContent era.dressing.ui_attach.IContentChunk[]

---@alias era.dressing.ui_attach.IHandleTask
---| fun(task: era.dressing.ui_attach.ITask): nil

---@class era.dressing.ui_attach.cmdline.ISpecial
---@field public c                      string
---@field public shift                  boolean

---@class era.dressing.ui_attach.cmdline.IState
---@field public content                era.dressing.ui_attach.IContent
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
---@field public special                era.dressing.ui_attach.cmdline.ISpecial|nil
---@field public confirming_task        era.dressing.ui_attach.ITask|nil
---@field public bufnr                  integer|nil
---@field public winnr                  integer|nil

---Message state is owned by `era.dressing.ui_attach.messages`: UI events flow into
---ordered groups or status fields, then into their renderers. Clears replace
---state first and schedule notifier dismissal; handler failures abort only the
---current event and are not retried.
---@class era.dressing.ui_attach.message.IState
---@field public history_bufnr          integer|nil
---@field public history_winnr          integer|nil
---@field public confirming_task        era.dressing.ui_attach.ITask|nil
---@field public groups                 table<string, era.dressing.ui_attach.message.IGroup>
---@field public id_refs                table<integer|string, era.dressing.ui_attach.message.IRef>
---@field public last_ref               era.dressing.ui_attach.message.IRef|nil
---@field public generation             integer
---@field public showcmd                string
---@field public ruler                  string

---@class era.dressing.ui_attach.message.IPart
---@field public id                     integer|string
---@field public content                era.dressing.ui_attach.IContent

---@class era.dressing.ui_attach.message.IGroup
---@field public key                    string
---@field public parts                  era.dressing.ui_attach.message.IPart[]

---@class era.dressing.ui_attach.message.IRef
---@field public group                  string
---@field public index                  integer

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
---@field public highlights             stl.t.IHighlight[]
---@field public bufnr                  integer|nil
---@field public winnr                  integer|nil

---@class era.dressing.ui_attach.state
---@field public cmdline                era.dressing.ui_attach.cmdline.IState[]
---@field public message                era.dressing.ui_attach.message.IState
---@field public popupmenu              era.dressing.ui_attach.popupmenu.IState|nil
---@field public cmdline_block          era.dressing.ui_attach.cmdline_block.IState
local M = {}

M.cmdline = {} ---@type era.dressing.ui_attach.cmdline.IState[]
M.message = {
  generation = 0,
  groups = {},
  id_refs = {},
  showcmd = "",
  ruler = "",
} ---@type era.dressing.ui_attach.message.IState
M.popupmenu = nil ---@type era.dressing.ui_attach.popupmenu.IState|nil
M.cmdline_block = { lines = {}, highlights = {} } ---@type era.dressing.ui_attach.cmdline_block.IState

---@return era.dressing.ui_attach.cmdline.IState|nil
function M.get_active_cmdline()
  local active = nil ---@type era.dressing.ui_attach.cmdline.IState|nil
  for _, candidate in pairs(M.cmdline) do
    if active == nil or candidate.level > active.level then
      active = candidate
    end
  end
  return active
end

return M
