local navigate_vim = require("fml.api.internal.navigate_vim")

local DISABLE_WHEN_ZOOMED = true ---@type boolean

---! Whether tmux should control the previous pane switching or no.
---!
---! by default it's true, so when you enter a new vim instance and
---! try to switch to a previous pane, tmux should take control
local tmux_control = true ---@type boolean

---@return nil
local function navigate_window_topest()
  vim.cmd("wincmd t")
end

---@param direction                     "p"|"n"|"h"|"j"|"k"|"l"
---@return nil
local function navigate_tmux(direction)
  if direction == "n" then
    local is_last_win = (vim.fn.winnr() == vim.fn.winnr("$"))

    if is_last_win then
      pcall(navigate_window_topest)
      eve.tmux.change_pane(direction)
    else
      navigate_vim(direction)
    end
  elseif direction == "p" then
    -- if the last pane was a tmux pane, then we need to handle control
    -- to tmux; otherwise, just issue a last pane command in vim
    if tmux_control == true then
      eve.tmux.change_pane(direction)
    elseif tmux_control == false then
      navigate_vim(direction)
    end
  else
    -- save the current window number to check later whether we're in the same
    -- window after issuing a vim navigation command
    local winnr = vim.api.nvim_tabpage_get_win(0) ---@type integer
    local config = vim.api.nvim_win_get_config(winnr) ---@type vim.api.keyset.win_config
    local should_by_tmux = config.relative ~= nil and config.relative ~= "" ---@type boolean

    if not should_by_tmux then
      -- try to navigate normally
      navigate_vim(direction)

      -- if we're in the same window after navigating
      local winnr_next = vim.api.nvim_tabpage_get_win(0) ---@type integer
      if winnr == winnr_next then
        should_by_tmux = true
      end
    end

    -- if we're in the same window and zoom is not disabled, tmux should take control
    -- if should_by_tmux and not tmux.is_tmux_pane_corner(direction) and tmux.should_tmux_control(DISABLE_WHEN_ZOOMED) then
    local is_zen_mode = eve.context.state.status.tmux_zen_mode:snapshot() ---@type boolean
    if should_by_tmux and (not DISABLE_WHEN_ZOOMED or not is_zen_mode) then
      eve.tmux.change_pane(direction)
      tmux_control = true
    else
      tmux_control = false
    end
  end
end

return navigate_tmux
