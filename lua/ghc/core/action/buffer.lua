local util_navigator = require("guanghechen.util.navigator")

---@param bufnr number
---@return number|nil
local function locate_buffer_index(bufnr)
  for i, value in ipairs(vim.t.bufs) do
    if value == bufnr then
      return i
    end
  end
  return nil
end

---see https://github.com/NvChad/ui/blob/5fe258afeb248519fc2a1681b48d24208ed22abe/lua/nvchad/tabufline/init.lua#L38
---@param bufnr number
---@return nil
local function close_buffer(bufnr)
  if vim.bo.buftype == "terminal" then
    vim.cmd(vim.bo.buflisted and "set nobl | enew" or "hide")
  else
    -- for those who have disabled tabufline
    if not vim.t.bufs then
      vim.cmd("bd")
      return
    end

    local curBufIndex = locate_buffer_index(bufnr)
    local bufhidden = vim.bo.bufhidden

    -- force close floating wins or nonbuflisted
    if (not vim.bo[bufnr].buflisted) or vim.api.nvim_win_get_config(0).zindex then
      vim.cmd("bw")
      return

      -- handle listed bufs
    elseif curBufIndex and #vim.t.bufs > 1 then
      local newBufIndex = curBufIndex == #vim.t.bufs and -1 or 1
      vim.cmd("b" .. vim.t.bufs[curBufIndex + newBufIndex])

      -- handle unlisted
    elseif not vim.bo.buflisted then
      local tmpbufnr = vim.t.bufs[1]

      if vim.g.nv_previous_buf and vim.api.nvim_buf_is_valid(vim.g.nv_previous_buf) then
        tmpbufnr = vim.g.nv_previous_buf
      end

      vim.cmd("b" .. tmpbufnr .. " | bw" .. bufnr)
      return
    else
      vim.cmd("enew")
    end

    if not (bufhidden == "delete") then
      vim.cmd("confirm bd" .. bufnr)
    end
  end

  vim.cmd("redrawtabline")
end

---@class ghc.core.action.buffer
local M = {}

function M.close_buffer()
  local bufnr = vim.api.nvim_get_current_buf() ---@type number
  close_buffer(bufnr)
end

function M.close_buffer_to_leftest()
  local bufnr = vim.api.nvim_get_current_buf() ---@type number
  local bufidx = locate_buffer_index(bufnr) ---@type number|nil

  if bufidx == nil then
    return
  end

  for l_bufidx, l_bufnr in ipairs(vim.t.bufs) do
    if l_bufidx < bufidx then
      close_buffer(l_bufnr)
    end
  end
end

function M.close_buffer_to_rightest()
  local bufnr = vim.api.nvim_get_current_buf() ---@type number
  local bufidx = locate_buffer_index(bufnr) ---@type number|nil

  if bufidx == nil then
    return
  end

  for r_bufidx, r_bufnr in ipairs(vim.t.bufs) do
    if r_bufidx > bufidx then
      close_buffer(r_bufnr)
    end
  end
end

function M.close_buffer_others()
  local bufnr = vim.api.nvim_get_current_buf() ---@type number
  for _, o_bufnr in ipairs(vim.t.bufs) do
    if bufnr ~= o_bufnr then
      close_buffer(o_bufnr)
    end
  end
end

function M.close_buffer_all()
  for _, bufnr in ipairs(vim.t.bufs) do
    close_buffer(bufnr)
  end
  vim.cmd("enew")
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

function M.open_buffer_left()
  local step = vim.v.count1 or 1
  local totalid = #vim.t.bufs
  local bufid_current = M.get_current_bufid()
  local bufid_next = util_navigator.navigate_circular(bufid_current, -step, totalid)

  if bufid_next ~= bufid_current then
    local bufid = vim.t.bufs[bufid_next]
    if type(bufid) == "number" then
      vim.api.nvim_set_current_buf(vim.t.bufs[bufid_next])
    end
  end
end

function M.open_buffer_right()
  local step = vim.v.count1 or 1
  local totalid = #vim.t.bufs
  local bufid_current = M.get_current_bufid()
  local bufid_next = util_navigator.navigate_circular(bufid_current, step, totalid)

  if bufid_next ~= bufid_current then
    local bufid = vim.t.bufs[bufid_next]
    if type(bufid) == "number" then
      vim.api.nvim_set_current_buf(vim.t.bufs[bufid_next])
    end
  end
end

function M.open_buffer_last()
  local bufnr_last = vim.fn.bufnr("#")
  if bufnr_last > 0 then
    vim.api.nvim_set_current_buf(bufnr_last)
  end
end

---@param bufid number
function M.open_buffer(bufid)
  local totalid = #vim.t.bufs
  local bufid_current = M.get_current_bufid()
  local bufid_next = util_navigator.navigate_limit(0, bufid, totalid)

  if bufid_current ~= bufid_next then
    vim.api.nvim_set_current_buf(vim.t.bufs[bufid_next])
  end
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
