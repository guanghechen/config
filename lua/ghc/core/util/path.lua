local Path = require("plenary.path")

local M = {}

M.findGitRepoFromPath = function(p)
  local current_dir = Path:new(p)
  while current_dir ~= nil do
    local gitDir = current_dir:joinpath(".git")
    if gitDir:exists() and gitDir:is_dir() then
      return current_dir
    end

    local parent_dir = current_dir:parent()
    if current_dir:absolute() == parent_dir:absolute() then
      return nil
    end
    current_dir = parent_dir
  end
  return nil
end

M.workspace = function()
  local cwd = vim.uv.cwd()
  return M.findGitRepoFromPath(cwd) or cwd
end

M.cwd = function()
  return vim.uv.cwd()
end

M.current = function()
  return vim.fn.expand("%:p:h")
end

return M
