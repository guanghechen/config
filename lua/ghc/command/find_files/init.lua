local session = require("ghc.context.session")
local state = require("ghc.command.find_files.state")

---@class ghc.command.find_files
local M = {}

---@return nil
function M.open()
  local select = state.get_select() ---@type fml.types.ui.select.ISelect
  select:focus()
end

---@return nil
function M.open_workspace()
  session.find_scope:next("W")
  M.open()
end

---@return nil
function M.open_cwd()
  session.find_scope:next("C")
  M.open()
end

---@return nil
function M.open_directory()
  session.find_scope:next("D")
  M.open()
end

return M
