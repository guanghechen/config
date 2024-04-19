local Path = require("plenary.path")

local function findWorkspace()
  local cwd = vim.uv.cwd()
  local currentDir = Path:new(cwd):absolute()
  repeat
    local gitDir = currentDir:join(".git")
    if gitDir:exists() and gitDir:is_dir() then
      return currentDir
    end
    currentDir = currentDir:parent()
  until currentDir == nil
  return cwd
end

return {
  workspace = function()
    return findWorkspace()
  end,
  cwd = function()
    return vim.uv.cwd()
  end,
  current = function()
    return vim.fn.expand("%:p:h")
  end,
}
