---@see https://github.com/folke/snacks.nvim/blob/fe7cfe9800a182274d0f868a74b7263b8c0c020b/lua/snacks/scroll.lua

local __module_name__ = "era.dressing.scroll" ---@type string

local SCROLL_UP = vim.api.nvim_replace_termcodes("<C-y>", true, true, true)
local SCROLL_DOWN = vim.api.nvim_replace_termcodes("<C-e>", true, true, true)
local MOUSE_SCROLL_DOWN = vim.api.nvim_replace_termcodes("<ScrollWheelDown>", true, true, true)
local MOUSE_SCROLL_UP = vim.api.nvim_replace_termcodes("<ScrollWheelUp>", true, true, true)

---@class era.dressing.scroll.IState
---@field public winnr                  integer
---@field public bufnr                  integer
---@field public view                   vim.fn.winsaveview.ret
---@field public current                vim.fn.winsaveview.ret
---@field public target                 vim.fn.winsaveview.ret
---@field public changedtick            integer
---@field public last                   integer
---@field public timer                  uv.uv_timer_t|nil
---@field public wincfg                 era.dressing.scroll.IWincfg

---@class era.dressing.scroll.IWincfg : vim.api.keyset.win_config
---@field public virtualedit            string|nil
---@field public scrolloff              integer|nil

---@class era.dressing.scroll.IConfig
---@field public duration               integer
---@field public step                   integer
---@field public easing                 string
---@field public repeat_duration        integer
---@field public repeat_step            integer
---@field public repeat_delay           integer
local config = {
  duration = 200,
  step = 10,
  easing = "outQuad",
  repeat_duration = 50,
  repeat_step = 5,
  repeat_delay = 100,
}

local augroup = stl.nvim.fn.augroup(__module_name__)

local states = {} ---@type table<integer, era.dressing.scroll.IState>
local pending_winnrs = {} ---@type table<integer, true>
local mouse_scrolling = false ---@type boolean
local on_key_ns = nil ---@type integer|nil
local initialized = false ---@type boolean
local enabled = false ---@type boolean

---@param bufnr                         integer
---@return boolean
local function is_enabled(bufnr)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end

  if vim.o.paste then
    return false
  end

  if vim.fn.reg_executing() ~= "" or vim.fn.reg_recording() ~= "" then
    return false
  end

  if vim.api.nvim_get_option_value("buftype", { buf = bufnr }) == "terminal" then
    return false
  end

  -- These surfaces own cursor publication; animation positions would become navigation input.
  local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr })
  if filetype == "explorer" or filetype == "treeview" then
    return false
  end

  return true
end

---@param state                         era.dressing.scroll.IState
---@return boolean
local function is_state_valid(state)
  if states[state.winnr] ~= state then
    return false
  end

  if not vim.api.nvim_win_is_valid(state.winnr) then
    return false
  end

  if not vim.api.nvim_buf_is_valid(state.bufnr) then
    return false
  end

  if vim.api.nvim_win_get_buf(state.winnr) ~= state.bufnr then
    return false
  end

  if vim.api.nvim_buf_get_changedtick(state.bufnr) ~= state.changedtick then
    return false
  end

  return true
end

---@param state                         era.dressing.scroll.IState
---@return nil
local function stop_animation(state)
  if state.timer then
    stl.timer.clear_timer(state.timer)
    state.timer = nil
  end

  if vim.api.nvim_win_is_valid(state.winnr) then
    for k, v in pairs(state.wincfg) do
      vim.api.nvim_set_option_value(k, v, { win = state.winnr, scope = "local" })
    end
  end
  state.wincfg = {}
end

---@param state                         era.dressing.scroll.IState
---@return nil
local function finish_animation(state)
  -- Restoring 'virtualedit' resets curswant, so the target view is restored afterwards.
  stop_animation(state)
  if is_state_valid(state) then
    vim.api.nvim_win_call(state.winnr, function()
      vim.fn.winrestview(state.target)
      state.current = vim.fn.winsaveview()
    end)
  end
end

---@param winnr                         integer
---@param from                          vim.fn.winsaveview.ret
---@param to                            vim.fn.winsaveview.ret
---@return integer
local function calc_scroll_lines(winnr, from, to)
  if from.topline == to.topline then
    return math.abs(from.topfill - to.topfill)
  end

  local f, t = from, to
  if to.topline < from.topline then
    f, t = to, from
  end

  -- Count from the top screen line of the upper view to that of the lower one. The start column drops the
  -- part of a wrapped line a smoothscroll view skips, and the filler lines above it, which the upper view
  -- shows as its topfill; the end column stops where the lower view starts.
  local height = vim.api.nvim_win_text_height(winnr, {
    start_row = f.topline - 1,
    start_vcol = f.skipcol,
    end_row = t.topline - 1,
    end_vcol = t.skipcol,
  })
  return height.all + f.topfill - t.topfill
