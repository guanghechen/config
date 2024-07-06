---@class guanghechen.core.action.toggle
local M = {}

function M.flight_copilot()
  local flight_copilot = ghc.context.search.flight_copilot:get_snapshot() ---@type boolean
  ghc.context.search.flight_copilot:next(not flight_copilot)
end

function M.transparency()
  local transparency = not ghc.context.shared.transparency:get_snapshot() ---@type boolean
  ghc.context.shared.toggle_scheme({ transparency = not transparency, persistent = true })
end

function M.theme()
  local darken = ghc.context.shared.mode:get_snapshot() == "darken" ---@type boolean
  local next_mode = darken and "lighten" or "darken"
  ghc.context.shared.toggle_scheme({ mode = next_mode, persistent = true })
end

function M.relative_line_number()
  ---@type boolean
  local next_relativenumber = not ghc.context.shared.relativenumber:get_snapshot()
  ghc.context.shared.relativenumber:next(next_relativenumber)

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
  ---@diagnostic disable-next-line: undefined-field
  local wrap = vim.opt_local.wrap:get() ---@type boolean
  vim.opt_local.wrap = not wrap
end

return M
