local session = require("ghc.context.session")

local state_find_cwd = eve.c.Observable.from_value(session.get_find_scope_cwd(eve.path.cwd()))
local _select = nil ---@type fml.types.ui.IFileSelect|nil

---@return nil
local function reload()
  if _select ~= nil then
    _select:mark_data_dirty()
  end
end

session.find_scope:subscribe(
  eve.c.Subscriber.new({
    on_next = function()
      local current_buf_dirpath = eve.widgets.get_current_buf_dirpath() ---@type string
      local current_find_cwd = state_find_cwd:snapshot() ---@type string
      local next_find_cwd = session.get_find_scope_cwd(current_buf_dirpath) ---@type string
      if current_find_cwd ~= next_find_cwd then
        state_find_cwd:next(next_find_cwd)
      end
    end,
  }),
  true
)
eve.mvc.observe({
  session.find_exclude_patterns,
  session.find_flag_case_sensitive,
  session.find_flag_gitignore,
  session.find_flag_fuzzy,
  session.find_flag_regex,
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
      exclude_patterns = eve.array.parse_comma_list(f_exclude_patterns),
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

        if raw_data.exclude_patterns == nil or not vim.islist(raw_data.exclude_patterns) then
          return "Invalid data.exclude_patterns, expect an array."
        end
      end,
      on_confirm = function(raw_data)
        vim.schedule(function()
          local raw = vim.tbl_extend("force", data, raw_data)
          ---@cast raw ghc.command.find_files.IConfigData

          local exclude_patterns = table.concat(raw.exclude_patterns, ",") ---@type string

          session.find_exclude_patterns:next(exclude_patterns)
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
      local cwd = eve.path.cwd() ---@type string
      local select_cwd = state_find_cwd:snapshot() ---@type string
      local quickfix_items = {} ---@type eve.types.IQuickFixItem[]
      local matched_items = _select:get_matched_items() ---@type fml.types.ui.select.IMatchedItem[]
      for _, matched_item in ipairs(matched_items) do
        local item = _select:get_item(matched_item.uuid) ---@type fml.types.ui.select.IItem|nil
        ---@cast item fml.types.ui.file_select.IItem

        if item ~= nil then
          local absolute_filepath = eve.path.join(select_cwd, item.data.filepath) ---@type string
          local relative_filepath = eve.path.relative(cwd, absolute_filepath, false) ---@type string
          table.insert(quickfix_items, {
            filename = relative_filepath,
            lnum = item.data.lnum or 1,
            col = item.data.col or 0,
          })
        end
      end

      if #quickfix_items > 0 then
        _select:close()

        eve.qflist.push(quickfix_items)
        eve.qflist.open_qflist(false)
      end
    end
  end,
  toggle_case_sensitive = function()
    local flag = session.find_flag_case_sensitive:snapshot() ---@type boolean
    session.find_flag_case_sensitive:next(not flag)
  end,
  toggle_flag_fuzzy = function()
    local flag = session.find_flag_fuzzy:snapshot() ---@type boolean
    session.find_flag_fuzzy:next(not flag)
  end,
  toggle_flag_regex = function()
    local flag = session.find_flag_regex:snapshot() ---@type boolean
    session.find_flag_regex:next(not flag)
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
    local frecency = state_frecency.load_and_autosave().files ---@type eve.types.collection.IFrecency
    local input_history = state_input_history.load_and_autosave().find_files ---@type eve.types.collection.IHistory

    ---@type eve.types.ux.widgets.IRawStatuslineItem[]
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
        symbol = eve.icons.symbols.flag_gitignore,
        state = session.find_flag_gitignore,
        callback = actions.toggle_gitignore,
      },
      {
        type = "flag",
        desc = "select: toggle flag fuzzy",
        symbol = eve.icons.symbols.flag_fuzzy,
        state = session.find_flag_fuzzy,
        callback = actions.toggle_flag_fuzzy,
      },
      {
        type = "flag",
        desc = "find: toggle case sensitive",
        symbol = eve.icons.symbols.flag_case_sensitive,
        state = session.find_flag_case_sensitive,
        callback = actions.toggle_case_sensitive,
      },
      {
        type = "flag",
        desc = "select: toggle flag regex",
        symbol = eve.icons.symbols.flag_regex,
        state = session.find_flag_regex,
        callback = actions.toggle_flag_regex,
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
        key = "<leader>r",
        callback = actions.toggle_flag_regex,
        desc = "find: toggle flag regex",
      },
      {
        modes = { "i", "n", "v" },
        key = "<C-q>",
        callback = actions.send_to_qflist,
        desc = "search: send to qflist",
      },
    }

    ---@type fml.types.IKeymap[]
    local input_keymaps = eve.array.concat({}, common_keymaps)

    ---@type fml.types.IKeymap[]
    local main_keymaps = eve.array.concat({}, common_keymaps)

    ---@type fml.types.IKeymap[]
    local preview_keymaps = eve.array.concat({}, common_keymaps)

    ---@type fml.types.ui.file_select.IProvider
    local provider = {
      fetch_data = function()
        local cwd = state_find_cwd:snapshot() ---@type string
        local workspace = eve.path.workspace() ---@type string
        local exclude_patterns = session.find_exclude_patterns:snapshot() ---@type string
        local flag_gitignore = session.find_flag_gitignore:snapshot() ---@type boolean

        ---@type string[]
        local filepaths = eve.oxi.find({
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
      dirty_on_close = false,
      enable_preview = true,
      extend_preset_keymaps = false,
      flag_fuzzy = session.find_flag_fuzzy,
      flag_regex = session.find_flag_regex,
      frecency = frecency,
      input = session.find_file_pattern,
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
