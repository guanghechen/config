local vim_navigate = require("guanghechen.core.action.window.navigate-vim")

local DISABLE_WHEN_ZOOMED = true ---@type boolean

-- whether tmux should control the previous pane switching or no
--
-- by default it's true, so when you enter a new vim instance and
-- try to switch to a previous pane, tmux should take control
local tmux_control = true

local function navigate_window_topest()
  vim.cmd("wincmd t")
end

---@param direction "p"|"n"|"h"|"j"|"k"|"l"
local function tmux_navigate(direction)
  if direction == "n" then
    local is_last_win = (vim.fn.winnr() == vim.fn.winnr("$"))

    if is_last_win then
      pcall(navigate_window_topest)
      fml.tmux.change_pane(direction)
    else
      vim_navigate(direction)
    end
  elseif direction == "p" then
    -- if the last pane was a tmux pane, then we need to handle control
    -- to tmux; otherwise, just issue a last pane command in vim
    if tmux_control == true then
      fml.tmux.change_pane(direction)
    elseif tmux_control == false then
      vim_navigate(direction)
    end
  else
    -- save the current window number to check later whether we're in the same
    -- window after issuing a vim navigation command
    local winnr = vim.fn.winnr()

    -- try to navigate normally
    vim_navigate(direction)

    -- if we're in the same window after navigating
    local is_same_winnr = (winnr == vim.fn.winnr())

    -- if we're in the same window and zoom is not disabled, tmux should take control
    if fml.tmux.should_tmux_control(is_same_winnr, DISABLE_WHEN_ZOOMED) then
      fml.tmux.change_pane(direction)
      tmux_control = true
    else
      tmux_control = false
    end
  end
end

return tmux_navigate
