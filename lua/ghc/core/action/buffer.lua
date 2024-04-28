---@class ghc.core.action.buffer
local M = {}

function M.close_buffer()
  require("nvchad.tabufline").close_buffer()
end

function M.close_buffer_to_leftest()
  require("nvchad.tabufline").closeBufs_at_direction("left")
end

function M.close_buffer_to_rightest()
  require("nvchad.tabufline").closeBufs_at_direction("right")
end

function M.close_buffer_others()
  require("nvchad.tabufline").closeOtherBufs()
end

function M.close_buffer_all()
  require("nvchad.tabufline").closeAllBufs()
end

function M.get_current_bufid()
  local bufnr = vim.api.nvim_get_current_buf()
  for i, value in ipairs(vim.t.bufs) do
    if value == bufnr then
      return i
    end
  end
  return 0
end

function M.is_current_leftest()
  if #vim.t.bufs <= 1 then
    return true
  end

  local bufnr_current = vim.api.nvim_get_current_buf()
  return bufnr_current == vim.t.bufs[1]
end

function M.is_current_rightest()
  if #vim.t.bufs <= 1 then
    return true
  end

  local bufnr_current = vim.api.nvim_get_current_buf()
  return bufnr_current == vim.t.bufs[#vim.t.bufs]
end

---@param bufid number
function M.open_buffer(bufid)
  if bufid < 1 or bufid > #vim.t.bufs then
    return
  end

  local bufid_current = M.get_current_bufid()
  if bufid_current == bufid then
    return
  end

  vim.api.nvim_set_current_buf(vim.t.bufs[bufid])
end

function M.open_buffer_left()
  local step = vim.v.count1 or 1
  local bufid_current = M.get_current_bufid()
  local bufid_candidate = bufid_current - step
  local bufid_next = bufid_candidate > 0 and bufid_candidate or 1

  if bufid_next == bufid_current then
    return
  end

  vim.api.nvim_set_current_buf(vim.t.bufs[bufid_next])
end

function M.open_buffer_right()
  local step = vim.v.count1 or 1
  local bufid_current = M.get_current_bufid()
  local bufid_candidate = bufid_current + step
  local bufid_next = bufid_candidate < #vim.t.bufs and bufid_candidate or #vim.t.bufs

  if bufid_next == bufid_current then
    return
  end

  vim.api.nvim_set_current_buf(vim.t.bufs[bufid_next])
end

function M.open_buffer_1()
  M.open_buffer(1)
end

function M.open_buffer_2()
  M.open_buffer(2)
end

function M.open_buffer_3()
  M.open_buffer(3)
end

function M.open_buffer_4()
  M.open_buffer(4)
end

function M.open_buffer_5()
  M.open_buffer(5)
end

function M.open_buffer_6()
  M.open_buffer(6)
end

function M.open_buffer_7()
  M.open_buffer(7)
end

function M.open_buffer_8()
  M.open_buffer(8)
end

function M.open_buffer_9()
  M.open_buffer(9)
end

function M.open_buffer_10()
  M.open_buffer(10)
end

function M.new_buffer()
  vim.cmd("enew")
end

return M
