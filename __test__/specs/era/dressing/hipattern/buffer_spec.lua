local harness = require("__test__.support.harness")

local t = harness.new()
local Hipattern = require("era.dressing.hipattern")
local Filetype = require("stl.filetype")

Hipattern.dressing()

---@param bufnr                         integer
---@return table[]
local function get_extmarks(bufnr)
  return vim.api.nvim_buf_get_extmarks(bufnr, -1, 0, -1, { details = true })
end

---@param bufnr                         integer
---@param count                         integer
---@return nil
local function wait_for_extmarks(bufnr, count)
  t.wait_until(function()
    return #get_extmarks(bufnr) == count
  end, 1000, string.format("expected %d extmarks", count))
end

---@param lines                         string[]
---@param filetype                      string
---@param callback                      fun(bufnr: integer): nil
---@return nil
local function with_buffer(lines, filetype, callback)
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local previous_bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local bufnr = vim.api.nvim_create_buf(false, false) ---@type integer
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value("filetype", filetype, { buf = bufnr })

  local ok, err = pcall(callback, bufnr)
  if vim.api.nvim_buf_is_valid(previous_bufnr) then
    vim.api.nvim_win_set_buf(winnr, previous_bufnr)
  end
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
  if not ok then
    error(err, 0)
  end
end

t:test("renders keyword and inline color decorations", function()
  with_buffer({ "TODO #ff0000" }, "lua", function(bufnr)
    Hipattern.enable(bufnr)
    wait_for_extmarks(bufnr, 2)

    local keyword = nil ---@type table|nil
    local color = nil ---@type table|nil
    for _, extmark in ipairs(get_extmarks(bufnr)) do
      local details = extmark[4]
      if details.hl_group == "f_hipattern_todo" then
        keyword = extmark
      elseif details.virt_text ~= nil then
        color = extmark
      end
    end
    t.assert_true(keyword ~= nil, "keyword extmark")
    t.assert_eq(4, keyword and keyword[4].end_col, "keyword end")
    t.assert_true(color ~= nil, "color extmark")
    t.assert_eq("EraHipatternColor_ff0000", color and color[4].virt_text[1][2], "color group")
  end)
end)

t:test("replaces repeated same-line updates without stale extmarks", function()
  with_buffer({ "TODO" }, "lua", function(bufnr)
    Hipattern.enable(bufnr)
    wait_for_extmarks(bufnr, 1)

    vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { "DONE" })
    t.wait_until(function()
      local extmarks = get_extmarks(bufnr)
      return #extmarks == 1 and extmarks[1][4].hl_group == "f_hipattern_success"
    end, 1000, "success highlight")

    vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { "plain" })
    wait_for_extmarks(bufnr, 0)
  end)
end)

t:test("keeps extmarks aligned across line insertion and deletion", function()
  with_buffer({ "TODO", "plain", "ERROR" }, "lua", function(bufnr)
    Hipattern.enable(bufnr)
    wait_for_extmarks(bufnr, 2)

    vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, { "head" })
    t.wait_until(function()
      local extmarks = get_extmarks(bufnr)
      return #extmarks == 2 and extmarks[1][2] == 1 and extmarks[2][2] == 3
    end, 1000, "inserted line positions")

    vim.api.nvim_buf_set_lines(bufnr, 1, 2, false, {})
    t.wait_until(function()
      local extmarks = get_extmarks(bufnr)
      return #extmarks == 1 and extmarks[1][2] == 2 and extmarks[1][4].hl_group == "f_hipattern_error"
    end, 1000, "deleted line positions")
  end)
end)

t:test("structural edits invalidate pending ranges in current coordinates", function()
  local lines = {} ---@type string[]
  for index = 1, 130 do
    lines[index] = "plain"
  end
  lines[101] = "TODO"

  with_buffer(lines, "lua", function(bufnr)
    Hipattern.enable(bufnr)
    wait_for_extmarks(bufnr, 1)

    vim.api.nvim_buf_set_lines(bufnr, 100, 101, false, { "DONE" })
    local inserted = {} ---@type string[]
    for index = 1, 20 do
      inserted[index] = "head"
    end
    vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, inserted)

    t.wait_until(function()
      local extmarks = get_extmarks(bufnr)
      return #extmarks == 1 and extmarks[1][2] == 120 and extmarks[1][4].hl_group == "f_hipattern_success"
    end, 1000, "shifted pending range")
  end)
