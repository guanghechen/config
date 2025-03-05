local env = require("eve.builtin.env")

---@param var                           string
---@return string
local function getenv(var)
  local v = os.getenv(var) ---@type string|nil
  return v or ""
end

---@class fml.action.lsp.python_venv.IManagerPaths
---@field public Poetry                 string
---@field public PDM                    string
---@field public Pipenv                 string
---@field public Pyenv                  string
---@field public Hatch                  string
---@field public VenvWrapper            string
---@field public AnacondaBase           string
---@field public AnacondaEnvs           string

---@type "mac"|"nix"|"win"|"unknown"
local osname = (env.IS_MAC and "mac") --
  or (env.IS_NIX and "nix")
  or (env.IS_WSL and "nix")
  or (env.IS_WIN and "win")
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

---@type fml.action.lsp.python_venv.IManagerPaths
local VENV_MANAGER_PATHS = ALL_VENV_MANAGER_PATHS[osname]

---@class fml.action.lsp.python_venv.config
local M = {}

M.settings = {
  poetry_path = VENV_MANAGER_PATHS.Poetry,
  pdm_path = VENV_MANAGER_PATHS.PDM,
  pipenv_path = VENV_MANAGER_PATHS.Pipenv,
  pyenv_path = VENV_MANAGER_PATHS.Pyenv,
  anaconda_base_path = VENV_MANAGER_PATHS.AnacondaBase,
  anaconda_envs_path = VENV_MANAGER_PATHS.AnacondaEnvs,
  venvwrapper_path = VENV_MANAGER_PATHS.VenvWrapper,
  hatch_path = VENV_MANAGER_PATHS.Hatch,
  dap_enabled = false,
}

---@param venv_path                     string
---@param venv_python                   string
---@return nil
---@diagnostic disable-next-line: unused-local
function M.hook_basedpyright(venv_path, venv_python)
  local client = vim.lsp.get_clients({ name = "basedpyright" })[1]
  if client then
    if client.settings then
      client.settings = vim.tbl_deep_extend("force", client.settings, { python = { pythonPath = venv_python } })
    else
      client.config.settings =
        vim.tbl_deep_extend("force", client.config.settings, { python = { pythonPath = venv_python } })
    end
    client.notify("workspace/didChangeConfiguration", { settings = nil })
  end
end

---@param venv_path                     string
---@param venv_python                   string
---@return nil
---@diagnostic disable-next-line: unused-local
function M.hook_pyright(venv_path, venv_python)
  local client = vim.lsp.get_clients({ name = "pyright" })[1]
  if client then
    if client.settings then
      client.settings = vim.tbl_deep_extend("force", client.settings, { python = { pythonPath = venv_python } })
    else
      client.config.settings =
        vim.tbl_deep_extend("force", client.config.settings, { python = { pythonPath = venv_python } })
    end
    client.notify("workspace/didChangeConfiguration", { settings = nil })
  end
end

---@param venv_path                     string
---@param venv_python                   string
---@return nil
---@diagnostic disable-next-line: unused-local
function M.hook_pylance(venv_path, venv_python)
  local client = vim.lsp.get_clients({ name = "pylance" })[1]
  if client then
    if client.settings then
      client.settings = vim.tbl_deep_extend("force", client.settings, { python = { pythonPath = venv_python } })
    else
      client.config.settings =
        vim.tbl_deep_extend("force", client.config.settings, { python = { pythonPath = venv_python } })
    end
    client.notify("workspace/didChangeConfiguration", { settings = nil })
  end
end

---@param venv_path                     string
---@param venv_python                   string
---@return nil
---@diagnostic disable-next-line: unused-local
function M.hook_pylsp(venv_path, venv_python)
  local client = vim.lsp.get_clients({ name = "pylsp" })[1]
  if client then
    local settings = vim.tbl_deep_extend("force", (client.settings or client.config.settings), {
      pylsp = {
        plugins = {
          jedi = {
            environment = venv_python,
          },
        },
      },
    })
    client.notify("workspace/didChangeConfiguration", { settings = settings })
  end
end

return M
