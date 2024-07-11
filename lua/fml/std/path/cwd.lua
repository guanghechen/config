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
  return vim.fn.getcwd()
end

---@return string
function M.current_directory()
  return vim.fn.expand("%:p:h")
end

---@return string
function M.current_filepath()
  return vim.api.nvim_buf_get_name(0)
end
