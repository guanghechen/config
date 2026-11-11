---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.support.dressing" ---@type string

-- Doubles of the runtime around `era.dressing` modules: flight switches, autocommand groups, timers, bars and
-- ephemeral decorations; the indentscope runtime with its buffers, drawn guide rows and screen reads.

local bootstrap = require("__test__.support.bootstrap")
local nvim_fn = require("stl.nvim.fn")

---@class __test__.support.dressing.Flight
---@field value                         any What `snapshot` returns.
---@field observers                     fun()[] Callbacks registered through `observe`, in order.
---@field observe                       fun(observables: table[], callback: fun(), ignore_initial: boolean): table
local Flight = {}
Flight.__index = Flight

---@class __test__.support.dressing.Augroups
---@field groups                        table<string, integer> The group of each name.
---@field ids                           integer[] The group each call returned, in order.
---@field augroup                       fun(name: string): integer

---@class __test__.support.dressing.Timer
---@field timeout                       ?integer
---@field repeat_ms                     ?integer
---@field callback                      ?fun()
---@field closing                       boolean
local Timer = {}
Timer.__index = Timer

---@class __test__.support.dressing.IExtmark
---@field bufnr                         integer
---@field row                           integer
---@field col                           integer
---@field options                       vim.api.keyset.set_extmark

---@class __test__.support.dressing.Bar
---@field props                         table What `Nvimbar.new` received.
---@field value                         ?string The last result fulfilled, which `snapshot` returns.
---@field refreshes                     integer
---@field disposals                     integer
local Bar = {}
Bar.__index = Bar

---@class __test__.support.dressing.Nvimbars
---@field Nvimbar                       { new: fun(props: table): __test__.support.dressing.Bar }
---@field bars                          table<string, __test__.support.dressing.Bar> The latest bar of each name.

local M = {}

---@return any
function Flight:snapshot()
  return self.value
end

---Switches to `value` and notifies every observer.
---@param value                         any
---@return nil
function Flight:set(value)
  self.value = value
  for _, observer in ipairs(self.observers) do
    observer()
  end
end

