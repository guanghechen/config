local Scope = require("era.dressing.indentscope.scope")

---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.dressing.indentscope.draw" ---@type string

---@class era.dressing.indentscope.draw
local M = {}

local namespace = vim.api.nvim_create_namespace("era.dressing.indentscope") ---@type integer

---@type table<string, boolean>
local DISABLED_BUFTYPES = {
  help = true,
  prompt = true,
  quickfix = true,
  terminal = true,
}

---@type table<string, boolean>
local DISABLED_FILETYPES = {
  [""] = true,
  ["diff"] = true,
  [stl.filetype.AI_TERMINAL] = true,
  [stl.filetype.BIGFILE] = true,
  [stl.filetype.BOARD] = true,
  [stl.filetype.CHECKHEALTH] = true,
  [stl.filetype.DIFFVIEW_CHANGES] = true,
  [stl.filetype.DIFFVIEW_COMMITS] = true,
  [stl.filetype.DIFFVIEW_FILES] = true,
  [stl.filetype.DIFFVIEW_SBS] = true,
  [stl.filetype.EXPLORER] = true,
  [stl.filetype.GITCOMMIT] = true,
  [stl.filetype.HELP] = true,
  [stl.filetype.IMAGE_VIEWER] = true,
  [stl.filetype.LSPINFO] = true,
  [stl.filetype.MAN] = true,
  [stl.filetype.MASON] = true,
  [stl.filetype.NOTIFY] = true,
  [stl.filetype.QUICKFIX] = true,
  [stl.filetype.SELECT] = true,
  [stl.filetype.STARTUPTIME] = true,
  [stl.filetype.TEMP_VIEWER] = true,
  [stl.filetype.TERM] = true,
  [stl.filetype.TERM_MASK] = true,
  [stl.filetype.UX_CMDLINE] = true,
  [stl.filetype.UX_INPUT] = true,
  [stl.filetype.UX_MESSAGE_HISTORY] = true,
  [stl.filetype.UX_PICKER_FINDER] = true,
  [stl.filetype.UX_PICKER_PREVIEW] = true,
  [stl.filetype.UX_PICKER_RESULT] = true,
  [stl.filetype.UX_POPUPMENU] = true,
  [stl.filetype.UX_SEARCHER_FINDER] = true,
  [stl.filetype.UX_SEARCHER_PREVIEW] = true,
  [stl.filetype.UX_SEARCHER_RESULT] = true,
  [stl.filetype.WINPICKER_MASK] = true,
  [stl.filetype.WINSEP] = true,
}

---@class era.dressing.indentscope.draw.IState
---@field public generation             integer
---@field public scope                  era.dressing.indentscope.IScope|nil
---@field public status                 "none"|"waiting"|"drawing"|"finished"
---@field public delay_timer            uv.uv_timer_t|nil
---@field public animation_timer        uv.uv_timer_t|nil
---@field public options                era.dressing.indentscope.IDrawOptions|nil
---@field public indicator              era.dressing.indentscope.draw.IIndicator|nil
---@field public drawn_distance         integer
local state = {
  generation = 0,
  scope = nil,
  status = "none",
  delay_timer = nil,
  animation_timer = nil,
  options = nil,
  indicator = nil,
  drawn_distance = 0,
}

---@return nil
local function clear_delay_timer()
  local timer = state.delay_timer ---@type uv.uv_timer_t|nil
  state.delay_timer = nil
  stl.timer.clear_timer(timer)
end

---@return nil
local function clear_animation_timer()
  local timer = state.animation_timer ---@type uv.uv_timer_t|nil
  state.animation_timer = nil
  stl.timer.clear_timer(timer)
end

---@param scope                         era.dressing.indentscope.IScope|nil
---@return nil
local function redraw_scope(scope)
  if scope ~= nil and vim.api.nvim_win_is_valid(scope.winnr) then
    pcall(vim.api.nvim__redraw, { win = scope.winnr, valid = false, flush = true })
  end
