local navigate = vim.env.TMUX and require("fml.api.win.navigate_tmux") or require("fml.api.win.navigate_vim")

---@class fml.api.win
local M = require("fml.api.win.mod")

---@return nil
function M.focus_top()
  navigate("k")
end

function M.focus_right()
  navigate("l")
end

function M.focus_bottom()
  navigate("j")
end

function M.focus_left()
  navigate("h")
end

function M.focus_prev()
  navigate("p")
end

function M.focus_next()
  navigate("n")
end

function M.focus_with_picker()
  local winnr_cur = vim.api.nvim_get_current_win()
  local winnr_target = M.pick("focus")
  if winnr_target and winnr_cur ~= winnr_target then
    vim.api.nvim_set_current_win(winnr_target)
  end
end
