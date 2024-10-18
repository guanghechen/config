local client = require("ghc.context.client")
local session = require("ghc.context.session")
local cmd_theme = require("ghc.command.theme")

---@class ghc.command.toggle
local M = {}

---@return nil
function M.flag_case_sensitive()
  local next_flag = not session.search_flag_case_sensitive:snapshot() ---@type boolean
  session.search_flag_case_sensitive:next(next_flag)
end

---@return nil
function M.flight_autoload_session()
  local next_flag = not session.flight_autoload_session:snapshot() ---@type boolean
  session.flight_autoload_session:next(next_flag)
end

---@return nil
function M.flight_copilot()
  local next_flag = not session.flight_copilot:snapshot() ---@type boolean
  session.flight_copilot:next(next_flag)
end

---@return nil
function M.flight_devmode()
  local next_flag = not client.flight_devmode:snapshot() ---@type boolean
  client.flight_devmode:next(next_flag)
end

---@return nil
function M.theme()
  local darken = client.theme:snapshot() == "darken" ---@type boolean
  local next_flag = darken and "lighten" or "darken"
  cmd_theme.toggle_scheme({ mode = next_flag, persistent = true })
end

---@return nil
function M.transparency()
  local next_flag = not client.transparency:snapshot() ---@type boolean
  cmd_theme.toggle_scheme({ transparency = next_flag, persistent = true })
end

---@return nil
function M.relativenumber()
  local next_flag = not client.relativenumber:snapshot() ---@type boolean
  client.relativenumber:next(next_flag)

  if vim.o.nu then
    vim.opt.relativenumber = next_flag
    vim.cmd("redraw")
  end
end

function M.wrap()
  ---@diagnostic disable-next-line: undefined-field
  local wrap = vim.opt_local.wrap:get() ---@type boolean
  vim.opt_local.wrap = not wrap
end

return M
