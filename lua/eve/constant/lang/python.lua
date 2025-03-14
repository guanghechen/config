---@param var                           string
---@return string
local function getenv(var)
  local v = os.getenv(var) ---@type string|nil
  return v or ""
end

---@class eve.constant.lang.python.IVenvManagerPaths
---@field public Poetry                 string
---@field public PDM                    string
---@field public Pipenv                 string
---@field public Pyenv                  string
---@field public Hatch                  string
---@field public VenvWrapper            string
---@field public AnacondaBase           string
---@field public AnacondaEnvs           string

---@type "mac"|"nix"|"win"|"unknown"
local osname = (eve.env.IS_MAC and "mac") --
  or (eve.env.IS_NIX and "nix")
  or (eve.env.IS_WSL and "nix")
  or (eve.env.IS_WIN and "win")
  or "unknown"

-- Use M.getenv here because env variables like $CONDA_PREFIX does not get resolved automatically (but $HOME and ~ does).
local ALL_VENV_MANAGER_PATHS = {
  nix = {
    Poetry = "~/.cache/pypoetry/virtualenvs",
    PDM = "~/.local/share/pdm/venvs",
    Pipenv = "~/.local/share/virtualenvs",
    Pyenv = "~/.pyenv/versions",
    Hatch = "~/.local/share/hatch/env/virtual",
    VenvWrapper = "~/.virtualenvs",
    AnacondaBase = getenv("CONDA_PREFIX"),
    AnacondaEnvs = getenv("HOME") .. "/.app/miniforge3/envs",
  },
  mac = {
    Poetry = "~/Library/Caches/pypoetry/virtualenvs",
    PDM = "~/.local/share/pdm/venvs",
    Pipenv = "~/.local/share/virtualenvs",
    Pyenv = "~/.pyenv/versions",
    Hatch = "~/Library/Application/Support/hatch/env/virtual",
    VenvWrapper = "~/.virtualenvs",
    AnacondaBase = getenv("CONDA_PREFIX"),
    AnacondaEnvs = getenv("HOME") .. "/.app/miniforge3/envs",
  },
  win = {
    Poetry = getenv("APPDATA") .. "\\pypoetry\\virtualenvs",
    PDM = getenv("APPDATA") .. "\\pdm\\venvs",
    Pipenv = "~\\.virtualenvs",
    Pyenv = getenv("USERPROFILE") .. "\\.pyenv\\pyenv-win\\versions",
    Hatch = getenv("USERPROFILE") .. "\\AppData\\Local\\hatch\\env\\virtual",
    VenvWrapper = getenv("USERPROFILE") .. ".virtualenvs", -- VenvWrapper not supported on Windows but need something here
    AnacondaBase = getenv("CONDA_PREFIX"),
    AnacondaEnvs = "C:\\app\\miniforge3\\envs",
  },
}

---@class eve.constant.lang.python
---@field paths eve.constant.lang.python.IVenvManagerPaths
local M = {
  paths = ALL_VENV_MANAGER_PATHS[osname],
}

return M
