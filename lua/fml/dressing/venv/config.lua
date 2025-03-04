local env = require("eve.builtin.env")
local path = require("eve.builtin.path")
local hooks = require("fml.dressing.venv.hook")

---@param var                           string
---@return string
local function getenv(var)
  local v = os.getenv(var) ---@type string|nil
  return v or ""
end

---@class fml.dressing.venv.IManagerPaths
---@field public Poetry                 string
---@field public PDM                    string
---@field public Pipenv                 string
---@field public Pyenv                  string
---@field public Hatch                  string
---@field public VenvWrapper            string
---@field public AnacondaBase           string
---@field public AnacondaEnvs           string

---@type "mac"|"nix"|"win"|"unknow"
local osname = (env.IS_MAC and "mac") --
  or (env.IS_NIX and "nix")
  or (env.IS_WSL and "nix")
  or (env.IS_WIN and "win")
  or "unknow"

-- Use M.getenv here because env variables like $CONDA_PREFIX doesnt get resolved automatically (but $HOME and ~ does).
local ALL_VENV_MANAGER_PATHS = {
  nix = {
    Poetry = "~/.cache/pypoetry/virtualenvs",
    PDM = "~/.local/share/pdm/venvs",
    Pipenv = "~/.local/share/virtualenvs",
    Pyenv = "~/.pyenv/versions",
    Hatch = "~/.local/share/hatch/env/virtual",
    VenvWrapper = "~/.virtualenvs",
    AnacondaBase = getenv("CONDA_PREFIX"),
    AnacondaEnvs = getenv("HOME") .. "/.conda/envs",
  },
  mac = {
    Poetry = "~/Library/Caches/pypoetry/virtualenvs",
    PDM = "~/.local/share/pdm/venvs",
    Pipenv = "~/.local/share/virtualenvs",
    Pyenv = "~/.pyenv/versions",
    Hatch = "~/Library/Application/Support/hatch/env/virtual",
    VenvWrapper = "~/.virtualenvs",
    AnacondaBase = getenv("CONDA_PREFIX"),
    AnacondaEnvs = getenv("HOME") .. "/.conda/envs",
  },
  win = {
    Poetry = getenv("APPDATA") .. "\\pypoetry\\virtualenvs",
    PDM = getenv("APPDATA") .. "\\pdm\\venvs",
    Pipenv = "~\\.virtualenvs",
    Pyenv = getenv("USERPROFILE") .. "\\.pyenv\\pyenv-win\\versions",
    Hatch = getenv("USERPROFILE") .. "\\AppData\\Local\\hatch\\env\\virtual",
    VenvWrapper = getenv("USERPROFILE") .. ".virtualenvs", -- VenvWrapper not supported on Windows but need something here
    AnacondaBase = getenv("CONDA_PREFIX"),
    AnacondaEnvs = getenv("HOME") .. "./conda/envs",
  },
}

---@type fml.dressing.venv.IManagerPaths
local VENV_MANAGER_PATHS = ALL_VENV_MANAGER_PATHS[osname]

---@class fml.dressing.venv.config
local M = {}

M.settings = {
  search = true,
  name = "venv",
  search_workspace = true,
  search_venv_managers = true,
  parents = 2, -- When search is true, go this many directories up from the current opened buffer
  poetry_path = VENV_MANAGER_PATHS.Poetry,
  pdm_path = VENV_MANAGER_PATHS.PDM,
  pipenv_path = VENV_MANAGER_PATHS.Pipenv,
  pyenv_path = VENV_MANAGER_PATHS.Pyenv,
  anaconda_base_path = VENV_MANAGER_PATHS.AnacondaBase,
  anaconda_envs_path = VENV_MANAGER_PATHS.AnacondaEnvs,
  anaconda = {
    python_parent_dir = nil,
    python_executable = nil,
  },
  venvwrapper_path = VENV_MANAGER_PATHS.VenvWrapper,
  hatch_path = VENV_MANAGER_PATHS.Hatch,
  enable_debug_output = false,
  auto_refresh = false, -- Uses cached results from last search
  cache_file = M.get_cache_default_path() .. "venvs.json",
  cache_dir = M.get_cache_default_path(),
  dap_enabled = false,
  notify_user_on_activate = true,
  changed_venv_hooks = {
    hooks.basedpyright_hook,
    hooks.pyright_hook,
    hooks.pylance_hook,
    hooks.pylsp_hook,
  },
}

-- Gets the search path supplied by the user in the setup function, or use current open buffer directory.
function M.get_buffer_dir()
  local buffer_dir
  if M.settings.path == nil then
    buffer_dir = require("telescope.utils").buffer_dir()
    -- buffer_dir = vim.fn.expand("%:p:h")
  else
    buffer_dir = vim.api.nvim_call_function("expand", { M.settings.path })
  end
  return buffer_dir
end

---@return string
function M.get_python_parent_path()
  local parent_dir = M.settings.anaconda.python_parent_dir
  if env.IS_WIN then
    return parent_dir or "Scripts"
  end
  return parent_dir or "bin"
end

---@return string
function M.get_python_name()
  local python_executable = M.settings.anaconda.python_executable
  if env.IS_WIN then
    return python_executable or "python.exe"
  end
  return python_executable or "python"
end

---@return string
function M.get_cache_default_path()
  return path.locate_cache_filepath("venv")
end

return M
