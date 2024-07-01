---@class guanghechen.core.action.buffer
local M = {}

function M.close()
  local bufnr = vim.api.nvim_get_current_buf() ---@type number
  fml.api.buf.close(bufnr)
end

function M.close_to_leftest()
  local bufnr = vim.api.nvim_get_current_buf() ---@type number
  local bufidx = fml.api.buf.locate_buffer_index(bufnr) ---@type number|nil

  if bufidx == nil then
    return
  end

  for l_bufidx, l_bufnr in ipairs(vim.t.bufs) do
    if l_bufidx < bufidx then
      fml.api.buf.close(l_bufnr)
    end
  end
end

function M.close_to_rightest()
  local bufnr = vim.api.nvim_get_current_buf() ---@type number
  local bufidx = fml.api.buf.locate_buffer_index(bufnr) ---@type number|nil

  if bufidx == nil then
    return
  end

  for r_bufidx, r_bufnr in ipairs(vim.t.bufs) do
    if r_bufidx > bufidx then
      fml.api.buf.close(r_bufnr)
    end
  end
end

function M.close_others()
  local bufnr = vim.api.nvim_get_current_buf() ---@type number
  for _, o_bufnr in ipairs(vim.t.bufs) do
    if bufnr ~= o_bufnr then
      fml.api.buf.close(o_bufnr)
    end
  end
end

function M.close_all()
  for _, bufnr in ipairs(vim.t.bufs) do
    fml.api.buf.close(bufnr)
  end
  vim.cmd("new")
end

function M.open_last()
  local bufnr_last = vim.fn.bufnr("#")
  if bufnr_last > 0 then
    vim.api.nvim_set_current_buf(bufnr_last)
  end
end

function M.new_buffer()
  vim.cmd("new")
end

return M
