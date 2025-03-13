local __module_name__ = "fml.action.find" ---@type string

local fn = require("eve.builtin.fn")
local oxi = require("eve.builtin.oxi")
local path = require("eve.std.path")
local reporter = require("eve.builtin.reporter")
local Observable = require("eve.collection.observable")
local icons = require("eve.constant.icon")
local instances = require("eve.constant.instance")
local state = require("eve.state")

local FileSelect = require("fml.ux.file_select")
local Select = require("fml.ux.select")
local Setting = require("fml.ux.setting")

local _select = nil ---@type fml.ux.IFileSelect|nil

---@return fml.ux.IFileSelect
local function get_select()
  if _select == nil then
    local scopes = vim.list_slice(state.select.find_file_scopes) ---@type eve.e.FindFileScope[]

    ---@param dirpath                       string
    ---@return string
    local function get_scope_cwd(dirpath)
      local scope = state.select.find_file_scope:snapshot() ---@type eve.e.FindFileScope
      if scope == "W" then
        return path.workspace()
      elseif scope == "C" then
        return path.cwd()
      elseif scope == "D" then
        return dirpath
      end

      reporter.error({
        from = __module_name__,
        subject = "get_scope_cwd",
        message = "Unknown scope.",
        details = { scope = scope, dirpath = dirpath },
      })
      return path.cwd()
    end

    local state_find_cwd = Observable.from_value(get_scope_cwd(path.cwd()))

    state.observe({ state.select.find_file_scope }, function()
      local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
      local bufnr = state.tab.get_bufnr_sourcefile(tabnr) ---@type integer|nil

      ---@type string
      local current_buf_dirpath = bufnr ~= nil and path.dirname(vim.api.nvim_buf_get_name(bufnr)) or path.cwd()

      local current_find_cwd = state_find_cwd:snapshot() ---@type string
      local next_find_cwd = get_scope_cwd(current_buf_dirpath) ---@type string
      if current_find_cwd ~= next_find_cwd then
        state_find_cwd:next(next_find_cwd)
      end
    end, true)

    state.observe({
      state.select.find_file.excludes,
      state.select.find_file.flag_case_sensitive,
      state.select.find_file.flag_exclude,
      state.select.find_file.flag_fuzzy,
      state.select.find_file.flag_gitignore,
      state.select.find_file.flag_regex,
      state_find_cwd,
    }, function()
      if _select ~= nil then
        _select:mark_data_dirty()
      end
    end, true)

    ---@param scope                         eve.e.FindFileScope
    ---@return nil
    local function change_scope(scope)
      local scope_current = state.select.find_file_scope:snapshot() ---@type eve.e.FindFileScope
      if scope_current ~= scope then
        state.select.find_file_scope:next(scope)
      end
    end

    ---@class fml.action.find.files.actions
    local actions = {
      ---@return nil
      edit_config = function()
        ---@class fml.action.find.files.actions.IConfigData
        ---@field public keyword        string
        ---@field public includes       string[]
        ---@field public excludes       string[]

        local s_keyword = state.select.find_file.input:snapshot() ---@type string
        local s_includes = state.select.find_file.includes:snapshot() ---@type string[]
        local s_excludes = state.select.find_file.excludes:snapshot() ---@type string[]

        ---@type fml.action.find.files.actions.IConfigData
        local data = {
          keyword = s_keyword,
          includes = s_includes,
          excludes = s_excludes,
        }

        local setting = Setting.new({
          position = "center",
          width = 100,
          title = "Edit Configuration (find files)",
          validate = function(raw_data)
            if type(raw_data) ~= "table" then
              return "Invalid find_files configuration, expect an object."
            end
            ---@cast raw_data               fml.action.find.files.actions.IConfigData

            if raw_data.keyword == nil or type(raw_data.keyword) ~= "string" then
              return "Invalid data.keyword, expect an string."
            end

            if raw_data.includes == nil or not vim.islist(raw_data.includes) then
              return "Invalid data.includes, expect an array."
            end

            if raw_data.excludes == nil or not vim.islist(raw_data.excludes) then
              return "Invalid data.excludes, expect an array."
            end
          end,
          on_confirm = function(raw_data)
            vim.schedule(function()
              local last_keyword = state.select.search_file.input:snapshot() ---@type string

              local raw = vim.tbl_extend("force", data, raw_data)
              ---@cast raw                  fml.action.find.files.actions.IConfigData

              local keyword = raw.keyword ---@type string
              local includes = raw.includes ---@type string[]
              local excludes = raw.excludes ---@type string[]

              state.select.find_file.input:next(keyword)
              state.select.find_file.includes:next(includes)
              state.select.find_file.excludes:next(excludes)

              if _select ~= nil then
                if keyword ~= last_keyword then
                  _select:reset_input(keyword)
                else
                  _select:mark_data_dirty()
                end
              end
            end)
            return true
          end,
        })
        setting:open({
          initial_value = data,
          text_cursor_row = 1,
          text_cursor_col = 1,
        })
      end,
      ---@return nil
      change_scope_cwd = function()
        change_scope("C")
      end,
      ---@return nil
      change_scope_directory = function()
        change_scope("D")
      end,
      ---@return nil
      change_scope_workspace = function()
        change_scope("W")
      end,
      send_to_qflist = function()
        if _select ~= nil then
          local cwd = path.cwd() ---@type string
          local select_cwd = state_find_cwd:snapshot() ---@type string
          local quickfix_items = {} ---@type eve.t.IQuickFixItem[]
          local matched_items = _select:get_matched_items() ---@type fml.ux.select.IMatchedItem[]
          for _, matched_item in ipairs(matched_items) do
            local item = _select:get_item(matched_item.uuid) ---@type fml.ux.select.IItem|nil
            ---@cast item                   fml.ux.file_select.IItem

            if item ~= nil then
              local absolute_filepath = path.join(select_cwd, item.data.filepath) ---@type string
              local relative_filepath = path.relative(cwd, absolute_filepath, false) ---@type string
              table.insert(quickfix_items, {
                filename = relative_filepath,
                lnum = item.data.lnum or 1,
                col = item.data.col or 0,
              })
            end
          end

          if #quickfix_items > 0 then
            _select:close()

            state.qflist.push(quickfix_items)
            state.qflist.open_qflist(false)
          end
        end
      end,
      toggle_case_sensitive = function()
        local flag = state.select.find_file.flag_case_sensitive:snapshot() ---@type boolean
        state.select.find_file.flag_case_sensitive:next(not flag)
      end,
      toggle_flag_exclude = function()
        local flag = state.select.find_file.flag_exclude:snapshot() ---@type boolean
        state.select.find_file.flag_exclude:next(not flag)
      end,
      toggle_flag_fuzzy = function()
        local flag = state.select.find_file.flag_fuzzy:snapshot() ---@type boolean
        state.select.find_file.flag_fuzzy:next(not flag)
      end,
      ---@return nil
      toggle_flag_gitignore = function()
        local flag = state.select.find_file.flag_gitignore:snapshot() ---@type boolean
        state.select.find_file.flag_gitignore:next(not flag)
      end,
      toggle_flag_regex = function()
        local flag = state.select.find_file.flag_regex:snapshot() ---@type boolean
        state.select.find_file.flag_regex:next(not flag)
      end,
      ---@return nil
      toggle_flag_scope = function()
        local scope = state.select.find_file_scope:snapshot() ---@type eve.e.FindFileScope
        local idx = fn.find_index(scopes, scope) or 1 ---@type integer
        local idx_next = idx == #scopes and 1 or idx + 1 ---@type integer
        local next_scope = scopes[idx_next] ---@type eve.e.FindFileScope
        state.select.find_file_scope:next(next_scope)
      end,
      ---@return nil
      toggle_flag_selected = function()
        local flag = state.select.find_file.flag_selected:snapshot() ---@type boolean
        state.select.find_file.flag_selected:next(not flag)
      end,
    }

    local frecency = state.frecency.files ---@type eve.collection.IFrecency

    ---@type eve.t.ux.widget.IRawStatuslineItem[]
    local statusline_items = {
      {
        type = "popup",
        desc = "find: edit settings",
        symbol = icons.symbols.setting,
        state = instances.observable_truthy,
        callback = actions.edit_config,
      },
      {
        type = "enum",
        desc = "find: toggle scope",
        symbol = "",
        state = state.select.find_file_scope,
        callback = actions.toggle_flag_scope,
      },
      {
        type = "flag",
        desc = "find: toggle selected",
        symbol = icons.symbols.flag_selected,
        state = state.select.find_file.flag_selected,
        callback = actions.toggle_flag_selected,
      },
      {
        type = "flag",
        desc = "find: toggle exclude",
        symbol = icons.symbols.flag_exclude,
        state = state.select.find_file.flag_exclude,
        callback = actions.toggle_flag_exclude,
      },
      {
        type = "flag",
        desc = "find: toggle gitignore",
        symbol = icons.symbols.flag_gitignore,
        state = state.select.find_file.flag_gitignore,
        callback = actions.toggle_flag_gitignore,
      },
      {
        type = "flag",
        desc = "select: toggle flag fuzzy",
        symbol = icons.symbols.flag_fuzzy,
        state = state.select.find_file.flag_fuzzy,
        callback = actions.toggle_flag_fuzzy,
      },
      {
        type = "flag",
        desc = "find: toggle case sensitive",
        symbol = icons.symbols.flag_case_sensitive,
        state = state.select.find_file.flag_case_sensitive,
        callback = actions.toggle_case_sensitive,
      },
      {
        type = "flag",
        desc = "select: toggle flag regex",
        symbol = icons.symbols.flag_regex,
        state = state.select.find_file.flag_regex,
        callback = actions.toggle_flag_regex,
      },
    }

    ---@type eve.t.IKeymap[]
    local common_keymaps = {
      {
        modes = { "i", "n", "v" },
        key = "<C-q>",
        callback = actions.send_to_qflist,
        desc = "search: send to qflist",
      },
      {
        modes = { "n", "v" },
        key = "<leader>tw",
        callback = actions.change_scope_workspace,
        desc = "find: change scope (workspace)",
      },
      {
        modes = { "n", "v" },
        key = "<leader>tc",
        callback = actions.change_scope_cwd,
        desc = "find: change scope (cwd)",
      },
      {
        modes = { "n", "v" },
        key = "<leader>td",
        callback = actions.change_scope_directory,
        desc = "find: change scope (directory)",
      },
      {
        modes = { "n", "v" },
        key = "<leader>ts",
        callback = actions.edit_config,
        desc = "find: edit config",
      },
      {
        modes = { "n", "v" },
        key = "<leader>ti",
        callback = actions.toggle_case_sensitive,
        desc = "find: toggle case sensitive",
      },
      {
        modes = { "n", "v" },
        key = "<leader>tr",
        callback = actions.toggle_flag_regex,
        desc = "find: toggle flag regex",
      },
    }

    ---@type eve.t.IKeymap[]
    local input_keymaps = vim.list_slice(common_keymaps)

    ---@type eve.t.IKeymap[]
    local main_keymaps = vim.list_slice(common_keymaps)

    ---@type eve.t.IKeymap[]
    local preview_keymaps = vim.list_slice(common_keymaps)

    ---@type fml.ux.file_select.IProvider
    local provider = {
      fetch_data = function()
        local cwd = state_find_cwd:snapshot() ---@type string
        local workspace = path.workspace() ---@type string
        local flag_exclude = state.select.find_file.flag_exclude:snapshot() ---@type boolean
        local flag_gitignore = state.select.find_file.flag_gitignore:snapshot() ---@type boolean
        local excludes = flag_exclude and state.select.find_file.excludes:snapshot() or {} ---@type string[]

        ---@type string[]
        local filepaths = oxi.find({
          workspace = workspace,
          cwd = cwd,
          flag_case_sensitive = false,
          flag_gitignore = flag_gitignore,
          flag_regex = false,
          search_pattern = "",
          search_paths = "",
          exclude_patterns = table.concat(excludes, ","),
        })
        table.sort(filepaths)

        local items = {} ---@type fml.ux.file_select.IRawItem[]
        for _, relative_filepath in ipairs(filepaths) do
          local filepath = path.resolve(cwd, relative_filepath) ---@type string
          ---@type fml.ux.file_select.IRawItem
          local item = {
            filepath = filepath,
            filepath_relative = relative_filepath,
          }
          table.insert(items, item)
        end
        local data = { items = items } ---@type fml.ux.file_select.IData
        return data
      end,
    }

    local states = state.select.find_file ---@type eve.state.select.item.state
    _select = FileSelect.new({
      case_sensitive = states.flag_case_sensitive,
      cmp = Select.cmp_by_score,
      dirty_on_invisible = false,
      preview_enabled = true,
      extend_preset_keymaps = false,
      flag_fuzzy = states.flag_fuzzy,
      flag_regex = states.flag_regex,
      flag_selected = states.flag_selected,
      frecency = frecency,
      input = states.input,
      input_history = states.input_history,
      input_keymaps = input_keymaps,
      main_keymaps = main_keymaps,
      multiple = true,
      permanent = true,
      preview_keymaps = preview_keymaps,
      provider = provider,
      statusline_items = statusline_items,
      title = "Find files",
    })
  end
  return _select
end

---@class fml.action.find
local M = {}

---@return nil
function M.find_files()
  local select = get_select() ---@type fml.ux.IFileSelect
  select:show()
end

---@return nil
function M.find_files_cwd()
  state.select.find_file_scope:next("C")
  local select = get_select() ---@type fml.ux.IFileSelect
  select:show()
end

---@return nil
function M.find_files_directory()
  state.select.find_file_scope:next("D")
  local select = get_select() ---@type fml.ux.IFileSelect
  select:show()
end

---@return nil
function M.find_files_workspace()
  state.select.find_file_scope:next("W")
  local select = get_select() ---@type fml.ux.IFileSelect
  select:show()
end

return M
