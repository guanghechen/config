local last_cwd = "" ---@type string
local last_cwd_pieces = {} ---@type string[]

---@class fml.std.path
local M = require("fml.std.path.mod")

---@return boolean
function M.is_git_repo()
  local cwd = vim.fn.getcwd()
  return M.locate_git_repo(cwd) ~= nil
end

---@return string
function M.workspace()
  local cwd = vim.fn.getcwd()
  return M.locate_git_repo(cwd) or cwd
end

---@return string
function M.cwd()
  local cwd = vim.fn.getcwd()
  if cwd ~= last_cwd then
    last_cwd = cwd
    last_cwd_pieces = M.split(cwd)
  end
  return cwd
end

---@return string[]
function M.get_cwd_pieces()
  return last_cwd_pieces
end

---@return string
function M.current_directory()
  return vim.fn.expand("%:p:h")
end

---@return string
function M.current_filepath()
  return vim.api.nvim_buf_get_name(0)
end
