local action_buffer = require("ghc.core.action.buffer")

---@class ghc.core.action.tab
local M = {}

---@param tabnr number
function M.find_tabid(tabnr)
  local tabpages = vim.api.nvim_list_tabpages()
  for i, value in ipairs(tabpages) do
    if tabnr == value then
      return i
    end
  end
end

function M.close_tab_current()
  local tabnr_last = vim.g.ghc_last_tabnr
  vim.cmd("tabclose")
  if tabnr_last ~= nil then
    local ok, err = pcall(function()
      vim.api.nvim_set_current_tabpage(tabnr_last)
    end)
    if not ok then
      vim.api.ghc_last_tabnr = nil
    end
  end
end

---@param count number
function M.close_tab_lefts(count)
  local tabpages = vim.api.nvim_list_tabpages()
  if #tabpages <= 1 then
    return
  end

  local tabnr_current = vim.api.nvim_get_current_tabpage()
  local tabid_current = M.find_tabid(tabnr_current)
  local step = math.min(count, tabid_current - 1)

  local i = 0
  while i < step do
    vim.cmd("-tabclose")
    i = i + 1
  end
end

---@param count number
function M.close_tab_rights(count)
  local tabpages = vim.api.nvim_list_tabpages()
  if #tabpages <= 1 then
    return
  end

  local tabnr_current = vim.api.nvim_get_current_tabpage()
  local tabid_current = M.find_tabid(tabnr_current)
  local step = math.min(count, #tabpages - tabid_current)

  local i = 0
  while i < step do
    vim.cmd("+tabclose")
    i = i + 1
  end
end

function M.close_tab_to_leftest()
  M.close_tab_lefts(math.huge)
end

function M.close_tab_to_rightest()
  M.close_tab_rights(math.huge)
end

function M.close_tab_others()
  vim.cmd("tabonly")
end

function M.goto_tab_left()
  local tabpages = vim.api.nvim_list_tabpages()
  local totalid = #tabpages
  if totalid <= 1 then
    return
  end

  local step = vim.v.count1 or 1
  local tabnr_current = vim.api.nvim_get_current_tabpage()
  local tabid_current = M.find_tabid(tabnr_current)
  local tabid_next = fml.fn.navigate_circular(tabid_current, -step, totalid)

  if tabid_next ~= tabid_current then
    local tabnr_next = tabpages[tabid_next]
    vim.api.nvim_set_current_tabpage(tabnr_next)
  end
end

function M.goto_tab_right()
  local tabpages = vim.api.nvim_list_tabpages()
  local totalid = #tabpages
  if totalid <= 1 then
    return
  end

  local step = vim.v.count1 or 1
  local tabnr_current = vim.api.nvim_get_current_tabpage()
  local tabid_current = M.find_tabid(tabnr_current)
  local tabid_next = fml.fn.navigate_circular(tabid_current, step, totalid)

  if tabid_next ~= tabid_current then
    local tabnr_next = tabpages[tabid_next]
    vim.api.nvim_set_current_tabpage(tabnr_next)
  end
end

function M.goto_tab(tabid)
  local tabpages = vim.api.nvim_list_tabpages()
  local totalid = #tabpages
  if totalid <= 1 then
    return
  end

  local tabnr_current = vim.api.nvim_get_current_tabpage()
  local tabid_next = fml.fn.navigate_limit(0, tabid, totalid)
  local tabnr_next = tabpages[tabid_next]

  if tabnr_current ~= tabnr_next then
    vim.api.nvim_set_current_tabpage(tabnr_next)
  end
end

function M.goto_tab_1()
  M.goto_tab(1)
end

function M.goto_tab_2()
  M.goto_tab(2)
end

function M.goto_tab_3()
  M.goto_tab(3)
end

function M.goto_tab_4()
  M.goto_tab(4)
end

function M.goto_tab_5()
  M.goto_tab(5)
end

function M.goto_tab_6()
  M.goto_tab(6)
end

function M.goto_tab_7()
  M.goto_tab(7)
end

function M.goto_tab_8()
  M.goto_tab(8)
end

function M.goto_tab_9()
  M.goto_tab(9)
end

function M.goto_tab_10()
  M.goto_tab(10)
end

function M.open_tab_new()
  -- Opens tabpage after the last one
  vim.cmd("$tabnew")
end

function M.open_tab_new_with_current_buf()
  local winnr_current = vim.api.nvim_get_current_win()
  local bufnr_current = vim.api.nvim_win_get_buf(winnr_current)
  local cursor_current = vim.api.nvim_win_get_cursor(winnr_current)

  -- Opens tabpage after the last one and open current buffer
  vim.cmd("$tabnew")
  vim.api.nvim_win_set_buf(0, bufnr_current)
  vim.api.nvim_win_set_cursor(0, cursor_current)
  action_buffer.close_buffer_others()
end

return M
