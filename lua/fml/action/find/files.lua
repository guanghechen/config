local __module_name__ = "fml.action.find" ---@type string

local fn = require("eve.builtin.fn")
local oxi = require("eve.builtin.oxi")
local path = require("eve.builtin.path")
local reporter = require("eve.builtin.reporter")
local Observable = require("eve.collection.observable")
local Subscriber = require("eve.collection.subscriber")
local icons = require("eve.constant.icon")
local editor = require("eve.module.editor")
local state = require("eve.state")
local command = require("eve.command")

local FileSelect = require("fml.ux.file_select")
local Select = require("fml.ux.select")
local Setting = require("fml.ux.setting")

local scopes = { "W", "C", "D" } ---@type eve.e.FindScope[]

---@return eve.e.FindScope
local function get_scope_carousel_next()
  local scope = state.find.scope:snapshot() ---@type eve.e.FindScope
  local idx = fn.find_index(scopes, scope) or 1 ---@type integer
  local idx_next = idx == #scopes and 1 or idx + 1 ---@type integer
  return scopes[idx_next]
end

---@param dirpath                       string
---@return string
local function get_scope_cwd(dirpath)
  local scope = state.find.scope:snapshot() ---@type eve.e.FindScope

  if scope == "W" then
    return path.workspace()
  end

  if scope == "C" then
    return path.cwd()
  end

  if scope == "D" then
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
local _select = nil ---@type fml.ux.IFileSelect|nil

---@return nil
local function reload()
  if _select ~= nil then
    _select:mark_data_dirty()
  end
end

state.find.scope:subscribe(
  Subscriber.new({
    on_next = function()
      local bufnr = command.context_bufnr() ---@type integer|nil

      ---@type string
      local current_buf_dirpath = bufnr ~= nil
          and editor.is_buf_valid(bufnr)
          and path.dirname(vim.api.nvim_buf_get_name(bufnr))
        or path.cwd()

      local current_find_cwd = state_find_cwd:snapshot() ---@type string
      local next_find_cwd = get_scope_cwd(current_buf_dirpath) ---@type string
      if current_find_cwd ~= next_find_cwd then
        state_find_cwd:next(next_find_cwd)
      end
    end,
  }),
  true
)
state.observe({
  state.find.excludes,
  state.find.flag_case_sensitive,
  state.find.flag_gitignore,
  state.find.flag_fuzzy,
  state.find.flag_regex,
  state_find_cwd,
}, function()
  reload()
end, true)

---@param scope                         eve.e.FindScope
---@return nil
local function change_scope(scope)
  local scope_current = state.find.scope:snapshot() ---@type eve.e.FindScope
  if scope_current ~= scope then
    state.find.scope:next(scope)
  end
end

---@class fml.action.find.files.actions
local actions = {
  ---@return nil
  edit_config = function()
    ---@class fml.action.find.files.actions.IConfigData
    ---@field public exclude_patterns       string[]

    local f_exclude_patterns = state.find.excludes:snapshot() ---@type string

    ---@type fml.action.find.files.actions.IConfigData
    local data = {
      exclude_patterns = fn.parse_comma_list(f_exclude_patterns),
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

        if raw_data.exclude_patterns == nil or not vim.islist(raw_data.exclude_patterns) then
          return "Invalid data.exclude_patterns, expect an array."
        end
      end,
      on_confirm = function(raw_data)
        vim.schedule(function()
          local raw = vim.tbl_extend("force", data, raw_data)
          ---@cast raw                  fml.action.find.files.actions.IConfigData

          local exclude_patterns = table.concat(raw.exclude_patterns, ",") ---@type string
          state.find.excludes:next(exclude_patterns)
          reload()
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
    local flag = state.find.flag_case_sensitive:snapshot() ---@type boolean
    state.find.flag_case_sensitive:next(not flag)
  end,
  toggle_flag_fuzzy = function()
    local flag = state.find.flag_fuzzy:snapshot() ---@type boolean
    state.find.flag_fuzzy:next(not flag)
  end,
  toggle_flag_regex = function()
    local flag = state.find.flag_regex:snapshot() ---@type boolean
    state.find.flag_regex:next(not flag)
  end,
  ---@return nil
  toggle_gitignore = function()
    local flag = state.find.flag_gitignore:snapshot() ---@type boolean
    state.find.flag_gitignore:next(not flag)
  end,
  ---@return nil
  toggle_scope = function()
    local next_scope = get_scope_carousel_next() ---@type eve.e.FindScope
    state.find.scope:next(next_scope)
  end,
}

---@return fml.ux.IFileSelect
local function get_select()
  if _select == nil then
    local frecency = state.frecency.files ---@type eve.collection.IFrecency
    local input_history = state.input_history.find_file ---@type eve.collection.IHistory

    ---@type eve.t.ux.widget.IRawStatuslineItem[]
    local statusline_items = {
      {
        type = "enum",
        desc = "find: toggle scope",
        symbol = "",
        state = state.find.scope,
        callback = actions.toggle_scope,
      },
      {
        type = "flag",
        desc = "find: toggle gitignore",
        symbol = icons.symbols.flag_gitignore,
        state = state.find.flag_gitignore,
        callback = actions.toggle_gitignore,
      },
      {
        type = "flag",
        desc = "select: toggle flag fuzzy",
        symbol = icons.symbols.flag_fuzzy,
        state = state.find.flag_fuzzy,
        callback = actions.toggle_flag_fuzzy,
      },
      {
        type = "flag",
        desc = "find: toggle case sensitive",
        symbol = icons.symbols.flag_case_sensitive,
        state = state.find.flag_case_sensitive,
        callback = actions.toggle_case_sensitive,
      },
      {
        type = "flag",
        desc = "select: toggle flag regex",
        symbol = icons.symbols.flag_regex,
        state = state.find.flag_regex,
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
        key = "<leader>tc",
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
        local flag_gitignore = state.find.flag_gitignore:snapshot() ---@type boolean
        local excludes = state.find.excludes:snapshot() ---@type string[]

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

    _select = FileSelect.new({
      case_sensitive = state.find.flag_case_sensitive,
      cmp = Select.cmp_by_score,
      dirty_on_invisible = false,
      preview_enabled = true,
      extend_preset_keymaps = false,
      flag_fuzzy = state.find.flag_fuzzy,
      flag_regex = state.find.flag_regex,
      frecency = frecency,
      input = state.find.keyword,
      input_history = input_history,
      input_keymaps = input_keymaps,
      main_keymaps = main_keymaps,
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

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.find_files(context)
  local select = get_select() ---@type fml.ux.IFileSelect
  select:focus()
end

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.find_files_cwd(context)
  state.find.scope:next("C")
  local select = get_select() ---@type fml.ux.IFileSelect
  select:focus()
end

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.find_files_directory(context)
  state.find.scope:next("D")
  local select = get_select() ---@type fml.ux.IFileSelect
  select:focus()
end

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.find_files_workspace(context)
  state.find.scope:next("W")
  local select = get_select() ---@type fml.ux.IFileSelect
  select:focus()
end

return M
