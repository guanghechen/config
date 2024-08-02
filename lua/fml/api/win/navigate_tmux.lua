local navigate_vim = require("fml.api.win.navigate_vim")
local tmux = require("fml.std.tmux")

local DISABLE_WHEN_ZOOMED = false ---@type boolean

-- whether tmux should control the previous pane switching or no
--
-- by default it's true, so when you enter a new vim instance and
-- try to switch to a previous pane, tmux should take control
local tmux_control = true

local function navigate_window_topest()
  vim.cmd("wincmd t")
end

---@param direction "p"|"n"|"h"|"j"|"k"|"l"
local function navigate_tmux(direction)
  if direction == "n" then
    local is_last_win = (vim.fn.winnr() == vim.fn.winnr("$"))

    if is_last_win then
      pcall(navigate_window_topest)
      tmux.change_pane(direction)
    else
      navigate_vim(direction)
    end
  elseif direction == "p" then
    -- if the last pane was a tmux pane, then we need to handle control
    -- to tmux; otherwise, just issue a last pane command in vim
    if tmux_control == true then
      tmux.change_pane(direction)
    elseif tmux_control == false then
      navigate_vim(direction)
    end
  else
    -- save the current window number to check later whether we're in the same
    -- window after issuing a vim navigation command
    local winnr = vim.fn.winnr()

    -- try to navigate normally
    navigate_vim(direction)

    -- if we're in the same window after navigating
    local is_same_winnr = (winnr == vim.fn.winnr())

    -- if we're in the same window and zoom is not disabled, tmux should take control
    if tmux.should_tmux_control(is_same_winnr, DISABLE_WHEN_ZOOMED) then
      tmux.change_pane(direction)
      tmux_control = true
    else
      tmux_control = false
    end
  end
end

return navigate_tmux
