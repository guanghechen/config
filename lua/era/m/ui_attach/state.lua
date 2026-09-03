---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.ui_attach.state" ---@type string

---@class era.m.ui_attach.ITask
---@field public event                  string
---@field public args                   any[]

---@alias era.m.ui_attach.IContentChunk [integer, string, integer]
---@alias era.m.ui_attach.IContent era.m.ui_attach.IContentChunk[]
---@alias era.m.ui_attach.popupmenu.ILabelHighlight { [1]: integer, [2]: integer, [3]: string, [4]: integer }

---@alias era.m.ui_attach.IHandleTask
---| fun(task: era.m.ui_attach.ITask): nil

---@class era.m.ui_attach.cmdline.ISpecial
---@field public c                      string
---@field public shift                  boolean

---@class era.m.ui_attach.cmdline.IState
---@field public content                era.m.ui_attach.IContent
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
---@field public special                era.m.ui_attach.cmdline.ISpecial|nil
---@field public ghost                  string|nil
---@field public echo_text              string|nil one-shot programmatic cmdline echo
---@field public echo_pos               integer|nil 0-indexed programmatic cmdline echo
---@field public preview_redraw_pending boolean|nil
---@field public confirming_task        era.m.ui_attach.ITask|nil
---@field public bufnr                  integer|nil
---@field public winnr                  integer|nil

---Message state is owned by `era.m.ui_attach.messages`: UI events flow into
---ordered groups or status fields, then into their renderers. Clears replace
---state first and schedule notifier dismissal; handler failures abort only the
---current event and are not retried.
---@class era.m.ui_attach.message.IState
---@field public history_bufnr          integer|nil
---@field public history_winnr          integer|nil
---@field public confirming_task        era.m.ui_attach.ITask|nil
---@field public groups                 table<string, era.m.ui_attach.message.IGroup>
---@field public id_refs                table<integer|string, era.m.ui_attach.message.IRef>
---@field public last_ref               era.m.ui_attach.message.IRef|nil
---@field public generation             integer
---@field public showcmd                string
---@field public ruler                  string

---@class era.m.ui_attach.message.IPart
---@field public id                     integer|string
---@field public content                era.m.ui_attach.IContent

---@class era.m.ui_attach.message.IGroup
---@field public key                    string
---@field public parts                  era.m.ui_attach.message.IPart[]

---@class era.m.ui_attach.message.IRef
---@field public group                  string
---@field public index                  integer

---@class era.m.ui_attach.popupmenu.IState
---@field public owner                  string
---@field public generation             integer
---@field public items                  string[][]
---@field public selected               integer
---@field public row                    integer
---@field public col                    integer
---@field public grid                   integer
---@field public bufnr                  integer|nil
---@field public winnr                  integer|nil
---@field public layout                 table|nil
---@field public doc_bufnr              integer|nil
---@field public doc_winnr              integer|nil
---@field public doc_timer              uv.uv_timer_t|nil
---@field public doc_generation         integer|nil
---@field public doc_enabled            boolean|nil
---@field public scrollbar_bufnr        integer|nil
---@field public scrollbar_winnr        integer|nil
---@field public resolve_highlights     (fun(indices: integer[]): table<integer, era.m.ui_attach.popupmenu.ILabelHighlight[]>)|nil
---@field public highlighted_rows       table<integer, boolean>|nil
---@field public label_geometry         { start_col: integer, visible_bytes: integer }[]|nil

---@class era.m.ui_attach.cmdline_block.IState
---@field public lines                  string[]
---@field public highlights             stl.t.IHighlight[]
---@field public bufnr                  integer|nil
---@field public winnr                  integer|nil

---@class era.m.ui_attach.state
---@field public cmdline                era.m.ui_attach.cmdline.IState[]
---@field public message                era.m.ui_attach.message.IState
---@field public popupmenu              era.m.ui_attach.popupmenu.IState|nil
---@field public cmdline_block          era.m.ui_attach.cmdline_block.IState
local M = {}

M.cmdline = {} ---@type era.m.ui_attach.cmdline.IState[]
M.message = {
  generation = 0,
  groups = {},
  id_refs = {},
  showcmd = "",
  ruler = "",
} ---@type era.m.ui_attach.message.IState
M.popupmenu = nil ---@type era.m.ui_attach.popupmenu.IState|nil
M.cmdline_block = { lines = {}, highlights = {} } ---@type era.m.ui_attach.cmdline_block.IState

---@return era.m.ui_attach.cmdline.IState|nil
function M.get_active_cmdline()
  local active = nil ---@type era.m.ui_attach.cmdline.IState|nil
  for _, candidate in pairs(M.cmdline) do
    if active == nil or candidate.level > active.level then
      active = candidate
    end
  end
  return active
end

return M
