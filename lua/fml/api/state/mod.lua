local reporter = require("fml.std.reporter")
local std_array = require("fml.std.array")
local History = require("fml.collection.history")

---@class fml.api.state.ITabItem
---@field public name                   string
---@field public bufnrs                 integer[]
---@field public wins                   table<integer, fml.api.state.ITabWinItem>

---@class fml.api.state.ITabWinItem
---@field public buf_history            fml.types.collection.IHistory

---@class fml.api.state.IBufItem
---@field public filepath               string
---@field public filename               string
---@field public pinned                 boolean

---@class fml.api.state
---@field public IGNORED_FILETYPES      table<string, boolean>
---@field public bufs                   table<integer, fml.api.state.IBufItem>
---@field public tabs                   table<integer, fml.api.state.ITabItem>
---@field public tab_history            fml.types.collection.IHistory
local M = {}

M.IGNORED_FILETYPES = {
  [""] = true,
  ["checkhealth"] = true,
  ["lspinfo"] = true,
  ["neo-tree"] = true,
  ["notify"] = true,
  ["PlenaryTestPopup"] = true,
  ["startuptime"] = true,
  ["term"] = true,
  ["TelescopePrompt"] = true,
  ["Trouble"] = true,
}
M.bufs = {}
M.tabs = {}
M.tab_history = History.new({
  name = "tabs",
  max_count = 100,
  validate = function(tabnr)
    return vim.api.nvim_tabpage_is_valid(tabnr)
  end,
})

---@param bufnr                         integer
---@return integer
function M.count_buf_copies(bufnr)
  local copies = 0 ---@type integer
  for _, tab in pairs(M.tabs) do
    if std_array.contains(tab.bufnrs, bufnr) then
      copies = copies + 1
    end
  end
  return copies
end

---@param bufnr                         integer
---@return fml.api.state.IBufItem|nil
function M.get_buf(bufnr)
  if M.bufs[bufnr] == nil then
    M.refresh_buf(bufnr)
  end

  local buf = M.bufs[bufnr] ---@type fml.api.state.IBufItem|nil
  if buf == nil then
    reporter.error({
      from = "fml.api.state",
      subject = "get_buf",
      message = "Cannot find buf from the state",
      details = { bufnr = bufnr },
    })
  end
  return buf
end

---@return fml.api.state.ITabItem|nil, integer
function M.get_current_tab()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  if M.tabs[tabnr] == nil then
    M.refresh_tab(tabnr)
  end

  local tab = M.tabs[tabnr] ---@type fml.api.state.ITabItem|nil
  if tab == nil then
    reporter.error({
      from = "fml.api.state",
      subject = "get_current_tab",
      message = "Cannot find tab from the state",
      details = { tabnr = tabnr },
    })
  end
  return tab, tabnr
end

---@param bufnr                         integer
---@return boolean
function M.validate_buf(bufnr)
  return vim.api.nvim_buf_is_valid(bufnr) and vim.fn.buflisted(bufnr) == 1
end

---@param tabnr                         integer
---@return boolean
function M.validate_tab(tabnr)
  return vim.api.nvim_tabpage_is_valid(tabnr)
end

return M