---@see https://github.com/nvim-mini/mini.splitjoin

---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.keystroke.splitjoin" ---@type string

---@class era.keystroke.splitjoin.IPosition
---@field public row                    integer
---@field public col                    integer

---@class era.keystroke.splitjoin.IRegion
---@field public from                   era.keystroke.splitjoin.IPosition
---@field public to                     era.keystroke.splitjoin.IPosition

---@class era.keystroke.splitjoin
local M = {}

local initialized = false ---@type boolean

---@return era.keystroke.splitjoin.action
local function get_action()
  return require("era.keystroke.splitjoin.action")
end

---@return era.keystroke.splitjoin.IRegion
function M.get_visual_region()
  return get_action().get_visual_region()
end

---@param specified                     era.keystroke.splitjoin.IRegion|string|nil
---@return nil
function M.split(specified)
  get_action().split(specified)
end

---@param specified                     era.keystroke.splitjoin.IRegion|string|nil
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
    vim.api.nvim_set_option_value("operatorfunc", "v:lua.era.keystroke.splitjoin." .. task, { scope = "global" })
    return "g@ "
  end
end

---@return nil
function M.setup()
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
      callback = ":<C-u>lua era.keystroke.splitjoin.split(era.keystroke.splitjoin.get_visual_region())<CR>",
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
      callback = ":<C-u>lua era.keystroke.splitjoin.join(era.keystroke.splitjoin.get_visual_region())<CR>",
    },
  }
  stl.nvim.fn.bindkeys(keymaps, { noremap = true, silent = true })
end

return M