end

---@param winnr                         integer
---@return era.dressing.scroll.IState|nil
local function get_state(winnr)
  local bufnr = vim.api.nvim_win_is_valid(winnr) and vim.api.nvim_win_get_buf(winnr)
  if not bufnr or not is_enabled(bufnr) then
    if states[winnr] then
      stop_animation(states[winnr])
    end
    states[winnr] = nil
    return nil
  end

  local view = vim.api.nvim_win_call(winnr, vim.fn.winsaveview)
  local state = states[winnr] ---@type era.dressing.scroll.IState|nil

  if not (state and is_state_valid(state)) then
    if state then
      stop_animation(state)
    end

    ---@type era.dressing.scroll.IState
    state = {
      winnr = winnr,
      bufnr = bufnr,
      view = view,
      current = vim.deepcopy(view),
      target = vim.deepcopy(view),
      changedtick = vim.api.nvim_buf_get_changedtick(bufnr),
      last = 0,
      timer = nil,
      wincfg = {},
    }
  end

  state.view = view
  states[winnr] = state

  return state
end

---@param winnr                         integer
---@return nil
local function check_scroll(winnr)
  local state = get_state(winnr) ---@type era.dressing.scroll.IState|nil
  if not state then
    return
  end

  -- Scrollbind partners follow scroll commands but not a view an animation restores, and Select mode
  -- would take the keys of the frames as text, so both scroll directly.
  if
    vim.api.nvim_get_option_value("scrollbind", { win = state.winnr })
    or vim.api.nvim_get_mode().mode:find("^[sS\19]")
  then
    stop_animation(state)
    state.current = vim.deepcopy(state.view)
    return
  end

  if mouse_scrolling then
    stop_animation(state)
    mouse_scrolling = false
    state.current = vim.deepcopy(state.view)
    return
  end

  if math.abs(state.view.topline - state.current.topline) <= 1 then
    state.current = vim.deepcopy(state.view)
    return
  end

  -- Every scroll animates all the way. A frame repaints the window instead of scrolling it when it
  -- moves more than a screen, as in a long jump, or when floats share the window's rows, such as
  -- winsep's separators or a context window; smooth scrolling is worth that.
  state.target = vim.deepcopy(state.view)
  stop_animation(state)

  state.wincfg.virtualedit = state.wincfg.virtualedit
    or vim.api.nvim_get_option_value("virtualedit", { win = state.winnr })
  state.wincfg.scrolloff = state.wincfg.scrolloff or vim.api.nvim_get_option_value("scrolloff", { win = state.winnr })
  vim.api.nvim_set_option_value("virtualedit", "all", { win = state.winnr, scope = "local" })
  vim.api.nvim_set_option_value("scrolloff", 0, { win = state.winnr, scope = "local" })

  local now = vim.uv.hrtime() ---@type integer
  local repeat_delta = (now - state.last) / 1e6 ---@type number
  state.last = now

  local is_repeat = repeat_delta <= config.repeat_delay ---@type boolean
  local duration = is_repeat and config.repeat_duration or config.duration ---@type integer
  local step = is_repeat and config.repeat_step or config.step ---@type integer
  local easing_fn = stl.easing[config.easing] or stl.easing.outQuad

  local scrolls = 0 ---@type integer
  local col_from = 0 ---@type integer
  local col_to = 0 ---@type integer
  local move_from = 0 ---@type integer
  local move_to = 0 ---@type integer

  vim.api.nvim_win_call(state.winnr, function()
    move_to = vim.fn.winline()
    vim.fn.winrestview(state.current)
    move_from = vim.fn.winline()
    state.current = vim.api.nvim_win_call(state.winnr, vim.fn.winsaveview)
    scrolls = calc_scroll_lines(state.winnr, state.current, state.target)
    col_from = vim.fn.virtcol({ state.current.lnum, state.current.col }) --[[@as integer]]
    col_to = vim.fn.virtcol({ state.target.lnum, state.target.col }) --[[@as integer]]
  end)

  if scrolls == 0 then
    stop_animation(state)
    return
  end

  local down = state.target.topline > state.current.topline
    or (state.target.topline == state.current.topline and state.target.topfill < state.current.topfill)

  local scrolled = 0 ---@type integer
  local elapsed = 0 ---@type integer
  local total_steps = math.ceil(duration / step) ---@type integer

  local timer = vim.uv.new_timer() ---@type uv.uv_timer_t|nil
  if not timer then
    return
  end
  state.timer = timer

  timer:start(0, step, function()
    vim.schedule(function()
      if not is_state_valid(state) or state.timer ~= timer then
        stl.timer.clear_timer(timer)
        return
      end
      -- Select mode entered without a typed key, such as a deferred snippet jump, owns the view.
      if vim.api.nvim_get_mode().mode:find("^[sS\19]") then
        stop_animation(state)
        state.current = vim.api.nvim_win_call(state.winnr, vim.fn.winsaveview)
        return
      end

      elapsed = elapsed + 1
      local progress = math.min(elapsed / total_steps, 1) ---@type number
      local eased = progress >= 1 and 1 or easing_fn(progress * duration, 0, 1, duration) ---@type number
      local value = eased * scrolls ---@type number

      vim.api.nvim_win_call(state.winnr, function()
        local count = vim.v.count ---@type integer

        local scroll_target = math.floor(value) ---@type integer
        local scroll_delta = scroll_target - scrolled ---@type integer
        local scroll_cmd = scroll_delta > 0 and ("%d%s"):format(scroll_delta, down and SCROLL_DOWN or SCROLL_UP) or ""
        scrolled = scrolled + scroll_delta

        local move = math.floor(value * math.abs(move_to - move_from) / scrolls) ---@type integer
        local move_target = move_from + ((move_to < move_from) and -1 or 1) * move ---@type integer

        local virtcol = math.floor(col_from + (col_to - col_from) * value / scrolls) ---@type integer

        if scroll_cmd ~= "" then
          vim.cmd(("keepjumps normal! %s"):format(scroll_cmd))
        end
        -- H lands on the topline at a count of 1, or at any count when the topline fills the window. A
        -- cursor moved onto the part of a smoothscroll topline that the view skips scrolls the window back
        -- to the start of that line, beyond the frames, so the frame keeps it on the first shown character.
        local view = vim.fn.winsaveview() ---@type vim.fn.winsaveview.ret
        if view.skipcol > 0 and (move_target <= 1 or vim.fn.line("w$") == view.topline) then
          local col = vim.fn.virtcol2col(state.winnr, view.topline, view.skipcol + 1) ---@type integer
          vim.api.nvim_win_set_cursor(state.winnr, { view.topline, math.max(col - 1, 0) })
        else
          vim.cmd(("keepjumps normal! %dH%d|"):format(move_target, virtcol + 1))
        end

        if vim.v.count ~= count then
          local cursor = vim.api.nvim_win_get_cursor(state.winnr) ---@type integer[]
          -- A leading 0 would be the motion to the first column rather than a count.
          vim.cmd(count > 0 and ("keepjumps normal! %dzh"):format(count) or "keepjumps normal! zh")
          vim.api.nvim_win_set_cursor(state.winnr, cursor)
        end

        if progress >= 1 then
          local target = state.target ---@type vim.fn.winsaveview.ret
          local view = vim.fn.winsaveview() ---@type vim.fn.winsaveview.ret
          -- Restoring 'virtualedit' resets curswant, so the target cursor is restored afterwards.
          stop_animation(state)
          if
            view.topline == target.topline
            and view.topfill == target.topfill
            and view.leftcol == target.leftcol
            and view.skipcol == target.skipcol
            and target.curswant ~= vim.v.maxcol
          then
            -- winrestview() resets the window layout, which repaints every row of the scrolled frame.
            -- cursor() cannot restore an end-of-line curswant, which takes the fallback.
            vim.fn.cursor({ target.lnum, target.col + 1, target.coladd, target.curswant + 1 })
          else
            vim.fn.winrestview(target)
          end
          state.current = vim.fn.winsaveview()
          return
        end

        state.current = vim.api.nvim_win_call(state.winnr, vim.fn.winsaveview)
      end)
    end)
  end)
