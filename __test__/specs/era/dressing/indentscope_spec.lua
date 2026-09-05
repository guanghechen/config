--- Run with: nvim -l __test__/run.lua __test__/specs/era/dressing/indentscope_spec.lua
---@diagnostic disable: undefined-global

local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

local t = harness.new("era.dressing.indentscope")

bootstrap.with_runtime(t, {
  stl = {
    filetype = require("stl.filetype"),
    nvim = {
      fn = require("stl.nvim.fn"),
    },
    timer = require("stl.timer"),
  },
  era = {
    dressing = {},
  },
})

local Indentscope = require("era.dressing.indentscope")
era.dressing.indentscope = Indentscope

---@param lines                         string[]
---@param callback                      fun(bufnr: integer): nil
---@return nil
local function with_buffer(lines, callback)
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local previous_bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local previous_foldmethod = vim.api.nvim_get_option_value("foldmethod", { win = winnr }) ---@type string
  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.api.nvim_win_set_buf(winnr, bufnr)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value("expandtab", true, { buf = bufnr })
  vim.api.nvim_set_option_value("filetype", "lua", { buf = bufnr })
  vim.api.nvim_set_option_value("shiftwidth", 2, { buf = bufnr })
  vim.api.nvim_set_option_value("tabstop", 2, { buf = bufnr })

  local ok, err = pcall(callback, bufnr)
  Indentscope.undraw()
  if vim.api.nvim_buf_is_valid(previous_bufnr) then
    vim.api.nvim_win_set_buf(winnr, previous_bufnr)
  end
  if vim.api.nvim_win_is_valid(winnr) then
    vim.api.nvim_set_option_value("foldmethod", previous_foldmethod, { win = winnr })
  end
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
  if not ok then
    error(err, 0)
  end
end

