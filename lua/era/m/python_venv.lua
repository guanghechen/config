---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.python_venv" ---@type string

----------------------------------------------------------------------------------------------------
-- Helper functions
----------------------------------------------------------------------------------------------------

---@param text                          string
---@return string
---@return integer
local function escape_pattern(text)
  return string.gsub(text, "([^%w])", "%%%1")
end

---@param folder                        string
---@return string|nil
local function format_search_path(folder)
  local resolved_path = vim.fn.expand(folder) ---@type string
  if #resolved_path < 1 or vim.fn.isdirectory(resolved_path) == 0 then
    return nil
  end

  resolved_path = resolved_path:gsub(" ", "\\ ")
  if folder == stl.lang.python.paths.Hatch then
    return resolved_path .. "/*/*"
  else
    return resolved_path
  end
end

----------------------------------------------------------------------------------------------------
-- LSP hooks
----------------------------------------------------------------------------------------------------

---@param venv_path                     string
---@param venv_python                   string
---@return nil
---@diagnostic disable-next-line: unused-local
local function hook_basedpyright(venv_path, venv_python)
  local client = vim.lsp.get_clients({ name = "basedpyright" })[1]
  if client then
    local settings = client.config.settings or {}
    settings.python = settings.python or {}
    ---@diagnostic disable-next-line: inject-field
    settings.python.pythonPath = venv_python
    client.config.settings = settings
    client.settings = settings
    client:notify("workspace/didChangeConfiguration", { settings = settings })
  end
end

---@param venv_path                     string
---@param venv_python                   string
---@return nil
---@diagnostic disable-next-line: unused-local
local function hook_pyright(venv_path, venv_python)
  local client = vim.lsp.get_clients({ name = "pyright" })[1]
  if client then
    local settings = client.config.settings or {}
    settings.python = settings.python or {}
    ---@diagnostic disable-next-line: inject-field
    settings.python.pythonPath = venv_python
    client.config.settings = settings
    client.settings = settings
    client:notify("workspace/didChangeConfiguration", { settings = settings })
  end
end

---@param venv_path                     string
---@param venv_python                   string
---@return nil
---@diagnostic disable-next-line: unused-local
local function hook_pylance(venv_path, venv_python)
  local client = vim.lsp.get_clients({ name = "pylance" })[1]
  if client then
    local settings = client.config.settings or {}
    settings.python = settings.python or {}
    ---@diagnostic disable-next-line: inject-field
    settings.python.pythonPath = venv_python
    client.config.settings = settings
    client.settings = settings
    client:notify("workspace/didChangeConfiguration", { settings = settings })
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
    client:notify("workspace/didChangeConfiguration", { settings = settings })
  end
end

----------------------------------------------------------------------------------------------------
-- Picker
----------------------------------------------------------------------------------------------------

---@class era.m.python_venv.IItemData
---@field public icon                   string
---@field public path                   string

---@class era.m.python_venv.IItem : era.m.picker.composer.list.IItem
---@field public data                   era.m.python_venv.IItemData
---@field public text_lower             string
---@field public highlights             table

local dirty_data = true ---@type boolean
local o_search_pattern = stl.c.Observable.from_value("")
local o_flag_fuzzy = stl.c.Observable.from_value(true)
local o_flag_regex = stl.c.Observable.from_value(false)
local o_flag_case_sensitive = stl.c.Observable.from_value(false)
local o_python_venv_path = dot.context.lsp.python_venv_path

