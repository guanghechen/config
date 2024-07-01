local fs = require("fml.std.fs")

---@return integer
local function get_current_bufid()
  local bufnr = vim.api.nvim_get_current_buf()
  for i, value in ipairs(vim.t.bufs) do
    if value == bufnr then
      return i
    end
  end
  return 0
end

---@class fml.api.buf
---@field public open1              fun(): nil
---@field public open2              fun(): nil
---@field public open3              fun(): nil
---@field public open4              fun(): nil
---@field public open5              fun(): nil
---@field public open6              fun(): nil
---@field public open7              fun(): nil
---@field public open8              fun(): nil
---@field public open9              fun(): nil
---@field public open10             fun(): nil
---@field public open11             fun(): nil
---@field public open12             fun(): nil
---@field public open13             fun(): nil
---@field public open14             fun(): nil
---@field public open15             fun(): nil
---@field public open16             fun(): nil
---@field public open17             fun(): nil
---@field public open18             fun(): nil
---@field public open19             fun(): nil
---@field public open20             fun(): nil
local M = {}

---@param bufid                         integer
---@return nil
function M.open(bufid)
  local totalid = #vim.t.bufs
  local bufid_current = get_current_bufid()
  local bufid_next = fml.fn.navigate_limit(0, bufid, totalid)

  if bufid_current ~= bufid_next then
    vim.api.nvim_set_current_buf(vim.t.bufs[bufid_next])
  end
end

for i = 1, 20 do
  M['open' .. i] = function()
    M.open(i)
  end
end

function M.open_left()
  local step = vim.v.count1 or 1
  local totalid = #vim.t.bufs
  local bufid_current = get_current_bufid()
  local bufid_next = fml.fn.navigate_circular(bufid_current, -step, totalid)

  if bufid_next ~= bufid_current then
    local bufid = vim.t.bufs[bufid_next]
    if type(bufid) == "number" then
      vim.api.nvim_set_current_buf(vim.t.bufs[bufid_next])
    end
  end
end

function M.open_right()
  local step = vim.v.count1 or 1
  local totalid = #vim.t.bufs
  local bufid_current = get_current_bufid()
  local bufid_next = fml.fn.navigate_circular(bufid_current, step, totalid)

  if bufid_next ~= bufid_current then
    local bufid = vim.t.bufs[bufid_next]
    if type(bufid) == "number" then
      vim.api.nvim_set_current_buf(vim.t.bufs[bufid_next])
    end
  end
end

---see https://github.com/NvChad/ui/blob/5fe258afeb248519fc2a1681b48d24208ed22abe/lua/nvchad/tabufline/init.lua#L38
---@param bufnr number
---@return nil
function M.close(bufnr)
  if vim.bo.buftype == "terminal" then
    vim.cmd(vim.bo.buflisted and "set nobl | new" or "hide")
  else
    local curBufIndex = M.locate_buffer_index(bufnr)
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
      vim.cmd("new")
    end

    if not (bufhidden == "delete") then
      vim.cmd("confirm bd" .. bufnr)
    end
  end
end

---@param filepath string
---@return integer|nil
function M.find_buf_with_filepath(filepath)
  ---Expand the filepath to get the absolute path.
  local target_filepath = vim.fn.fnamemodify(filepath, ":p") ---@type string
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      local bufname = vim.api.nvim_buf_get_name(bufnr)
      local buf_filepath = vim.fn.fnamemodify(bufname, ":p")
      if buf_filepath == target_filepath then
        return bufnr
      end
    end
  end
  return nil
end

---@param bufnr number
---@return number|nil
function M.locate_buffer_index(bufnr)
  for i, value in ipairs(vim.t.bufs) do
    if value == bufnr then
      return i
    end
  end
  return nil
end

---@param filepath string
---@return string
function M.read_or_load_buf_with_filepath(filepath)
  local target_filepath = vim.fn.fnamemodify(filepath, ":p") ---@type string
  local target_bufnr = M.find_buf_with_filepath(filepath) ---@type integer|nil

  if target_bufnr ~= nil then
    local lines = vim.api.nvim_buf_get_lines(target_bufnr, 0, -1, false) ---@type string[]
    return table.concat(lines, "\n")
  end

  return fs.read_file({ filepath = target_filepath, silent = true }) or ""
end

return M
