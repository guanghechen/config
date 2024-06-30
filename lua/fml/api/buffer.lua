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

---@class fml.api.buffer
---@field public goto_buf1              fun(): nil
---@field public goto_buf2              fun(): nil
---@field public goto_buf3              fun(): nil
---@field public goto_buf4              fun(): nil
---@field public goto_buf5              fun(): nil
---@field public goto_buf6              fun(): nil
---@field public goto_buf7              fun(): nil
---@field public goto_buf8              fun(): nil
---@field public goto_buf9              fun(): nil
---@field public goto_buf10             fun(): nil
---@field public goto_buf11             fun(): nil
---@field public goto_buf12             fun(): nil
---@field public goto_buf13             fun(): nil
---@field public goto_buf14             fun(): nil
---@field public goto_buf15             fun(): nil
---@field public goto_buf16             fun(): nil
---@field public goto_buf17             fun(): nil
---@field public goto_buf18             fun(): nil
---@field public goto_buf19             fun(): nil
---@field public goto_buf20             fun(): nil
local M = {}

---@param bufid                         integer
---@return nil
function M.goto_buf(bufid)
  local totalid = #vim.t.bufs
  local bufid_current = get_current_bufid()
  local bufid_next = fml.fn.navigate_limit(0, bufid, totalid)

  if bufid_current ~= bufid_next then
    vim.api.nvim_set_current_buf(vim.t.bufs[bufid_next])
  end
end

for i = 1, 20 do
  M['goto_buf' .. i] = function()
    M.goto_buf(i)
  end
end

---see https://github.com/NvChad/ui/blob/5fe258afeb248519fc2a1681b48d24208ed22abe/lua/nvchad/tabufline/init.lua#L38
---@param bufnr number
---@return nil
function M.close_buffer(bufnr)
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
function M.read_of_load_buf_with_filepath(filepath)
  local target_filepath = vim.fn.fnamemodify(filepath, ":p") ---@type string
  local target_bufnr = M.find_buf_with_filepath(filepath) ---@type integer|nil

  if target_bufnr ~= nil then
    local lines = vim.api.nvim_buf_get_lines(target_bufnr, 0, -1, false) ---@type string[]
    return table.concat(lines, "\n")
  end

  return fs.read_file({ filepath = target_filepath, silent = true }) or ""
end

return M
