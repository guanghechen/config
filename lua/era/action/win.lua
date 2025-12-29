local __module_name__ = "era.action.win" ---@type string

---@class era.action.win
---@field public navigate               fun(direction: "p"|"n"|"h"|"j"|"k"|"l"): nil
local M = {}

----------------------------------------------------------------------------------------------------
-- close
----------------------------------------------------------------------------------------------------

---@return nil
function M.close()
  vim.cmd("close")
end

---@return nil
function M.close_others()
  vim.cmd("only")
end

----------------------------------------------------------------------------------------------------
-- focus
----------------------------------------------------------------------------------------------------

---@return nil
local function __vim_navigate_window_prev__()
  vim.cmd("wincmd p")
end

---@return nil
local function __vim_navigate_window_next__()
  vim.cmd("wincmd w")
end

---@param direction                     "h"|"j"|"k"|"l"
local function __vim_navigate_window__(direction)
  vim.cmd("wincmd " .. direction)
end

---@param direction                     "p"|"n"|"h"|"j"|"k"|"l"
local function __vim_navigate__(direction)
  if direction == "p" then
    pcall(__vim_navigate_window_prev__)
    return
  end

  if direction == "n" then
    pcall(__vim_navigate_window_next__)
    return
  end

  local ok, error = pcall(__vim_navigate_window__, direction)
  if not ok then
    stl.reporter.error({
      from = __module_name__,
      message = "E11: Invalid in command-line window; <cr> executes, ctrl-c quits",
      details = { direction = direction, error = error },
    })
  end
end

---! Whether tmux should control the previous pane switching or no.
---!
---! by default it's true, so when you enter a new vim instance and
---! try to switch to a previous pane, tmux should take control
local tmux_control = true ---@type boolean
local DISABLE_WHEN_ZOOMED = true ---@type boolean

---@return nil
local function __tmux_navigate_window_topmost__()
  vim.cmd("wincmd t")
end

---@param direction                     "p"|"n"|"h"|"j"|"k"|"l"
---@return nil
local function __tmux_navigate__(direction)
  if direction == "n" then
    local is_last_win = (vim.fn.winnr() == vim.fn.winnr("$"))

    if is_last_win then
      pcall(__tmux_navigate_window_topmost__)
      stl.tmux.change_pane(direction)
    else
      __vim_navigate__(direction)
    end
  elseif direction == "p" then
    -- if the last pane was a tmux pane, then we need to handle control
    -- to tmux; otherwise, just issue a last pane command in vim
    if tmux_control == true then
      stl.tmux.change_pane(direction)
    elseif tmux_control == false then
      __vim_navigate__(direction)
    end
  else
    -- save the current window number to check later whether we're in the same
    -- window after issuing a vim navigation command
    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    local winnr = vim.api.nvim_tabpage_get_win(tabnr) ---@type integer
    local config = vim.api.nvim_win_get_config(winnr) ---@type vim.api.keyset.win_config
    local should_by_tmux = config.relative ~= nil and config.relative ~= "" ---@type boolean

    if not should_by_tmux then
      -- try to navigate normally
      __vim_navigate__(direction)

      -- if we're in the same window after navigating
      local winnr_next = vim.api.nvim_tabpage_get_win(tabnr) ---@type integer
      if winnr == winnr_next then
        should_by_tmux = true
      end
    end

    -- if we're in the same window and zoom is not disabled, tmux should take control
    -- if should_by_tmux and not stl.tmux.is_tmux_pane_corner(direction) and stl.tmux.should_tmux_control(DISABLE_WHEN_ZOOMED) then
    local is_zen_mode = dot.state.status.tmux_zen_mode:snapshot() ---@type boolean
    if should_by_tmux and (not DISABLE_WHEN_ZOOMED or not is_zen_mode) then
      stl.tmux.change_pane(direction)
      tmux_control = true
    else
      tmux_control = false
    end
  end
end

local navigate = stl.env.IS_TMUX and __tmux_navigate__ or __vim_navigate__
M.navigate = navigate

---@return nil
function M.focus_bottom()
  navigate("j")
end

---@return nil
function M.focus_left()
  navigate("h")
end

---@return nil
function M.focus_next()
  navigate("n")
end

---@return nil
function M.focus_prev()
  navigate("p")
end

---@return nil
function M.focus_right()
  navigate("l")
end

---@return nil
function M.focus_top()
  navigate("k")
end

----------------------------------------------------------------------------------------------------
-- mark
----------------------------------------------------------------------------------------------------

---@return nil
function M.mark_sourcefile()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  dot.win.set_type(winnr, nil)

  vim.wo[winnr].cursorline = true
  vim.wo[winnr].number = true
  vim.wo[winnr].relativenumber = true
  vim.wo[winnr].signcolumn = "yes"
  vim.wo[winnr].spell = false
  vim.wo[winnr].winfixbuf = false
  vim.wo[winnr].wrap = false
end

----------------------------------------------------------------------------------------------------
-- picker
----------------------------------------------------------------------------------------------------

