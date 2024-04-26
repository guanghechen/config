local Path = require("plenary.path")

local M = {}

function M.findGitRepoFromPath(p)
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

function M.relative(from, to)
  return Path:new(to):make_relative(from)
end

function M.is_absolute(p)
  return Path:new(p):is_absolute()
end

function M.workspace()
  local cwd = vim.uv.cwd()
  return M.findGitRepoFromPath(cwd) or cwd
end

function M.cwd()
  return vim.uv.cwd()
end

function M.current()
  return vim.fn.expand("%:p:h")
end

return M
