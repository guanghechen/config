local __module_name__ = "fml.action.win" ---@type string

local reporter = require("eve.lib.reporter")
local state = require("eve.state")

---@return nil
local function vim_navigate_window_prev()
  vim.cmd("wincmd p")
end

---@return nil
local function vim_navigate_window_next()
  vim.cmd("wincmd w")
end

---@param direction "h"|"j"|"k"|"l"
local function vim_navigate_window(direction)
  vim.cmd("wincmd " .. direction)
end

---@param direction "p"|"n"|"h"|"j"|"k"|"l"
local function vim_navigate(direction)
  if direction == "p" then
    pcall(vim_navigate_window_prev)
    return
  end

  if direction == "n" then
    pcall(vim_navigate_window_next)
    return
  end

  local ok = pcall(vim_navigate_window, direction)
  if not ok then
    reporter.error({
      from = __module_name__,
      message = "E11: Invalid in command-line window; <CR> executes, CTRL-C quits",
      details = { direction = direction },
    })
  end
end

----------------------------------------------------------------------------------------------------

---! Whether tmux should control the previous pane switching or no.
---!
---! by default it's true, so when you enter a new vim instance and
---! try to switch to a previous pane, tmux should take control
local tmux_control = true ---@type boolean
local DISABLE_WHEN_ZOOMED = true ---@type boolean

---@return nil
local function tmux_navigate_window_topmost()
  vim.cmd("wincmd t")
end

---@param direction                     "p"|"n"|"h"|"j"|"k"|"l"
---@return nil
local function tmux_navigate(direction)
  local tmux = require("eve.lib.tmux")
  if direction == "n" then
    local is_last_win = (vim.fn.winnr() == vim.fn.winnr("$"))

    if is_last_win then
      pcall(tmux_navigate_window_topmost)
      tmux.change_pane(direction)
    else
      vim_navigate(direction)
    end
  elseif direction == "p" then
    -- if the last pane was a tmux pane, then we need to handle control
    -- to tmux; otherwise, just issue a last pane command in vim
    if tmux_control == true then
      tmux.change_pane(direction)
    elseif tmux_control == false then
      vim_navigate(direction)
    end
  else
    -- save the current window number to check later whether we're in the same
    -- window after issuing a vim navigation command
    local winnr = vim.api.nvim_tabpage_get_win(0) ---@type integer
    local config = vim.api.nvim_win_get_config(winnr) ---@type vim.api.keyset.win_config
    local should_by_tmux = config.relative ~= nil and config.relative ~= "" ---@type boolean

    if not should_by_tmux then
      -- try to navigate normally
      vim_navigate(direction)

      -- if we're in the same window after navigating
      local winnr_next = vim.api.nvim_tabpage_get_win(0) ---@type integer
      if winnr == winnr_next then
        should_by_tmux = true
      end
    end

    -- if we're in the same window and zoom is not disabled, tmux should take control
    -- if should_by_tmux and not tmux.is_tmux_pane_corner(direction) and tmux.should_tmux_control(DISABLE_WHEN_ZOOMED) then
    local is_zen_mode = state.status.tmux_zen_mode:snapshot() ---@type boolean
    if should_by_tmux and (not DISABLE_WHEN_ZOOMED or not is_zen_mode) then
      tmux.change_pane(direction)
      tmux_control = true
    else
      tmux_control = false
    end
  end
end

----------------------------------------------------------------------------------------------------

local navigate = vim.env.TMUX and tmux_navigate or vim_navigate

---@class fml.action.win
local M = {}

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.focus_top(context)
  navigate("k")
end

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.focus_right(context)
  navigate("l")
end

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.focus_bottom(context)
  navigate("j")
end

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.focus_left(context)
  navigate("h")
end

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.focus_prev(context)
  navigate("p")
end

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.focus_next(context)
  navigate("n")
end

return M
