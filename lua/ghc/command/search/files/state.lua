local __module_name__ = "ghc.command.search.files" ---@type string

local path = require("eve.lib.path")
local reporter = require("eve.lib.reporter")
local Observable = require("eve.lib.collection.observable")
local Subscriber = require("eve.lib.collection.subscriber")
local checks = require("eve.builtin.checks")
local state = require("eve.state")

---@param dirpath                       string
---@return string
local function get_scope_cwd(dirpath)
  local scope = state.state.search.scope:snapshot() ---@type eve.e.SearchScope

  if scope == "W" then
    return path.workspace()
  end

  if scope == "C" then
    return path.cwd()
  end

  if scope == "D" then
    return dirpath
  end

  if scope == "B" then
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

local state_search_cwd = Observable.from_value(get_scope_cwd(path.cwd()))
state.state.search.scope:subscribe(
  Subscriber.new({
    on_next = function(scope)
      local bufnr = eve.tab.get_current_bufnr() ---@type integer
      ---@type string
      local current_buf_dirpath = checks.is_buf_valid(bufnr) --
          and path.dirname(vim.api.nvim_buf_get_name(bufnr))
        or path.cwd()

      local current_search_cwd = state_search_cwd:snapshot() ---@type string
      local next_search_cwd = get_scope_cwd(current_buf_dirpath) ---@type string
      if current_search_cwd ~= next_search_cwd then
        state_search_cwd:next(next_search_cwd)
      end
      if scope == "B" then
        state_search_cwd:next(next_search_cwd, { force = true })
      end
    end,
  }),
  true
)

local _search = nil ---@type fml.t.ux.search.ISearch|nil

---@class ghc.command.search.files.state
local M = {}

M.search_cwd = state_search_cwd

---@return fml.t.ux.search.ISearch
function M.get_search()
  if _search == nil then
    local api = require("ghc.command.search.files.api")
    local keybindings = require("ghc.command.search.files.keybindings")

    local frecency = state.state.frecency.files ---@type eve.lib.collection.IFrecency
    local input_history = state.state.input_history.search_in_files ---@type eve.lib.collection.IHistory
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
      input = state.state.search.keyword,
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
        vim.cmd.checktime()
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
  local search_paths = state.state.search.search_paths:snapshot() ---@type string[]
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
