local session = require("ghc.context.session")

local state_find_cwd = fml.collection.Observable.from_value(session.get_find_scope_cwd(fml.path.cwd()))
local _select = nil ---@type fml.types.ui.IFileSelect|nil

---@return nil
local function reload()
  if _select ~= nil then
    _select:mark_data_dirty()
  end
end

fml.fn.watch_observables({ session.find_scope }, function()
  local current_find_cwd = state_find_cwd:snapshot() ---@type string
  local dirpath = fml.ui.search.get_current_path() ---@type string
  local next_find_cwd = session.get_find_scope_cwd(dirpath) ---@type string
  if current_find_cwd ~= next_find_cwd then
    state_find_cwd:next(next_find_cwd)
  end
end, true)
fml.fn.watch_observables({
  session.find_exclude_patterns,
  session.find_flag_case_sensitive,
  session.find_flag_gitignore,
  session.find_flag_fuzzy,
  state_find_cwd,
}, function()
  reload()
end, true)

---@param scope                         ghc.enums.context.FindScope
---@return nil
local function change_scope(scope)
  local scope_current = session.find_scope:snapshot() ---@type ghc.enums.context.FindScope
  if scope_current ~= scope then
    session.find_scope:next(scope)
  end
end

---@class ghc.command.find_files.actions
local actions = {
  ---@return nil
  edit_config = function()
    ---@class ghc.command.find_files.IConfigData
    ---@field public exclude_patterns       string[]

    local f_exclude_patterns = session.find_exclude_patterns:snapshot() ---@type string

    ---@type ghc.command.find_files.IConfigData
    local data = {
      exclude_patterns = fml.array.parse_comma_list(f_exclude_patterns),
    }

    local setting = fml.ui.Setting.new({
      position = "center",
      width = 100,
      title = "Edit Configuration (find files)",
      validate = function(raw_data)
        if type(raw_data) ~= "table" then
          return "Invalid find_files configuration, expect an object."
        end
        ---@cast raw_data ghc.command.find_files.IConfigData

        if raw_data.exclude_patterns == nil or not fml.is.array(raw_data.exclude_patterns) then
          return "Invalid data.exclude_patterns, expect an array."
        end
      end,
      on_confirm = function(raw_data)
        local raw = vim.tbl_extend("force", data, raw_data)
        ---@cast raw ghc.command.find_files.IConfigData

        local exclude_patterns = table.concat(raw.exclude_patterns, ",") ---@type string

        session.find_exclude_patterns:next(exclude_patterns)
        reload()
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
  ---@return nil
  toggle_case_sensitive = function()
    local flag = session.find_flag_case_sensitive:snapshot() ---@type boolean
    session.find_flag_case_sensitive:next(not flag)
  end,
  toggle_flag_fuzzy = function()
    local flag = session.find_flag_fuzzy:snapshot() ---@type boolean
    session.find_flag_fuzzy:next(not flag)
  end,
  ---@return nil
  toggle_gitignore = function()
    local flag = session.find_flag_gitignore:snapshot() ---@type boolean
    session.find_flag_gitignore:next(not flag)
  end,
  ---@return nil
  toggle_scope = function()
    local next_scope = session.get_find_scope_carousel_next() ---@type ghc.enums.context.FindScope
    session.find_scope:next(next_scope)
  end,
}

---@return fml.types.ui.IFileSelect
local function get_select()
  if _select == nil then
    local state_frecency = require("ghc.state.frecency")
    local state_input_history = require("ghc.state.input_history")
    local frecency = state_frecency.load_and_autosave().files ---@type fml.types.collection.IFrecency
    local input_history = state_input_history.load_and_autosave().find_files ---@type fml.types.collection.IHistory

    ---@type fml.types.ui.search.IRawStatuslineItem[]
    local statusline_items = {
      {
        type = "enum",
        desc = "find: toggle scope",
        symbol = "",
        state = session.find_scope,
        callback = actions.toggle_scope,
      },
      {
        type = "flag",
        desc = "find: toggle gitignore",
        symbol = fml.ui.icons.symbols.flag_gitignore,
        state = session.find_flag_gitignore,
        callback = actions.toggle_gitignore,
      },
      {
        type = "flag",
        desc = "find: toggle case sensitive",
        symbol = fml.ui.icons.symbols.flag_case_sensitive,
        state = session.find_flag_case_sensitive,
        callback = actions.toggle_case_sensitive,
      },
      {
        type = "flag",
        desc = "select: toggle fuzzy mode",
        symbol = fml.ui.icons.symbols.flag_fuzzy,
        state = session.find_flag_fuzzy,
        callback = actions.toggle_flag_fuzzy,
      },
    }

    ---@type fml.types.IKeymap[]
    local common_keymaps = {
      {
        modes = { "n", "v" },
        key = "<leader>W",
        callback = actions.change_scope_workspace,
        desc = "find: change scope (workspace)",
      },
      {
        modes = { "n", "v" },
        key = "<leader>C",
        callback = actions.change_scope_cwd,
        desc = "find: change scope (cwd)",
      },
      {
        modes = { "n", "v" },
        key = "<leader>D",
        callback = actions.change_scope_directory,
        desc = "find: change scope (directory)",
      },
      {
        modes = { "n", "v" },
        key = "<leader>c",
        callback = actions.edit_config,
        desc = "find: edit config",
      },
      {
        modes = { "n", "v" },
        key = "<leader>i",
        callback = actions.toggle_case_sensitive,
        desc = "find: toggle case sensitive",
      },
      {
        modes = { "n", "v" },
        key = "<leader>f",
        callback = actions.toggle_flag_fuzzy,
        desc = "find: toggle fuzzy mode",
      },
    }

    ---@type fml.types.IKeymap[]
    local input_keymaps = fml.array.concat({}, common_keymaps)

    ---@type fml.types.IKeymap[]
    local main_keymaps = fml.array.concat({}, common_keymaps)

    ---@type fml.types.IKeymap[]
    local preview_keymaps = fml.array.concat({}, common_keymaps)

    ---@type fml.types.ui.file_select.IProvider
    local provider = {
      fetch_data = function()
        local cwd = state_find_cwd:snapshot() ---@type string
        local workspace = fml.path.workspace() ---@type string
        local exclude_patterns = session.find_exclude_patterns:snapshot() ---@type string
        local flag_gitignore = session.find_flag_gitignore:snapshot() ---@type boolean

        ---@type string[]
        local filepaths = fml.oxi.find({
          workspace = workspace,
          cwd = cwd,
          flag_case_sensitive = false,
          flag_gitignore = flag_gitignore,
          flag_regex = false,
          search_pattern = "",
          search_paths = "",
          exclude_patterns = exclude_patterns,
        })
        table.sort(filepaths)

        local items = fml.ui.FileSelect.make_items_by_filepaths(filepaths) ---@type fml.types.ui.file_select.IRawItem[]
        local data = { cwd = cwd, items = items }
        return data
      end,
    }

    _select = fml.ui.FileSelect.new({
      case_sensitive = session.find_flag_case_sensitive,
      cmp = fml.ui.Select.cmp_by_score,
      destroy_on_close = false,
      dirty_on_close = false,
      enable_preview = true,
      frecency = frecency,
      fuzzy = session.find_flag_fuzzy,
      input = session.find_file_pattern,
      input_history = input_history,
      input_keymaps = input_keymaps,
      main_keymaps = main_keymaps,
      preview_keymaps = preview_keymaps,
      provider = provider,
      statusline_items = statusline_items,
      title = "Find files",
    })
  end
  return _select
end

---@class ghc.command.find_files
local M = {}

---@return nil
function M.open()
  local select = get_select() ---@type fml.types.ui.IFileSelect
  select:focus()
end

---@return nil
function M.open_workspace()
  session.find_scope:next("W")
  M.open()
end

---@return nil
function M.open_cwd()
  session.find_scope:next("C")
  M.open()
end

---@return nil
function M.open_directory()
  session.find_scope:next("D")
  M.open()
end

return M
