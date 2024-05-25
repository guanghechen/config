local util_tmux = require("ghc.core.util.tmux")

local DISABLE_WHEN_ZOOMED = true ---@type boolean

local function vim_navigate_window_prev()
  vim.cmd("wincmd t")
end

local function vim_navigate_window_next()
  vim.cmd("wincmd w")
end

local function vim_navigate_window(direction)
  vim.cmd("wincmd " .. direction)
end

local function vim_navigate(direction)
  if direction == "n" then
    pcall(vim_navigate_window_next)
  elseif pcall(vim_navigate_window, direction) then
    -- success
  else
    -- error, cannot wincmd from the command-line window
    vim.cmd(
      [[ echohl ErrorMsg | echo 'E11: Invalid in command-line window; <CR> executes, CTRL-C quits' | echohl None ]]
    )
  end
end

-- whether tmux should control the previous pane switching or no
--
-- by default it's true, so when you enter a new vim instance and
-- try to switch to a previous pane, tmux should take control
local tmux_control = true

local function tmux_navigate(direction)
  if direction == "n" then
    local is_last_win = (vim.fn.winnr() == vim.fn.winnr("$"))

    if is_last_win then
      pcall(vim_navigate_window_prev)
      util_tmux.tmux_change_pane(direction)
    else
      vim_navigate(direction)
    end
  elseif direction == "p" then
    -- if the last pane was a tmux pane, then we need to handle control
    -- to tmux; otherwise, just issue a last pane command in vim
    if tmux_control == true then
      util_tmux.tmux_change_pane(direction)
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
    if util_tmux.should_tmux_control(is_same_winnr, DISABLE_WHEN_ZOOMED) then
      util_tmux.tmux_change_pane(direction)
      tmux_control = true
    else
      tmux_control = false
    end
  end
end

-- if in tmux, map to vim-tmux navigation, otherwise just map to vim navigation
local navigate = nil
if vim.env.TMUX ~= nil then
  navigate = tmux_navigate
else
  navigate = vim_navigate
end

---@class ghc.core.action.window
local M = require("ghc.core.action.window.module")

function M.focus_window_top()
  navigate("k")
end

function M.focus_window_right()
  navigate("l")
end

function M.focus_window_bottom()
  navigate("j")
end
-- lua functions
function M.focus_window_left()
  navigate("h")
end

function M.focus_window_prev()
  navigate("p")
end

function M.focus_window_next()
  navigate("n")
end
