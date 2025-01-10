local ft = require("eve.constant.filetype")
local editor = require("eve.module.editor")

---@class guanghechen.action.avante
local M = {}

---@param context                       eve.command.IContext
---@return nil
function M.ask(context)
  require("avante.api").ask()
  vim.schedule(function()
    local winnr = editor.find_winnr(ft.AVANTE_INPUT) ---@type integer|nil
    if winnr ~= nil then
      vim.api.nvim_tabpage_set_win(context.tabnr, winnr)
    end
  end)
end

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.edit(context)
  require("avante.api").edit()
end

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.refresh(context)
  require("avante.api").refresh()
end

return M
