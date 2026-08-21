---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/era/m/git/hunk_nav.lua

local harness = require("__test__.harness")

local hunk_nav = assert(loadfile("lua/era/m/git/hunk_nav.lua"))()

local t = harness.new("era.m.git.hunk_nav")

t:test("navigation persists until the source window changes buffer or is cleared", function()
  local winnr = vim.api.nvim_get_current_win()
  local bufnr_previous = vim.api.nvim_win_get_buf(winnr)
  local bufnr = vim.api.nvim_create_buf(false, true)
  local dirty_calls = {} ---@type { winnr: integer, force: boolean }[]
  local deleted_autocmds = 0
  local nvim_del_autocmd = vim.api.nvim_del_autocmd

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "one", "two", "three", "four" })
  vim.api.nvim_win_set_buf(winnr, bufnr)
  vim.api.nvim_win_set_cursor(winnr, { 1, 0 })

  t:patch_global("era", {
    m = {
      git = {
        buffer = {
          is_attached = function()
            return true
          end,
          get_unstaged_hunks = function()
            return {
              { added = { start = 2 }, vend = 2 },
              { added = { start = 4 }, vend = 4 },
            }
          end,
        },
      },
    },
  })
  t:patch_global("dot", {
    state = {
      status = {
        dirty_winline_nr = {
          next = function(_, dirty_winnr, opts)
            dirty_calls[#dirty_calls + 1] = { winnr = dirty_winnr, force = opts ~= nil and opts.force == true }
          end,
        },
      },
    },
  })
  t:patch_table(vim.api, "nvim_del_autocmd", function(autocmd_id)
    deleted_autocmds = deleted_autocmds + 1
    return nvim_del_autocmd(autocmd_id)
  end)
  hunk_nav.nav("next")

  local index, total = hunk_nav.get_nav_indicator(winnr)
  t.assert_eq(1, index, "current hunk")
  t.assert_eq(2, total, "total hunks")
  t.assert_eq(2, vim.api.nvim_win_get_cursor(winnr)[1], "target line")
  t.assert_eq(winnr, dirty_calls[#dirty_calls].winnr, "dirty window")
  t.assert_true(dirty_calls[#dirty_calls].force, "force redraw for repeated window")

  vim.api.nvim_win_set_cursor(winnr, { 3, 0 })
  index, total = hunk_nav.get_nav_indicator(winnr)
  t.assert_eq(1, index, "cursor movement preserves the indicator")
  t.assert_eq(2, total, "cursor movement preserves the total")

  local other_bufnr = vim.api.nvim_create_buf(false, true)
  vim.cmd("vsplit")
  local other_winnr = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(other_winnr, other_bufnr)
  vim.api.nvim_set_current_win(winnr)
  vim.api.nvim_set_current_win(other_winnr)
  index, total = hunk_nav.get_nav_indicator(winnr)
  t.assert_eq(1, index, "window focus preserves the indicator")
  t.assert_eq(2, total, "window focus preserves the total")
  vim.api.nvim_win_close(other_winnr, true)
  t.assert_eq(0, deleted_autocmds, "peer window close preserves the indicator")
  index, total = hunk_nav.get_nav_indicator(winnr)
  t.assert_eq(1, index, "peer window close preserves the index")
  t.assert_eq(2, total, "peer window close preserves the total")

  vim.api.nvim_set_current_win(winnr)
  vim.cmd("vsplit")
  other_winnr = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(other_winnr, other_bufnr)
  vim.api.nvim_set_current_win(winnr)

  vim.api.nvim_win_set_buf(winnr, other_bufnr)
  t.assert_nil(hunk_nav.get_nav_indicator(winnr), "source buffer switch clears the indicator")
  t.assert_eq(1, deleted_autocmds, "source buffer switch clears the lifecycle autocmd")

  vim.api.nvim_win_set_buf(winnr, bufnr)
  t.assert_nil(hunk_nav.get_nav_indicator(winnr), "indicator does not return after restoring its buffer")
  hunk_nav.nav("next")
  hunk_nav.clear_nav()
  t.assert_nil(hunk_nav.get_nav_indicator(winnr), "cleared indicator")
  t.assert_eq(2, deleted_autocmds, "explicit clear removes the lifecycle autocmd")

  hunk_nav.nav("next")
  vim.api.nvim_win_set_buf(other_winnr, bufnr_previous)
  vim.api.nvim_win_close(winnr, true)
  t.assert_eq(3, deleted_autocmds, "source window close removes the lifecycle autocmd")

  vim.api.nvim_buf_delete(bufnr, { force = true })
  vim.api.nvim_buf_delete(other_bufnr, { force = true })
end)

t:test("diff navigation publishes native hunk position", function()
  local left_winnr = vim.api.nvim_get_current_win()
  local left_bufnr_previous = vim.api.nvim_win_get_buf(left_winnr)
  local left_bufnr = vim.api.nvim_create_buf(false, true)
  local right_bufnr = vim.api.nvim_create_buf(false, true)
  local dirty_winnr = nil ---@type integer|nil

  vim.api.nvim_buf_set_lines(left_bufnr, 0, -1, false, { "a", "b", "c", "d", "e" })
  vim.api.nvim_buf_set_lines(right_bufnr, 0, -1, false, { "A", "b", "c", "D", "e", "f" })
  vim.api.nvim_win_set_buf(left_winnr, left_bufnr)
  vim.cmd("vsplit")
  local right_winnr = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(right_winnr, right_bufnr)
  vim.cmd("diffthis")
  vim.api.nvim_set_option_value("cursorbind", true, { win = right_winnr, scope = "local" })
  vim.api.nvim_set_current_win(left_winnr)
  vim.cmd("diffthis")
  vim.api.nvim_set_option_value("cursorbind", true, { win = left_winnr, scope = "local" })
  vim.cmd("diffupdate")
  vim.api.nvim_win_set_cursor(left_winnr, { 1, 0 })
  vim.api.nvim_win_set_cursor(right_winnr, { 1, 0 })
  vim.api.nvim_set_current_win(left_winnr)

  t:patch_global("dot", {
    state = {
      status = {
        dirty_winline_nr = {
          next = function(_, winnr)
            dirty_winnr = winnr
          end,
        },
      },
    },
  })

  vim.cmd("clearjumps")

  hunk_nav.nav_diff("next")

  local index, total = hunk_nav.get_nav_indicator(left_winnr)
  t.assert_eq(2, index, "current diff hunk")
  t.assert_eq(3, total, "total diff hunks")
  t.assert_eq(4, vim.api.nvim_win_get_cursor(left_winnr)[1], "native diff target")
  t.assert_eq(4, vim.api.nvim_win_get_cursor(right_winnr)[1], "paired cursor remains at native target")
  t.assert_eq(left_winnr, dirty_winnr, "dirty diff window")
  local jumps = vim.fn.getjumplist()[1] ---@type table[]
  t.assert_eq(1, #jumps, "one native jump entry")
  t.assert_eq(left_bufnr, jumps[1].bufnr, "native jump buffer")
  t.assert_eq(1, jumps[1].lnum, "native jump origin")

  hunk_nav.clear_nav()
  vim.api.nvim_set_option_value("diff", false, { win = left_winnr, scope = "local" })
  vim.api.nvim_set_option_value("diff", false, { win = right_winnr, scope = "local" })
  vim.api.nvim_win_close(right_winnr, true)
  vim.api.nvim_win_set_buf(left_winnr, left_bufnr_previous)
  vim.api.nvim_buf_delete(left_bufnr, { force = true })
  vim.api.nvim_buf_delete(right_bufnr, { force = true })
end)

t:test("diff navigation preserves empty document byte semantics", function()
  local left_winnr = vim.api.nvim_get_current_win()
  local left_bufnr_previous = vim.api.nvim_win_get_buf(left_winnr)
  local left_bufnr = vim.api.nvim_create_buf(false, true)
  local newline_path = vim.fn.tempname()
  local empty_path = vim.fn.tempname()

  t.assert_eq(0, vim.fn.writefile({ "" }, newline_path), "single-newline fixture")
  t.assert_eq(0, vim.fn.writefile({}, empty_path, "b"), "empty fixture")

  local newline_bufnr = vim.fn.bufadd(newline_path) ---@type integer
  local empty_bufnr = vim.fn.bufadd(empty_path) ---@type integer
  vim.fn.bufload(newline_bufnr)
  vim.fn.bufload(empty_bufnr)
  vim.api.nvim_set_option_value("endofline", false, { buf = left_bufnr })
  t.assert_eq(
    1,
    vim.api.nvim_buf_call(newline_bufnr, function()
      return vim.fn.wordcount().bytes
    end),
    "single-newline bytes"
  )
  t.assert_eq(
    0,
    vim.api.nvim_buf_call(empty_bufnr, function()
      return vim.fn.wordcount().bytes
    end),
    "empty bytes"
  )

  vim.api.nvim_win_set_buf(left_winnr, left_bufnr)
  vim.cmd("vsplit")
  local right_winnr = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(right_winnr, newline_bufnr)
  vim.cmd("diffthis")
  vim.api.nvim_set_option_value("cursorbind", true, { win = right_winnr, scope = "local" })
  vim.api.nvim_set_current_win(left_winnr)
  vim.cmd("diffthis")
  vim.api.nvim_set_option_value("cursorbind", true, { win = left_winnr, scope = "local" })

  t:patch_global("dot", {
    state = {
      status = {
        dirty_winline_nr = {
          next = function() end,
        },
      },
    },
  })

  vim.cmd("diffupdate")
  vim.api.nvim_win_set_cursor(left_winnr, { 1, 0 })
  vim.api.nvim_win_set_cursor(right_winnr, { 1, 0 })
  vim.api.nvim_set_current_win(left_winnr)
  hunk_nav.nav_diff("next")

  local index, total = hunk_nav.get_nav_indicator(left_winnr)
  t.assert_eq(1, index, "single-newline hunk")
  t.assert_eq(1, total, "single-newline total")

  hunk_nav.clear_nav()
  vim.api.nvim_win_set_buf(right_winnr, empty_bufnr)
  vim.api.nvim_set_option_value("diff", true, { win = right_winnr, scope = "local" })
  vim.api.nvim_set_option_value("cursorbind", true, { win = right_winnr, scope = "local" })
  vim.cmd("diffupdate")
  vim.api.nvim_win_set_cursor(left_winnr, { 1, 0 })
  vim.api.nvim_win_set_cursor(right_winnr, { 1, 0 })
  vim.api.nvim_set_current_win(left_winnr)
  hunk_nav.nav_diff("next")
  t.assert_nil(hunk_nav.get_nav_indicator(left_winnr), "empty buffers have no synthetic hunk")

  vim.api.nvim_set_option_value("diff", false, { win = left_winnr, scope = "local" })
  vim.api.nvim_set_option_value("diff", false, { win = right_winnr, scope = "local" })
  vim.api.nvim_win_close(right_winnr, true)
  vim.api.nvim_win_set_buf(left_winnr, left_bufnr_previous)
  vim.api.nvim_buf_delete(left_bufnr, { force = true })
  vim.api.nvim_buf_delete(newline_bufnr, { force = true })
  vim.api.nvim_buf_delete(empty_bufnr, { force = true })
  vim.fn.delete(newline_path)
  vim.fn.delete(empty_path)
end)

t:test("diff navigation does not publish boundary no-ops", function()
  local left_winnr = vim.api.nvim_get_current_win()
  local left_bufnr_previous = vim.api.nvim_win_get_buf(left_winnr)
  local left_bufnr = vim.api.nvim_create_buf(false, true)
  local right_bufnr = vim.api.nvim_create_buf(false, true)

  vim.api.nvim_buf_set_lines(left_bufnr, 0, -1, false, { "a", "b", "c", "d", "e" })
  vim.api.nvim_buf_set_lines(right_bufnr, 0, -1, false, { "a", "B", "c", "d", "e" })
  vim.api.nvim_win_set_buf(left_winnr, left_bufnr)
  vim.cmd("vsplit")
  local right_winnr = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(right_winnr, right_bufnr)
  vim.cmd("diffthis")
  vim.api.nvim_set_current_win(left_winnr)
  vim.cmd("diffthis")
  vim.cmd("diffupdate")

  t:patch_global("dot", {
    state = {
      status = {
        dirty_winline_nr = {
          next = function() end,
        },
      },
    },
  })

  for _, cursorbind in ipairs({ false, true }) do
    vim.api.nvim_set_option_value("cursorbind", cursorbind, { win = left_winnr, scope = "local" })
    vim.api.nvim_set_option_value("cursorbind", cursorbind, { win = right_winnr, scope = "local" })
    for _, case in ipairs({
      { direction = "next", lnum = 5 },
      { direction = "prev", lnum = 1 },
    }) do
      hunk_nav.clear_nav()
      vim.api.nvim_win_set_cursor(left_winnr, { case.lnum, 0 })
      vim.api.nvim_win_set_cursor(right_winnr, { case.lnum, 0 })
      vim.api.nvim_set_current_win(left_winnr)
      hunk_nav.nav_diff(case.direction)
      t.assert_nil(
        hunk_nav.get_nav_indicator(left_winnr),
        string.format("%s boundary no-op (cursorbind=%s)", case.direction, cursorbind)
      )
    end
  end

  vim.api.nvim_set_option_value("diff", false, { win = left_winnr, scope = "local" })
  vim.api.nvim_set_option_value("diff", false, { win = right_winnr, scope = "local" })
  vim.api.nvim_win_close(right_winnr, true)
  vim.api.nvim_win_set_buf(left_winnr, left_bufnr_previous)
  vim.api.nvim_buf_delete(left_bufnr, { force = true })
  vim.api.nvim_buf_delete(right_bufnr, { force = true })
end)

t:test("diff navigation counts a one-line EOF filler in both directions", function()
  local left_winnr = vim.api.nvim_get_current_win()
  local left_bufnr_previous = vim.api.nvim_win_get_buf(left_winnr)
  local left_bufnr = vim.api.nvim_create_buf(false, true)
  local right_bufnr = vim.api.nvim_create_buf(false, true)

  vim.api.nvim_buf_set_lines(left_bufnr, 0, -1, false, { "a" })
  vim.api.nvim_buf_set_lines(right_bufnr, 0, -1, false, { "a", "b" })
  vim.api.nvim_win_set_buf(left_winnr, left_bufnr)
  vim.cmd("vsplit")
  local right_winnr = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(right_winnr, right_bufnr)
  vim.cmd("diffthis")
  vim.api.nvim_set_option_value("cursorbind", true, { win = right_winnr, scope = "local" })
  vim.api.nvim_set_current_win(left_winnr)
  vim.cmd("diffthis")
  vim.api.nvim_set_option_value("cursorbind", true, { win = left_winnr, scope = "local" })
  vim.cmd("diffupdate")

  t:patch_global("dot", {
    state = {
      status = {
        dirty_winline_nr = {
          next = function() end,
        },
      },
    },
  })

  for _, direction in ipairs({ "next", "prev" }) do
    vim.api.nvim_win_set_cursor(left_winnr, { 1, 0 })
    hunk_nav.nav_diff(direction)

    local index, total = hunk_nav.get_nav_indicator(left_winnr)
    t.assert_eq(1, index, direction .. " EOF hunk")
    t.assert_eq(1, total, direction .. " EOF total")

    vim.wait(10, function()
      return false
    end)
    hunk_nav.clear_nav()
  end

  vim.api.nvim_set_option_value("diff", false, { win = left_winnr, scope = "local" })
  vim.api.nvim_set_option_value("diff", false, { win = right_winnr, scope = "local" })
  vim.api.nvim_win_close(right_winnr, true)
  vim.api.nvim_win_set_buf(left_winnr, left_bufnr_previous)
  vim.api.nvim_buf_delete(left_bufnr, { force = true })
  vim.api.nvim_buf_delete(right_bufnr, { force = true })
end)

t:test("diff navigation shares and caches canonical Git hunks across panes", function()
  local left_winnr = vim.api.nvim_get_current_win()
  local left_bufnr_previous = vim.api.nvim_win_get_buf(left_winnr)
  local right_bufnr = vim.api.nvim_create_buf(false, true)
  local left_bufnr = vim.api.nvim_create_buf(false, true)
  local text_diff = vim.text.diff
  local diff_calls = 0 ---@type integer
  t.assert_true(right_bufnr < left_bufnr, "right buffer is allocated first")

  vim.api.nvim_win_set_buf(left_winnr, left_bufnr)
  vim.cmd("rightbelow vsplit")
  local right_winnr = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(right_winnr, right_bufnr)
  vim.cmd("diffthis")
  vim.api.nvim_set_current_win(left_winnr)
  vim.cmd("diffthis")

  t:patch_global("dot", {
    state = {
      status = {
        dirty_winline_nr = {
          next = function() end,
        },
      },
    },
  })
  t:patch_table(vim.text, "diff", function(...)
    diff_calls = diff_calls + 1
    return text_diff(...)
  end)

  ---@param left_lines                  string[]
  ---@param right_lines                 string[]
  ---@param label                       string
  ---@param expected_total              integer
  ---@param expected_short_noop         boolean|nil
  local function assert_shared_pair(left_lines, right_lines, label, expected_total, expected_short_noop)
    expected_short_noop = expected_short_noop ~= false
    vim.api.nvim_buf_set_lines(left_bufnr, 0, -1, false, left_lines)
    vim.api.nvim_buf_set_lines(right_bufnr, 0, -1, false, right_lines)
    vim.api.nvim_set_current_win(left_winnr)
    vim.cmd("diffupdate")
    vim.api.nvim_win_set_cursor(left_winnr, { 1, 0 })
    vim.api.nvim_win_set_cursor(right_winnr, { 1, 0 })

    hunk_nav.nav_diff("next")
    local index, total = hunk_nav.get_nav_indicator(left_winnr)
    t.assert_eq(1, index, label .. " short first")
    t.assert_eq(expected_total, total, label .. " short total")

    hunk_nav.clear_nav()
    local first_lnum = vim.api.nvim_win_get_cursor(left_winnr)[1] ---@type integer
    hunk_nav.nav_diff("next")
    index, total = hunk_nav.get_nav_indicator(left_winnr)
    t.assert_eq(first_lnum, vim.api.nvim_win_get_cursor(left_winnr)[1], label .. " short native no-op")
    if expected_short_noop then
      t.assert_eq(1, index, label .. " short no-op index")
      t.assert_eq(expected_total, total, label .. " short no-op total")
    else
      t.assert_nil(index, label .. " short no-op index")
      t.assert_nil(total, label .. " short no-op total")
    end

    hunk_nav.clear_nav()
    vim.api.nvim_set_current_win(right_winnr)
    vim.api.nvim_win_set_cursor(left_winnr, { 1, 0 })
    vim.api.nvim_win_set_cursor(right_winnr, { 1, 0 })
    hunk_nav.nav_diff("next")
    index, total = hunk_nav.get_nav_indicator(right_winnr)
    t.assert_eq(1, index, label .. " long first")
    t.assert_eq(expected_total, total, label .. " long total")

    hunk_nav.clear_nav()
    hunk_nav.nav_diff("next")
    index, total = hunk_nav.get_nav_indicator(right_winnr)
    t.assert_eq(math.min(2, expected_total), index, label .. " long second")
    t.assert_eq(expected_total, total, label .. " long second total")
    hunk_nav.clear_nav()
  end

  assert_shared_pair({ "a", "b" }, { "a", "X", "b", "Y" }, "separate fillers", 2)
  assert_shared_pair({ "a", "b" }, { "a", "X", "Y" }, "changed EOF", 1)
  assert_shared_pair({ "a" }, { "X", "Y" }, "BOF changed", 1)
  assert_shared_pair({ "a", "b", "c" }, { "a", "X", "Y", "c" }, "internal changed", 1)
  assert_shared_pair({ "a", "b" }, { "b", "a", "c", "b" }, "semantic left-to-right order", 1, false)
  t.assert_eq(5, diff_calls, "one canonical diff per changed pair")

  vim.api.nvim_buf_set_lines(left_bufnr, 0, -1, false, { "b", "a", "d", "b", "c", "c", "a", "b" })
  vim.api.nvim_buf_set_lines(right_bufnr, 0, -1, false, { "d", "b", "a", "b", "d", "d" })
  vim.api.nvim_set_current_win(left_winnr)
  vim.cmd("diffupdate")
  vim.api.nvim_win_set_cursor(left_winnr, { 1, 0 })
  vim.api.nvim_win_set_cursor(right_winnr, { 1, 0 })
  hunk_nav.nav_diff("next")
  local index, total = hunk_nav.get_nav_indicator(left_winnr)
  t.assert_eq(2, index, "left target gap advances monotonically")
  t.assert_eq(3, total, "left target gap total")

  hunk_nav.clear_nav()
  vim.api.nvim_set_current_win(right_winnr)
  vim.api.nvim_win_set_cursor(right_winnr, { 1, 0 })
  hunk_nav.nav_diff("next")
  index, total = hunk_nav.get_nav_indicator(right_winnr)
  t.assert_eq(2, index, "right target gap advances monotonically")
  t.assert_eq(3, total, "right target gap total")

  hunk_nav.clear_nav()
  vim.api.nvim_set_current_win(left_winnr)
  vim.api.nvim_win_set_cursor(left_winnr, { 8, 0 })
  hunk_nav.nav_diff("prev")
  index, total = hunk_nav.get_nav_indicator(left_winnr)
  t.assert_eq(2, index, "left previous target gap")
  t.assert_eq(3, total, "left previous target gap total")

  hunk_nav.clear_nav()
  vim.api.nvim_set_current_win(right_winnr)
  vim.api.nvim_win_set_cursor(right_winnr, { 5, 0 })
  hunk_nav.nav_diff("prev")
  index, total = hunk_nav.get_nav_indicator(right_winnr)
  t.assert_eq(2, index, "right previous target gap")
  t.assert_eq(3, total, "right previous target gap total")
  t.assert_eq(6, diff_calls, "target-gap mapping reuses one canonical diff")
  hunk_nav.clear_nav()

  vim.api.nvim_buf_set_lines(left_bufnr, 0, -1, false, { "a", "b", "a", "c", "d" })
  vim.api.nvim_buf_set_lines(right_bufnr, 0, -1, false, { "d", "d", "c" })
  vim.api.nvim_set_current_win(left_winnr)
  vim.cmd("diffupdate")
  vim.api.nvim_win_set_cursor(left_winnr, { 4, 0 })
  vim.api.nvim_win_set_cursor(right_winnr, { 3, 0 })
  hunk_nav.nav_diff("prev")
  index, total = hunk_nav.get_nav_indicator(left_winnr)
  t.assert_eq(1, index, "left conflicting targets use shared previous index")
  t.assert_eq(2, total, "left conflicting target total")

  hunk_nav.clear_nav()
  vim.api.nvim_set_current_win(right_winnr)
  vim.api.nvim_win_set_cursor(left_winnr, { 4, 0 })
  vim.api.nvim_win_set_cursor(right_winnr, { 3, 0 })
  hunk_nav.nav_diff("prev")
  index, total = hunk_nav.get_nav_indicator(right_winnr)
  t.assert_eq(1, index, "right conflicting targets use shared previous index")
  t.assert_eq(2, total, "right conflicting target total")
  t.assert_eq(7, diff_calls, "conflicting target mapping reuses one canonical diff")
  hunk_nav.clear_nav()

  vim.api.nvim_buf_set_lines(left_bufnr, 0, -1, false, { "a", "a", "a" })
  vim.api.nvim_buf_set_lines(right_bufnr, 0, -1, false, { "b", "a", "b" })
  vim.api.nvim_set_current_win(left_winnr)
  vim.cmd("diffupdate")
  vim.api.nvim_win_set_cursor(left_winnr, { 3, 0 })
  vim.api.nvim_win_set_cursor(right_winnr, { 3, 0 })
  vim.cmd("clearjumps")
  hunk_nav.nav_diff("prev")
  index, total = hunk_nav.get_nav_indicator(left_winnr)
  t.assert_eq(1, index, "left trigger crosses canonical linematch stops")
  t.assert_eq(2, total, "left trigger canonical transition total")
  t.assert_eq(1, #vim.fn.getjumplist()[1], "canonical continuation keeps one user jump")

  hunk_nav.clear_nav()
  vim.api.nvim_set_current_win(right_winnr)
  vim.api.nvim_win_set_cursor(left_winnr, { 3, 0 })
  vim.api.nvim_win_set_cursor(right_winnr, { 3, 0 })
  hunk_nav.nav_diff("prev")
  index, total = hunk_nav.get_nav_indicator(right_winnr)
  t.assert_eq(1, index, "right trigger shares the canonical transition")
  t.assert_eq(2, total, "right trigger canonical transition total")
  t.assert_eq(8, diff_calls, "canonical continuation reuses one diff")
  hunk_nav.clear_nav()

  vim.api.nvim_buf_set_lines(left_bufnr, 0, -1, false, { "a", "a" })
  vim.api.nvim_buf_set_lines(right_bufnr, 0, -1, false, { "b", "a", "b", "a", "b" })
  vim.api.nvim_set_current_win(left_winnr)
  vim.cmd("diffupdate")
  vim.api.nvim_win_set_cursor(left_winnr, { 2, 0 })
  vim.api.nvim_win_set_cursor(right_winnr, { 5, 0 })
  vim.cmd("clearjumps")
  hunk_nav.nav_diff("prev")
  index, total = hunk_nav.get_nav_indicator(left_winnr)
  t.assert_eq(2, index, "left trigger clamps to adjacent shared hunk")
  t.assert_eq(3, total, "left adjacent transition total")
  t.assert_eq(1, #vim.fn.getjumplist()[1], "left adjacent transition keeps one user jump")

  hunk_nav.clear_nav()
  vim.api.nvim_set_current_win(right_winnr)
  vim.api.nvim_win_set_cursor(left_winnr, { 2, 0 })
  vim.api.nvim_win_set_cursor(right_winnr, { 5, 0 })
  vim.cmd("clearjumps")
  hunk_nav.nav_diff("prev")
  index, total = hunk_nav.get_nav_indicator(right_winnr)
  t.assert_eq(2, index, "right trigger shares the adjacent transition")
  t.assert_eq(3, total, "right adjacent transition total")
  t.assert_eq(1, #vim.fn.getjumplist()[1], "right adjacent transition keeps one user jump")
  t.assert_eq(9, diff_calls, "adjacent transition reuses one canonical diff")
  hunk_nav.clear_nav()

  local left_lines = {} ---@type string[]
  local right_lines = {} ---@type string[]
  for i = 1, 2000 do
    left_lines[#left_lines + 1] = "same " .. i
    left_lines[#left_lines + 1] = "left " .. i
    right_lines[#right_lines + 1] = "same " .. i
    right_lines[#right_lines + 1] = "right " .. i
  end
  vim.api.nvim_buf_set_lines(left_bufnr, 0, -1, false, left_lines)
  vim.api.nvim_buf_set_lines(right_bufnr, 0, -1, false, right_lines)
  vim.api.nvim_set_current_win(left_winnr)
  vim.cmd("diffupdate")
  vim.api.nvim_win_set_cursor(left_winnr, { 1, 0 })

  local normal = vim.cmd.normal
  local normal_calls = 0 ---@type integer
  t:patch_table(vim.cmd, "normal", function(...)
    normal_calls = normal_calls + 1
    return normal(...)
  end)

  hunk_nav.nav_diff("next")
  index, total = hunk_nav.get_nav_indicator(left_winnr)
  t.assert_eq(1, index, "large diff first hunk")
  t.assert_eq(2000, total, "large diff total")

  hunk_nav.clear_nav()
  hunk_nav.nav_diff("next")
  index, total = hunk_nav.get_nav_indicator(left_winnr)
  t.assert_eq(2, index, "large diff second hunk")
  t.assert_eq(2000, total, "large diff cached total")
  t.assert_eq(10, diff_calls, "large canonical map is cached")
  t.assert_eq(2, normal_calls, "navigation performs no internal motions")

  hunk_nav.clear_nav()
  vim.api.nvim_buf_set_lines(right_bufnr, 1, 2, false, { "right updated" })
  vim.cmd("diffupdate")
  vim.api.nvim_win_set_cursor(left_winnr, { 1, 0 })
  hunk_nav.nav_diff("next")
  t.assert_eq(11, diff_calls, "peer changedtick invalidates the cache")
  t.assert_eq(4, normal_calls, "cache invalidation uses bounded native continuation")

  hunk_nav.clear_nav()
  vim.api.nvim_set_option_value("diff", false, { win = left_winnr, scope = "local" })
  vim.api.nvim_set_option_value("diff", false, { win = right_winnr, scope = "local" })
  vim.api.nvim_win_close(right_winnr, true)
  vim.api.nvim_win_set_buf(left_winnr, left_bufnr_previous)
  vim.api.nvim_buf_delete(left_bufnr, { force = true })
  vim.api.nvim_buf_delete(right_bufnr, { force = true })
end)

t:test("git winline component renders hunk navigation position", function()
  t:patch_global("stl", {
    icon = {
      git = {
        Git = "G",
      },
    },
    nvim = {
      fn = {
        txt = function(text)
          return text
        end,
      },
    },
  })
  t:patch_global("era", {
    m = {
      git = {
        hunk_nav = {
          get_nav_indicator = function(winnr)
            t.assert_eq(42, winnr, "component window")
            return 2, 10
          end,
        },
      },
    },
  })

  local git_component = assert(loadfile("lua/era/m/nvimbar/component/git.lua"))()
  local component = git_component.hunk_nav("f_wl")

  local context = {
    winnr = 42,
    bufnr = 1,
    cwd = "",
    filename = "",
    filepath = "",
    fileicon = "",
    fileicon_hl = "",
    filetype = "",
    mode = "normal",
    mode_name = "NORMAL",
    git_branch = nil,
  } ---@type era.m.nvimbar.INvimbarContext
  t.assert_true(component.condition(context, 20), "visible with navigation state")
  local text, _, full = component.render(context, 20)
  t.assert_eq("G 2/10", text, "rendered position")
  t.assert_true(full, "atomic result")
end)

t:run()