---@return era.m.picker.composer.list.IResetData
local function fetch_data()
  dirty_data = false

  local cwd = dot.path.cwd() ---@type string
  local workspace = dot.path.workspace() ---@type string

  local items = {} ---@type era.m.python_venv.IItem[]
  local uuid_set = {} ---@type table<string, true>

  do
    local anaconda_base_path = format_search_path(stl.lang.python.paths.AnacondaBase) ---@type string|nil
    local anaconda_envs_path = format_search_path(stl.lang.python.paths.AnacondaEnvs) ---@type string|nil

    ---@type string[]
    local cmd = {
      "fd",
      "--absolute-path",
      "--color",
      "never",
      "-E",
      "/proc",
    }
    if anaconda_base_path then
      table.insert(cmd, "-E")
      table.insert(cmd, anaconda_base_path)
    end
    if anaconda_envs_path then
      table.insert(cmd, "-E")
      table.insert(cmd, anaconda_envs_path)
    end
    table.insert(cmd, "-HItd")
    table.insert(cmd, "^(venv|\\.venv)$")
    table.insert(cmd, cwd)
    local output, err = vim.fn.system(cmd)

    if vim.v.shell_error ~= 0 then
      stl.reporter.error({
        from = __module_name__,
        subject = "find_venvs",
        message = "Failed to run fd command.",
        details = { cmd = cmd, error = err or "Unknown error" },
      })
      ---@type era.m.picker.composer.list.IResetData
      local result = { items = {} }
      return result
    end

    if output then
      local lines = vim.split(output, "\n") ---@type string[]
      for _, line in ipairs(lines) do
        if #line > 0 then
          local icon = "󰅬" ---@type string
          local dirpath = stl.string.remove_last_slash(line) ---@type string
          if not uuid_set[dirpath] then
            uuid_set[dirpath] = true
            local resolved_dirpath = yoz.path.is_descendant(workspace, dirpath) and dot.path.relative(cwd, dirpath)
              or dirpath
            local text_content = icon .. " " .. resolved_dirpath

            ---@type era.m.python_venv.IItem
            local item = {
              uuid = dirpath,
              text = text_content,
              text_lower = string.lower(text_content),
              highlights = {},
              data = {
                icon = icon,
                path = dirpath,
              },
            }
            table.insert(items, item)
          end
        end
      end
    end
  end

  do
    --- search lsp workspace folders
    local lsp_workspace_paths = {}
    for _, client in pairs(vim.lsp.get_clients()) do
      if vim.tbl_contains({ "basedpyright", "pyright", "pylance" }, client.name) then
        for _, folder in pairs(client.workspace_folders or {}) do
          local search_path = format_search_path(folder.name) ---@type string|nil
          if search_path ~= nil then
            table.insert(lsp_workspace_paths, search_path)
          end
        end
      end
    end
    if #lsp_workspace_paths > 0 then
      local cmd = vim.list_extend({
        "fd",
        "--absolute-path",
        "--color",
        "never",
        "-HItd",
        "^(venv|\\.venv)$",
      }, lsp_workspace_paths)
      local output, err = vim.fn.system(cmd)

      if vim.v.shell_error ~= 0 then
        stl.reporter.error({
          from = __module_name__,
          subject = "find_venvs",
          message = "Failed to run fd command.",
          details = { cmd = cmd, error = err or "Unknown error" },
        })
        ---@type era.m.picker.composer.list.IResetData
        local result = { items = {} }
        return result
      end

      if output then
        local lines = vim.split(output, "\n") ---@type string[]
        for _, line in ipairs(lines) do
          if #line > 0 then
            local icon = "" ---@type string
            local dirpath = stl.string.remove_last_slash(line) ---@type string
            if not uuid_set[dirpath] then
              uuid_set[dirpath] = true
              local text_content = icon .. " " .. dirpath

              ---@type era.m.python_venv.IItem
              local item = {
                uuid = dirpath,
                text = text_content,
                text_lower = string.lower(text_content),
                highlights = {},
                data = {
                  icon = icon,
                  path = dirpath,
                },
              }
              table.insert(items, item)
            end
          end
        end
      end
    end
  end

  --- Search venv manager paths
  do
    local venv_manager_paths = {
      stl.lang.python.paths.Poetry,
      stl.lang.python.paths.PDM,
      stl.lang.python.paths.Pipenv,
      stl.lang.python.paths.Pyenv,
      stl.lang.python.paths.Hatch,
      stl.lang.python.paths.VenvWrapper,
      stl.lang.python.paths.AnacondaEnvs,
    }
    local search_paths = {} ---@type string[]
    for _, folder in ipairs(venv_manager_paths) do
      local search_path = format_search_path(folder)
      if search_path then
        table.insert(search_paths, search_path)
      end
    end

    if #search_paths > 0 then
      local cmd = vim.list_extend({
        "fd",
        "--absolute-path",
        "--color",
        "never",
        "--max-depth",
        "1",
        "-E",
        "3.*.*",
        "-tl",
        "-HItd",
        ".",
      }, search_paths)
      local output, err = vim.fn.system(cmd)

      if vim.v.shell_error ~= 0 then
        stl.reporter.error({
          from = __module_name__,
          subject = "find_venvs",
          message = "Failed to run fd command.",
          details = { cmd = cmd, error = err or "Unknown error" },
        })
        ---@type era.m.picker.composer.list.IResetData
        local result = { items = {} }
        return result
      end

      if output then
        local lines = vim.split(output, "\n") ---@type string[]
        for _, line in ipairs(lines) do
          if #line > 0 then
            local icon = "" ---@type string
            local dirpath = stl.string.remove_last_slash(line) ---@type string
            if not uuid_set[dirpath] then
              uuid_set[dirpath] = true
              local text_content = icon .. " " .. dirpath
              ---@type era.m.python_venv.IItem
              local item = {
                uuid = dirpath,
                text = text_content,
                text_lower = string.lower(text_content),
                highlights = {},
                data = {
                  icon = icon,
                  path = dirpath,
                },
              }
              table.insert(items, item)
            end
          end
        end
      end
    end

    -- If $CONDA_PREFIX is defined and exists, add the path as an existing venv
    if vim.fn.isdirectory(stl.lang.python.paths.AnacondaBase) ~= 0 then
      local icon = "" ---@type string
      local dirpath = stl.string.remove_last_slash(stl.lang.python.paths.AnacondaBase .. "/") ---@type string
      if not uuid_set[dirpath] then
        uuid_set[dirpath] = true
        local text_content = icon .. " " .. dirpath

        ---@type era.m.python_venv.IItem
        local item = {
          uuid = dirpath,
          text = text_content,
          text_lower = string.lower(text_content),
          highlights = {},
          data = {
            icon = icon,
            path = dirpath,
          },
        }
        table.insert(items, item)
      end
    end
  end

  ---@type era.m.picker.composer.list.IResetData
  local result = {
    items = items,
    uuid_current = o_python_venv_path:snapshot(),
    uuid_present = o_python_venv_path:snapshot(),
  }
  return result
