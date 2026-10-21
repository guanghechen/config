---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.fuzzy.probes" ---@type string

-- Child-side observation for the L3 benchmark. Wraps only functions present in both the baseline and
-- the current checkout, and only observes: every wrapper returns what the original returned.

local M = {}

---@param stage                         string
---@param payload                       ?table
---@return nil
local function notify(stage, payload)
  payload = payload or {}
  payload.stage, payload.t = stage, vim.uv.hrtime()
  vim.rpcnotify(1, "fuzzy_stage", payload)
end

---@param class                         table|nil
---@param method                        string
---@param before                        fun(self: table, ...): nil
---@param after                         ?fun(self: table, result: any, ...): nil
---@return nil
local function wrap(class, method, before, after)
  local original = class and rawget(class, method)
  if type(original) ~= "function" then
    return
  end
  class[method] = function(self, ...)
    before(self, ...)
    local results = vim.F.pack_len(original(self, ...))
    if after then
      after(self, results[1], ...)
    end
    return vim.F.unpack_len(results)
  end
end

---@return nil
function M.install()
  local bench = { errors = {} }
  _G.fuzzy_bench = bench
  local report = stl.reporter.error
  stl.reporter.error = function(value)
    bench.errors[#bench.errors + 1] = tostring(value.message or value.subject)
    return report(value)
  end

  -- Completion pops up in finders (path source); while its menu is visible the finder receives
  -- TextChangedP instead of TextChangedI and stops filtering. Keep it out of the measurement.
  local ok, cmp_context = pcall(require, "era.keystroke.cmp.context")
  if ok and type(cmp_context.enabled) == "function" then
    local enabled = cmp_context.enabled
    cmp_context.enabled = function(context)
      if context.filetype == stl.filetype.UX_PICKER_FINDER then
        return false
      end
      return enabled(context)
    end
  end

  local factory = era.m.picker.BasicComposer.new
  era.m.picker.BasicComposer.new = function(props)
    local value = factory(props)
    bench.basic, bench.owner = value, props.result_tree
    -- The header shows this total; its changes say which total the screen must show next.
    local total = value.result.lnum_total
    local next = total.next
    total.next = function(self, count, ...)
      local changed = count ~= self:snapshot()
      local results = vim.F.pack_len(next(self, count, ...))
      if changed then
        -- The finder may already hold later keystrokes; the result belongs to the query last published.
        notify("total", { input = bench.publishing or "", rows = count })
      end
      return vim.F.unpack_len(results)
    end
    return value
  end

  for _, name in ipairs({ "ListComposer", "TreeComposer", "FiletreeComposer" }) do
    wrap(era.m.picker[name], "__match__", function(_, input)
      notify("match_start", { input = input })
    end, function(_, _, input)
      bench.matched = input
      notify("match_end", { input = input })
    end)
  end

  local ResultTree = require("era.view.result_tree")
  wrap(ResultTree, "_display", function(self)
    if self == bench.owner then
      notify("display_start")
    end
  end, function(self)
    if self == bench.owner then
      notify("display_end")
    end
  end)
  wrap(ResultTree, "publish", function() end, function(self, future)
    if self ~= bench.owner or type(future) ~= "table" or not future.finally then
      return
    end
    -- Publishing may be scheduled after later keystrokes were typed; it shows the last matched query.
    local input = bench.matched or ""
    bench.publishing = input
    future:finally(function(ok)
      local total = bench.basic and bench.basic.result.lnum_total:snapshot()
      notify("published", { ok = ok, input = input, rows = total })
    end)
  end)
end

-- Records finder edits after the composer exists; the finder's own observer runs first.
---@return nil
local function watch_input()
  local bench = _G.fuzzy_bench
  local bufnr = bench.basic.finder:get_bufnr()
  if bench.watched == bufnr then
    return
  end
  bench.watched = bufnr
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    buf = bufnr,
    callback = function()
      bench.input = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
      notify("input", { input = bench.input })
    end,
  })
end

---@param paths                         string[]
---@param ages                          integer[][]
---@return integer
function M.seed_frecency(paths, ages)
  local frecency = dot.context.frecency.files
  local now = os.time()
  for index, path in ipairs(paths) do
    frecency:access(path)
    local item = frecency._items[frecency._normalize(path)]
    item.timestamps, item.idx = {}, #ages[index]
    for at, age in ipairs(ages[index]) do
      item.timestamps[at] = now - age
    end
  end
  return #paths
end

---@param scenario                      "files"|"list"
---@param options                       { mode: string, labels: ?string, fuzzy: boolean }
---@return nil
function M.open(scenario, options)
  local bench = _G.fuzzy_bench
  if scenario == "files" then
    local flags = dot.context.select.find_file
    flags.flag_viewtype:next(options.mode)
    flags.flag_fuzzy:next(options.fuzzy)
    flags.flag_regex:next(false)
    flags.flag_case_sensitive:next(false)
    era.fn.find_files("workspace")
  else
    local items = {}
    for index, text in ipairs(vim.fn.readfile(assert(options.labels))) do
      items[index] = { uuid = tostring(index), text = text, text_lower = text:lower(), highlights = {} }
    end
    local observable = stl.c.Observable.from_value
    bench.picker = era.m.picker.ListComposer.new({
      name = "fuzzy bench",
      title = "fuzzy bench",
      permanent = true,
      search_pattern = observable(""),
      flag_fuzzy = observable(options.fuzzy),
      flag_regex = observable(false),
      flag_case_sensitive = observable(false),
    })
    bench.picker:reset_data({ items = items })
    bench.picker:focus()
  end
end

---@return table
function M.status()
  local bench = _G.fuzzy_bench
  local basic = bench and bench.basic
  local finder = basic and basic.finder
  local winnr = finder and finder:get_winnr()
  return {
    composer = basic ~= nil,
    rows = basic and basic.result.lnum_total:snapshot() or nil,
    input = finder
      and finder:get_bufnr()
      and table.concat(vim.api.nvim_buf_get_lines(finder:get_bufnr(), 0, -1, false), "\n"),
    finder_focused = winnr ~= nil and vim.api.nvim_get_current_win() == winnr,
    mode = vim.api.nvim_get_mode().mode,
    current = vim.bo.filetype .. ":" .. vim.api.nvim_buf_get_name(0),
    errors = bench and bench.errors or {},
  }
end

-- Clears the query, then focuses the finder in Insert mode at the end of its line.
---@return nil
function M.arm()
  local bench = _G.fuzzy_bench
  watch_input()
  bench.input = ""
  bench.basic.finder:set_content("")
  local winnr = bench.basic.finder:get_winnr()
  if winnr and vim.api.nvim_win_is_valid(winnr) then
    vim.api.nvim_set_current_win(winnr)
  end
  vim.cmd("startinsert!")
end

---@return table
function M.finish()
  local metrics = require("__test__.bench.metrics")
  collectgarbage("collect")
  local result = metrics.memory()
  result.errors = _G.fuzzy_bench.errors
  return result
end

return M
