local session = require("ghc.context.session")

local initial_dirpath = vim.fn.expand("%:p:h") ---@type string
local state_find_cwd = fml.collection.Observable.from_value(session.get_find_scope_cwd(initial_dirpath))
fml.fn.watch_observables({ session.find_scope }, function()
  local current_find_cwd = state_find_cwd:snapshot() ---@type string
  local dirpath = fml.ui.search.get_current_path() ---@type string
  local next_find_cwd = session.get_find_scope_cwd(dirpath) ---@type string
  if current_find_cwd ~= next_find_cwd then
    state_find_cwd:next(next_find_cwd)
  end
end, true)

local _select = nil ---@type fml.types.ui.select.ISelect|nil

---@class ghc.command.find_files.state
local M = {}

M.find_cwd = state_find_cwd

fml.fn.watch_observables({
  session.find_exclude_patterns,
  session.find_flag_case_sensitive,
  session.find_flag_gitignore,
  state_find_cwd,
}, function()
  M.reload()
end, true)

---@return fml.types.ui.select.ISelect
function M.get_select()
  if _select == nil then
    local state_frecency = require("ghc.state.frecency")
    local state_input_history = require("ghc.state.input_history")
    local keybindings = require("ghc.command.find_files.keybindings")

    local frecency = state_frecency.load_and_autosave().files ---@type fml.types.collection.IFrecency
    local input_history = state_input_history.load_and_autosave().find_files ---@type fml.types.collection.IHistory

    _select = fml.ui.select.Select.new({
      title = "Find files",
      statusline_items = keybindings.statusline_items,
      items = {},
      case_sensitive = session.find_flag_case_sensitive,
      input = session.find_file_pattern,
      input_history = input_history,
      frecency = frecency,
      render_line = fml.ui.select.defaults.render_filepath,
      input_keymaps = keybindings.input_keymaps,
      main_keymaps = keybindings.main_keymaps,
      preview_keymaps = keybindings.preview_keymaps,
      width = 0.4,
      height = 0.8,
      width_preview = 0.45,
      max_height = 1,
      max_width = 1,
      on_close = function() end,
      fetch_preview_data = function(item)
        local cwd = state_find_cwd:snapshot() ---@type string
        local filepath = fml.path.join(cwd, item.display) ---@type string
        local filename = fml.path.basename(filepath) ---@type string

        local is_text_file = fml.is.printable_file(filename) ---@type boolean
        if is_text_file then
          local filetype = vim.filetype.match({ filename = filename }) ---@type string|nil
          local lines = fml.fs.read_file_as_lines({ filepath = filepath, max_lines = 300, silent = true }) ---@type string[]

          ---@type fml.ui.search.preview.IData
          return {
            lines = lines,
            highlights = {},
            filetype = filetype,
            show_numbers = true,
            title = item.display,
          }
        end

        ---@type fml.types.ui.IHighlight[]
        local highlights = { { lnum = 1, coll = 0, colr = -1, hlname = "f_us_preview_error" } }

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
    local exclude_patterns = session.find_exclude_patterns:snapshot() ---@type string
    local flag_gitignore = session.find_flag_gitignore:snapshot() ---@type boolean

    ---@type string[]
    local filepaths = fml.oxi.find({
      workspace = workspace,
      cwd = find_cwd,
      flag_case_sensitive = false,
      flag_gitignore = flag_gitignore,
      flag_regex = false,
      search_pattern = "",
      search_paths = "",
      exclude_patterns = exclude_patterns,
    })
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

return M