end

---@return nil
local function enable()
  if enabled then
    return
  end
  enabled = true

  states = {}

  -- Typed keys act on the cursor, which an animation holds short of its target, so running animations
  -- finish on their targets first. Keys of the frames are not typed, and mouse keys act on the screen as
  -- drawn. Mapped wheels reach here as the keys of their mappings, so the typed key identifies them.
  on_key_ns = vim.on_key(function(key, typed)
    local name = typed ~= "" and vim.fn.keytrans(typed) or "" ---@type string
    if key == MOUSE_SCROLL_DOWN or key == MOUSE_SCROLL_UP or name:find("ScrollWheel") then
      mouse_scrolling = true
      return
    end
    if name == "" or name:find("Mouse") or name:find("Drag") or name:find("Release") then
      return
    end
    for _, state in pairs(states) do
      if state.timer then
        finish_animation(state)
      end
    end
  end)

  -- A buffer leaving a window keeps that window's options for its return, so its animation ends first.
  vim.api.nvim_create_autocmd("BufLeave", {
    group = augroup,
    callback = function(ev)
      local state = states[vim.api.nvim_get_current_win()] ---@type era.dressing.scroll.IState|nil
      if state ~= nil and state.timer ~= nil and state.bufnr == ev.buf then
        finish_animation(state)
      end
    end,
  })

  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = augroup,
    callback = vim.schedule_wrap(function(ev)
      for _, winnr in ipairs(vim.fn.win_findbuf(ev.buf)) do
        get_state(winnr)
      end
    end),
  })

  vim.api.nvim_create_autocmd({ "InsertLeave", "TextChanged", "TextChangedI" }, {
    group = augroup,
    callback = function(ev)
      for _, winnr in ipairs(vim.fn.win_findbuf(ev.buf)) do
        get_state(winnr)
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    group = augroup,
    callback = vim.schedule_wrap(function(ev)
      for _, winnr in ipairs(vim.fn.win_findbuf(ev.buf)) do
        local state = states[winnr]
        if state and vim.api.nvim_win_is_valid(state.winnr) then
          state.current = vim.api.nvim_win_call(state.winnr, vim.fn.winsaveview)
        end
      end
    end),
  })

  vim.api.nvim_create_autocmd("CmdlineLeave", {
    group = augroup,
    callback = function(ev)
      if (ev.file == "/" or ev.file == "?") and vim.o.incsearch then
        for _, winnr in ipairs(vim.fn.win_findbuf(ev.buf)) do
          local state = states[winnr]
          if state then
            stop_animation(state)
            states[winnr] = nil
          end
        end
      end
    end,
  })

  vim.api.nvim_create_autocmd("WinClosed", {
    group = augroup,
    callback = function(ev)
      local winnr = tonumber(ev.match) ---@type integer|nil
      if winnr ~= nil and states[winnr] ~= nil then
        stop_animation(states[winnr])
        states[winnr] = nil
      end
    end,
  })

  -- Keys still pending, such as the zz of a mapping like nzzzv, would run on the view an animation
  -- restores; their windows wait until the whole sequence has run, which is still before the redraw.
  vim.api.nvim_create_autocmd("WinScrolled", {
    group = augroup,
    callback = function()
      local pending = vim.fn.state("m") ~= "" ---@type boolean
      for winnr, changes in pairs(vim.v.event) do
        winnr = tonumber(winnr)
        if winnr and changes.topline ~= 0 then
          if pending then
            pending_winnrs[winnr] = true
          else
            check_scroll(winnr)
          end
        end
      end
    end,
  })
  vim.api.nvim_create_autocmd("SafeState", {
    group = augroup,
    callback = function()
      for winnr in pairs(pending_winnrs) do
        pending_winnrs[winnr] = nil
        if vim.api.nvim_win_is_valid(winnr) then
          check_scroll(winnr)
        end
      end
      -- A wheel that scrolled no animated window must not turn the next scroll into a jump.
      mouse_scrolling = false
    end,
  })

  for _, winnr in ipairs(vim.api.nvim_list_wins()) do
    get_state(winnr)
  end
