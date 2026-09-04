---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.dressing.hipattern.buffer" ---@type string

local dirty = require("era.dressing.hipattern.dirty")
local render = require("era.dressing.hipattern.render")
local reporter = require("stl.reporter")

---@class era.dressing.hipattern.buffer.IState
---@field public enabled                boolean
---@field public is_eligible            fun(bufnr: integer): boolean
---@field public scheduled              boolean
---@field public dirty_all              boolean
---@field public dirty_ranges           era.dressing.hipattern.dirty.IRange[]

---@class era.dressing.hipattern.buffer
local M = {}

local states = {} ---@type table<integer, era.dressing.hipattern.buffer.IState>
local initialized = false ---@type boolean

---@param bufnr                         integer|nil
---@return integer|nil
local function resolve_bufnr(bufnr)
  if bufnr == nil or bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end
  if type(bufnr) ~= "number" or not vim.api.nvim_buf_is_valid(bufnr) then
    return nil
  end
  return bufnr
end

---@param bufnr                         integer
---@param range                         era.dressing.hipattern.dirty.IRange|nil
---@param dirty_all                     boolean
---@param err                           any
---@return nil
local function report_failure(bufnr, range, dirty_all, err)
  reporter.error({
    from = __module_name__,
    subject = "render",
    message = "Failed to update hipatterns",
    details = { bufnr = bufnr, range = range, dirty_all = dirty_all, error = err },
  })
end

