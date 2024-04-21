local M = {}

local Path = require("plenary.path")

M.workspace = function()
  local cwd = vim.uv.cwd()
  local currentDir = Path:new(cwd)
  while currentDir ~= nil do
    local gitDir = currentDir:joinpath(".git")
    if gitDir:exists() and gitDir:is_dir() then
      return currentDir
    end
    currentDir = currentDir:parent()
  end
  return cwd
end

M.cwd = function()
  return vim.uv.cwd()
end

M.current = function()
  return vim.fn.expand("%:p:h")
end

return M
