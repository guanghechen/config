local context_session = require("guanghechen.core.context.session")

---@class guanghechen.core.action.toggle
local M = {}

function M.flight_copilot()
  local flight_copilot_next = not context_session.flight_copilot:get_snapshot() ---@type boolean
  context_session.flight_copilot:next(flight_copilot_next)
end

function M.transparency()
  local next_transparency = not ghc.context.theme.transparency:get_snapshot() ---@type boolean
  ghc.context.theme.toggle_scheme({ transparency = next_transparency, persistent = true })

  require("nvconfig").ui.transparency = ghc.context.theme.transparency:get_snapshot()
  require("base46").load_all_highlights()
end

function M.theme()
  local darken = ghc.context.theme.mode:get_snapshot() == "darken" ---@type boolean
  local next_mode = darken and "lighten" or "darken"
  ghc.context.theme.toggle_scheme({ mode = next_mode, persistent = true })

  local current_theme = ghc.context.theme.mode:get_snapshot() == "darken" and "onedark" or "one_light" ---@type string
  require("nvconfig").ui.theme = current_theme
  require("base46").load_all_highlights()
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
  ---@type boolean
  local wrap_current = vim.opt_local.wrap:get()
  ---@type boolean
  local wrap_next = not wrap_current
  vim.opt_local.wrap = wrap_next
end

return M
