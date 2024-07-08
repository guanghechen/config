local client = require("ghc.context.client")
local session = require("ghc.context.session")

---@class ghc.command.toggle
local M = {}

---@return nil
function M.flight_copilot()
  local next_flight_copilot = not session.flight_copilot:get_snapshot() ---@type boolean
  session.flight_copilot:next(next_flight_copilot)
end

---@return nil
function M.theme()
  local darken = client.mode:get_snapshot() == "darken" ---@type boolean
  local next_mode = darken and "lighten" or "darken"
  client.toggle_scheme({ mode = next_mode, persistent = true })
end

---@return nil
function M.transparency()
  local next_transparency = client.transparency:get_snapshot() ---@type boolean
  client.toggle_scheme({ transparency = next_transparency, persistent = true })
end

---@return nil
function M.relative_line_number()
  local next_relativenumber = not client.relativenumber:get_snapshot() ---@type boolean
  client.relativenumber:next(next_relativenumber)

  local bufnr = vim.api.nvim_get_current_buf()
  vim.opt.relativenumber = next_relativenumber
  if next_relativenumber then
    vim.cmd("bufdo set relativenumber")
  else
    vim.cmd("bufdo set norelativenumber")
  end
  vim.api.nvim_set_current_buf(bufnr)
end

function M.wrap()
  ---@diagnostic disable-next-line: undefined-field
  local wrap = vim.opt_local.wrap:get() ---@type boolean
  vim.opt_local.wrap = not wrap
end

return M
