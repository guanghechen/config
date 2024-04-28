---@class ghc.core.action.buffer
local M = {}

function M.close_buffer()
  vim.cmd("bdelete")
end

function M.close_buffer_to_leftest()
  vim.cmd("BufferLineCloseLeft")
end

function M.close_buffer_to_rightest()
  vim.cmd("BufferLineCloseRight")
end

function M.close_buffer_others()
  vim.cmd("BufferLineCloseOthers")
end

function M.close_buffer_all()
  vim.cmd("BufferLineCloseOthers")
  vim.cmd("bdelete")
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
  vim.cmd("BufferLineGoToBuffer 1")
end

function M.open_buffer_2()
  vim.cmd("BufferLineGoToBuffer 2")
end

function M.open_buffer_3()
  vim.cmd("BufferLineGoToBuffer 3")
end

function M.open_buffer_4()
  vim.cmd("BufferLineGoToBuffer 4")
end

function M.open_buffer_5()
  vim.cmd("BufferLineGoToBuffer 5")
end

function M.open_buffer_6()
  vim.cmd("BufferLineGoToBuffer 6")
end

function M.open_buffer_7()
  vim.cmd("BufferLineGoToBuffer 7")
end

function M.open_buffer_8()
  vim.cmd("BufferLineGoToBuffer 8")
end

function M.open_buffer_9()
  vim.cmd("BufferLineGoToBuffer 9")
end

function M.open_buffer_10()
  vim.cmd("BufferLineGoToBuffer 10")
end

function M.new_buffer()
  vim.cmd("enew")
end

return M