---@return nil
function M.picker_focus()
  local winnr_source = vim.api.nvim_get_current_win() ---@type integer
  local winnr_target = dot.win.pick_focusable(winnr_source) ---@type integer|nil
  if winnr_target and winnr_target ~= winnr_source then
    vim.api.nvim_set_current_win(winnr_target)
  end
end

---@return nil
function M.picker_project()
  local winnr_source = vim.api.nvim_get_current_win() ---@type integer
  local winnr_target = dot.win.pick_projectable(winnr_source) ---@type integer|nil
  if winnr_target and winnr_target ~= winnr_source then
    local cursor_source = vim.api.nvim_win_get_cursor(winnr_source)
    local bufnr = vim.api.nvim_win_get_buf(winnr_source) ---@type integer

    vim.api.nvim_win_set_buf(winnr_target, bufnr)
    vim.api.nvim_win_set_cursor(winnr_target, cursor_source)
    vim.api.nvim_set_current_win(winnr_target)
  end
end

---@return nil
function M.picker_swap()
  local winnr_source = vim.api.nvim_get_current_win() ---@type integer
  local winnr_target = dot.win.pick_swappable(winnr_source) ---@type integer|nil
  if winnr_target and winnr_target ~= winnr_source then
    local wincfg_source = vim.api.nvim_win_get_config(winnr_source) ---@type vim.api.keyset.win_config
    local wincfg_target = vim.api.nvim_win_get_config(winnr_target) ---@type vim.api.keyset.win_config

    vim.api.nvim_win_set_config(winnr_source, wincfg_target)
    vim.api.nvim_win_set_config(winnr_target, wincfg_source)
  end
end

----------------------------------------------------------------------------------------------------
-- resize
----------------------------------------------------------------------------------------------------

---@return nil
function M.resize_horizontal_minus()
  local step = vim.v.count1 or 1
  vim.cmd("resize -" .. step)
end

---@return nil
function M.resize_horizontal_plus()
  local step = vim.v.count1 or 1
  vim.cmd("resize +" .. step)
end

---@return nil
function M.resize_vertical_minus()
  local step = vim.v.count1 or 1
  vim.cmd("vertical resize -" .. step)
end

---@return nil
function M.resize_vertical_plus()
  local step = vim.v.count1 or 1
  vim.cmd("vertical resize +" .. step)
end

----------------------------------------------------------------------------------------------------
-- split
----------------------------------------------------------------------------------------------------

---@param direction                     'h'|'j'|'k'|'l'
---@return integer
local function __split__(direction)
  if direction == "h" then
    vim.o.splitright = false
    vim.cmd("vsplit")
    vim.o.splitright = true
  elseif direction == "j" then
    vim.o.splitbelow = true
    vim.cmd("split")
  elseif direction == "k" then
    vim.o.splitbelow = false
    vim.cmd("split")
    vim.o.splitbelow = true
  elseif direction == "l" then
    vim.o.splitright = true
    vim.cmd("vsplit")
  end
  return vim.api.nvim_get_current_win()
end

---@param direction                     'h'|'j'|'k'|'l'
---@return nil
function M.split(direction)
  local winnr_original = vim.api.nvim_get_current_win() ---@type integer
  if ark.vim.win.is_float(winnr_original) then
    return
  end

  if dot.win.is_sourcefile(winnr_original) then
    local winnr_target = __split__(direction) ---@type integer
    dot.win.fork(winnr_original, winnr_target)
    return
  end

  local bufnr_original = vim.api.nvim_win_get_buf(winnr_original) ---@type integer
  local bufnr_scratch = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.bo[bufnr_scratch].buflisted = false
  vim.bo[bufnr_scratch].buftype = "nofile"
  vim.bo[bufnr_scratch].filetype = "text"
  vim.bo[bufnr_scratch].swapfile = false

  if vim.wo[winnr_original].winfixbuf then
    vim.wo[winnr_original].winfixbuf = false
    vim.api.nvim_win_set_buf(winnr_original, bufnr_scratch)
    vim.wo[winnr_original].winfixbuf = true
  else
    vim.api.nvim_win_set_buf(winnr_original, bufnr_scratch)
  end

  local winnr_target = __split__(direction) ---@type integer
  vim.api.nvim_win_set_buf(winnr_original, bufnr_original)
  vim.api.nvim_win_set_buf(winnr_target, bufnr_scratch)

  vim.wo[winnr_target].cursorline = true
  vim.wo[winnr_target].number = true
  vim.wo[winnr_target].relativenumber = true
  vim.wo[winnr_target].signcolumn = "yes"
  vim.wo[winnr_target].spell = false
  vim.wo[winnr_target].winfixbuf = false
  vim.wo[winnr_target].wrap = false

  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(bufnr_scratch) then
      vim.bo[bufnr_scratch].bufhidden = "wipe"
    end
  end)
end

---@return nil
function M.split_above()
  M.split("k")
end

---@return nil
function M.split_below()
  M.split("j")
end

---@return nil
function M.split_left()
  M.split("h")
end

---@return nil
function M.split_right()
  M.split("l")
end

return M
