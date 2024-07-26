local constant = require("fml.constant")
local path = require("fml.std.path")

---@class fml.api.state
local M = require("fml.api.state.mod")

---@return nil
function M.refresh_bufs()
  local bufnrs = vim.api.nvim_list_bufs() ---@type integer[]
  local bufs = {} ---@type table<integer, fml.types.api.state.IBufItem>
  for _, bufnr in ipairs(bufnrs) do
    local buf = M.refresh_buf(bufnr) ---@type fml.types.api.state.IBufItem|nil
    if buf ~= nil then
      bufs[bufnr] = buf
    end
  end

  M.bufs = bufs
end

---@param bufnr                         integer|nil
---@return fml.types.api.state.IBufItem|nil
function M.refresh_buf(bufnr)
  if bufnr == nil or type(bufnr) ~= "number" then
    return
  end

  if not M.validate_buf(bufnr) then
    M.bufs[bufnr] = nil
    return
  end

  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string

  local buf = M.bufs[bufnr] ---@type fml.types.api.state.IBufItem|nil
  if buf == nil then
    local filename = path.basename(filepath) ---@type string
    filename = (not filename or filename == "") and constant.BUF_UNTITLED or filename

    ---@type fml.types.api.state.IBufItem
    buf = {
      filepath = filepath,
      filename = filename,
      real_paths = path.split_prettier(path.get_cwd_pieces(), filepath),
      pinned = false,
    }
    M.bufs[bufnr] = buf
  elseif buf.filepath ~= filepath then
    local filename = path.basename(filepath) ---@type string
    filename = #filename > 0 and filename or constant.BUF_UNTITLED
    buf.filepath = filepath
    buf.filename = filename
  end
  return buf
end

---@param bufnrs                        ?integer[]
---@return integer
function M.remove_unrefereced_bufs(bufnrs)
  bufnrs = bufnrs or vim.api.nvim_list_bufs() ---@type integer[]
  local bufnrs_to_remove = {} ---@type integer[]
  for _, bufnr in ipairs(bufnrs) do
    if M.validate_buf(bufnr) then
      local has_copy = false ---@type boolean
      for _, tab in pairs(M.tabs) do
        if tab.bufnr_set[bufnr] then
          has_copy = true
          break
        end
      end

      if not has_copy then
        M.bufs[bufnr] = nil
        table.insert(bufnrs_to_remove, bufnr)
      end
    else
      M.bufs[bufnr] = nil
    end
  end

  for _, bufnr in ipairs(bufnrs_to_remove) do
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
  return #bufnrs_to_remove
end
