local client = require("ghc.context.client")
local session = require("ghc.context.session")

---@class ghc.command.toggle
local M = {}

---@return nil
function M.flag_case_sensitive()
  local next_case_sensitive = not session.search_flag_case_sensitive:snapshot() ---@type boolean
  session.search_flag_case_sensitive:next(next_case_sensitive)
end

---@return nil
function M.flight_autoload_session()
  local next_flight_autoload_session = not session.flight_autoload_session:snapshot() ---@type boolean
  session.flight_autoload_session:next(next_flight_autoload_session)
end

---@return nil
function M.flight_copilot()
  local next_flight_copilot = not session.flight_copilot:snapshot() ---@type boolean
  session.flight_copilot:next(next_flight_copilot)
end

---@return nil
function M.theme()
  local darken = client.mode:snapshot() == "darken" ---@type boolean
  local next_mode = darken and "lighten" or "darken"
  client.toggle_scheme({ mode = next_mode, persistent = true })
end

---@return nil
function M.transparency()
  local next_transparency = not client.transparency:snapshot() ---@type boolean
  client.toggle_scheme({ transparency = next_transparency, persistent = true })
end

---@return nil
function M.relativenumber()
  local next_relativenumber = not client.relativenumber:snapshot() ---@type boolean
  client.relativenumber:next(next_relativenumber)

  if vim.o.nu then
    vim.opt.relativenumber = next_relativenumber
    vim.cmd("redraw")
  end
end

function M.wrap()
  ---@diagnostic disable-next-line: undefined-field
  local wrap = vim.opt_local.wrap:get() ---@type boolean
  vim.opt_local.wrap = not wrap
end

return M