---@param callback                      fun(render: fun(winnr: integer|nil): integer[]): nil
---@return nil
local function with_render_capture(callback)
  require("era.dressing.indentscope.draw")
  local namespace = vim.api.nvim_get_namespaces()["era.dressing.indentscope"] ---@type integer
  local original = vim.api.nvim_buf_set_extmark
  local rendered_rows = {} ---@type integer[]

  t:patch_table(vim.api, "nvim_buf_set_extmark", function(bufnr, ns_id, row, col, options)
    if ns_id == namespace and options.ephemeral == true then
      rendered_rows[#rendered_rows + 1] = row
    end
    return original(bufnr, ns_id, row, col, options)
  end)

  local function render(winnr)
    rendered_rows = {}
    vim.api.nvim__redraw({ win = winnr or vim.api.nvim_get_current_win(), valid = false, flush = true })
    table.sort(rendered_rows)
    return rendered_rows
  end

  callback(render)
end

t:test("init keeps rendering and actions lazy", function()
  t.assert_nil(package.loaded["era.dressing.indentscope.draw"], "draw loaded during init")
  t.assert_nil(package.loaded["era.dressing.indentscope.action"], "action loaded during init")
end)

t:test("try_as_border resolves the nested scope from its header", function()
  with_buffer({ "function outer()", "  if ok then", "    call()", "  end", "end" }, function()
    vim.api.nvim_win_set_cursor(0, { 2, 2 })
    local scope = Indentscope.get_scope()

    t.assert_eq(3, scope.reference.line, "reference line")
    t.assert_eq(3, scope.body.top, "body top")
    t.assert_eq(3, scope.body.bottom, "body bottom")
    t.assert_eq(2, scope.border.top, "border top")
    t.assert_eq(4, scope.border.bottom, "border bottom")
    t.assert_eq(2, scope.border.indent, "border indent")
  end)
end)

t:test("border policy controls blank lines at scope edges", function()
  with_buffer({ "function outer()", "", "    call()", "", "  end" }, function()
    vim.api.nvim_win_set_cursor(0, { 3, 4 })

    local both = Indentscope.get_scope(nil, nil, { border = "both", try_as_border = false })
    local top = Indentscope.get_scope(nil, nil, { border = "top", try_as_border = false })
    local bottom = Indentscope.get_scope(nil, nil, { border = "bottom", try_as_border = false })
    local none = Indentscope.get_scope(nil, nil, { border = "none", try_as_border = false })

    t.assert_eq(2, both.body.top, "both top")
    t.assert_eq(4, both.body.bottom, "both bottom")
    t.assert_eq(2, top.body.top, "top top")
    t.assert_eq(3, top.body.bottom, "top bottom")
    t.assert_eq(3, bottom.body.top, "bottom top")
    t.assert_eq(4, bottom.body.bottom, "bottom bottom")
    t.assert_eq(3, none.body.top, "none top")
    t.assert_eq(3, none.body.bottom, "none bottom")
  end)
end)

t:test("scope scans beyond the former line limit", function()
  local lines = {} ---@type string[]
  for index = 1, 8193 do
    lines[index] = "  line"
  end

  with_buffer(lines, function()
    vim.api.nvim_win_set_cursor(0, { 4097, 2 })
    local scope = Indentscope.get_scope(nil, nil, { try_as_border = false })

    t.assert_eq(1, scope.body.top, "scope top")
    t.assert_eq(8193, scope.body.bottom, "scope bottom")
  end)
end)

t:test("scope cache reuses unchanged boundaries and invalidates on edits", function()
  local lines = { "root" } ---@type string[]
  for index = 2, 201 do
    lines[index] = "  line"
  end
  lines[202] = "tail"

  with_buffer(lines, function(bufnr)
    vim.api.nvim_win_set_cursor(0, { 150, 2 })
    local first = Indentscope.get_scope(nil, nil, { try_as_border = false })
    t.assert_eq(2, first.body.top, "initial scope top")
    t.assert_eq(201, first.body.bottom, "initial scope bottom")

    local original_indent = vim.fn.indent
    local indent_calls = 0 ---@type integer
    t:patch_table(vim.fn, "indent", function(...)
      indent_calls = indent_calls + 1
      return original_indent(...)
    end)

    vim.api.nvim_win_set_cursor(0, { 151, 2 })
    local reused = Indentscope.get_scope(nil, nil, { try_as_border = false })
    t.assert_eq(2, reused.body.top, "reused scope top")
    t.assert_eq(201, reused.body.bottom, "reused scope bottom")
    t.assert_eq(1, indent_calls, "cached indent reads")

    indent_calls = 0
    vim.api.nvim_buf_set_lines(bufnr, 119, 120, false, { "break" })
    local invalidated = Indentscope.get_scope(nil, nil, { try_as_border = false })
    t.assert_eq(121, invalidated.body.top, "invalidated scope top")
    t.assert_eq(201, invalidated.body.bottom, "invalidated scope bottom")
    t.assert_true(indent_calls > 50, "edit forces a full scan")
  end)
end)

t:test("draw renders one guide on every scope body line", function()
  with_buffer({ "if ok then", "  one()", "  two()", "end" }, function(bufnr)
    with_render_capture(function(render)
      vim.api.nvim_win_set_cursor(0, { 2, 2 })
      local scope = Indentscope.get_scope(nil, nil, { try_as_border = false })
      Indentscope.draw(scope, { interval = 0 })

      local rows = render(nil)
      t.assert_eq(2, #rows, "guide count")
      t.assert_eq(1, rows[1], "first guide row")
      t.assert_eq(2, rows[2], "second guide row")

      local namespace = vim.api.nvim_get_namespaces()["era.dressing.indentscope"] ---@type integer
      local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, namespace, 0, -1, {}) ---@type table[]
      t.assert_eq(0, #extmarks, "persistent extmark count")
    end)
  end)
end)

t:test("draw clips guides to the current viewport", function()
  local lines = { "root" } ---@type string[]
  for index = 2, 201 do
    lines[index] = "  line"
  end
  lines[202] = "tail"

  with_buffer(lines, function()
    with_render_capture(function(render)
      vim.api.nvim_win_set_cursor(0, { 101, 2 })
      vim.cmd("normal! zz")
      local visible_top = vim.fn.line("w0") ---@type integer
      local visible_bottom = vim.fn.line("w$") ---@type integer
      local scope = Indentscope.get_scope(nil, nil, { try_as_border = false })
      Indentscope.draw(scope, { interval = 0 })

      local rows = render(nil)
      t.assert_eq(visible_bottom - visible_top + 1, #rows, "viewport guide count")
      t.assert_eq(visible_top - 1, rows[1], "first viewport row")
      t.assert_eq(visible_bottom - 1, rows[#rows], "last viewport row")
      t.assert_true(#rows < scope.body.bottom - scope.body.top + 1, "scope is clipped")
    end)
  end)
end)

t:test("draw renders only in the active window for a shared buffer", function()
  with_buffer({
    "function outer()",
    "  if one then",
    "    one()",
    "  end",
    "  if two then",
    "    two()",
    "  end",
    "end",
  }, function()
    local inactive_winnr = vim.api.nvim_get_current_win() ---@type integer
    vim.api.nvim_win_set_cursor(inactive_winnr, { 3, 4 })
    vim.cmd("vsplit")
    local active_winnr = vim.api.nvim_get_current_win() ---@type integer
    vim.api.nvim_win_set_cursor(active_winnr, { 6, 4 })

    local ok, err = pcall(function()
      local scope = Indentscope.get_scope(nil, nil, { try_as_border = false })
      Indentscope.draw(scope, { interval = 0 })
      vim.api.nvim__redraw({ valid = false, flush = true })

      local function screen_char(winnr, lnum, col)
        local position = vim.api.nvim_win_get_position(winnr) ---@type integer[]
        local info = vim.fn.getwininfo(winnr)[1] ---@type table
        local topline = vim.api.nvim_win_call(winnr, function()
          return vim.fn.line("w0")
        end) ---@type integer
        local row = position[1] + lnum - topline + 1 ---@type integer
        local screen_col = position[2] + info.textoff + col + 1 ---@type integer
        return vim.fn.screenstring(row, screen_col)
      end

      t.assert_eq("╎", screen_char(active_winnr, 6, 2), "active window guide")
      t.assert_eq(" ", screen_char(inactive_winnr, 6, 2), "inactive window guide")

      vim.api.nvim_set_current_win(inactive_winnr)
      scope = Indentscope.get_scope(nil, nil, { try_as_border = false })
      Indentscope.draw(scope, { interval = 0 })

      t.assert_eq("╎", screen_char(inactive_winnr, 3, 2), "new active window guide")
      t.assert_eq(" ", screen_char(active_winnr, 6, 2), "previous active window guide")
    end)

    if vim.api.nvim_win_is_valid(active_winnr) then
      vim.api.nvim_win_close(active_winnr, true)
    end
    if vim.api.nvim_win_is_valid(inactive_winnr) then
      vim.api.nvim_set_current_win(inactive_winnr)
    end
    if not ok then
      error(err, 0)
    end
  end)
end)

t:test("restarting animation clears the previous scope immediately", function()
  with_buffer({
    "if first then",
    "  first_a()",
    "  first_b()",
    "end",
    "",
    "if second then",
    "  second_a()",
    "  second_b()",
    "  second_c()",
    "end",
  }, function()
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    local position = vim.api.nvim_win_get_position(winnr) ---@type integer[]
    local info = vim.fn.getwininfo(winnr)[1] ---@type table

    local function guide_at(lnum)
      local topline = vim.api.nvim_win_call(winnr, function()
        return vim.fn.line("w0")
      end) ---@type integer
      local row = position[1] + lnum - topline + 1 ---@type integer
      local col = position[2] + info.textoff + 1 ---@type integer
      return vim.fn.screenstring(row, col)
    end

    vim.api.nvim_win_set_cursor(winnr, { 2, 2 })
    Indentscope.draw(Indentscope.get_scope(nil, nil, { try_as_border = false }), { interval = 0 })
    t.assert_eq("╎", guide_at(2), "previous scope guide")

    vim.api.nvim_win_set_cursor(winnr, { 8, 2 })
    Indentscope.draw(Indentscope.get_scope(nil, nil, { try_as_border = false }), {
      interval = 100,
      max_duration = 600,
    })

    t.assert_eq(" ", guide_at(2), "previous scope cleared")
    t.assert_eq("╎", guide_at(8), "new origin guide")
  end)
end)

t:test("draw skips lines hidden inside a closed fold", function()
  local lines = { "root" } ---@type string[]
  for index = 2, 201 do
    lines[index] = "  line"
  end
  lines[202] = "tail"

  with_buffer(lines, function()
    with_render_capture(function(render)
      vim.api.nvim_set_option_value("foldmethod", "manual", { win = 0 })
      vim.cmd("2,201fold")
      vim.api.nvim_win_set_cursor(0, { 2, 2 })
      vim.cmd("normal! zc")
      local scope = Indentscope.get_scope(nil, nil, { try_as_border = false })
      Indentscope.draw(scope, { interval = 0 })

      local rows = render(nil)
      t.assert_eq(1, #rows, "fold guide count")
      t.assert_eq(1, rows[1], "fold start row")
    end)
  end)
end)

t:test("draw refreshes when a fold opens or closes", function()
  local lines = { "root" } ---@type string[]
  for index = 2, 101 do
    lines[index] = "  line"
  end
  lines[102] = "tail"

  with_buffer(lines, function()
    with_render_capture(function(render)
      vim.api.nvim_set_option_value("foldmethod", "manual", { win = 0 })
      vim.cmd("2,101fold")
      vim.api.nvim_win_set_cursor(0, { 2, 2 })
      vim.cmd("normal! zc")
      local scope = Indentscope.get_scope(nil, nil, { try_as_border = false })
      Indentscope.draw(scope, { interval = 0 })

      local function guide_count()
        return #render(nil)
      end

      t.assert_eq(1, guide_count(), "closed fold")
      vim.cmd("normal! zo")
      vim.cmd("redraw")
      t.wait_until(function()
        return guide_count() > 1
      end, 100, "opened fold redraw")

      vim.cmd("normal! zc")
      vim.cmd("redraw")
      t.wait_until(function()
        return guide_count() == 1
      end, 100, "closed fold redraw")
    end)
  end)
end)

t:test("draw suppresses a scope spanning the whole indented buffer", function()
  with_buffer({ "  one()", "  two()", "  three()" }, function()
    with_render_capture(function(render)
      vim.api.nvim_win_set_cursor(0, { 2, 2 })
      local scope = Indentscope.get_scope(nil, nil, { try_as_border = false })
      Indentscope.draw(scope, { interval = 0 })

      t.assert_eq(-1, scope.border.indent, "imaginary border indent")
      t.assert_eq(0, #render(nil), "guide count")
    end)
  end)
end)

t:test("animated draw completes within the configured frame budget", function()
  with_buffer({ "if ok then", "  one()", "  two()", "  three()", "end" }, function()
    with_render_capture(function(render)
      vim.api.nvim_win_set_cursor(0, { 3, 2 })
      local scope = Indentscope.get_scope(nil, nil, { try_as_border = false })
      Indentscope.draw(scope, { interval = 5, max_duration = 20 })

      t.wait_until(function()
        return #render(nil) == 3
      end, 100, "animation completion")
    end)
  end)
end)

t:test("real timer preserves an intermediate animation frame", function()
  with_buffer({ "if ok then", "  one", "  two", "  three", "  four", "  five", "  six", "  seven", "end" }, function()
    vim.api.nvim_win_set_cursor(0, { 5, 2 })
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    local position = vim.api.nvim_win_get_position(winnr) ---@type integer[]
    local info = vim.fn.getwininfo(winnr)[1] ---@type table

    local function guide_count()
      local count = 0 ---@type integer
      for lnum = 2, 8 do
        local row = position[1] + lnum ---@type integer
        local col = position[2] + info.textoff + 1 ---@type integer
        if vim.fn.screenstring(row, col) == "╎" then
          count = count + 1
        end
      end
      return count
    end

    local scope = Indentscope.get_scope(nil, nil, { try_as_border = false })
    Indentscope.draw(scope, { interval = 100, max_duration = 600 })
    t.assert_eq(1, guide_count(), "origin frame")

    vim.wait(120)
    t.assert_eq(3, guide_count(), "intermediate frame")
    t.wait_until(function()
      return guide_count() == 7
    end, 600, "animation completion")
  end)
end)

t:test("animation reveals one scope layer per frame", function()
  with_buffer({ "if ok then", "  one", "  two", "  three", "  four", "  five", "  six", "  seven", "end" }, function()
    local timers = {} ---@type table[]
    t:patch_table(vim, "schedule_wrap", function(callback)
      return callback
    end)
    t:patch_table(vim.uv, "new_timer", function()
      local timer = { closing = false } ---@type table
      function timer:start(_, _, callback)
        self.callback = callback
      end
      function timer:stop() end
      function timer:close()
        self.closing = true
      end
      function timer:is_closing()
        return self.closing
      end
      timers[#timers + 1] = timer
      return timer
    end)

    with_render_capture(function(render)
      vim.api.nvim_win_set_cursor(0, { 5, 2 })
      local scope = Indentscope.get_scope(nil, nil, { try_as_border = false })

      Indentscope.draw(scope, { interval = 20, max_duration = 300 })
      t.assert_eq(1, #render(nil), "origin frame")
      timers[1].callback()
      t.assert_eq(3, #render(nil), "first frame")
      timers[1].callback()
      t.assert_eq(5, #render(nil), "second frame")
      timers[1].callback()
      t.assert_eq(7, #render(nil), "final frame")
    end)
  end)
end)

t:test("animation limits each frame to new line ranges", function()
  with_buffer({ "if ok then", "  one", "  two", "  three", "  four", "  five", "  six", "  seven", "end" }, function()
    local timers = {} ---@type table[]
    local redraws = {} ---@type table[]
    t:patch_table(vim, "schedule_wrap", function(callback)
      return callback
    end)
    t:patch_table(vim.uv, "new_timer", function()
      local timer = { closing = false } ---@type table
      function timer:start(_, _, callback)
        self.callback = callback
      end
      function timer:stop() end
      function timer:close()
        self.closing = true
      end
      function timer:is_closing()
        return self.closing
      end
      timers[#timers + 1] = timer
      return timer
    end)
    t:patch_table(vim.api, "nvim__redraw", function(options)
      redraws[#redraws + 1] = options
    end)

    vim.api.nvim_win_set_cursor(0, { 5, 2 })
    local scope = Indentscope.get_scope(nil, nil, { try_as_border = false })
    Indentscope.draw(scope, { interval = 20, max_duration = 300 })

    t.assert_eq(1, #redraws, "origin redraw count")
    t.assert_true(redraws[1].range ~= nil, "origin redraw range")

    redraws = {}
    timers[1].callback()
    t.assert_eq(2, #redraws, "frame redraw count")
    t.assert_eq(1, redraws[1].range[2] - redraws[1].range[1], "upper range size")
    t.assert_eq(1, redraws[2].range[2] - redraws[2].range[1], "lower range size")
    t.assert_false(redraws[1].flush, "upper range flush")
    t.assert_true(redraws[2].flush, "lower range flush")
  end)
end)

t:test("stale animation callback does not clear the current timer", function()
  with_buffer({ "if ok then", "  one()", "  two()", "end" }, function()
    local queued = {} ---@type fun()[]
    local timers = {} ---@type table[]

    t:patch_table(vim, "schedule_wrap", function(callback)
      return function(...)
        local args = { ... }
        queued[#queued + 1] = function()
          callback(unpack(args))
        end
      end
    end)
    t:patch_table(vim.uv, "new_timer", function()
      local timer = { closing = false } ---@type table
      function timer:start(_, _, callback)
        self.callback = callback
      end
      function timer:stop() end
      function timer:close()
        self.closing = true
      end
      function timer:is_closing()
        return self.closing
      end
      timers[#timers + 1] = timer
      return timer
    end)

    vim.api.nvim_win_set_cursor(0, { 2, 2 })
    local first_scope = Indentscope.get_scope(nil, nil, { try_as_border = false })
    Indentscope.draw(first_scope, { interval = 10, max_duration = 100 })
    timers[1].callback()

    vim.api.nvim_win_set_cursor(0, { 3, 2 })
    local second_scope = Indentscope.get_scope(nil, nil, { try_as_border = false })
    Indentscope.draw(second_scope, { interval = 10, max_duration = 100 })
    queued[1]()

    t.assert_false(timers[2].closing, "current timer")
  end)
end)

t:test("waiting refresh restarts delay with the latest reference", function()
  with_buffer({ "if ok then", "  one()", "  two()", "end" }, function()
    local deferred = {} ---@type { callback: fun(), timer: table }[]
    local timers = {} ---@type table[]

    local function new_timer()
      local timer = { closing = false } ---@type table
      function timer:start(_, _, callback)
        self.callback = callback
      end
      function timer:stop() end
      function timer:close()
        self.closing = true
      end
      function timer:is_closing()
        return self.closing
      end
      return timer
    end

    t:patch_table(vim, "defer_fn", function(callback)
      local timer = new_timer()
      deferred[#deferred + 1] = { callback = callback, timer = timer }
      return timer
    end)
    t:patch_table(vim.uv, "new_timer", function()
      local timer = new_timer()
      timers[#timers + 1] = timer
      return timer
    end)

    with_render_capture(function(render)
      local Draw = require("era.dressing.indentscope.draw")
      local options = {
        delay = 100,
        interval = 10,
        max_duration = 100,
        priority = 2,
        symbol = "╎",
        highlights = { "Normal" },
      } ---@type era.dressing.indentscope.IDrawOptions

      vim.api.nvim_win_set_cursor(0, { 2, 2 })
      Draw.refresh(Indentscope.get_scope(nil, nil, { try_as_border = false }), options, true)
      vim.api.nvim_win_set_cursor(0, { 3, 2 })
      Draw.refresh(Indentscope.get_scope(nil, nil, { try_as_border = false }), options, true)

      t.assert_eq(2, #deferred, "deferred draws")
      t.assert_true(deferred[1].timer.closing, "first delay timer")
      deferred[2].callback()

      local rows = render(nil)
      t.assert_eq(1, #rows, "initial animation guides")
      t.assert_eq(2, rows[1], "latest reference row")
      t.assert_eq(1, #timers, "animation timers")
    end)
  end)
end)

t:test("eligibility is owned by indentscope", function()
  with_buffer({ "if ok then", "  one()", "end" }, function(bufnr)
    t.assert_true(Indentscope.is_enabled(bufnr), "source buffer")

    for _, filetype in ipairs({ "", stl.filetype.BIGFILE, stl.filetype.BOARD, "diff" }) do
      vim.api.nvim_set_option_value("filetype", filetype, { buf = bufnr })
      t.assert_false(Indentscope.is_enabled(bufnr), filetype == "" and "empty filetype" or filetype)
    end

    vim.api.nvim_set_option_value("filetype", "lua", { buf = bufnr })
    vim.api.nvim_set_option_value("buftype", "prompt", { buf = bufnr })
    t.assert_false(Indentscope.is_enabled(bufnr), "prompt buffer")
  end)
end)

t:test("excluded filetype suppresses drawing", function()
  with_buffer({ "if ok then", "  one()", "end" }, function(bufnr)
    with_render_capture(function(render)
      vim.api.nvim_win_set_cursor(0, { 2, 2 })
      local scope = Indentscope.get_scope(nil, nil, { try_as_border = false })
      vim.api.nvim_set_option_value("filetype", stl.filetype.BOARD, { buf = bufnr })
      Indentscope.draw(scope, { interval = 0 })

      t.assert_eq(0, #render(nil), "guide count")
    end)
  end)
end)

t:test("FileType immediately removes an ineligible scope", function()
  with_buffer({ "if ok then", "  one()", "end" }, function(bufnr)
    with_render_capture(function(render)
      Indentscope.dressing()
      vim.api.nvim_win_set_cursor(0, { 2, 2 })
      local scope = Indentscope.get_scope(nil, nil, { try_as_border = false })
      Indentscope.draw(scope, { interval = 0 })
      t.assert_eq(1, #render(nil), "eligible guide count")

      vim.api.nvim_set_option_value("filetype", stl.filetype.BOARD, { buf = bufnr })
      t.assert_eq(0, #render(nil), "ineligible guide count")
    end)
  end)
end)

t:test("hidden FileType events preserve the active scope", function()
  with_buffer({ "if ok then", "  one()", "end" }, function()
    with_render_capture(function(render)
      Indentscope.dressing()
      vim.api.nvim_win_set_cursor(0, { 2, 2 })
      local scope = Indentscope.get_scope(nil, nil, { try_as_border = false })
      Indentscope.draw(scope, { interval = 0 })
      t.assert_eq(1, #render(nil), "active guide count")

      local hidden_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
      vim.api.nvim_set_option_value("filetype", stl.filetype.BOARD, { buf = hidden_bufnr })
      t.assert_eq(1, #render(nil), "guide count after hidden FileType")
      vim.api.nvim_buf_delete(hidden_bufnr, { force = true })
    end)
  end)
end)

t:test("move_cursor chooses border or body", function()
  with_buffer({ "if ok then", "  one()", "  two()", "end" }, function()
    vim.api.nvim_win_set_cursor(0, { 2, 2 })
    local scope = Indentscope.get_scope(nil, nil, { try_as_border = false })

    Indentscope.move_cursor("bottom", true, scope)
    t.assert_eq(4, vim.api.nvim_win_get_cursor(0)[1], "bottom border")

    Indentscope.move_cursor("top", false, scope)
    t.assert_eq(2, vim.api.nvim_win_get_cursor(0)[1], "top body")
  end)
end)

t:test("inner textobject selects the scope body linewise", function()
  with_buffer({ "if ok then", "  one()", "  two()", "end" }, function()
    vim.api.nvim_win_set_cursor(0, { 2, 2 })
    Indentscope.textobject(false)
    vim.cmd("normal! y")

    t.assert_eq("  one()\n  two()\n", vim.fn.getreg('"'), "yanked scope")
  end)
end)

t:test("excluded CursorMoved skips scope computation", function()
  with_buffer({ "  one()", "  two()" }, function(bufnr)
    local Scope = require("era.dressing.indentscope.scope")
    local calls = 0 ---@type integer
    t:patch_table(Scope, "get", function()
      calls = calls + 1
      error("disabled scope computation")
    end)

    vim.api.nvim_set_option_value("filetype", stl.filetype.BOARD, { buf = bufnr })
    Indentscope.dressing()
    vim.api.nvim_exec_autocmds("CursorMoved", { modeline = false })

    t.assert_eq(0, calls, "scope calls")
  end)
end)

t:test("window and buffer entry refresh the active scope", function()
  with_buffer({ "if ok then", "  one()", "end" }, function()
    local Scope = require("era.dressing.indentscope.scope")
    local original = Scope.get
    local calls = 0 ---@type integer
    t:patch_table(Scope, "get", function(...)
      calls = calls + 1
      return original(...)
    end)

    Indentscope.dressing()
    vim.api.nvim_exec_autocmds("WinEnter", { modeline = false })
    vim.api.nvim_exec_autocmds("BufWinEnter", { modeline = false })

    t.assert_eq(2, calls, "scope calls")
  end)
end)

t:test("WinScrolled updates layout without recomputing scope", function()
  with_buffer({ "if ok then", "  one()", "  two()", "end" }, function()
    vim.api.nvim_win_set_cursor(0, { 2, 2 })
    Indentscope.draw(Indentscope.get_scope(nil, nil, { try_as_border = false }), { interval = 0 })

    local Scope = require("era.dressing.indentscope.scope")
    local calls = 0 ---@type integer
    t:patch_table(Scope, "get", function()
      calls = calls + 1
      error("WinScrolled recomputed scope")
    end)

    Indentscope.dressing()
    vim.api.nvim_exec_autocmds("WinScrolled", { modeline = false })

    t.assert_eq(0, calls, "scope calls")
  end)
end)

t:run()
