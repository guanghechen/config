---@see https://github.com/nvim-mini/mini.splitjoin

---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.splitjoin" ---@type string

---@class era.m.splitjoin.IPosition
---@field public row                    integer
---@field public col                    integer

---@class era.m.splitjoin.IRegion
---@field public from                   era.m.splitjoin.IPosition
---@field public to                     era.m.splitjoin.IPosition

---@class era.m.splitjoin
local M = {}

local initialized = false ---@type boolean

---@return era.m.splitjoin.action
local function get_action()
  return require("era.m.splitjoin.action")
end

---@return era.m.splitjoin.IRegion
function M.get_visual_region()
  return get_action().get_visual_region()
end

---@param specified                    era.m.splitjoin.IRegion|string|nil
---@return nil
function M.split(specified)
  get_action().split(specified)
end

---@param specified                    era.m.splitjoin.IRegion|string|nil
---@return nil
function M.join(specified)
  get_action().join(specified)
end

---@param task                          "split"|"join"
---@return fun(): string
local function make_operator(task)
  return function()
    if not get_action().is_available(vim.api.nvim_get_current_buf()) then
      return "<Esc>"
    end
    vim.api.nvim_set_option_value("operatorfunc", "v:lua.era.m.splitjoin." .. task, { scope = "global" })
    return "g@ "
  end
end

---@return nil
function M.dressing()
  if initialized then
    return
  end
  initialized = true

  ---@type stl.t.IKeymap[]
  local keymaps = {
    {
      modes = { "n" },
      key = "gS",
      desc = "splitjoin: split",
      callback = make_operator("split"),
      expr = true,
    },
    {
      modes = { "x" },
      key = "gS",
      desc = "splitjoin: split",
      callback = ":<C-u>lua era.m.splitjoin.split(era.m.splitjoin.get_visual_region())<CR>",
    },
    {
      modes = { "n" },
      key = "gJ",
      desc = "splitjoin: join",
      callback = make_operator("join"),
      expr = true,
    },
    {
      modes = { "x" },
      key = "gJ",
      desc = "splitjoin: join",
      callback = ":<C-u>lua era.m.splitjoin.join(era.m.splitjoin.get_visual_region())<CR>",
    },
  }
  stl.nvim.fn.bindkeys(keymaps, { noremap = true, silent = true })
end

return M
