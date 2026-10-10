---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.ux.treeview.guide_path" ---@type string

local t = require("__test__.support.harness").new("ux.treeview.guide_path")

t:test("the cursor path colors individual guide columns and keeps Visual's displayed ancestry", function()
  local ui = require("__test__.support.ui").new()
  local grid = require("__test__.support.ui_grid").new(ui)
  t:defer(function()
    ui:close()
  end)
  ui:rpc("nvim_ui_attach", 100, 30, { rgb = true, ext_linegrid = true })
  ui:rpc(
    "nvim_exec_lua",
    [=[
    local root = ...
    vim.opt.runtimepath:prepend(root)
    local extension = vim.uv.os_uname().sysname == "Darwin" and "dylib" or "so"
    yoz = assert(package.loadlib(root .. "/rust/target/debug/libyoz." .. extension, "luaopen_yoz"))()
    errors, writes = {}, 0
    stl = { c = { Future = require("stl.c.future") }, nvim = { fn = require("stl.nvim.fn") },
      reporter = { error = function(options) errors[#errors + 1] = options.message end } }
    ---@param future                    stl.c.Future
    ---@return any
    function await(future)
      assert(vim.wait(10000, function() return future:is_done() end))
      assert(not future:is_failed(), future:get_error())
      local value = future:get_result()
      assert(value.kind ~= "Rejected", vim.inspect(value))
      return value
    end
    local treeview = require("ux.treeview")
    local set_extmark = vim.api.nvim_buf_set_extmark
    guide_marks = {}
    vim.api.nvim_buf_set_extmark = function(bufnr, namespace, row, col, options)
      local chunk = options.virt_text and options.virt_text[1]
      if options.ephemeral and chunk and type(chunk[2]) == "string" and chunk[2]:match("^TreeviewGuide") then
        guide_marks[row] = (guide_marks[row] or 0) + 1
      end
      return set_extmark(bufnr, namespace, row, col, options)
    end
    data = treeview.new_data()
    local records = {
      { key = "root", label = "root", can_expand = true },
      { key = "src", parent = "root", label = "src", can_expand = true },
      { key = "lib", parent = "src", label = "lib", can_expand = true },
      { key = "helper", parent = "lib", label = "helper", can_expand = true },
      { key = "nested", parent = "helper", label = "nested" },
      { key = "target", parent = "lib", label = "target" },
      { key = "other", parent = "src", label = "other" },
      { key = "docs", parent = "root", label = "docs" },
    }
    for index = 1, 100 do
      records[#records + 1] = { key = "n" .. index, parent = "root", label = string.format("row-%03d", index) }
    end
    await(data:import(records))
    state = await(data:create_state({ kind = "children_of", node = data:source():id("root") }))
    await(state:set_expanded({ data:source():id("root") }, true, true))
    view = treeview.attach(state, { keymaps = false })
    assert(vim.wait(10000, function() return view:frame() ~= nil and not view._busy end))
    vim.api.nvim_set_option_value("cursorline", true, { win = view.winnr })
    vim.api.nvim_set_hl(0, "Normal", { fg = "#eeeeee", bg = "#111111" })
    vim.api.nvim_set_hl(0, "CursorLine", { bg = "#222222" })
    vim.api.nvim_set_hl(0, "Visual", { bg = "#333355" })
    vim.api.nvim_set_hl(0, "TreeviewGuide", { fg = "#444444" })
    vim.api.nvim_set_hl(0, "TreeviewGuideActive", { fg = "#777777" })
    vim.api.nvim_set_hl(0, "TreeviewGuidePath", { fg = "#ff69b4" })
    local set_lines = vim.api.nvim_buf_set_lines
    vim.api.nvim_buf_set_lines = function(bufnr, ...)
      if bufnr == view.bufnr then writes = writes + 1 end
      return set_lines(bufnr, ...)
    end
    ---@param row                       integer
    ---@return nil
    function move(row)
      await(view:set_cursor(row))
      assert(vim.wait(10000, function()
        return view:frame():header().cursor_row == row and not view._busy and not view._latest
      end))
    end
    move(5)
  ]=],
    { assert(vim.uv.cwd()) }
  )

  ---@param code                        string
  ---@return any
  local function eval(code)
    return ui:rpc("nvim_exec_lua", code, {})
  end

  local normal, active, pink = 0x444444, 0x777777, 0xff69b4

  ---@param label                       string
  ---@param depth                       integer
  ---@param column                      integer
  ---@param glyph                       string
  ---@param foreground                  integer
  ---@return nil
  local function cell(label, depth, column, glyph, foreground)
    local location = grid:find(label)
    if not location then
      local screen = {}
      for _, cells in ipairs(grid.grids[1].rows) do
        local text = {}
        for _, value in ipairs(cells) do
          text[#text + 1] = value[1]
        end
        screen[#screen + 1] = table.concat(text)
      end
      error("missing " .. label .. ": " .. vim.inspect(eval("return errors")) .. "\n" .. table.concat(screen, "\n"))
    end
    local start = location.col - (depth + 1) * 2 - 2
    local value = grid.grids[location.grid].rows[location.row + 1][start + column + 1]
    t.assert_eq(glyph, value[1], label .. " column " .. column)
    local highlight = grid.highlights[value[2]]
    t.assert_eq(foreground, highlight.foreground, label .. " column " .. column .. " color")
  end

  ui:rpc("nvim_command", "redraw")
  cell("src", 0, 0, "╰", pink)
  cell("src", 0, 1, "─", pink)
  cell("lib", 1, 0, "│", normal)
  cell("lib", 1, 2, "╰", pink)
  cell("lib", 1, 3, "─", pink)
  cell("helper", 2, 4, "│", pink)
  cell("helper", 2, 5, "─", normal)
  cell("nested", 3, 0, "│", normal)
  cell("nested", 3, 2, "│", normal)
  cell("nested", 3, 4, "│", pink)
  cell("nested", 3, 6, "╰", normal)
  cell("target", 2, 0, "│", active)
  cell("target", 2, 2, "│", active)
  cell("target", 2, 4, "╰", pink)
  cell("target", 2, 5, "─", pink)
  cell("other", 1, 2, "╰", normal)
  cell("docs", 0, 0, "├", normal)
  eval("guide_marks = {}")
  ui:rpc("nvim_command", "redraw!")
  t.assert_true(
    eval(
      "for _, count in pairs(guide_marks) do if count ~= 1 then return false end end return next(guide_marks) ~= nil"
    ),
    "each visible row submits one guide overlay"
  )
  t.assert_true(
    vim.deep_equal(
      { { first = 1, last = 1, depth = 0 }, { first = 2, last = 2, depth = 1 }, { first = 3, last = 5, depth = 2 } },
      eval("return view:frame():guide_path(5, 1, 10)")
    ),
    "native path rows use 1-based inclusive bounds"
  )

  eval("cached_path = view._guide_path; vim.api.nvim_win_set_cursor(view.winnr, {5, 8})")
  ui:rpc("nvim_command", "redraw")
  t.assert_true(eval("return view._guide_path == cached_path"), "horizontal movement reuses the path")
  for leftcol = 1, 7 do
    ui:rpc(
      "nvim_exec_lua",
      [=[
      local leftcol = ...
      vim.api.nvim_win_call(view.winnr, function() vim.fn.winrestview({leftcol=leftcol}) end)
    ]=],
      { leftcol }
    )
    ui:rpc("nvim_command", "redraw!")
    local location = assert(grid:find("target"))
    local cells = grid.grids[location.grid].rows[location.row + 1]
    if leftcol <= 4 then
      local column = 5 - leftcol
      t.assert_eq("╰", cells[column][1], "visible connector survives clipping")
      t.assert_eq(pink, grid.highlights[cells[column][2]].foreground)
      t.assert_eq("─", cells[column + 1][1])
    else
      for column = 1, location.col do
        t.assert_false(
          vim.tbl_contains({ "│", "╰", "├", "─" }, cells[column][1]),
          "a connector clipped at its start must not cover the filename"
        )
      end
    end
  end
  eval("vim.api.nvim_win_call(view.winnr, function() vim.fn.winrestview({leftcol=0}) end)")
  eval("move(7)")
  ui:rpc("nvim_command", "redraw")
  cell("src", 0, 0, "│", pink)
  cell("src", 0, 1, "─", normal)
  cell("nested", 3, 0, "│", pink)
  cell("nested", 3, 4, "│", normal)
  cell("target", 2, 4, "╰", normal)
  cell("docs", 0, 0, "╰", pink)
  cell("docs", 0, 1, "─", pink)
  t.assert_eq(0, eval("return writes"), "cursor paths never rewrite body text")

  for _, motion in ipairs({
    "vim.api.nvim_win_set_cursor(view.winnr, {7, 0})",
    'vim.cmd.normal({args={"7G"},bang=true})',
  }) do
    eval("move(5)")
    ui:rpc("nvim_command", "redraw!")
    eval(motion .. "; vim.cmd.redraw()")
    t.wait_until(function()
      return eval("return view:frame():header().cursor_row == 7 and not view._busy and not view._latest")
    end, 10000)
    cell("src", 0, 0, "│", pink)
    cell("src", 0, 1, "─", normal)
    cell("lib", 1, 2, "├", normal)
    cell("nested", 3, 0, "│", pink)
    cell("nested", 3, 4, "│", normal)
    cell("docs", 0, 0, "╰", pink)
  end

  eval("move(5)")
  ui:rpc("nvim_command", "redraw!")
  eval([=[
    vim.api.nvim_win_set_cursor(view.winnr, {7, 0})
    vim.cmd.redraw()
    vim.api.nvim_win_set_cursor(view.winnr, {5, 0})
    vim.cmd.redraw()
  ]=])
  -- A round trip can produce no CursorMoved event; the redraw itself must retain its pending differences.
  t.wait_until(function()
    return eval("return not view._guide_dirty and not view._guide_redraw_pending")
  end, 10000)
  cell("src", 0, 0, "╰", pink)
  cell("src", 0, 1, "─", pink)
  cell("lib", 1, 2, "╰", pink)
  cell("helper", 2, 4, "│", pink)
  cell("nested", 3, 0, "│", normal)
  cell("nested", 3, 4, "│", pink)
  cell("docs", 0, 0, "├", normal)

  eval([=[
    burst_dispatch, burst_redraw = state.dispatch, vim.api.nvim__redraw
    state.dispatch = function() return stl.c.Future.resolve({kind="NoChange"}) end
    burst_ranges = 0
    vim.api.nvim__redraw = function(options)
      if options.win == view.winnr and options.range then burst_ranges = burst_ranges + 1 end
      return burst_redraw(options)
    end
    for index = 1, 30 do view:set_cursor(index % 2 == 0 and 7 or 5) end
    state.dispatch = burst_dispatch
  ]=])
  t.wait_until(function()
    return eval("return not view._guide_dirty and not view._guide_redraw_pending")
  end, 10000)
  t.assert_true(eval("return burst_ranges <= 1"), "one callback coalesces intermediate cursor paths")
  cell("src", 0, 0, "│", pink)
  cell("lib", 1, 2, "├", normal)
  cell("nested", 3, 0, "│", pink)
  cell("docs", 0, 0, "╰", pink)
  eval("vim.api.nvim__redraw = burst_redraw")

  eval("move(5)")
  eval([=[
    saved_dispatch = state.dispatch
    state.dispatch = function() return stl.c.Future.resolve({kind="NoChange"}) end
    await(view:set_cursor(7))
  ]=])
  ui:rpc("nvim_command", "redraw")
  t.assert_eq(5, eval("return view:frame():header().cursor_row"), "native publication is still at the old cursor")
  cell("src", 0, 1, "─", normal)
  cell("lib", 1, 2, "├", normal)
  cell("nested", 3, 0, "│", pink)
  cell("docs", 0, 1, "─", pink)
  eval("await(view:set_cursor(6))")
  ui:rpc("nvim_command", "redraw")
  cell("src", 0, 1, "─", pink)
  cell("lib", 1, 2, "│", pink)
  cell("lib", 1, 3, "─", normal)
  cell("other", 1, 3, "─", pink)
  cell("docs", 0, 1, "─", normal)
  eval("state.dispatch = saved_dispatch; move(5)")
  ui:rpc("nvim_input", "Vk")
  t.wait_until(function()
    return eval("return vim.api.nvim_get_mode().mode == 'V' and vim.api.nvim_win_get_cursor(view.winnr)[1] == 4")
  end, 10000)
  ui:rpc("nvim_command", "redraw")
  cell("helper", 2, 5, "─", pink)
  cell("nested", 3, 4, "│", active)
  cell("nested", 3, 6, "╰", pink)
  cell("target", 2, 4, "╰", active)
  eval([=[
    visual_frame = view:frame()
    await(data:batch({ {kind="insert", key="first", parent="lib", position="first", label="first"} }))
    assert(vim.wait(10000, function() return view._latest ~= nil end))
  ]=])
  t.assert_true(eval("return view:frame() == visual_frame"), "Visual retains the displayed topology")
  ui:rpc("nvim_input", "k")
  t.wait_until(function()
    return eval("return vim.api.nvim_win_get_cursor(view.winnr)[1] == 3")
  end, 10000)
  ui:rpc("nvim_command", "redraw")
  cell("helper", 2, 4, "╰", pink)
  cell("helper", 2, 5, "─", pink)
  cell("nested", 3, 6, "╰", active)
  t.assert_eq(0, eval("return writes"), "frozen Visual paths never publish pending layout text")
  ui:rpc("nvim_input", "<Esc>")
  t.wait_until(function()
    return eval(
      "return not view._gesture and view:frame():header().layout_revision ~= visual_frame:header().layout_revision"
    )
  end, 10000)
  ui:rpc("nvim_command", "redraw")
  cell("first", 2, 4, "│", pink)
  cell("first", 2, 5, "─", normal)
  cell("helper", 2, 5, "─", pink)

  eval([=[
    cached_path = view._guide_path
    local result = await(data:batch({ {kind="update",node="helper",right_text="metadata"} }))
    assert(vim.wait(10000,function() return state._native:applicable(view:frame(),result.revisions.commit) end))
  ]=])
  ui:rpc("nvim_command", "redraw")
  t.assert_true(eval("return view._guide_path == cached_path"), "metadata publications reuse the layout path")
  eval([=[
    local result = await(state:set_expanded({ data:source():id("lib") }, false, false))
    assert(vim.wait(10000,function() return state._native:applicable(view:frame(),result.revisions.commit) end))
  ]=])
  ui:rpc("nvim_command", "redraw")
  cell("lib", 1, 2, "╰", pink)
  cell("lib", 1, 3, "─", pink)
  t.assert_nil(grid:find("target"), "folded descendants disappear")
  eval("move(80)")
  ui:rpc("nvim_command", "redraw")
  t.assert_true(eval("return view._guide_path.first > 0"), "scrolled path is viewport-clipped")
  local cursor_label = eval("return view:frame():rows(80, 80).labels[1]")
  cell(cursor_label, 0, 0, "╰", pink)
  cell(cursor_label, 0, 1, "─", pink)
  eval([=[
    local result = await(state:set_display({mode="list"}))
    assert(vim.wait(10000,function() return state._native:applicable(view:frame(),result.revisions.commit) end))
  ]=])
  ui:rpc("nvim_command", "redraw")
  t.assert_true(eval("return view._guide_path == nil"), "List does not retain a tree path")
  eval([=[
    local result = await(state:set_display({mode="tree"}))
    assert(vim.wait(10000, function() return state._native:applicable(view:frame(),result.revisions.commit) end))
    move(1)
  ]=])
  ui:rpc("nvim_command", "redraw!")
  t.assert_true(
    eval([=[
    vim.api.nvim_win_set_cursor(view.winnr, {7, 0})
    vim.cmd.redraw()
    local pending = view._guide_redraw_pending
    view:detach()
    return pending
  ]=]),
    "detach occurs with a deferred path redraw queued"
  )
  t.wait_until(function()
    return eval("return not view._guide_dirty and not view._guide_redraw_pending")
  end, 10000)
  t.assert_eq(0, eval("return #errors"))
end)

t:run()
