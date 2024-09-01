local session = require("ghc.context.session")

local state_search_cwd = fc.c.Observable.from_value(session.get_search_scope_cwd(fc.path.cwd()))
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

    local frecency = state_frecency.load_and_autosave().files ---@type fc.types.collection.IFrecency
    local input_history = state_input_history.load_and_autosave().search_in_files ---@type fc.types.collection.IHistory

    _search = fml.ui.search.Search.new({
      destroy_on_close = false,
      dimension = {
        height = 0.8,
        max_height = 1,
        max_width = 1,
        width = 0.4,
        width_preview = 0.45,
      },
      enable_multiline_input = true,
      fetch_data = api.fetch_data,
      delay_fetch = 512,
      fetch_preview_data = api.fetch_preview_data,
      input = session.search_pattern,
      input_history = input_history,
      input_keymaps = keybindings.input_keymaps,
      main_keymaps = keybindings.main_keymaps,
      patch_preview_data = api.patch_preview_data,
      preview_keymaps = keybindings.preview_keymaps,
      delay_render = 64,
      statusline_items = keybindings.statusline_items,
      title = "Search in files",
      on_close = function()
        vim.cmd("checktime")
      end,
      on_confirm = function(item)
        return api.open_file(item, frecency)
      end,
    })
  end
  return _search
end

---@param uuid                          string
---@return boolean
function M.has_item_deleted(uuid)
  return _search ~= nil and _search.state:has_item_deleted(uuid)
end

---@param uuid                          string
---@return nil
function M.mark_item_deleted(uuid)
  if _search ~= nil then
    _search.state:mark_item_deleted(uuid)
  end
end

---@return nil
function M:mark_all_items_deleted()
  if _search ~= nil then
    _search.state:mark_all_items_deleted()
  end
end

---@return nil
function M.reload()
  if _search ~= nil then
    _search.state.dirtier_data:mark_dirty()
  end
end

---@param text                          string
---@return nil
function M.reset_input(text)
  if _search ~= nil then
    _search:reset_input(text)
  end
end

---@return nil
function M.close()
  if _search ~= nil then
    _search:close()
  end
end

return M