---A `dot.context.flight` switch holding `value`. Its `observe`, standing in for `stl.fn.observe`, requires the switch
---to be the first observable and the initial notification to be ignored, and records the callback.
---@param t                             __test__.support.Harness
---@param value                         any
---@return __test__.support.dressing.Flight
function M.flight(t, value)
  local flight = setmetatable({ value = value, observers = {} }, Flight)
  function flight.observe(observables, callback, ignore_initial)
    t.assert_eq(flight, observables[1], "observed flight")
    t.assert_true(ignore_initial, "initial notification ignored")
    flight.observers[#flight.observers + 1] = callback
    return { unsubscribe = function() end }
  end
  return flight
end

---Records the autocommand groups `augroup` creates as `stl.nvim.fn.augroup` does, deleting each group when the case
---(or the suite, outside a case) ends.
---@param t                             __test__.support.Harness
---@return __test__.support.dressing.Augroups
function M.augroups(t)
  local augroups = { groups = {}, ids = {} } ---@type __test__.support.dressing.Augroups
  function augroups.augroup(name)
    local group = nvim_fn.augroup(name) ---@type integer
    if augroups.groups[name] == nil then
      t:defer(function()
        vim.api.nvim_del_augroup_by_id(group)
      end)
    end
    augroups.groups[name] = group
    augroups.ids[#augroups.ids + 1] = group
    return group
  end
  return augroups
end

---Declares the globals `era.dressing.indentline` reads: its flight switch is on and never notifies.
---@param t                             __test__.support.Harness
---@return nil
function M.with_indentline(t)
  bootstrap.with_runtime(t, {
    stl = {
      filetype = require("stl.filetype"),
      fn = {
        observe = function()
          return { unsubscribe = function() end }
        end,
      },
      nvim = {
        fn = {
          augroup = function(name)
            return vim.api.nvim_create_augroup(name, { clear = true })
          end,
        },
      },
    },
    dot = {
      context = {
        flight = {
          dressing_indent = {
            snapshot = function()
              return true
            end,
          },
        },
      },
    },
  })
end

---Declares the globals `era.dressing.indentscope` reads and returns the module, which its keymaps reach as
---`era.dressing.indentscope`.
---@param t                             __test__.support.Harness
---@return era.dressing.indentscope
function M.with_indentscope(t)
  bootstrap.with_runtime(t, {
    stl = {
      filetype = require("stl.filetype"),
      nvim = { fn = nvim_fn },
      timer = require("stl.timer"),
    },
    era = { dressing = {} },
  })
  local Indentscope = require("era.dressing.indentscope")
  era.dressing.indentscope = Indentscope
  return Indentscope
end

---Shows `lines` as two-space indented Lua in the current window; the drawn scope is cleared and the window gets its
---fold method back when the case ends.
---@param t                             __test__.support.Harness
---@param lines                         string[]
---@return integer
function M.indentscope_buffer(t, lines)
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local foldmethod = vim.api.nvim_get_option_value("foldmethod", { win = winnr }) ---@type string
  local bufnr = t:buffer(lines, { filetype = "lua", current = true }) ---@type integer
  t:defer(function()
    require("era.dressing.indentscope").undraw()
    if vim.api.nvim_win_is_valid(winnr) then
      vim.api.nvim_set_option_value("foldmethod", foldmethod, { win = winnr })
    end
  end)
  vim.api.nvim_set_option_value("expandtab", true, { buf = bufnr })
  vim.api.nvim_set_option_value("shiftwidth", 2, { buf = bufnr })
  vim.api.nvim_set_option_value("tabstop", 2, { buf = bufnr })
  return bufnr
end

---Lines of one indented scope, `count` lines long, between the lines "root" and "tail".
---@param count                         integer
---@return string[]
function M.indented_lines(count)
  local lines = { "root" } ---@type string[]
  for index = 2, count + 1 do
    lines[index] = "  line"
  end
  lines[count + 2] = "tail"
  return lines
end

---Redraws `winnr` (the current window by default) and returns the rows indentscope draws guides on, in order.
---@param t                             __test__.support.Harness
---@param winnr                         ?integer
---@return integer[]
function M.indentscope_rows(t, winnr)
  require("era.dressing.indentscope.draw")
  local namespace = vim.api.nvim_get_namespaces()["era.dressing.indentscope"] ---@type integer
  local extmarks = M.ephemeral_extmarks(t, namespace, function()
    vim.api.nvim__redraw({ win = winnr or vim.api.nvim_get_current_win(), valid = false, flush = true })
  end)
  local rows = {} ---@type integer[]
  for _, extmark in ipairs(extmarks) do
    rows[#rows + 1] = extmark.row
  end
  table.sort(rows)
  return rows
end

---The character on the screen at display column `col` (0 by default) of line `lnum` in `winnr`.
---@param winnr                         integer
---@param lnum                          integer
---@param col                           ?integer
---@return string
function M.screen_char(winnr, lnum, col)
  local position = vim.api.nvim_win_get_position(winnr) ---@type integer[]
  local info = vim.fn.getwininfo(winnr)[1] ---@type table
  local topline = vim.api.nvim_win_call(winnr, function()
    return vim.fn.line("w0")
  end) ---@type integer
  return vim.fn.screenstring(position[1] + lnum - topline + 1, position[2] + info.textoff + (col or 0) + 1)
end

---@param timeout                       integer
---@param repeat_ms                     integer
---@param callback                      fun()
---@return nil
function Timer:start(timeout, repeat_ms, callback)
  self.timeout, self.repeat_ms, self.callback = timeout, repeat_ms, callback
end

---@return nil
function Timer:stop() end

---@return nil
function Timer:close()
  self.closing = true
end

---@return boolean
function Timer:is_closing()
  return self.closing
end

---A `uv_timer_t` double that only records how it is started; a case runs its `callback` to fire it.
---@return __test__.support.dressing.Timer
function M.timer()
  return setmetatable({ closing = false }, Timer)
end

---Hands out a new `timer()` for each `vim.uv.new_timer()` until the case (or the suite) ends.
---@param t                             __test__.support.Harness
---@return __test__.support.dressing.Timer[] timers The timers handed out, in order.
function M.timers(t)
  local timers = {} ---@type __test__.support.dressing.Timer[]
  t:patch_table(vim.uv, "new_timer", function()
    local timer = M.timer()
    timers[#timers + 1] = timer
    return timer
  end)
  return timers
end

---Runs `callback` and returns the ephemeral extmarks a decoration provider sets in `namespace` meanwhile.
---@param t                             __test__.support.Harness
---@param namespace                     integer
---@param callback                      fun()
---@return __test__.support.dressing.IExtmark[]
function M.ephemeral_extmarks(t, namespace, callback)
  local original = vim.api.nvim_buf_set_extmark
  local extmarks = {} ---@type __test__.support.dressing.IExtmark[]
  local restore = t:patch_table(vim.api, "nvim_buf_set_extmark", function(bufnr, ns_id, row, col, options)
    if ns_id == namespace and options.ephemeral == true then
      extmarks[#extmarks + 1] = { bufnr = bufnr, row = row, col = col, options = vim.deepcopy(options) }
    end
    return original(bufnr, ns_id, row, col, options)
  end)
  callback()
  restore()
  return extmarks
end

---@return __test__.support.dressing.Bar
function Bar:place()
  return self
end

---@return __test__.support.dressing.Bar
function Bar:refresh()
  self.refreshes = self.refreshes + 1
  return self
end

---@return string|nil
function Bar:snapshot()
  return self.value
end

---@return boolean
function Bar:isdisposed()
  return self.disposals > 0
end

---@return nil
function Bar:dispose()
  self.disposals = self.disposals + 1
end

---Publishes `result` as a completed refresh does.
---@param result                        string
---@return nil
function Bar:fulfill(result)
  self.value = result
  self.props.on_fulfilled(result)
end

---An `era.m.nvimbar` double whose bars count their refreshes and disposals and publish only what a case fulfills.
---@return __test__.support.dressing.Nvimbars
function M.nvimbars()
  local nvimbars = { bars = {} } ---@type __test__.support.dressing.Nvimbars
  nvimbars.Nvimbar = {
    new = function(props)
      local bar = setmetatable({ props = props, refreshes = 0, disposals = 0 }, Bar)
      nvimbars.bars[props.name] = bar
      return bar
    end,
  }
  return nvimbars
end

return M
