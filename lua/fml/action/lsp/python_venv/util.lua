local __module_name__ = "fml.action.lsp.python_venv" ---@type string

local env = require("eve.builtin.env")
local path = require("eve.builtin.path")
local reporter = require("eve.builtin.reporter")
local state = require("eve.state")
local config = require("fml.action.lsp.python_venv.config")

---@param text                          string
---@return string
---@return integer
local function escape_pattern(text)
  return string.gsub(text, "([^%w])", "%%%1")
end

-- Keeps track of old system path so we can remove it when adding a new one
local _current_bin_path = nil ---@type string|nil

---@class fml.action.lsp.python_venv.util
local M = {}

-- Manages the paths to python since they are different on Linux, Mac and Windows
-- systems. The user selects the virtual environment to use in the Telescope picker,
-- but inside the virtual environment, the actual python and its parent directory name
-- differs between Linux, Mac and Windows. This function sets up the correct full path
-- to python, adds it to the system path and sets the VIRTUAL_ENV variable.
---@param venv_path                     string
---@return nil
function M.activate_venv(venv_path)
  local python_name = env.IS_WIN and "python.exe" or "python" ---@type string
  local python_parent_path = env.IS_WIN and "Scripts" or "bin" ---@type string

  local new_bin_path = path.join(venv_path, python_parent_path) ---@type string
  local venv_python = path.join(new_bin_path, python_name) ---@type string

  -- Make sure our python exists on disk before activating it, in case paths are wrong
  if vim.fn.executable(venv_python) == 0 then
    reporter.info({
      from = __module_name__,
      subject = "set_venv_and_system_paths",
      message = "The python path '" .. venv_python .. "' does not exist.",
    })
    return
  end

  if config.settings.dap_enabled == true then
    local ok, dap_python = pcall(require, "dap-python")
    if ok and dap_python then
      dap_python.resolve_python = function()
        return venv_python
      end
    end
  end

  reporter.info({
    from = __module_name__,
    subject = "set_venv_and_system_paths",
    message = "Activated '" .. venv_python .. "'",
  })

  config.hook_basedpyright(venv_path, venv_python)
  config.hook_pyright(venv_path, venv_python)
  config.hook_pylance(venv_path, venv_python)
  config.hook_pylsp(venv_path, venv_python)

  local current_system_path = vim.fn.getenv("PATH")
  local prev_bin_path = _current_bin_path

  -- Remove previous bin path from path
  if prev_bin_path ~= nil then
    current_system_path = string.gsub(current_system_path, escape_pattern(prev_bin_path .. env.PATH_ENV_SEP), "")
  end

  -- Add new bin path to path
  local new_system_path = new_bin_path .. env.PATH_ENV_SEP .. current_system_path
  vim.fn.setenv("PATH", new_system_path)
  _current_bin_path = new_bin_path

  -- Set VIRTUAL_ENV
  -- Set CONDA_PREFIX instead if we are on Windows and a conda environment is activated
  if env.IS_WIN then
    local venv_path_std = string.gsub(venv_path, "/", "\\")
    local conda_base_path_std = string.gsub(config.settings.anaconda_base_path, "/", "\\")
    local conda_envs_path_std = string.gsub(config.settings.anaconda_envs_path, "/", "\\")
    local is_conda_base = string.find(venv_path_std, conda_base_path_std)
    local is_conda_env = string.find(venv_path, conda_envs_path_std)
    if is_conda_base == 1 or is_conda_env == 1 then
      vim.fn.setenv("CONDA_PREFIX", venv_path)
    else
      vim.fn.setenv("VIRTUAL_ENV", venv_path)
    end
  else
    vim.fn.setenv("VIRTUAL_ENV", venv_path)
  end
end

---@return nil
function M.deactivate_venv()
  -- Remove previous bin path from path
  local current_system_path = vim.fn.getenv("PATH")
  local prev_bin_path = _current_bin_path

  if prev_bin_path ~= nil then
    current_system_path = string.gsub(current_system_path, escape_pattern(prev_bin_path .. env.PATH_ENV_SEP), "")
    vim.fn.setenv("PATH", current_system_path)
  end

  -- Remove VIRTUAL_ENV environment variable.
  vim.fn.setenv("VIRTUAL_ENV", nil)

  -- TODO: Set pyright to use system python if it exists.
  -- Not sure how to do this in a cross platform compatible way.

  state.lsp.python_venv_path:next(nil)
end

return M
