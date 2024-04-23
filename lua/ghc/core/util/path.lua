local Path = require("plenary.path")

local M = {}

M.findGitRepoFromPath = function(p)
  local current_dir = Path:new(p)
  while current_dir ~= nil do
    local gitDir = current_dir:joinpath(".git")
    if gitDir:exists() and gitDir:is_dir() then
      return current_dir:absolute()
    end

    local parent_dir = current_dir:parent()
    if current_dir:absolute() == parent_dir:absolute() then
      return nil
    end
    current_dir = parent_dir
  end
  return nil
end

M.relative = function(from, to)
  return Path:new(to):make_relative(from)
end

M.is_absolute = function(p)
  return Path:new(p):is_absolute()
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