end

---@param scope                         era.dressing.indentscope.IScope
---@param indicator                     era.dressing.indentscope.draw.IIndicator
---@param from_distance                 integer
---@param to_distance                   integer
---@return nil
local function redraw_distances(scope, indicator, from_distance, to_distance)
  if not vim.api.nvim_win_is_valid(scope.winnr) then
    return
  end

  local ranges = {} ---@type integer[][]
  local upper_first = math.max(indicator.origin_index - to_distance, 1) ---@type integer
  local upper_last = indicator.origin_index - from_distance ---@type integer
  if upper_first <= upper_last then
    ranges[#ranges + 1] = { indicator.rows[upper_first] - 1, indicator.rows[upper_last] }
  end

  local lower_first = indicator.origin_index + math.max(from_distance, 1) ---@type integer
  local lower_last = math.min(indicator.origin_index + to_distance, #indicator.rows) ---@type integer
  if lower_first <= lower_last then
    ranges[#ranges + 1] = { indicator.rows[lower_first] - 1, indicator.rows[lower_last] }
  end

  for index, range in ipairs(ranges) do
    pcall(vim.api.nvim__redraw, {
      win = scope.winnr,
      range = range,
      flush = index == #ranges,
    })
  end
end

---@param bufnr                         integer
---@return boolean
function M.is_enabled(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end

  local buftype = vim.api.nvim_get_option_value("buftype", { buf = bufnr }) ---@type string
  if DISABLED_BUFTYPES[buftype] then
    return false
  end

  local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr }) ---@type string
  return DISABLED_FILETYPES[filetype] ~= true
end

---@return integer
local function next_generation()
  state.generation = state.generation + 1
  return state.generation
end

vim.api.nvim_set_decoration_provider(namespace, {
  on_win = function(_, winnr, bufnr)
    local scope = state.scope
    local indicator = state.indicator
    if
      scope == nil
      or indicator == nil
      or state.status == "none"
      or state.status == "waiting"
      or scope.winnr ~= winnr
      or scope.bufnr ~= bufnr
    then
      return false
    end
    return true
  end,
  on_line = function(_, winnr, bufnr, row)
    local scope = state.scope
    local indicator = state.indicator
    if scope == nil or indicator == nil or scope.winnr ~= winnr or scope.bufnr ~= bufnr then
      return
    end
    local lnum = row + 1 ---@type integer
    if lnum < scope.body.top or lnum > scope.body.bottom then
      return
    end

    if state.status == "drawing" then
      local index = indicator.row_indexes[lnum] ---@type integer|nil
      if index == nil or math.abs(index - indicator.origin_index) > state.drawn_distance then
        return
      end
    end
    pcall(vim.api.nvim_buf_set_extmark, bufnr, namespace, row, 0, indicator.extmark_options)
  end,
})

---@return nil
function M.undraw()
  local previous = state.scope ---@type era.dressing.indentscope.IScope|nil
  next_generation()
  clear_delay_timer()
  clear_animation_timer()
  state.scope = nil
  state.status = "none"
  state.options = nil
  state.indicator = nil
  state.drawn_distance = 0
  redraw_scope(previous)
end

---@param scope                         era.dressing.indentscope.IScope
---@param options                       era.dressing.indentscope.IDrawOptions
---@return era.dressing.indentscope.draw.IIndicator|nil
local function make_indicator(scope, options)
  local draw_col = Scope.get_draw_col(scope) ---@type integer
  if draw_col < 0 or not vim.api.nvim_win_is_valid(scope.winnr) then
    return nil
  end
  if vim.api.nvim_win_get_buf(scope.winnr) ~= scope.bufnr then
    return nil
  end

  local view = vim.api.nvim_win_call(scope.winnr, function()
    local saved = vim.fn.winsaveview() ---@type table
    local viewport_top = vim.fn.line("w0") ---@type integer
    local viewport_bottom = vim.fn.line("w$") ---@type integer
    local scope_top = math.max(scope.body.top, viewport_top) ---@type integer
    local scope_bottom = math.min(scope.body.bottom, viewport_bottom) ---@type integer
    local rows = {} ---@type integer[]
    local lnum = scope_top ---@type integer
    while lnum <= scope_bottom do
      local fold_start = vim.fn.foldclosed(lnum) ---@type integer
      if fold_start < 0 then
        rows[#rows + 1] = lnum
        lnum = lnum + 1
      else
        if fold_start >= scope_top then
          rows[#rows + 1] = fold_start
        end
        lnum = math.max(vim.fn.foldclosedend(lnum) + 1, lnum + 1)
      end
    end
    return {
      leftcol = saved.leftcol,
      rows = rows,
    }
  end) ---@type table
  local screen_col = draw_col - view.leftcol ---@type integer
  if screen_col < 0 or #view.rows == 0 then
    return nil
  end

  local origin_index = 1 ---@type integer
  local origin_distance = math.abs(view.rows[1] - scope.reference.line) ---@type integer
  for index = 2, #view.rows do
    local distance = math.abs(view.rows[index] - scope.reference.line) ---@type integer
    if distance < origin_distance then
      origin_index = index
      origin_distance = distance
    end
  end

  local shiftwidth = vim.api.nvim_get_option_value("shiftwidth", { buf = scope.bufnr }) ---@type integer
  if shiftwidth == 0 then
    shiftwidth = vim.api.nvim_get_option_value("tabstop", { buf = scope.bufnr })
  end
  shiftwidth = math.max(shiftwidth, 1)

  local highlight_index = math.floor(draw_col / shiftwidth) % #options.highlights + 1 ---@type integer
  local extmark_options = {
    ephemeral = true,
    hl_mode = "combine",
    priority = options.priority,
    right_gravity = false,
    virt_text = { { options.symbol, options.highlights[highlight_index] } },
    virt_text_pos = "overlay",
    virt_text_win_col = screen_col,
  } ---@type vim.api.keyset.set_extmark

  local breakindent = vim.api.nvim_get_option_value("breakindent", { win = scope.winnr }) ---@type boolean
  local showbreak = vim.api.nvim_get_option_value("showbreak", { win = scope.winnr }) ---@type string
  if breakindent and showbreak == "" then
    extmark_options.virt_text_repeat_linebreak = true
  end

  local row_indexes = {} ---@type table<integer, integer>
  for index, lnum in ipairs(view.rows) do
    row_indexes[lnum] = index
  end

  return {
    rows = view.rows,
    row_indexes = row_indexes,
    origin_index = origin_index,
    extmark_options = extmark_options,
  }
end

---@param scope                         era.dressing.indentscope.IScope
---@param options                       era.dressing.indentscope.IDrawOptions
---@param generation                    integer
---@return nil
local function start_drawing(scope, options, generation)
  if generation ~= state.generation then
    return
  end
  if not M.is_enabled(scope.bufnr) then
    M.undraw()
    return
  end

  local indicator = make_indicator(scope, options)
  if indicator == nil then
    state.status = "finished"
    state.indicator = nil
    state.drawn_distance = 0
    redraw_scope(scope)
    return
  end

  state.indicator = indicator
  local maximum_distance = math.max(indicator.origin_index - 1, #indicator.rows - indicator.origin_index) ---@type integer
  if options.interval <= 0 or options.max_duration <= 0 or maximum_distance == 0 then
    state.status = "finished"
    state.drawn_distance = maximum_distance
    redraw_scope(scope)
    return
  end

  local timer = vim.uv.new_timer() ---@type uv.uv_timer_t|nil
  if timer == nil then
    state.status = "finished"
    state.drawn_distance = maximum_distance
    redraw_scope(scope)
    return
  end

  state.status = "drawing"
  state.drawn_distance = 0
  state.animation_timer = timer
  local frame_count = math.max(math.floor(options.max_duration / options.interval), 1) ---@type integer
  local distance_per_frame = math.max(math.ceil(maximum_distance / frame_count), 1) ---@type integer
  redraw_distances(scope, indicator, 0, 0)
  timer:start(
    options.interval,
    options.interval,
    vim.schedule_wrap(function()
      if generation ~= state.generation then
        stl.timer.clear_timer(timer)
        return
      end
      if not M.is_enabled(scope.bufnr) then
        M.undraw()
        return
      end

      local target_distance = math.min(state.drawn_distance + distance_per_frame, maximum_distance) ---@type integer

      if target_distance > state.drawn_distance then
        local previous_distance = state.drawn_distance ---@type integer
        state.drawn_distance = target_distance
        if state.drawn_distance >= maximum_distance then
          state.status = "finished"
          redraw_scope(scope)
        else
          redraw_distances(scope, indicator, previous_distance + 1, state.drawn_distance)
        end
      end

      if state.drawn_distance >= maximum_distance then
        clear_animation_timer()
      end
    end)
  )
end

---@param scope                         era.dressing.indentscope.IScope
---@param options                       era.dressing.indentscope.IDrawOptions
---@param delay                         integer
---@return nil
local function schedule_drawing(scope, options, delay)
  local previous = state.scope ---@type era.dressing.indentscope.IScope|nil
  local generation = next_generation() ---@type integer
  clear_delay_timer()
  clear_animation_timer()
  state.scope = scope
  state.status = delay > 0 and "waiting" or "drawing"
  state.options = options
  state.indicator = nil
  state.drawn_distance = 0

  if delay <= 0 then
    local restarts_animation = options.interval > 0 and options.max_duration > 0 ---@type boolean
    if previous ~= nil and (previous.winnr ~= scope.winnr or restarts_animation) then
      redraw_scope(previous)
    end
    start_drawing(scope, options, generation)
    return
  end

  redraw_scope(previous)
  state.delay_timer = vim.defer_fn(function()
    if generation ~= state.generation then
      return
    end
    state.delay_timer = nil
    start_drawing(scope, options, generation)
  end, delay)
end

---@param scope                         era.dressing.indentscope.IScope
---@param options                       era.dressing.indentscope.IDrawOptions
---@return nil
function M.draw(scope, options)
  if not M.is_enabled(scope.bufnr) then
    M.undraw()
    return
  end
  schedule_drawing(scope, options, 0)
end

---@param scope                         era.dressing.indentscope.IScope
---@param options                       era.dressing.indentscope.IDrawOptions
---@param lazy                          boolean
---@return nil
function M.refresh(scope, options, lazy)
  if not M.is_enabled(scope.bufnr) then
    M.undraw()
    return
  end
  if
    lazy
    and state.scope ~= nil
    and state.status ~= "none"
    and state.status ~= "waiting"
    and Scope.equals(scope, state.scope)
  then
    return
  end

  local resolved = vim.tbl_extend("force", {}, options) ---@type era.dressing.indentscope.IDrawOptions
  if
    state.scope ~= nil
    and state.status ~= "none"
    and state.status ~= "waiting"
    and Scope.intersects(scope, state.scope)
  then
    resolved.interval = 0
    resolved.delay = 0
  end
  schedule_drawing(scope, resolved, resolved.delay)
end

---@return boolean
function M.relayout()
  local scope = state.scope ---@type era.dressing.indentscope.IScope|nil
  local options = state.options ---@type era.dressing.indentscope.IDrawOptions|nil
  if scope == nil or options == nil then
    return false
  end
  if not M.is_enabled(scope.bufnr) then
    M.undraw()
    return true
  end

  local resolved = vim.tbl_extend("force", {}, options, { delay = 0, interval = 0 }) ---@type era.dressing.indentscope.IDrawOptions
  schedule_drawing(scope, resolved, 0)
  return true
end

return M
