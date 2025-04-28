local __module_name__ = "fml.action.find" ---@type string

local observable_truthy = eve.std.Observable.from_value(true)
local _select = nil ---@type eve.ux.IFileSelect|nil

---@param dirpath                       string
---@return string
local function get_scope_cwd(dirpath)
  local scope = eve.state.select.find_file_scope:snapshot() ---@type eve.e.FindFileScope
  if scope == "W" then
    return eve.path.workspace()
  elseif scope == "C" then
    return eve.path.cwd()
  elseif scope == "D" then
    return dirpath
  end

  eve.reporter.error({
    from = __module_name__,
    subject = "get_scope_cwd",
    message = "Unknown scope.",
    details = { scope = scope, dirpath = dirpath },
  })
  return eve.path.cwd()
end

local scopes = vim.list_slice(eve.state.select.find_file_scopes) ---@type eve.e.FindFileScope[]
local state_cwd = eve.std.Observable.from_value(get_scope_cwd(eve.path.cwd()))

---@return string
local function gen_title()
  local scope = eve.state.select.find_file_scope:snapshot() ---@type eve.e.FindFileScope
  if scope == "W" then
    return "Find files (workspace)" ---@type string
  elseif scope == "C" then
    return "Find files (cwd)" ---@type string
  end

  local cwd = eve.path.cwd() ---@type string
  local dirpath = state_cwd:snapshot() ---@type string
  if dirpath == cwd then
    return "Find files (dir: .)" ---@type string
  end

  local relative_dirpath = eve.path.relative(cwd, dirpath, false)
  if #relative_dirpath < 1 or relative_dirpath == "." then
    return "Find files (dir: .)" ---@type string
  end

  dirpath = relative_dirpath:sub(1, 1) ~= "." and relative_dirpath or dirpath
  return "Find files (dir: " .. dirpath .. ")" ---@type string
end

eve.state.observe({ eve.state.select.find_file_scope }, function()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local _, bufnr_sourcefile = eve.tab.retrieve_buf_sourcefile(tabnr) ---@type eve.builtin.tab.IBufItem|nil, integer|nil
  local current_buf_dirpath = bufnr_sourcefile ~= nil and eve.path.dirname(vim.api.nvim_buf_get_name(bufnr_sourcefile))
    or eve.path.cwd() ---@type string
  local current_find_cwd = state_cwd:snapshot() ---@type string
  local next_find_cwd = get_scope_cwd(current_buf_dirpath) ---@type string
  if current_find_cwd ~= next_find_cwd then
    state_cwd:next(next_find_cwd)
  end
end, true)

eve.state.observe({
  eve.state.select.find_file.excludes,
  eve.state.select.find_file.flag_case_sensitive,
  eve.state.select.find_file.flag_exclude,
  eve.state.select.find_file.flag_fuzzy,
  eve.state.select.find_file.flag_gitignore,
  eve.state.select.find_file.flag_regex,
}, function()
  if _select ~= nil then
    _select:mark_data_dirty()
  end
end, true)

eve.state.observe({
  eve.state.select.find_file_scope,
  state_cwd,
}, function()
  if _select ~= nil then
    _select:mark_data_dirty()

    local title = gen_title() ---@type string
    _select:change_input_title(title)
  end
end, true)

