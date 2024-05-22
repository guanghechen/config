local context_config = require("ghc.core.context.config")
local context_session = require("ghc.core.context.session")

---@class ghc.core.action.toggle
local M = {}

function M.flight_copilot()
  local flight_copilot_next = not context_session.flight_copilot:get_snapshot() ---@type boolean
  context_session.flight_copilot:next(flight_copilot_next)
end

function M.transparency()
  context_config.transparency:next(not context_config.transparency:get_snapshot())

  require("nvconfig").ui.transparency = context_config.transparency:get_snapshot()
  require("base46").load_all_highlights()
end

function M.theme()
  ---@type boolean
  local darken = context_config.darken:get_snapshot()
  context_config.darken:next(not darken)

  require("nvconfig").ui.theme = context_config.get_current_theme()
  require("base46").load_all_highlights()
end

function M.relative_line_number()
  ---@type boolean
  local next_relativenumber = not context_config.relativenumber:get_snapshot()
  context_config.relativenumber:next(next_relativenumber)

  local bufnr = vim.api.nvim_get_current_buf()

  if next_relativenumber then
    vim.cmd("bufdo set relativenumber")
  else
    vim.cmd("bufdo set norelativenumber")
  end
  vim.opt.relativenumber = next_relativenumber
  vim.api.nvim_set_current_buf(bufnr)
end

function M.wrap()
  ---@type boolean
  local wrap_current = vim.opt_local.wrap:get()
  ---@type boolean
  local wrap_next = not wrap_current
  vim.opt_local.wrap = wrap_next
end

return M
