local constant = require("fml.constant")
local statusline = require("ghc.ui.statusline")
local session = require("ghc.context.session")
local state_frecency = require("ghc.state.frecency")
local state_input_history = require("ghc.state.input_history")

---@class ghc.command.find_files
local M = {}

local _select = nil ---@type fml.types.ui.select.ISelect|nil
local initial_dirpath = vim.fn.expand("%:p:h") ---@type string
local state_dirpath = fml.collection.Observable.from_value(initial_dirpath)
local state_find_cwd = fml.collection.Observable.from_value(session.get_find_scope_cwd(initial_dirpath))
fml.fn.watch_observables({ session.find_scope }, function()
  local current_find_cwd = state_find_cwd:snapshot() ---@type string
  local dirpath = state_dirpath:snapshot() ---@type string
  local next_find_cwd = session.get_find_scope_cwd(dirpath) ---@type string
  if current_find_cwd ~= next_find_cwd then
    state_find_cwd:next(next_find_cwd)
    M.reload()
  end
end, true)

---@param scope                         ghc.enums.context.FindScope
---@return nil
local function change_scope(scope)
  local scope_current = session.find_scope:snapshot() ---@type ghc.enums.context.FindScope
  if _select ~= nil and scope_current ~= scope then
    session.find_scope:next(scope)
  end
end

---@return nil
local function edit_config()
  ---@class ghc.command.find_files.IConfigData
  ---@field public exclude_patterns       string[]

  ---@type ghc.command.find_files.IConfigData
  local data = {
    exclude_patterns = session.find_exclude_pattern:snapshot(),
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
      ---@cast raw_data ghc.command.find_files.IConfigData
      local raw = vim.tbl_extend("force", data, raw_data)

      local exclude_patterns = raw.exclude_patterns ---@type string[]
      session.find_exclude_pattern:next(exclude_patterns)
      M.reload()
    end,
  })
  setting:open({
    initial_value = data,
    text_cursor_row = 1,
    text_cursor_col = 1,
  })
end

---@return fml.types.ui.select.ISelect
local function get_select()
  if _select == nil then
    local actions = {
      change_scope_workspace = function()
        change_scope("W")
      end,
      change_scope_cwd = function()
        change_scope("C")
      end,
      change_scope_directory = function()
        change_scope("D")
      end,
    }

    ---@type fml.types.IKeymap[]
    local input_keymaps = {
      {
        modes = { "i", "n" },
        key = "<C-a>c",
        callback = edit_config,
        desc = "find: edit configuration",
      },
      {
        modes = { "n", "v" },
        key = "<leader>w",
        callback = actions.change_scope_workspace,
        desc = "find: change scope (workspace)",
      },
      {
        modes = { "n", "v" },
        key = "<leader>c",
        callback = actions.change_scope_cwd,
        desc = "find: change scope (cwd)",
      },
      {
        modes = { "n", "v" },
        key = "<leader>d",
        callback = actions.change_scope_directory,
        desc = "find: change scope (directory)",
      },
    }

    ---@type fml.types.IKeymap[]
    local main_keymaps = vim.tbl_deep_extend("force", {}, input_keymaps)

    local dirpath = state_dirpath:snapshot() ---@type string
    local find_cwd = session.get_find_scope_cwd(dirpath) ---@type string
    state_find_cwd:next(find_cwd)

    local frecency = state_frecency.load_and_autosave().files ---@type fml.types.collection.IFrecency
    local input_history = state_input_history.load_and_autosave().find_files ---@type fml.types.collection.IHistory
    _select = fml.ui.select.Select.new({
      title = "Find files",
      items = {},
      input = session.find_file_pattern,
      input_history = input_history,
      frecency = frecency,
      render_line = fml.ui.select.defaults.render_filepath,
      input_keymaps = input_keymaps,
      main_keymaps = main_keymaps,
      width = 0.4,
      height = 0.8,
      width_preview = 0.45,
      max_height = 1,
      max_width = 1,
      on_close = function()
        statusline.disable(statusline.cnames.find_files)
      end,
      fetch_preview_data = function(item)
        local cwd = state_find_cwd:snapshot() ---@type string
        local filepath = fml.path.join(cwd, item.display) ---@type string

        local is_text_file = fml.fs.is_text_file(filepath) ---@type boolean
        if is_text_file then
          local filename = fml.path.basename(filepath) ---@type string
          local filetype = vim.filetype.match({ filename = filename }) ---@type string|nil

          ---@type fml.ui.search.preview.IData
          return {
            lines = fml.fs.read_file_as_lines({ filepath = filepath, silent = true }),
            highlights = {},
            filetype = filetype,
            show_numbers = true,
            title = item.display,
          }
        end
        local highlights = {} ---@type table<integer, fml.types.ui.printer.ILineHighlight[]>
        highlights[1] = { { cstart = 0, cend = -1, hlname = "f_us_preview_error" } }

        ---@type fml.ui.search.preview.IData
        return {
          lines = { "  Not a text file, cannot preview." },
          highlights = highlights,
          filetype = nil,
          show_numbers = false,
          title = item.display,
        }
      end,
      on_confirm = function(item)
        local winnr = fml.api.state.win_history:present() ---@type integer
        if winnr ~= nil then
          local cwd = state_find_cwd:snapshot() ---@type string
          local filepath = fml.path.join(cwd, item.display) ---@type string
          vim.schedule(function()
            fml.api.buf.open(winnr, filepath)
          end)
          return true
        end
        return false
      end,
    })
  end

  M.reload()
  return _select
end

---@return nil
function M.reload()
  if _select ~= nil then
    local find_cwd = state_find_cwd:snapshot() ---@type string
    local workspace = fml.path.workspace() ---@type string
    local exclude_pattern = session.find_exclude_pattern:snapshot() ---@type string[]
    local filepaths = fml.oxi.collect_file_paths(find_cwd, exclude_pattern)
    local items = {} ---@type fml.types.ui.select.IItem[]
    for _, filepath in ipairs(filepaths) do
      local absolute_filepath = fml.path.resolve(find_cwd, filepath) ---@type string
      local relative_filepath = fml.path.relative(workspace, absolute_filepath) ---@type string
      local item = {
        group = nil,
        uuid = relative_filepath,
        display = filepath,
        lower = filepath:lower(),
      } ---@type fml.types.ui.select.IItem
      table.insert(items, item)
    end
    table.sort(items, function(a, b)
      return a.display < b.display
    end)
    _select:update_items(items)
  end
end

---@return nil
function M.focus()
  state_dirpath:next(vim.fn.expand("%:p:h"))
  local select = get_select() ---@type fml.types.ui.select.ISelect
  statusline.enable(statusline.cnames.find_files)
  select:focus()
end

return M