end

local picker ---@type era.m.picker.ListComposer|nil
picker = era.m.picker.ListComposer.new({
  name = __module_name__,
  permanent = true,
  title = "Find python venv",
  height = 25,
  width = 120,

  search_pattern = o_search_pattern,
  flag_fuzzy = o_flag_fuzzy,
  flag_regex = o_flag_regex,
  flag_case_sensitive = o_flag_case_sensitive,

  on_confirm = function(composer, item)
    ---@cast item era.m.python_venv.IItem
    composer:close()
    if item then
      o_python_venv_path:next(item.data.path)
      dirty_data = true
    end
  end,
  on_disposed = function()
    o_search_pattern:dispose()
    o_flag_fuzzy:dispose()
    o_flag_regex:dispose()
    o_flag_case_sensitive:dispose()
  end,
  on_refresh = function(composer)
    local result = fetch_data()
    composer:reset_data(result)
  end,
})

----------------------------------------------------------------------------------------------------
-- Module state
----------------------------------------------------------------------------------------------------

-- Keeps track of old system path so we can remove it when adding a new one
local _current_bin_path = nil ---@type string|nil
local initialized = false ---@type boolean

---@class era.m.python_venv
local M = {}

----------------------------------------------------------------------------------------------------
-- Public API
----------------------------------------------------------------------------------------------------

---@param venv_path                     string
---@return nil
function M.activate_venv(venv_path)
  local venv_python, bin_path = dot.context.lsp.get_python_bin_path() ---@type string|nil, string|nil
  if venv_python == nil or bin_path == nil then
    return
  end

  -- Make sure our python exists on disk before activating it, in case paths are wrong
  if vim.fn.executable(venv_python) == 0 then
    stl.reporter.info({
      from = __module_name__,
      subject = "set_venv_and_system_paths",
      message = "The python path '" .. venv_python .. "' does not exist.",
    })
    return
  end

  stl.reporter.info({
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
    current_system_path = string.gsub(current_system_path, escape_pattern(prev_bin_path .. stl.env.PATH_ENV_SEP), "")
  end

  -- Add new bin path to path
  local new_system_path = bin_path .. stl.env.PATH_ENV_SEP .. current_system_path
  vim.fn.setenv("PATH", new_system_path)
  _current_bin_path = bin_path

  -- Set VIRTUAL_ENV
  -- Set CONDA_PREFIX instead if we are on Windows and a conda environment is activated
  if stl.env.IS_WIN then
    local venv_path_std = string.gsub(venv_path, "/", "\\")
    local conda_base_path_std = string.gsub(stl.lang.python.paths.AnacondaBase, "/", "\\")
    local conda_envs_path_std = string.gsub(stl.lang.python.paths.AnacondaEnvs, "/", "\\")
    local is_conda_base = string.find(venv_path_std, conda_base_path_std, 1, true)
    local is_conda_env = string.find(venv_path_std, conda_envs_path_std, 1, true)
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
    current_system_path = string.gsub(current_system_path, escape_pattern(prev_bin_path .. stl.env.PATH_ENV_SEP), "")
    vim.fn.setenv("PATH", current_system_path)
  end

  -- Remove VIRTUAL_ENV environment variable.
  ---@diagnostic disable-next-line: param-type-mismatch
  vim.fn.setenv("VIRTUAL_ENV", nil)

  -- TODO: Set pyright to use system python if it exists.
  -- Not sure how to do this in a cross platform compatible way.

  dot.context.lsp.python_venv_path:next(nil)
end

---@return nil
function M.select_venv()
  if dirty_data then
    local data = fetch_data()
    picker:reset_data(data)
  end
  picker:focus()
end

----------------------------------------------------------------------------------------------------
-- Setup
----------------------------------------------------------------------------------------------------

---@return nil
local function __setup__()
  if not initialized then
    stl.fn.observe({ dot.context.lsp.python_venv_path }, function()
      local venv_path = dot.context.lsp.python_venv_path:snapshot() ---@type string
      if venv_path ~= nil and vim.fn.isdirectory(venv_path) ~= 0 then
        M.activate_venv(venv_path)
      end
    end, true)

    -- Commit the state only after registration succeeds, so a later FileType can retry on failure.
    initialized = true
  end
end

---@return nil
function M.dressing()
  __setup__()
end

return M
