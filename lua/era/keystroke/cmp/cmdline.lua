---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.keystroke.cmp.cmdline" ---@type string

local Context = require("era.keystroke.cmp.context")
local M = {}
local queued = false

---@return boolean
function M.enabled()
  if vim.api.nvim_get_mode().mode ~= "c" then
    return false
  end
  local cmdtype = vim.fn.getcmdtype()
  return cmdtype == ":" or cmdtype == "/" or cmdtype == "?" or cmdtype == "@"
end

---@return boolean
function M.is_visible()
  return M.enabled() and vim.fn.pumvisible() == 1
end

---@return boolean
function M.show()
  if not M.enabled() then
    return false
  end
  local cmdtype = vim.fn.getcmdtype()
  if
    (cmdtype == "/" or cmdtype == "?") and Context.is_private(vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf()))
  then
    return true
  end
  vim.o.wildmode = cmdtype == ":" and "noselect:full,full" or "full"
  vim.fn.wildtrigger()
  return true
end

---@return nil
function M.update()
  if queued then
    return
  end
  queued = true
  -- The external cmdline UI must register its native window anchor before expansion begins.
  vim.schedule(function()
    queued = false
    if vim.fn.getcmdtype() == ":" then
      M.show()
    end
  end)
end

---@param direction                     integer
---@return boolean
function M.select(direction)
  if not M.is_visible() then
    return false
  end
  local info = vim.fn.cmdcomplete_info()
  local index = info.selected == -1 and (direction > 0 and 0 or #info.matches - 1) or info.selected + direction
  if index < 0 or index >= #info.matches then
    index = -1
  end
  vim.api.nvim_select_popupmenu_item(index, false, false, {})
  return true
end

---@param index                         ?integer
---@return boolean
function M.accept(index)
  if not M.is_visible() then
    return false
  end
  vim.api.nvim_select_popupmenu_item(
    index and index - 1 or math.max(0, vim.fn.cmdcomplete_info().selected),
    false,
    true,
    {}
  )
  return true
end

---@param cancel                        ?boolean
---@return boolean
function M.hide(cancel)
  if not M.is_visible() then
    return false
  end
  vim.api.nvim_select_popupmenu_item(cancel and -1 or vim.fn.cmdcomplete_info().selected, false, true, {})
  return true
end

---@param direction                     integer
---@return boolean
function M.tab(direction)
  if M.is_visible() and #vim.fn.cmdcomplete_info().matches == 1 then
    return M.accept()
  end
  return M.select(direction) or M.show()
end

return M
