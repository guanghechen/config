---@see https://github.com/folke/snacks.nvim/blob/fe7cfe9800a182274d0f868a74b7263b8c0c020b/lua/snacks/scroll.lua

local __module_name__ = "fml.dressing.scroll" ---@type string

local SCROLL_UP = vim.api.nvim_replace_termcodes("<C-y>", true, true, true)
local SCROLL_DOWN = vim.api.nvim_replace_termcodes("<C-e>", true, true, true)
local MOUSE_SCROLL_DOWN = vim.api.nvim_replace_termcodes("<ScrollWheelDown>", true, true, true)
local MOUSE_SCROLL_UP = vim.api.nvim_replace_termcodes("<ScrollWheelUp>", true, true, true)

---@class fml.dressing.scroll.IState
---@field public winnr                  integer
---@field public bufnr                  integer
---@field public view                   vim.fn.winsaveview.ret
---@field public current                vim.fn.winsaveview.ret
---@field public target                 vim.fn.winsaveview.ret
---@field public changedtick            integer
---@field public last                   integer
---@field public timer                  uv.uv_timer_t|nil
---@field public wincfg                 vim.api.keyset.win_config

---@class fml.dressing.scroll.IConfig
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

local augroup = ark.nvim.augroup(__module_name__)

local states = {} ---@type table<integer, fml.dressing.scroll.IState>
local mouse_scrolling = false ---@type boolean
local on_key_ns = nil ---@type integer|nil
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

  if vim.bo[bufnr].buftype == "terminal" then
    return false
  end

  return true
end

---@param state                         fml.dressing.scroll.IState
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

---@param state                         fml.dressing.scroll.IState
---@return nil
local function stop_animation(state)
  if state.timer then
    ark.timer.clear_timer(state.timer)
    state.timer = nil
  end

  if vim.api.nvim_win_is_valid(state.winnr) then
    for k, v in pairs(state.wincfg) do
      vim.wo[state.winnr][k] = v
    end
  end
  state.wincfg = {}
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

  local start_row = f.topline - 1 ---@type integer
  local end_row = t.topline - 1 ---@type integer
  local offset = 0 ---@type integer
  if f.topfill > 0 then
    start_row = start_row + 1
    offset = f.topfill + 1
  end
  if t.topfill > 0 then
    offset = offset - t.topfill
  end

  local height = vim.api.nvim_win_text_height(winnr, { start_row = start_row, end_row = end_row })
  return height.all + offset - 1
end

---@param winnr                         integer
---@return fml.dressing.scroll.IState|nil
local function get_state(winnr)
  local bufnr = vim.api.nvim_win_is_valid(winnr) and vim.api.nvim_win_get_buf(winnr)
  if not bufnr or not is_enabled(bufnr) then
    states[winnr] = nil
    return nil
  end

  local view = vim.api.nvim_win_call(winnr, vim.fn.winsaveview)
  local state = states[winnr] ---@type fml.dressing.scroll.IState|nil

  if not (state and is_state_valid(state)) then
    if state then
      stop_animation(state)
    end

    ---@type fml.dressing.scroll.IState
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
  local state = get_state(winnr) ---@type fml.dressing.scroll.IState|nil
  if not state then
    return
  end

  if vim.wo[state.winnr].scrollbind and vim.api.nvim_get_current_win() ~= state.winnr then
    stop_animation(state)
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

  state.target = vim.deepcopy(state.view)
  stop_animation(state)

  state.wincfg.virtualedit = state.wincfg.virtualedit or vim.wo[state.winnr].virtualedit
  state.wincfg.scrolloff = state.wincfg.scrolloff or vim.wo[state.winnr].scrolloff
  vim.wo[state.winnr].virtualedit = "all"
  vim.wo[state.winnr].scrolloff = 0

  local now = vim.uv.hrtime() ---@type integer
  local repeat_delta = (now - state.last) / 1e6 ---@type number
  state.last = now

  local is_repeat = repeat_delta <= config.repeat_delay ---@type boolean
  local duration = is_repeat and config.repeat_duration or config.duration ---@type integer
  local step = is_repeat and config.repeat_step or config.step ---@type integer
  local easing_fn = ark.easing[config.easing] or ark.easing.outQuad

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
        ark.timer.clear_timer(timer)
        return
      end

      elapsed = elapsed + 1
      local progress = math.min(elapsed / total_steps, 1) ---@type number
      local eased = easing_fn(progress * duration, 0, 1, duration) ---@type number
      local value = eased * scrolls ---@type number

      vim.api.nvim_win_call(state.winnr, function()
        if progress >= 1 then
          vim.fn.winrestview(state.target)
          state.current = vim.api.nvim_win_call(state.winnr, vim.fn.winsaveview)
          stop_animation(state)
          return
        end

        local count = vim.v.count ---@type integer

        local scroll_target = math.floor(value) ---@type integer
        local scroll_delta = scroll_target - scrolled ---@type integer
        local scroll_cmd = scroll_delta > 0 and ("%d%s"):format(scroll_delta, down and SCROLL_DOWN or SCROLL_UP) or ""
        scrolled = scrolled + scroll_delta

        local move = math.floor(value * math.abs(move_to - move_from) / scrolls) ---@type integer
        local move_target = move_from + ((move_to < move_from) and -1 or 1) * move ---@type integer

        local virtcol = math.floor(col_from + (col_to - col_from) * value / scrolls) ---@type integer

        vim.cmd(("keepjumps normal! %s%dH%d|"):format(scroll_cmd, move_target, virtcol + 1))

        if vim.v.count ~= count then
          local cursor = vim.api.nvim_win_get_cursor(state.winnr) ---@type integer[]
          vim.cmd(("keepjumps normal! %dzh"):format(count))
          vim.api.nvim_win_set_cursor(state.winnr, cursor)
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

  on_key_ns = vim.on_key(function(key)
    if key == MOUSE_SCROLL_DOWN or key == MOUSE_SCROLL_UP then
      mouse_scrolling = true
    end
  end)

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

  vim.api.nvim_create_autocmd("WinScrolled", {
    group = augroup,
    callback = function()
      for winnr, changes in pairs(vim.v.event) do
        winnr = tonumber(winnr)
        if winnr and changes.topline ~= 0 then
          check_scroll(winnr)
        end
      end
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

  if on_key_ns then
    vim.on_key(nil, on_key_ns)
    on_key_ns = nil
  end

  vim.api.nvim_clear_autocmds({ group = augroup })
end

ark.fn.observe({ dot.context.flight.dressing_scroll }, function()
  if dot.context.flight.dressing_scroll:snapshot() then
    enable()
  else
    disable()
  end
end)
