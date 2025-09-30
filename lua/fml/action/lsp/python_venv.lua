local __module_name__ = "fml.action.lsp.python_venv" ---@type string

local clp = require("eve.constant.lang.python")

local dirty_data = true ---@type boolean
local o_finder_input = std.Observable.from_value("")
local o_flag_fuzzy = std.Observable.from_value(true)
local o_flag_regex = std.Observable.from_value(false)
local o_flag_case_sensitive = std.Observable.from_value(false)
local o_python_venv_path = eve.context.lsp.python_venv_path

---@param folder                               string
---@return                              string|nil
local function format_search_path(folder)
  local resolved_path = vim.fn.expand(folder) ---@type string
  if #resolved_path < 1 or vim.fn.isdirectory(resolved_path) == 0 then
    return nil
  end

  resolved_path = resolved_path:gsub(" ", "\\ ")
  if folder == clp.paths.Hatch then
    return resolved_path .. "/*/*"
  else
    return resolved_path
  end
end

---@class fml.action.lsp.python_venv.IItemData
---@field public icon                   string
---@field public path                   string

---@class fml.action.lsp.python_venv.IItem : eve.ux.picker.composer.list.IItem
---@field public data                   fml.action.lsp.python_venv.IItemData
---@field public text_lower             string
---@field public highlights             table

---@return eve.ux.picker.composer.list.IResetData
local function fetch_data()
  dirty_data = false

  local cwd = std.path.cwd() ---@type string
  local workspace = std.path.workspace() ---@type string

  local items = {} ---@type fml.action.lsp.python_venv.IItem[]
  local uuid_set = {} ---@type table<string, true>

  do
    local anaconda_base_path = format_search_path(clp.paths.AnacondaBase) ---@type string|nil
    local anaconda_envs_path = format_search_path(clp.paths.AnacondaEnvs) ---@type string|nil

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
      std.reporter.error({
        from = __module_name__,
        subject = "find_venvs",
        message = "Failed to run fd command.",
        details = { cmd = cmd, error = err or "Unknown error" },
      })
      ---@type eve.ux.picker.composer.list.IResetData
      local result = { items = {} }
      return result
    end

    if output then
      local lines = vim.split(output, "\n") ---@type string[]
      for _, line in ipairs(lines) do
        if #line > 0 then
          local icon = "󰅬" ---@type string
          local dirpath = std.string.remove_last_slash(line) ---@type string
          if not uuid_set[dirpath] then
            uuid_set[dirpath] = true
            local resolved_dirpath = std.path.is_under(workspace, dirpath) and std.path.relative(cwd, dirpath, false)
              or dirpath
            local text_content = icon .. " " .. resolved_dirpath

            ---@type fml.action.lsp.python_venv.IItem
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
        std.reporter.error({
          from = __module_name__,
          subject = "find_venvs",
          message = "Failed to run fd command.",
          details = { cmd = cmd, error = err or "Unknown error" },
        })
        ---@type eve.ux.picker.composer.list.IResetData
        local result = { items = {} }
        return result
      end

      if output then
        local lines = vim.split(output, "\n") ---@type string[]
        for _, line in ipairs(lines) do
          if #line > 0 then
            local icon = "" ---@type string
            local dirpath = std.string.remove_last_slash(line) ---@type string
            if not uuid_set[dirpath] then
              uuid_set[dirpath] = true
              local text_content = icon .. " " .. dirpath

              ---@type fml.action.lsp.python_venv.IItem
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
      clp.paths.Poetry,
      clp.paths.PDM,
      clp.paths.Pipenv,
      clp.paths.Pyenv,
      clp.paths.Hatch,
      clp.paths.VenvWrapper,
      clp.paths.AnacondaEnvs,
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
        std.reporter.error({
          from = __module_name__,
          subject = "find_venvs",
          message = "Failed to run fd command.",
          details = { cmd = cmd, error = err or "Unknown error" },
        })
        ---@type eve.ux.picker.composer.list.IResetData
        local result = { items = {} }
        return result
      end

      if output then
        local lines = vim.split(output, "\n") ---@type string[]
        for _, line in ipairs(lines) do
          if #line > 0 then
            local icon = "" ---@type string
            local dirpath = std.string.remove_last_slash(line) ---@type string
            if not uuid_set[dirpath] then
              uuid_set[dirpath] = true
              local text_content = icon .. " " .. dirpath
              ---@type fml.action.lsp.python_venv.IItem
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
    if vim.fn.isdirectory(clp.paths.AnacondaBase) ~= 0 then
      local icon = "" ---@type string
      local dirpath = std.string.remove_last_slash(clp.paths.AnacondaBase .. "/") ---@type string
      if not uuid_set[dirpath] then
        uuid_set[dirpath] = true
        local text_content = icon .. " " .. dirpath

        ---@type fml.action.lsp.python_venv.IItem
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

  ---@type eve.ux.picker.composer.list.IResetData
  local result = {
    items = items,
    uuid_current = o_python_venv_path:snapshot(),
    uuid_present = o_python_venv_path:snapshot(),
  }
  return result
end

local picker ---@type eve.ux.picker.ListComposer|nil
picker = eve.ux.picker.ListComposer.new({
  name = __module_name__,
  permanent = true,
  title = "Find python venv",
  height = 25,
  width = 120,

  finder_input = o_finder_input,
  flag_fuzzy = o_flag_fuzzy,
  flag_regex = o_flag_regex,
  flag_case_sensitive = o_flag_case_sensitive,

  on_confirm = function(composer, item)
    ---@cast item fml.action.lsp.python_venv.IItem
    composer:close() -- or composer:close() if appropriate
    if item then -- ListComposer passes a single item if multiple=false
      o_python_venv_path:next(item.data.path)
      dirty_data = true
    end
  end,
  on_disposed = function()
    o_finder_input:dispose()
    o_flag_fuzzy:dispose()
    o_flag_regex:dispose()
    o_flag_case_sensitive:dispose()
  end,
  on_refresh = function(composer)
    local result = fetch_data()
    composer:reset_data(result)
  end,
})

---@class fml.action.lsp.python_venv
local M = {}

---@return                              nil
function M.activate_venv()
  if dirty_data then
    local data = fetch_data()
    picker:reset_data(data)
  end
  picker:focus()
end

return M
