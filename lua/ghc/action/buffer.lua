---@class ghc.action.buffer
local M = {}

function M.close_buffer()
  require("nvchad.tabufline").close_buffer()
end

function M.close_buffer_lefts()
  require("nvchad.tabufline").closeBufs_at_direction("left")
end

function M.close_buffer_rights()
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
  if bufid > 0 and bufid <= #vim.t.bufs then
    vim.api.nvim_set_current_buf(vim.t.bufs[bufid])
  end
end

function M.open_buffer_left()
  if M.is_current_leftest() then
    return
  end

  local step = vim.v.count1 or 1
  local bufid_current = M.get_current_bufid()
  local bufid_new = bufid_current - step
  local bufid_valid = bufid_new > 0 and bufid_new or 1
  vim.api.nvim_set_current_buf(vim.t.bufs[bufid_valid])
end

function M.open_buffer_right()
  if M.is_current_rightest() then
    return
  end

  local step = vim.v.count1 or 1
  local bufid_current = M.get_current_bufid()
  local bufid_new = bufid_current + step
  local bufid_valid = bufid_new < #vim.t.bufs and bufid_new or #vim.t.bufs
  vim.api.nvim_set_current_buf(vim.t.bufs[bufid_valid])
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

return M
