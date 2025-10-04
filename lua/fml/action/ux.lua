---@class fml.action.ux
local M = {}

---@param arg                           unknown|nil
---@return nil
function M.reload_theme(arg)
  local force = type(arg) == "string" and arg:lower() == "force" ---@type boolean
  eve.context.theme.reload_theme(force, true)
end

---@return nil
function M.resume_last_widget()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local meta = eve.win.resolve(winnr, false) ---@type eve.builtin.win.IMeta|nil
  if meta ~= nil and meta.wintype == eve.win.Types.MAXIMIZE then
    eve.command.execute(eve.command.definitions.toggle.maximize.uuid)
    return
  end

  -- Check if searcher buffer widget exists and is visible
  local search_buffer_action = require("fml.action.search.buffer")
  local searcher = search_buffer_action.get_searcher() ---@type eve.ux.searcher.buffer.Searcher|nil
  if searcher ~= nil then
    local winnr_finder = searcher:get_winnr_finder() ---@type integer|nil
    if winnr_finder ~= nil and vim.api.nvim_win_is_valid(winnr_finder) then
      -- Searcher buffer widget exists, focus back to the last focused window
      searcher:focus_last()
      return
    end
  end

  if eve.widget.resume() then
    local widget, widget_index = eve.widget.get_widget_visible() ---@type std.t.ux.IWidget|nil
    if widget ~= nil and widget_index ~= nil then
      widget:focus()
      eve.widget.history:go(widget_index)
    else
      local winnr_command = eve.status.get_winnr_command() ---@type integer|nil
      if winnr_command ~= nil then
        vim.api.nvim_set_current_win(winnr_command)
      end
    end
  else
    eve.command.execute(eve.command.definitions.find.files.uuid)
  end
end

return M
