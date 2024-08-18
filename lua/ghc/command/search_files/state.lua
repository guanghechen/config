local session = require("ghc.context.session")
local statusline = require("ghc.ui.statusline")

local _initial_dirpath = vim.fn.expand("%:p:h") ---@type string
local state_search_cwd = fml.collection.Observable.from_value(session.get_search_scope_cwd(_initial_dirpath))
fml.fn.watch_observables({ session.search_scope }, function()
  local current_search_cwd = state_search_cwd:snapshot() ---@type string
  local dirpath = fml.ui.search.get_current_path() ---@type string
  local next_search_cwd = session.get_search_scope_cwd(dirpath) ---@type string
  if current_search_cwd ~= next_search_cwd then
    state_search_cwd:next(next_search_cwd)
  end
  if session.search_scope == "B" then
    state_search_cwd:next(next_search_cwd, { force = true })
  end
end, true)

local _search = nil ---@type fml.types.ui.search.ISearch|nil

---@class ghc.command.search_files.state
local M = {}

M.search_cwd = state_search_cwd

---@return fml.types.ui.search.ISearch
function M.get_search()
  if _search == nil then
    local state_frecency = require("ghc.state.frecency")
    local state_input_history = require("ghc.state.input_history")
    local api = require("ghc.command.search_files.api")
    local keybindings = require("ghc.command.search_files.keybindings")

    local frecency = state_frecency.load_and_autosave().files ---@type fml.types.collection.IFrecency
    local input_history = state_input_history.load_and_autosave().search_in_files ---@type fml.types.collection.IHistory

    _search = fml.ui.search.Search.new({
      title = "Search in files",
      input = session.search_pattern,
      input_history = input_history,
      input_keymaps = keybindings.input_keymaps,
      main_keymaps = keybindings.main_keymaps,
      preview_keymaps = keybindings.preview_keymaps,
      fetch_items = api.fetch_items,
      fetch_delay = 512,
      render_delay = 64,
      width = 0.4,
      height = 0.8,
      width_preview = 0.45,
      max_height = 1,
      max_width = 1,
      on_close = function()
        statusline.disable(statusline.cnames.search_files)
      end,
      fetch_preview_data = api.fetch_preview_data,
      patch_preview_data = api.patch_preview_data,
      on_confirm = function(item)
        return api.open_file(item, frecency)
      end,
    })
  end
  return _search
end

---@return nil
function M.reload()
  if _search ~= nil then
    _search.state:mark_dirty()
  end
end

return M