end

---@return nil
local function disable()
  if not enabled then
    return
  end
  enabled = false

  for _, state in pairs(states) do
    stop_animation(state)
  end
  states = {}
  pending_winnrs = {}

  if on_key_ns then
    vim.on_key(nil, on_key_ns)
    on_key_ns = nil
  end

  vim.api.nvim_clear_autocmds({ group = augroup })
end

---@class era.dressing.scroll
local M = {}

---@param winnr                         integer
---@return nil
function M.accept_current_view(winnr)
  if not enabled or not vim.api.nvim_win_is_valid(winnr) then
    return
  end

  local state = get_state(winnr) ---@type era.dressing.scroll.IState|nil
  if not state then
    return
  end

  stop_animation(state)

  local view = vim.api.nvim_win_call(winnr, vim.fn.winsaveview)
  state.view = view
  state.current = vim.deepcopy(view)
  state.target = vim.deepcopy(view)
  state.last = 0
end

--- Register the observer once; workspace toggles control activation separately.
---@return nil
function M.dressing()
  if initialized then
    return
  end
  initialized = true

  stl.fn.observe({ dot.context.flight.dressing_scroll }, function()
    if dot.context.flight.dressing_scroll:snapshot() then
      enable()
    else
      disable()
    end
  end)
end

return M
