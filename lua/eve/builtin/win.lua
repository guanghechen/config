local fs = require("eve.lib.fs")
local path = require("eve.lib.path")
local AdvanceHistory = require("eve.lib.collection.history_advance")
local checks = require("eve.builtin.checks")
local constant = require("eve.builtin.constant")

local meta_map = {} ---@type table<integer, eve.t.state.state.win.IMeta>

---@class eve.builtin.win
local M = {}

---@param winnr                         integer|nil
---@return eve.t.state.state.win.IMeta|nil
function M.get_meta(winnr)
  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    return meta_map[winnr]
  end
end

---@param winnr                         integer|nil
---@param meta                          eve.t.state.state.win.IMeta|nil
---@return eve.t.state.state.win.IMeta|nil
function M.set_meta(winnr, meta)
  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    meta_map[winnr] = meta
    return meta
  end
end

---@param winnr                         integer|nil
---@return nil
function M.del_meta(winnr)
  if winnr ~= nil then
    meta_map[winnr] = nil
  end
end

---@param winnr                         integer|nil
---@return eve.t.state.state.win.IMeta|nil
function M.fork_meta(winnr)
  local meta = M.resolve(winnr) ---@type eve.t.state.state.win.IMeta|nil
  if meta ~= nil then
    ---@type eve.t.state.state.win.IMeta
    local meta_forked = {
      filepath_history = meta.filepath_history:fork({ name = "win_filepath" }),
      lsp_symbols = vim.list_slice(meta.lsp_symbols),
    }
    return meta_forked
  end
end

---@param winnr_a                       integer|nil
---@param winnr_b                       integer|nil
---@return nil
function M.swap_meta(winnr_a, winnr_b)
  local meta_a = M.resolve(winnr_a) ---@type eve.t.state.state.win.IMeta|nil
  local meta_b = M.resolve(winnr_b) ---@type eve.t.state.state.win.IMeta|nil
  M.set_meta(winnr_a, meta_b)
  M.set_meta(winnr_b, meta_a)
end

---@param winnr                         integer|nil
---@return eve.t.state.state.win.IMeta|nil
function M.resolve(winnr)
  if winnr == nil or not checks.is_win_valid(winnr) then
    return nil
  end

  local meta = M.get_meta(winnr) ---@type eve.t.state.state.win.IMeta|nil
  if meta ~= nil then
    return meta
  end

  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
  local filepath_history = AdvanceHistory.new({
    name = "win#bufs",
    capacity = constant.WIN_BUF_HISTORY_CAPACITY,
    validate = checks.is_valid_filepath,
  })
  filepath_history:push(filepath)

  ---@type eve.t.state.state.win.IMeta
  meta = {
    filepath_history = filepath_history,
    lsp_symbols = {},
  }
  return M.set_meta(winnr, meta)
end

---@param winnr                         integer|nil
---@return eve.t.state.state.win.IMeta|nil
function M.refresh(winnr)
  if winnr == nil then
    return
  end

  local meta = M.get_meta(winnr) ---@type eve.t.state.state.win.IMeta|nil
  if meta == nil then
    return M.resolve(winnr)
  end

  --- FIXME update the win meta
end

---@return nil
function M.refresh_all()
  local winnrs = vim.api.nvim_list_wins() ---@type integer[]
  for _, winnr in ipairs(winnrs) do
    M.refresh(winnr)
  end
end

---@param tabnr                         integer
---@return nil
function M.refresh_tabpage_wins(tabnr)
  local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
  for _, winnr in ipairs(winnrs) do
    M.refresh(winnr)
  end
end

---@param bufnr                         integer
---@return nil
function M.on_buf_enter(bufnr)
  if bufnr == nil or not checks.is_buf_valid(bufnr) then
    return
  end

  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local meta = M.resolve(winnr) ---@type eve.t.state.state.win.IMeta|nil
  if meta == nil then
    return
  end

  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
  meta.filepath_history:push(filepath)
end

----------------------------------------------------------------------------------------------------

---@class eve.builtin.win.IDetails
---@field public winnr                  integer
---@field public bufnr                  integer
---@field public filepath               string|nil
---@field public dirpath                string|nil

---@param winnr                         integer|nil
---@return eve.builtin.win.IDetails|nil
function M.get_details(winnr)
  if winnr == nil or not checks.is_win_valid(winnr) then
    return nil
  end

  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
  local filetype = fs.is_file_or_dir(filepath) ---@type eve.e.FileType|nil
  if filetype == "file" or filetype == "directory" then
    local dirpath = filetype == "file" and path.dirname(filepath) or filepath ---@type string
    dirpath = path.normalize(dirpath)
    return { winnr = winnr, bufnr = bufnr, filepath = filepath, dirpath = dirpath }
  end
  return { winnr = winnr, bufnr = bufnr }
end

return M
