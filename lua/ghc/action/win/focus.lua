---@class ghc.action.win
local M = require("ghc.action.win.mod")

---@return nil
function M.focus_top()
  fml.api.win.navigate("k")
end

---@return nil
function M.focus_right()
  fml.api.win.navigate("l")
end

---@return nil
function M.focus_bottom()
  fml.api.win.navigate("j")
end

---@return nil
function M.focus_left()
  fml.api.win.navigate("h")
end

---@return nil
function M.focus_prev()
  fml.api.win.navigate("p")
end

---@return nil
function M.focus_next()
  fml.api.win.navigate("n")
end

---@return nil
function M.focus_with_picker()
  local winnr_cur = vim.api.nvim_get_current_win()
  local winnr_target = M.pick("focus")
  if winnr_target and winnr_cur ~= winnr_target then
    vim.api.nvim_set_current_win(winnr_target)
  end
end
