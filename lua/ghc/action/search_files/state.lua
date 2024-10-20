local state_search_cwd = eve.c.Observable.from_value(fml.api.search.get_scope_cwd(eve.path.cwd()))
eve.context.state.search.scope:subscribe(
  eve.c.Subscriber.new({
    on_next = function()
      local current_buf_dirpath = eve.locations.get_current_buf_dirpath() ---@type string
      local current_search_cwd = state_search_cwd:snapshot() ---@type string
      local next_search_cwd = fml.api.search.get_scope_cwd(current_buf_dirpath) ---@type string
      if current_search_cwd ~= next_search_cwd then
        state_search_cwd:next(next_search_cwd)
      end
      if eve.context.state.search.scope == "B" then
        state_search_cwd:next(next_search_cwd, { force = true })
      end
    end,
  }),
  true
)

local _search = nil ---@type t.fml.ux.search.ISearch|nil

---@class ghc.action.search_files.state
local M = {}

M.search_cwd = state_search_cwd

---@return t.fml.ux.search.ISearch
function M.get_search()
  if _search == nil then
    local api = require("ghc.action.search_files.api")
    local keybindings = require("ghc.action.search_files.keybindings")

    local frecency = eve.context.state.frecency.files ---@type t.eve.collection.IFrecency
    local input_history = eve.context.state.input_history.search_in_files ---@type t.eve.collection.IHistory
    local title = M.get_title() ---@type string

    _search = fml.ux.search.Search.new({
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
      input = eve.context.state.search.keyword,
      input_history = input_history,
      input_keymaps = keybindings.input_keymaps,
      main_keymaps = keybindings.main_keymaps,
      patch_preview_data = api.patch_preview_data,
      permanent = true,
      preview_keymaps = keybindings.preview_keymaps,
      delay_render = 64,
      statusline_items = keybindings.statusline_items,
      title = title,
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

---@return string
function M.get_title()
  local search_paths = eve.context.state.search.search_paths:snapshot() ---@type string[]
  local title = (search_paths ~= nil and #search_paths > 0) --
      and "Search in files (" .. table.concat(search_paths, ",") .. ")"
    or "Search in files"
  return title
end

---@return nil
function M.refresh_title()
  if _search ~= nil then
    local title = M.get_title() ---@type string
    _search:change_input_title(title)
  end
end

return M
