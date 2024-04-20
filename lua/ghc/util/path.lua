local Path = require("plenary.path")

local function findWorkspace()
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

local paths = {
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

return {
  paths = paths,
}
