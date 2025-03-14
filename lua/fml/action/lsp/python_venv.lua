local __module_name__ = "fml.action.lsp.python_venv" ---@type string

local clp = require("eve.constant.lang.python")
local state = require("eve.state")
local Select = require("fml.ux.select")

---@param folder                        string
---@return string|nil
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

---@class fml.action.lsp.python_venv.IItem : fml.ux.select.IItem
---@field public data                   fml.action.lsp.python_venv.IItemData

local _select ---@type fml.ux.ISelect|nil

---@return fml.ux.ISelect
local function get_select()
  if _select == nil then
    ---@type fml.ux.select.IProvider
    local provider = {
      fetch_data = function()
        local items = {} ---@type fml.action.lsp.python_venv.IItem[]
        local root = eve.path.cwd() ---@type string
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
          table.insert(cmd, root)
          local output, err = vim.fn.system(cmd)

          if vim.v.shell_error ~= 0 then
            eve.reporter.error({
              from = __module_name__,
              subject = "find_venvs",
              message = "Failed to run fd command.",
              details = { cmd = cmd, error = err or "Unknown error" },
            })
            return items
          end

          if output then
            local lines = vim.split(output, "\n") ---@type string[]
            for _, line in ipairs(lines) do
              if #line > 0 then
                local icon = "󰅬" ---@type string
                local dirpath = eve.string.remove_last_slash(line) ---@type string
                if not uuid_set[dirpath] then
                  uuid_set[dirpath] = true

                  ---@type fml.action.lsp.python_venv.IItem
                  local item = {
                    uuid = dirpath,
                    text = icon .. " " .. dirpath,
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
              eve.reporter.error({
                from = __module_name__,
                subject = "find_venvs",
                message = "Failed to run fd command.",
                details = { cmd = cmd, error = err or "Unknown error" },
              })
              return items
            end

            if output then
              local lines = vim.split(output, "\n") ---@type string[]
              for _, line in ipairs(lines) do
                if #line > 0 then
                  local icon = "" ---@type string
                  local dirpath = eve.string.remove_last_slash(line) ---@type string
                  if not uuid_set[dirpath] then
                    uuid_set[dirpath] = true

                    ---@type fml.action.lsp.python_venv.IItem
                    local item = {
                      uuid = dirpath,
                      text = icon .. " " .. dirpath,
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
              eve.reporter.error({
                from = __module_name__,
                subject = "find_venvs",
                message = "Failed to run fd command.",
                details = { cmd = cmd, error = err or "Unknown error" },
              })
              return items
            end

            if output then
              local lines = vim.split(output, "\n") ---@type string[]
              for _, line in ipairs(lines) do
                if #line > 0 then
                  local icon = "" ---@type string
                  local dirpath = eve.string.remove_last_slash(line) ---@type string
                  if not uuid_set[dirpath] then
                    uuid_set[dirpath] = true
                    ---@type fml.action.lsp.python_venv.IItem
                    local item = {
                      uuid = dirpath,
                      text = icon .. " " .. dirpath,
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

            -- If $CONDA_PREFIX is defined and exists, add the path as an existing venv
            if vim.fn.isdirectory(clp.paths.AnacondaBase) ~= 0 then
              local icon = "" ---@type string
              local dirpath = eve.string.remove_last_slash(clp.paths.AnacondaBase .. "/") ---@type string
              if not uuid_set[dirpath] then
                uuid_set[dirpath] = true

                ---@type fml.action.lsp.python_venv.IItem
                local item = {
                  uuid = dirpath,
                  text = icon .. " " .. dirpath,
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

        ---@type fml.ux.select.IData
        return { items = items, uuid_present = state.lsp.python_venv_path:snapshot() }
      end,
    }

    ---@type fml.ux.ISelect
    _select = Select.new({
      dimension = {
        height = 0.8,
        max_height = 1,
        max_width = 1,
        width = 120,
      },
      dirty_on_invisible = true,
      flag_case_sensitive = state.select.find_python_venv.flag_case_sensitive,
      flag_fuzzy = state.select.find_python_venv.flag_fuzzy,
      flag_regex = state.select.find_python_venv.flag_regex,
      flag_selected = state.select.find_python_venv.flag_selected,
      input = state.select.find_python_venv.input,
      input_history = state.select.find_python_venv.input_history,
      multiple = false,
      preview_enabled = false,
      extend_preset_keymaps = true,
      provider = provider,
      title = "Find python venv",
      on_confirm = function(widget, items)
        widget:hide()

        if #items == 1 then
          local item = items[1]
          state.lsp.python_venv_path:next(item.data.path)
        end
      end,
    })
  end
  return _select
end

---@class fml.action.lsp.python_venv
local M = {}

---@return nil
function M.activate_venv()
  local select = get_select()
  select:show()
end

return M