end)

t:test("disjoint edits preserve extmarks between dirty ranges", function()
  local lines = {} ---@type string[]
  for index = 1, 100 do
    lines[index] = "plain"
  end
  lines[50] = "NOTE"

  with_buffer(lines, "lua", function(bufnr)
    Hipattern.enable(bufnr)
    wait_for_extmarks(bufnr, 1)
    local middle_id = get_extmarks(bufnr)[1][1] ---@type integer

    vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { "TODO" })
    vim.api.nvim_buf_set_lines(bufnr, 99, 100, false, { "ERROR" })
    wait_for_extmarks(bufnr, 3)

    local preserved = false ---@type boolean
    for _, extmark in ipairs(get_extmarks(bufnr)) do
      if extmark[1] == middle_id and extmark[2] == 49 and extmark[4].hl_group == "f_hipattern_info" then
        preserved = true
      end
    end
    t.assert_true(preserved, "middle extmark identity")
  end)
end)

t:test("tail deletion clears sentinel extmarks", function()
  with_buffer({ "plain", "TODO", "ERROR" }, "lua", function(bufnr)
    Hipattern.enable(bufnr)
    wait_for_extmarks(bufnr, 2)

    vim.api.nvim_buf_set_lines(bufnr, 1, 3, false, {})
    wait_for_extmarks(bufnr, 0)
  end)
end)

t:test("uses the target buffer filetype during background updates", function()
  with_buffer({ "rgb(255, 0, 0)" }, "css", function(bufnr)
    vim.api.nvim_set_option_value("filetype", "lua", { buf = 0 })
    Hipattern.enable(bufnr)
    wait_for_extmarks(bufnr, 1)
    t.assert_eq("EraHipatternColor_ff0000", get_extmarks(bufnr)[1][4].virt_text[1][2], "background color")
  end)
end)

