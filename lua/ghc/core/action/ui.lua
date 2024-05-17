---@class ghc.core.action.ui.context
local context = {
  config = require("ghc.core.context.config"),
}

---@class ghc.core.action.ui
local M = {}

function M.show_inspect_pos()
  vim.show_pos()
end

function M.dismiss_notifications()
  require("notify").dismiss({
    silent = true,
    pending = true,
  })
end

function M.toggle_transparency()
  context.config.transparency:next(not context.config.transparency:get_snapshot())

  require("nvconfig").ui.transparency = context.config.transparency:get_snapshot()
  require("base46").load_all_highlights()
end

function M.toggle_theme()
  ---@type boolean
  local darken = context.config.darken:get_snapshot()
  context.config.darken:next(not darken)

  require("nvconfig").ui.theme = context.config.get_current_theme()
  require("base46").load_all_highlights()
end

function M.toggle_relative_line_number()
  ---@type boolean
  local next_relativenumber = not context.config.relativenumber:get_snapshot()
  context.config.relativenumber:next(next_relativenumber)

  local bufnr = vim.api.nvim_get_current_buf()

  if next_relativenumber then
    vim.cmd("bufdo set relativenumber")
  else
    vim.cmd("bufdo set norelativenumber")
  end
  vim.opt.relativenumber = next_relativenumber
  vim.api.nvim_set_current_buf(bufnr)
end

return M