---@param bufnr                         integer
---@param state                         era.dressing.hipattern.buffer.IState
---@return nil
local function flush(bufnr, state)
  state.scheduled = false
  if states[bufnr] ~= state or not state.enabled or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  if not state.is_eligible(bufnr) then
    M.disable(bufnr)
    return
  end

  local dirty_all = state.dirty_all ---@type boolean
  local dirty_ranges = state.dirty_ranges ---@type era.dressing.hipattern.dirty.IRange[]
  state.dirty_all = false
  state.dirty_ranges = {}
  if not dirty_all and #dirty_ranges == 0 then
    return
  end

  if dirty_all then
    local ok, err = pcall(render.update_all, bufnr)
    if not ok then
      report_failure(bufnr, nil, true, err)
    end
  else
    for _, range in ipairs(dirty_ranges) do
      local ok, err = pcall(render.update, bufnr, range.from, range.to)
      if not ok then
        report_failure(bufnr, range, false, err)
      end
    end
  end

  if (state.dirty_all or #state.dirty_ranges > 0) and not state.scheduled then
    state.scheduled = true
    vim.schedule(function()
      flush(bufnr, state)
    end)
  end
end

---@param bufnr                         integer
---@param state                         era.dressing.hipattern.buffer.IState
---@param from_row                      integer
---@param to_row                        integer
---@param dirty_all                     boolean|nil
---@return nil
local function queue_update(bufnr, state, from_row, to_row, dirty_all)
  if dirty_all then
    state.dirty_all = true
    state.dirty_ranges = {}
  elseif not state.dirty_all then
    state.dirty_ranges = dirty.add(state.dirty_ranges, from_row, to_row)
  end
  if state.scheduled then
    return
  end

  state.scheduled = true
  vim.schedule(function()
    flush(bufnr, state)
  end)
end

---@param state                         era.dressing.hipattern.buffer.IState
---@param first                         integer
---@param last_orig                     integer
---@param last_new                      integer
---@return nil
local function transform_dirty_ranges(state, first, last_orig, last_new)
  if state.dirty_all then
    return
  end
  state.dirty_ranges = dirty.transform(state.dirty_ranges, first, last_orig, last_new)
end

---@param bufnr                         integer
---@param state                         era.dressing.hipattern.buffer.IState
---@return boolean
local function attach(bufnr, state)
  return vim.api.nvim_buf_attach(bufnr, false, {
    on_detach = function(_, buf)
      if states[buf] == state then
        states[buf] = nil
      end
    end,
    on_lines = function(_, buf, _, first, last_orig, last_new)
      if states[buf] ~= state then
        return true
      end
      if not state.enabled then
        return
      end

      transform_dirty_ranges(state, first, last_orig, last_new)
      queue_update(buf, state, first, math.max(last_new + 1, first + 1))
    end,
    on_reload = function(_, buf)
      if states[buf] == state and state.enabled then
        queue_update(buf, state, 0, 0, true)
      end
    end,
  })
end

---@param bufnr                         integer|nil
---@param is_eligible                   fun(bufnr: integer): boolean
---@return nil
function M.enable(bufnr, is_eligible)
  bufnr = resolve_bufnr(bufnr)
  if bufnr == nil then
    return
  end
  if not is_eligible(bufnr) then
    M.disable(bufnr)
    return
  end

  local state = states[bufnr]
  if state ~= nil then
    state.is_eligible = is_eligible
    if state.enabled then
      return
    end
    state.enabled = true
    queue_update(bufnr, state, 0, 0, true)
    return
  end

  state = { enabled = true, is_eligible = is_eligible, scheduled = false, dirty_all = false, dirty_ranges = {} }
  states[bufnr] = state
  if not attach(bufnr, state) then
    states[bufnr] = nil
    reporter.warn({
      from = __module_name__,
      subject = "attach",
      message = "Failed to attach hipatterns to buffer",
      details = { bufnr = bufnr },
    })
    return
  end

  queue_update(bufnr, state, 0, 0, true)
end

---@param bufnr                         integer|nil
---@return nil
function M.disable(bufnr)
  bufnr = resolve_bufnr(bufnr)
  if bufnr == nil then
    return
  end

  local state = states[bufnr]
  if state == nil or not state.enabled then
    return
  end
  state.enabled = false
  state.dirty_all = false
  state.dirty_ranges = {}
  render.clear(bufnr, 0, -1)
end

---@param bufnr                         integer|nil
---@param is_eligible                   fun(bufnr: integer): boolean
---@return nil
function M.toggle(bufnr, is_eligible)
  bufnr = resolve_bufnr(bufnr)
  if bufnr == nil then
    return
  end
  if M.is_enabled(bufnr) then
    M.disable(bufnr)
  else
    M.enable(bufnr, is_eligible)
  end
end

---@param bufnr                         integer|nil
---@return boolean
function M.is_enabled(bufnr)
  bufnr = resolve_bufnr(bufnr)
  if bufnr == nil then
    return false
  end
  local state = states[bufnr]
  return state ~= nil and state.enabled
end

---@param bufnr                         integer|nil
---@param from_row                      integer|nil
---@param to_row                        integer|nil
---@return nil
function M.update(bufnr, from_row, to_row)
  bufnr = resolve_bufnr(bufnr)
  if bufnr == nil then
    return
  end
  local state = states[bufnr]
  if state == nil or not state.enabled then
    return
  end

  if from_row == nil and to_row == nil then
    queue_update(bufnr, state, 0, 0, true)
  else
    local line_count = vim.api.nvim_buf_line_count(bufnr) ---@type integer
    queue_update(bufnr, state, from_row or 0, to_row or line_count)
  end
end

---@param is_eligible                   fun(bufnr: integer): boolean
---@return nil
function M.setup(is_eligible)
  if initialized then
    return
  end
  initialized = true

  local augroup = vim.api.nvim_create_augroup(__module_name__, { clear = true })
  vim.api.nvim_create_autocmd("BufEnter", {
    group = augroup,
    callback = function(ev)
      M.enable(ev.buf, is_eligible)
    end,
  })
  vim.api.nvim_create_autocmd("FileType", {
    group = augroup,
    callback = function(ev)
      if is_eligible(ev.buf) then
        if M.is_enabled(ev.buf) then
          M.update(ev.buf)
        else
          M.enable(ev.buf, is_eligible)
        end
      else
        M.disable(ev.buf)
      end
    end,
  })
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = augroup,
    callback = render.refresh_highlights,
  })

  local enabled_bufnrs = {} ---@type table<integer, true>
  for _, winnr in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(winnr) then
      local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
      if not enabled_bufnrs[bufnr] then
        enabled_bufnrs[bufnr] = true
        M.enable(bufnr, is_eligible)
      end
    end
  end
end

return M
