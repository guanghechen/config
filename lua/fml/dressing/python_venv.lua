local __module_name__ = "fml.dressing.python_venv" ---@type string

local env = require("eve.std.env")
local fn = require("eve.builtin.fn")
local reporter = require("eve.std.reporter")
local clp = require("eve.constant.lang.python")
local state = require("eve.state")

---@param text                          string
---@return string
---@return integer
local function escape_pattern(text)
  return string.gsub(text, "([^%w])", "%%%1")
end

---@param venv_path                     string
---@param venv_python                   string
---@return nil
---@diagnostic disable-next-line: unused-local
local function hook_basedpyright(venv_path, venv_python)
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
local function hook_pyright(venv_path, venv_python)
  local client = vim.lsp.get_clients({ name = "pyright" })[1]
  if client then
    client.settings.python.pythonPath = venv_python
    client.notify("workspace/didChangeConfiguration", { settings = nil })
  end
end

---@param venv_path                     string
---@param venv_python                   string
---@return nil
---@diagnostic disable-next-line: unused-local
local function hook_pylance(venv_path, venv_python)
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
local function hook_pylsp(venv_path, venv_python)
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

-- Keeps track of old system path so we can remove it when adding a new one
local _current_bin_path = nil ---@type string|nil

---@class fml.dressing.python_venv
local M = {}

-- Manages the paths to python since they are different on Linux, Mac and Windows
-- systems. The user selects the virtual environment to use in the Telescope picker,
-- but inside the virtual environment, the actual python and its parent directory name
-- differs between Linux, Mac and Windows. This function sets up the correct full path
-- to python, adds it to the system path and sets the VIRTUAL_ENV variable.
---@param venv_path                     string
---@return nil
function M.activate_venv(venv_path)
  local venv_python, bin_path = state.lsp.get_python_bin_path() ---@type string|nil, string|nil
  if venv_python == nil or bin_path == nil then
    return
  end

  -- Make sure our python exists on disk before activating it, in case paths are wrong
  if vim.fn.executable(venv_python) == 0 then
    reporter.info({
      from = __module_name__,
      subject = "set_venv_and_system_paths",
      message = "The python path '" .. venv_python .. "' does not exist.",
    })
    return
  end

  reporter.info({
    from = __module_name__,
    subject = "set_venv_and_system_paths",
    message = "Activated '" .. venv_python .. "'",
  })

  hook_basedpyright(venv_path, venv_python)
  hook_pyright(venv_path, venv_python)
  hook_pylance(venv_path, venv_python)
  hook_pylsp(venv_path, venv_python)

  local current_system_path = vim.fn.getenv("PATH")
  local prev_bin_path = _current_bin_path

  -- Remove previous bin path from path
  if prev_bin_path ~= nil then
    current_system_path = string.gsub(current_system_path, escape_pattern(prev_bin_path .. env.PATH_ENV_SEP), "")
  end

  -- Add new bin path to path
  local new_system_path = bin_path .. env.PATH_ENV_SEP .. current_system_path
  vim.fn.setenv("PATH", new_system_path)
  _current_bin_path = bin_path

  -- Set VIRTUAL_ENV
  -- Set CONDA_PREFIX instead if we are on Windows and a conda environment is activated
  if env.IS_WIN then
    local venv_path_std = string.gsub(venv_path, "/", "\\")
    local conda_base_path_std = string.gsub(clp.paths.AnacondaBase, "/", "\\")
    local conda_envs_path_std = string.gsub(clp.paths.AnacondaEnvs, "/", "\\")
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

local initialized = false ---@type boolean

---@return nil
local function setup()
  if not initialized then
    initialized = true

    state.observe({ state.lsp.python_venv_path }, function()
      local venv_path = state.lsp.python_venv_path:snapshot() ---@type string
      if venv_path ~= nil and vim.fn.isdirectory(venv_path) ~= 0 then
        M.activate_venv(venv_path)
      end
    end, true)
  end
end

vim.api.nvim_create_autocmd("FileType", {
  group = fn.augroup("filetype_python_venv"),
  pattern = "python",
  callback = setup,
})

return M
