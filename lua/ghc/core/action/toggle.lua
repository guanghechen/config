local context_session = require("ghc.core.context.session")

---@class ghc.core.action.toggle
local M = {}

function M.flight_copilot()
  local flight_copilot_next = not context_session.flight_copilot:get_snapshot() ---@type boolean
  context_session.flight_copilot:next(flight_copilot_next)
end

function M.transparency()
  local next_transparency = not fml.context.theme.transparency:get_snapshot() ---@type boolean
  fml.context.theme.toggle_scheme({ transparency = next_transparency })

  require("nvconfig").ui.transparency = fml.context.theme.transparency:get_snapshot()
  require("base46").load_all_highlights()
end

function M.theme()
  local darken = fml.context.theme.mode:get_snapshot() == "darken" ---@type boolean
  local next_mode = darken and "lighten" or "darken"
  fml.context.theme.toggle_scheme({ mode = next_mode })

  local current_theme = fml.context.theme.mode:get_snapshot() == "darken" and "onedark" or "one_light" ---@type string
  require("nvconfig").ui.theme = current_theme
  require("base46").load_all_highlights()
end

function M.relative_line_number()
  ---@type boolean
  local next_relativenumber = not fml.context.shared.relativenumber:get_snapshot()
  fml.context.shared.relativenumber:next(next_relativenumber)

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