t:test("toggle clears and restores buffer decorations", function()
  with_buffer({ "TODO" }, "lua", function(bufnr)
    Hipattern.enable(bufnr)
    wait_for_extmarks(bufnr, 1)
    t.assert_true(Hipattern.is_enabled(bufnr), "enabled")

    Hipattern.toggle(bufnr)
    t.assert_false(Hipattern.is_enabled(bufnr), "disabled")
    t.assert_eq(0, #get_extmarks(bufnr), "cleared")

    Hipattern.toggle(bufnr)
    t.assert_true(Hipattern.is_enabled(bufnr), "re-enabled")
    wait_for_extmarks(bufnr, 1)
  end)
end)

t:test("eligibility is owned by hipattern", function()
  with_buffer({ "TODO" }, "lua", function(bufnr)
    Hipattern.enable(bufnr)
    wait_for_extmarks(bufnr, 1)

    for _, value in ipairs({ "", Filetype.BIGFILE, Filetype.BOARD, "diff", "excalidraw", "git-credentials" }) do
      vim.api.nvim_set_option_value("filetype", value, { buf = bufnr })
      Hipattern.enable(bufnr)
      t.assert_false(Hipattern.is_enabled(bufnr), value == "" and "empty filetype" or value)
      t.assert_eq(0, #get_extmarks(bufnr), "disabled decorations")
    end

    vim.api.nvim_set_option_value("filetype", "unknown-filetype", { buf = bufnr })
    Hipattern.enable(bufnr)
    t.assert_true(Hipattern.is_enabled(bufnr), "unknown filetype")
    wait_for_extmarks(bufnr, 1)

    vim.api.nvim_set_option_value("buftype", "prompt", { buf = bufnr })
    Hipattern.enable(bufnr)
    t.assert_false(Hipattern.is_enabled(bufnr), "prompt buffer")
    t.assert_eq(0, #get_extmarks(bufnr), "prompt decorations")
  end)
end)

t:test("filetype changes reconcile eligibility", function()
  with_buffer({ "TODO" }, "lua", function(bufnr)
    Hipattern.enable(bufnr)
    wait_for_extmarks(bufnr, 1)

    vim.api.nvim_set_option_value("filetype", "board", { buf = bufnr })
    t.assert_false(Hipattern.is_enabled(bufnr), "disabled after filetype change")
    t.assert_eq(0, #get_extmarks(bufnr), "cleared after filetype change")

    vim.api.nvim_set_option_value("filetype", "lua", { buf = bufnr })
    t.assert_true(Hipattern.is_enabled(bufnr), "enabled after filetype change")
    wait_for_extmarks(bufnr, 1)
  end)
end)

t:test("eligible nofile buffers are enabled by filetype", function()
  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "TODO", "---Title---" })
  vim.api.nvim_set_option_value("filetype", "notepad", { buf = bufnr })

  local ok, err = pcall(function()
    t.assert_true(Hipattern.is_enabled(bufnr), "notepad enabled")
    wait_for_extmarks(bufnr, 2)
  end)
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
  if not ok then
    error(err, 0)
  end
end)

t:test("colorscheme restores generated color groups", function()
  with_buffer({ "#ff0000" }, "lua", function(bufnr)
    Hipattern.enable(bufnr)
    wait_for_extmarks(bufnr, 1)

    vim.api.nvim_set_hl(0, "EraHipatternColor_ff0000", {})
    t.assert_eq(nil, vim.api.nvim_get_hl(0, { name = "EraHipatternColor_ff0000" }).fg, "cleared color")
    vim.api.nvim_exec_autocmds("ColorScheme", { modeline = false })
    t.assert_true(vim.api.nvim_get_hl(0, { name = "EraHipatternColor_ff0000" }).fg ~= nil, "restored color")
  end)
end)

---@param lines                         string[]
---@return integer bufnr
---@return integer winnr
local function show_lines(lines)
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local previous_bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local bufnr = vim.api.nvim_create_buf(false, false) ---@type integer
  t:defer(function()
    if vim.api.nvim_buf_is_valid(previous_bufnr) then
      vim.api.nvim_win_set_buf(winnr, previous_bufnr)
    end
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_win_set_buf(winnr, bufnr)
  return bufnr, winnr
end

-- Queues steps instead of running them and makes every clock read exceed the step budget, so a step
-- renders the screen and exactly one chunk; setting the filetype then starts the full render.
---@param bufnr                         integer
---@return fun()[] steps
---@return string[] queued_by
local function begin_stepped_render(bufnr)
  local steps = {} ---@type fun()[]
  local queued_by = {} ---@type string[]
  for _, name in ipairs({ "schedule", "defer_fn" }) do
    t:patch_table(vim, name, function(callback)
      steps[#steps + 1] = callback
      queued_by[#queued_by + 1] = name
    end)
  end
  local now = 0 ---@type integer
  t:patch_table(vim.uv, "hrtime", function()
    now = now + 5 * 1000000
    return now
  end)
  vim.api.nvim_set_option_value("filetype", "lua", { buf = bufnr })
  t.assert_eq(1, #steps, "first step queued")
  return steps, queued_by
end

---@param bufnr                         integer
---@return table<integer, true>
local function rendered_rows(bufnr)
  local rows = {} ---@type table<integer, true>
  for _, extmark in ipairs(get_extmarks(bufnr)) do
    rows[extmark[2]] = true
  end
  return rows
end

---@param steps                         fun()[]
---@return integer count
local function drain(steps)
  local count = 0 ---@type integer
  while #steps > 0 do
    count = count + 1
    table.remove(steps, 1)()
  end
  return count
end

t:test("a full render draws the visible rows first and finishes the rest in later steps", function()
  local lines = {} ---@type string[]
  for index = 1, 3000 do
    lines[index] = "TODO " .. index
  end
  local bufnr, winnr = show_lines(lines)
  vim.api.nvim_win_set_cursor(winnr, { 2000, 0 })
  vim.cmd("normal! zz")
  local steps, queued_by = begin_stepped_render(bufnr)
  table.remove(steps, 1)()

  local rows = rendered_rows(bufnr)
  local top = vim.fn.line("w0", winnr) - 1 ---@type integer
  local bottom = vim.fn.line("w$", winnr) - 1 ---@type integer
  t.assert_true(rows[top] and rows[bottom], "visible rows render in the first step")
  t.assert_true(rows[0] and rows[255] and not rows[256], "one chunk renders besides the screen")
  t.assert_nil(rows[1000], "other rows wait for later steps")
  -- A scheduled continuation would keep the event queue busy and hold back the screen update.
  t.assert_eq("defer_fn", queued_by[2], "later steps wait for a timer")
  t.assert_true(drain(steps) > 1, "the rest spans several steps")
  t.assert_eq(3000, #get_extmarks(bufnr), "every row renders")
end)

t:test("wide lines shrink a chunk to its byte limit", function()
  local lines = {} ---@type string[]
  for index = 1, 600 do
    lines[index] = "TODO " .. string.rep("x", 1000)
  end
  local bufnr, winnr = show_lines(lines)
  local steps = begin_stepped_render(bufnr)
  table.remove(steps, 1)()

  local rows = rendered_rows(bufnr)
  -- The visible pass covers a screen of rows from the top; the first chunk starts after it.
  local after_screen = vim.fn.getwininfo(winnr)[1].topline - 1 + vim.api.nvim_win_get_height(winnr) ---@type integer
  t.assert_true(rows[after_screen], "a chunk follows the screen")
  t.assert_nil(rows[after_screen + 20], "the chunk stops near 16 KiB instead of 256 rows")
  drain(steps)
  t.assert_eq(600, #get_extmarks(bufnr), "every row renders")
end)

t:test("closed folds keep the first step to a screen of rows", function()
  local lines = {} ---@type string[]
  for index = 1, 3000 do
    lines[index] = "TODO " .. index
  end
  local bufnr, winnr = show_lines(lines)
  vim.api.nvim_set_option_value("foldmethod", "manual", { win = winnr })
  vim.cmd("2,2990fold")
  local steps = begin_stepped_render(bufnr)
  table.remove(steps, 1)()

  local rows = rendered_rows(bufnr)
  t.assert_true(rows[0], "the first screen renders")
  t.assert_nil(rows[1000], "folded rows wait for later steps")
  drain(steps)
  t.assert_eq(3000, #get_extmarks(bufnr), "every row renders")
end)

t:test("an update past the end of the buffer drops the missing rows", function()
  local bufnr = show_lines({ "TODO 1", "TODO 2" })
  vim.api.nvim_set_option_value("filetype", "lua", { buf = bufnr })
  wait_for_extmarks(bufnr, 2)

  local render = require("era.dressing.hipattern.render")
  local update = render.update
  local calls = 0 ---@type integer
  t:patch_table(render, "update", function(...)
    calls = calls + 1
    return update(...)
  end)
  Hipattern.update(bufnr, 0, 200000)
  t.wait_until(function()
    return calls > 0
  end, 1000, "rendered")
  vim.wait(50)
  t.assert_true(calls <= 2, "rendered once instead of row by row, got " .. calls)
  t.assert_eq(2, #get_extmarks(bufnr), "existing rows still render")
end)

t:test("an update before the first row starts at the first row", function()
  with_buffer({ "TODO", "TODO" }, "lua", function(bufnr)
    Hipattern.enable(bufnr)
    wait_for_extmarks(bufnr, 2)

    Hipattern.update(bufnr, -5, 1)
    vim.api.nvim_buf_set_lines(bufnr, 1, 2, false, { "DONE" })
    t.wait_until(function()
      local extmarks = get_extmarks(bufnr)
      return #extmarks == 2 and extmarks[2][4].hl_group == "f_hipattern_success"
    end, 1000, "later edits still render")
  end)
end)

t:run()