---@param scope                         eve.e.FindFileScope
---@return nil
local function change_scope(scope)
  local scope_current = eve.state.select.find_file_scope:snapshot() ---@type eve.e.FindFileScope
  if scope_current ~= scope then
    eve.state.select.find_file_scope:next(scope)
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

    local s_keyword = eve.state.select.find_file.input:snapshot() ---@type string
    local s_includes = eve.state.select.find_file.includes:snapshot() ---@type string[]
    local s_excludes = eve.state.select.find_file.excludes:snapshot() ---@type string[]

    ---@type fml.action.find.files.actions.IConfigData
    local data = {
      keyword = s_keyword,
      includes = s_includes,
      excludes = s_excludes,
    }

    local setting = eve.ux.Setting.new({
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
          local last_keyword = eve.state.select.search_file.input:snapshot() ---@type string

          local raw = vim.tbl_extend("force", data, raw_data)
          ---@cast raw                  fml.action.find.files.actions.IConfigData

          local keyword = raw.keyword ---@type string
          local includes = raw.includes ---@type string[]
          local excludes = raw.excludes ---@type string[]

          eve.state.select.find_file.input:next(keyword)
          eve.state.select.find_file.includes:next(includes)
          eve.state.select.find_file.excludes:next(excludes)

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
      local cwd = eve.path.cwd() ---@type string
      local select_cwd = state_cwd:snapshot() ---@type string
      local quickfix_items = {} ---@type eve.t.IQuickFixItem[]
      local matched_items = _select:get_matched_items() ---@type eve.ux.select.IMatchedItem[]
      for _, matched_item in ipairs(matched_items) do
        local item = _select:get_item(matched_item.uuid) ---@type eve.ux.select.IItem|nil
        ---@cast item                   eve.ux.select_file.IItem

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
    local flag = eve.state.select.find_file.flag_case_sensitive:snapshot() ---@type boolean
    eve.state.select.find_file.flag_case_sensitive:next(not flag)
  end,
  toggle_flag_exclude = function()
    local flag = eve.state.select.find_file.flag_exclude:snapshot() ---@type boolean
    eve.state.select.find_file.flag_exclude:next(not flag)
  end,
  toggle_flag_fuzzy = function()
    local flag = eve.state.select.find_file.flag_fuzzy:snapshot() ---@type boolean
    eve.state.select.find_file.flag_fuzzy:next(not flag)
  end,
  ---@return nil
  toggle_flag_gitignore = function()
    local flag = eve.state.select.find_file.flag_gitignore:snapshot() ---@type boolean
    eve.state.select.find_file.flag_gitignore:next(not flag)
  end,
  toggle_flag_regex = function()
    local flag = eve.state.select.find_file.flag_regex:snapshot() ---@type boolean
    eve.state.select.find_file.flag_regex:next(not flag)
  end,
  ---@return nil
  toggle_flag_scope = function()
    local scope = eve.state.select.find_file_scope:snapshot() ---@type eve.e.FindFileScope
    local idx = eve.table.find_index(scopes, scope) or 1 ---@type integer
    local idx_next = idx == #scopes and 1 or idx + 1 ---@type integer
    local next_scope = scopes[idx_next] ---@type eve.e.FindFileScope
    eve.state.select.find_file_scope:next(next_scope)
  end,
  ---@return nil
  toggle_flag_selected = function()
    local flag = eve.state.select.find_file.flag_selected:snapshot() ---@type boolean
    eve.state.select.find_file.flag_selected:next(not flag)
  end,
}

---@type eve.t.ux.widget.IRawStatuslineItem[]
local statusline_items = {
  {
    type = "popup",
    desc = "find: edit settings",
    symbol = eve.icon.symbols.setting,
    state = observable_truthy,
    callback = actions.edit_config,
  },
  {
    type = "enum",
    desc = "find: toggle scope",
    symbol = "",
    state = eve.state.select.find_file_scope,
    callback = actions.toggle_flag_scope,
  },
  {
    type = "flag",
    desc = "find: toggle selected",
    symbol = eve.icon.symbols.flag_selected,
    state = eve.state.select.find_file.flag_selected,
    callback = actions.toggle_flag_selected,
  },
  {
    type = "flag",
    desc = "find: toggle exclude",
    symbol = eve.icon.symbols.flag_exclude,
    state = eve.state.select.find_file.flag_exclude,
    callback = actions.toggle_flag_exclude,
  },
  {
    type = "flag",
    desc = "find: toggle gitignore",
    symbol = eve.icon.symbols.flag_gitignore,
    state = eve.state.select.find_file.flag_gitignore,
    callback = actions.toggle_flag_gitignore,
  },
  {
    type = "flag",
    desc = "select: toggle flag fuzzy",
    symbol = eve.icon.symbols.flag_fuzzy,
    state = eve.state.select.find_file.flag_fuzzy,
    callback = actions.toggle_flag_fuzzy,
  },
  {
    type = "flag",
    desc = "find: toggle case sensitive",
    symbol = eve.icon.symbols.flag_case_sensitive,
    state = eve.state.select.find_file.flag_case_sensitive,
    callback = actions.toggle_case_sensitive,
  },
  {
    type = "flag",
    desc = "select: toggle flag regex",
    symbol = eve.icon.symbols.flag_regex,
    state = eve.state.select.find_file.flag_regex,
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

---@type eve.ux.select_file.IProvider
local provider = {
  fetch_data = function()
    local cwd = state_cwd:snapshot() ---@type string
    local workspace = eve.path.workspace() ---@type string
    local flag_exclude = eve.state.select.find_file.flag_exclude:snapshot() ---@type boolean
    local flag_gitignore = eve.state.select.find_file.flag_gitignore:snapshot() ---@type boolean
    local excludes = flag_exclude and eve.state.select.find_file.excludes:snapshot() or {} ---@type string[]

    ---@type string[]
    local filepaths = eve.oxi.find({
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

    local items = {} ---@type eve.ux.select_file.IRawItem[]
    for _, relative_filepath in ipairs(filepaths) do
      local filepath = eve.path.resolve(cwd, relative_filepath) ---@type string
      ---@type eve.ux.select_file.IRawItem
      local item = {
        filepath = filepath,
        filepath_relative = relative_filepath,
      }
      table.insert(items, item)
    end
    local data = { items = items } ---@type eve.ux.select_file.IData
    return data
  end,
}

local states = eve.state.select.find_file ---@type eve.state.select.item.state

---@type eve.ux.IFileSelect
local select = eve.ux.FileSelect.new({
  case_sensitive = states.flag_case_sensitive,
  cmp = eve.ux.Select.cmp_by_score,
  dirty_on_invisible = false,
  preview_enabled = true,
  extend_preset_keymaps = false,
  flag_fuzzy = states.flag_fuzzy,
  flag_regex = states.flag_regex,
  flag_selected = states.flag_selected,
  frecency = eve.state.frecency.files,
  input = states.input,
  input_history = states.input_history,
  input_keymaps = input_keymaps,
  main_keymaps = main_keymaps,
  multiple = true,
  permanent = true,
  preview_keymaps = preview_keymaps,
  provider = provider,
  statusline_items = statusline_items,
  title = gen_title(),
})
_select = select

---@class fml.action.find
local M = {}

---@return nil
function M.find_files()
  select:show()
end

---@return nil
function M.find_files_cwd()
  eve.state.select.find_file_scope:next("C")
  select:show()
end

---@param specified_filepath            string|nil
---@return nil
function M.find_files_directory(specified_filepath)
  local silent = false ---@type boolean
  if specified_filepath ~= nil and #specified_filepath > 0 then
    if eve.path.is_exist_dirpath(specified_filepath) then
      local dirpath = eve.path.normalize(specified_filepath) ---@type string
      state_cwd:next(dirpath)
      silent = true
    elseif eve.path.is_exist_filepath(specified_filepath) then
      local dirpath = eve.path.dirname(specified_filepath) ---@type string
      state_cwd:next(dirpath)
      silent = true
    end
  end
  eve.state.select.find_file_scope:next("D", { silent = silent })
  eve.status.dirtier_statusline:mark_dirty()
  select:show()
end

---@return nil
function M.find_files_workspace()
  eve.state.select.find_file_scope:next("W")
  select:show()
end

return M
