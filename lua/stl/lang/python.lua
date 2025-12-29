---@param var                           string
---@return string
local function getenv(var)
  local v = os.getenv(var) ---@type string|nil
  return v or ""
end

---@class stl.lang.python.IVenvManagerPaths
---@field public Poetry                 string
---@field public PDM                    string
---@field public Pipenv                 string
---@field public Pyenv                  string
---@field public Hatch                  string
---@field public VenvWrapper            string
---@field public AnacondaBase           string
---@field public AnacondaEnvs           string

---@class stl.lang.python
---@field public paths                  stl.lang.python.IVenvManagerPaths
local M = {}

if stl.env.IS_MAC then
  ---@type stl.lang.python.IVenvManagerPaths
  M.paths = {
    Poetry = "~/Library/Caches/pypoetry/virtualenvs",
    PDM = "~/.local/share/pdm/venvs",
    Pipenv = "~/.local/share/virtualenvs",
    Pyenv = "~/.pyenv/versions",
    Hatch = "~/Library/Application/Support/hatch/env/virtual",
    VenvWrapper = "~/.virtualenvs",
    AnacondaBase = getenv("CONDA_PREFIX"),
    AnacondaEnvs = stl.env.HOME_USER .. "/.app/miniforge3/envs",
  }
elseif stl.env.IS_WIN then
  ---@type stl.lang.python.IVenvManagerPaths
  M.paths = {
    Poetry = getenv("APPDATA") .. "\\pypoetry\\virtualenvs",
    PDM = getenv("APPDATA") .. "\\pdm\\venvs",
    Pipenv = "~\\.virtualenvs",
    Pyenv = stl.env.HOME_USER .. "\\.pyenv\\pyenv-win\\versions",
    Hatch = stl.env.HOME_USER .. "\\AppData\\Local\\hatch\\env\\virtual",
    VenvWrapper = stl.env.HOME_USER .. ".virtualenvs", -- VenvWrapper not supported on Windows but need something here
    AnacondaBase = getenv("CONDA_PREFIX"),
    AnacondaEnvs = "C:\\app\\miniforge\\envs",
  }
else
  ---@type stl.lang.python.IVenvManagerPaths
  M.paths = {
    Poetry = "~/.cache/pypoetry/virtualenvs",
    PDM = "~/.local/share/pdm/venvs",
    Pipenv = "~/.local/share/virtualenvs",
    Pyenv = "~/.pyenv/versions",
    Hatch = "~/.local/share/hatch/env/virtual",
    VenvWrapper = "~/.virtualenvs",
    AnacondaBase = getenv("CONDA_PREFIX"),
    AnacondaEnvs = stl.env.HOME_USER .. "/.app/miniforge3/envs",
  }
end

return M
