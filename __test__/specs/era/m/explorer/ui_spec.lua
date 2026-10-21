local t = require("__test__.support.harness").new()
local explorer = require("__test__.support.explorer")

t:test("cursor movement and unchanged refresh preserve colors without recalculating icons", function()
  local path = vim.fn.tempname()
  assert(vim.uv.fs_mkdir(path, 448))
  for index = 1, 20 do
    vim.fn.writefile({ "return true" }, path .. "/item-" .. string.format("%02d", index) .. ".lua")
  end
  local ui = require("__test__.support.ui").new()
  t:defer(function()
    ui:close()
    vim.fn.delete(path, "rf")
  end)
  local tracking, faded, missing, observed = false, {}, {}, 0
  local grid = require("__test__.support.ui_grid").new(ui, function(screen)
    if not tracking then
      return
    end
    observed = observed + 1
    for _, name in ipairs({ "item-01.lua", "item-15.lua" }) do
      local cell = screen:find(name)
      if not cell then
        missing[#missing + 1] = name
      elseif cell.highlight.foreground ~= 0xFF0000 then
        faded[#faded + 1] = { flush = screen.flushes, name = name, foreground = cell.highlight.foreground }
      end
    end
  end)
  explorer.start_ui(ui, { width = 100, height = 30, path = path })
  ui:lua(
    [=[
    local path = ...
    vim.api.nvim_set_hl(0, "DiagnosticError", { fg = 0xFF0000 })
    vim.api.nvim_set_hl(0, "m_ft_filename", { fg = 0x808080 })
    widget = require("era.m.explorer.widget").new({name="cursor-test",root=path})
    widget:focus()
    assert(vim.wait(10000,function()
      local view = widget._views[vim.api.nvim_get_current_tabpage()]
      return view and view:frame() and view:frame():header().row_count == 20
    end,1))
    session, view = widget:context()
    local future = session.data:set_diagnostics(1,1,1,path .. "/item-01.lua",{1,0,0,0})
    assert(vim.wait(10000,function() return future:is_done() end,1))
    future = session.data:set_diagnostics(1,2,1,path .. "/item-15.lua",{1,0,0,0})
    assert(vim.wait(10000,function() return future:is_done() end,1))
    local icon = stl.fileicon.get_file_icon
    counts = {icons=0,writes=0}
    stl.fileicon.get_file_icon = function(...)
      counts.icons=counts.icons+1
      return icon(...)
    end
    local set_lines=vim.api.nvim_buf_set_lines
    vim.api.nvim_buf_set_lines = function(bufnr,...)
      if bufnr == view.bufnr then counts.writes=counts.writes+1 end
      return set_lines(bufnr,...)
    end
  ]=],
    path
  )
  t.wait_until(function()
    local first, other = grid:find("item-01.lua"), grid:find("item-15.lua")
    return first and other and first.highlight.foreground == 0xFF0000 and other.highlight.foreground == 0xFF0000
  end, 10000)
  ui:lua("counts.icons,counts.writes=0,0")
  tracking = true
  local previous_revision = ui:lua([[
    local previous = view:frame():header().data_revision
    refreshing = session.data:refresh(session.state)
    return previous
  ]])
  ui:wait_until(function()
    return ui:lua(
      [[
      return refreshing:is_done() and not refreshing:is_failed()
        and not session.data:native():is_busy()
        and view:frame():header().data_revision ~= ...
    ]],
      previous_revision
    )
  end, 10000, "an unchanged refresh must publish its loading state")
  for step = 1, 12 do
    local row = step <= 6 and step + 1 or 13 - step
    ui:rpc("nvim_input", step <= 6 and "j" or "k")
    ui:wait_until(function()
      return ui:lua("return view:frame():header().cursor_row == ...", row)
    end, 10000)
  end
  vim.wait(80, function()
    return false
  end, 1)
  tracking = false
  local counts = ui:lua("return counts")
  t.assert_true(observed >= 12, "must observe movement flushes")
  t.assert_eq(0, #missing, "filenames disappeared during cursor movement")
  t.assert_eq(0, #faded, "filename highlight disappeared during cursor movement: " .. vim.inspect(faded))
  t.assert_eq(0, counts.writes, "cursor movement rewrote the body")
  t.assert_eq(0, counts.icons, "unchanged viewport recomputed filename icons")
  t.assert_eq(0, ui:lua("return #errors"))
  ui:lua(
    [[
    local path = ...
    assert(vim.uv.fs_rename(path .. "/item-01.lua", path .. "/z-last.lua"))
    widget:refresh()
  ]],
    path
  )
  ui:wait_until(function()
    return ui:lua("return view:frame():rows(1,1).labels[1] == 'item-02.lua'")
  end, 10000)
  ui:rpc("nvim_command", "normal! ggzt")
  t.wait_until(function()
    local moved, next_item, other = grid:find("z-last.lua"), grid:find("item-02.lua"), grid:find("item-15.lua")
    return moved
      and next_item
      and other
      and moved.highlight.foreground == 0x808080
      and next_item.highlight.foreground == 0x808080
      and other.highlight.foreground == 0xFF0000
  end, 10000, "structural changes must not reuse annotations for the previous row order")
  ui:lua([[
    session.data:set_diagnostics(1,2,2,nil,{0,0,0,0})
  ]])
  t.wait_until(function()
    local cell = grid:find("item-15.lua")
    return cell and cell.highlight.foreground == 0x808080
  end, 10000, "annotation revisions must invalidate the retained viewport")
  ui:lua("widget:dispose()")
end)

t:test("purpose changes repaint all selection markers even when row data is reusable", function()
  local path = vim.fn.tempname()
  assert(vim.uv.fs_mkdir(path, 448))
  for _, name in ipairs({ "first.lua", "second.lua" }) do
    vim.fn.writefile({ "return true" }, path .. "/" .. name)
  end
  local ui = require("__test__.support.ui").new()
  local grid = require("__test__.support.ui_grid").new(ui)
  t:defer(function()
    ui:close()
    vim.fn.delete(path, "rf")
  end)
  explorer.start_ui(ui, { width = 100, height = 30, path = path })
  ui:lua(
    [=[
    local path = ...
    vim.o.showtabline = 2
    widget = require("era.m.explorer.widget").new({name="purpose-markers",root=path})
    widget:focus()
    assert(vim.wait(10000, function()
      local current = widget._views[vim.api.nvim_get_current_tabpage()]
      return current and current:frame() and current:frame():header().row_count == 2
        and not current._busy and not current._latest and not widget._session.data:native():is_busy()
    end))
    session, view = widget:context()
    ---@param future                    stl.c.Future
    ---@return any
    function await(future)
      assert(vim.wait(10000, function() return future:is_done() end))
      assert(not future:is_failed(), future:get_error())
      local result = future:get_result()
      assert(result.kind ~= "Rejected", vim.inspect(result))
      return result
    end
    await(widget._action:mark("copy"))
    await(view:set_cursor(2))
    assert(vim.wait(10000, function() return view:frame():header().cursor_row == 2 and not view._busy end))
    await(widget._action:mark("copy"))
    assert(vim.wait(10000, function()
      return session:mode(view:frame()) == "copy" and view:frame():rows(1, 2).marked[2] and not view._busy
    end))
    writes, reusable = 0, 0
    local set_lines = vim.api.nvim_buf_set_lines
    vim.api.nvim_buf_set_lines = function(bufnr, ...)
      if bufnr == view.bufnr then writes = writes + 1 end
      return set_lines(bufnr, ...)
    end
  ]=],
    path
  )
  ui:rpc("nvim_command", "redraw!")

  for _, mode in ipairs({ "cut", "copy", "select", "cut", "cancel" }) do
    ui:lua(
      [=[
      local mode = ...
      local original = view:frame()
      if mode == "cancel" then
        await(widget._action:cancel_transfer_or_clear_selection())
        mode = "select"
      else
        await(widget._action:mark(mode))
      end
      assert(vim.wait(10000, function()
        return session:mode(view:frame()) == mode and not view._busy and not view._latest
      end))
      assert(original:header().selection_revision == view:frame():header().selection_revision,
        "purpose changes do not restamp selected nodes")
      if original:same_rows(view:frame()) then reusable = reusable + 1 end
    ]=],
      mode
    )
    local glyph = ui:lua("return view._glyphs.selected")
    t.wait_until(function()
      for _, label in ipairs({ "first.lua", "second.lua" }) do
        local location = grid:find(label)
        if not location then
          return false
        end
        local text = {}
        for _, cell in ipairs(grid.grids[location.grid].rows[location.row + 1]) do
          text[#text + 1] = cell[1]
        end
        if not table.concat(text):find(glyph, 1, true) then
          return false
        end
      end
      return true
    end, 1000, mode .. " must repaint both markers without a forced redraw")
  end
  t.assert_true(ui:lua("return reusable > 0"), "exercise the unchanged-row publication path")
  t.assert_eq(0, ui:lua("return writes"), "marker changes do not write body text")
  t.assert_eq(0, ui:lua("return #errors"))
  ui:lua("widget:dispose()")
end)

t:test("fold keys coexist with which-key and publish names and status together", function()
  local path = t:tempdir()
  vim.fn.mkdir(path .. "/branch/nested", "p")
  for _, name in ipairs({ "keep-a.lua", "keep-b.lua", "branch/inside.lua", "branch/nested/leaf.lua" }) do
    vim.fn.writefile({ "content" }, path .. "/" .. name)
  end
  local ui = require("__test__.support.ui").new()
  t:defer(function()
    ui:close()
    vim.fn.delete(path, "rf")
  end)
  local tracking, failures, observed = false, {}, 0
  local expected = {
    ["branch"] = { color = 0xFFFF00, status = "W:1" },
    ["keep-a.lua"] = { color = 0xFF0000, status = "E:1" },
    ["keep-b.lua"] = { color = 0xFFFF00, status = "W:1" },
    ["inside.lua"] = { color = 0xFFFF00, status = "W:1", optional = true },
    ["nested"] = { color = 0x808080, status = "", optional = true },
    ["leaf.lua"] = { color = 0x808080, status = "", optional = true },
  }
  local grid = require("__test__.support.ui_grid").new(ui, function(screen)
    if not tracking then
      return
    end
    observed = observed + 1
    for name, value in pairs(expected) do
      local cell = screen:find(name)
      if cell then
        local cells = screen.grids[cell.grid].rows[cell.row + 1]
        local line = {}
        for _, item in ipairs(cells) do
          line[#line + 1] = item[1]
        end
        if cell.highlight.foreground ~= value.color or not table.concat(line):find(value.status, 1, true) then
          failures[#failures + 1] = { flush = screen.flushes, name = name, color = cell.highlight.foreground }
        end
      elseif not value.optional then
        failures[#failures + 1] = { flush = screen.flushes, name = name, missing = true }
      end
    end
  end)
  explorer.start_ui(ui, { width = 100, height = 30, path = path })
  ui:lua(
    [=[
    local path = ...
    vim.api.nvim_set_hl(0, "DiagnosticError", { fg = 0xFF0000 })
    vim.api.nvim_set_hl(0, "DiagnosticWarn", { fg = 0xFFFF00 })
    vim.api.nvim_set_hl(0, "m_ft_filename", { fg = 0x808080 })
    whichkey = era.dressing.whichkey
    whichkey.state.setup()
    whichkey.state.enable()
    popups, navigations = 0, 0
    local render = whichkey.view.render
    whichkey.view.render = function(...)
      popups = popups + 1
      return render(...)
    end
    local keymaps = require("era.m.explorer.keymaps")
    local bind = keymaps.bind
    keymaps.bind = function(widget, view)
      vim.api.nvim_buf_call(view.bufnr, function()
        whichkey.state.__attach__(view.bufnr)
        assert(vim.fn.maparg("z", "n", false, true).desc == "wk-trigger")
      end)
      bind(widget, view)
    end
    widget = require("era.m.explorer.widget").new({ name = "fold-test", root = path })
    local navigate = widget._action.navigate
    widget._action.navigate = function(self, direction)
      navigations = navigations + 1
      return navigate(self, direction)
    end
    widget:focus()
    assert(vim.wait(10000, function()
      local current = widget._views[vim.api.nvim_get_current_tabpage()]
      return current and current:frame() and current:frame():header().row_count == 3
    end))
    session, view = widget:context()
    for index, name in ipairs({ "keep-a.lua", "keep-b.lua", "branch/inside.lua" }) do
      local counts = index == 1 and { 1, 0, 0, 0 } or { 0, 1, 0, 0 }
      local future = session.data:set_diagnostics(1, index, 1, path .. "/" .. name, counts)
      assert(vim.wait(10000, function() return future:is_done() end))
      assert(not future:is_failed(), future:get_error())
    end
    local on_frame = view._options.on_frame
    view._options.on_frame = function(frame)
      on_frame(frame)
      -- Observers may redraw immediately after a frame is published.
      vim.cmd("redraw")
    end
  ]=],
    path
  )
  t.wait_until(function()
    for name, value in pairs(expected) do
      local cell = grid:find(name)
      if not value.optional and (not cell or cell.highlight.foreground ~= value.color) then
        return false
      end
    end
    return true
  end, 10000)
  ui:rpc("nvim_input", "[")
  ui:wait_until(function()
    return ui:lua("return whichkey.state.keys == '['")
  end, 10000, "the prefix must enter which-key before its child is typed")
  ui:rpc("nvim_input", "i")
  ui:wait_until(function()
    return ui:lua("return navigations == 1 and not whichkey.state.is_suspended(view.bufnr, 'n')")
  end, 10000, "a which-key prefix must execute and restore its triggers")
  t.assert_eq(
    "Explorer: recursive expansion",
    ui:lua("return vim.fn.maparg('z', 'n', false, true).desc"),
    "which-key must preserve Explorer's replacement mapping"
  )
  ui:lua("popups = 0")
  tracking = true
  for step = 1, 8 do
    local expanded = step % 2 == 1
    local recursive = step > 4
    ui:rpc("nvim_input", recursive and "z" or expanded and "l" or "h")
    ui:wait_until(function()
      return ui:lua(
        [[
        local expanded, recursive = ...
        local frame = view:frame()
        return frame:header().row_count == (expanded and (recursive and 6 or 5) or 3)
          and frame:rows(1, 1).expanded[1] == expanded
      ]],
        expanded,
        recursive
      )
    end, 10000)
  end
  tracking = false
  t.assert_true(observed >= 8, "fold transitions must reach the UI")
  t.assert_eq(0, #failures, "fold/expand lost decorations: " .. vim.inspect(failures[1]))
  t.assert_eq(0, ui:lua("return popups"), "fold keys must not open which-key")
  t.assert_eq(0, ui:lua("return #errors"))
  ui:lua("widget:dispose(); whichkey.state.disable()")
end)

t:test("guides stay visible through Visual selection and clip correctly when scrolled", function()
  local path = t:tempdir()
  vim.fn.mkdir(path .. "/branch", "p")
  local long_name = "b-long-child-for-horizontal-scroll.lua"
  for _, name in ipairs({ "branch/a.lua", "branch/" .. long_name, "z.lua" }) do
    vim.fn.writefile({ "content" }, path .. "/" .. name)
  end
  local ui = require("__test__.support.ui").new()
  local grid = require("__test__.support.ui_grid").new(ui)
  t:defer(function()
    ui:close()
    vim.fn.delete(path, "rf")
  end)
  explorer.start_ui(ui, { width = 100, height = 30, path = path })
  ui:lua(
    [=[
    local path = ...
    widget = require("era.m.explorer.widget").new({
      name = "indent-visual", root = path,
      o_flag_foldempty = stl.c.Observable.from_value(false),
    })
    widget:focus()
    local future = widget:reveal(path .. "/branch/a.lua")
    assert(vim.wait(10000, function() return future:is_done() end))
    assert(not future:is_failed(), future:get_error())
    session, view = widget:context()
    assert(vim.wait(10000, function()
      return view:frame() and view:frame():header().row_count == 4
        and not session.data:native():is_busy() and session.state:native():applicable(view:frame())
    end))
  ]=],
    path
  )

  ---@param row                         integer
  ---@return nil
  local function move(row)
    ui:lua(
      [=[
      local row = ...
      local future = view:set_cursor(row)
      assert(vim.wait(10000, function() return future:is_done() end))
      assert(not future:is_failed(), future:get_error())
      assert(vim.wait(10000, function()
        return view:frame():header().cursor_row == row and not view._busy and not view._latest
      end))
    ]=],
      row
    )
  end

  ---@param label                       string
  ---@return nil
  local function visible_guides(label)
    ui:rpc("nvim_command", "redraw!")
    local location = assert(grid:find("a.lua"), label .. ": missing filename: " .. vim.inspect(ui:lua("return errors")))
    local cells = grid.grids[location.grid].rows[location.row + 1]
    local colors = ui:lua([=[
      local cursor = vim.api.nvim_win_get_cursor(view.winnr)[1]
      local mode = vim.api.nvim_get_mode().mode:sub(1, 1)
      local active = cursor == 2 or mode == "v" or mode == "V" or mode == "\22"
      return {
        path = vim.api.nvim_get_hl(0, {name="m_ex_indent_path",link=false}).fg,
        base = vim.api.nvim_get_hl(0, {name=active and "m_ex_indent_active" or "m_ex_indent",link=false}).fg,
        cursor = cursor,
      }
    ]=])
    local guides = {}
    for col = 1, location.col do
      local cell = cells[col]
      if cell[1] == "│" or cell[1] == "├" or cell[1] == "╰" or cell[1] == "─" then
        guides[#guides + 1] = cell[1]
        local highlight = grid.highlights[cell[2]]
        t.assert_true(highlight.foreground ~= highlight.background, label .. ": guide blends into its background")
        local path = #guides == 2 or #guides == 3 and colors.cursor == 2
        t.assert_eq(
          path and colors.path or colors.base,
          highlight.foreground,
          label .. ": exact path column " .. #guides .. ", cursor " .. colors.cursor
        )
      end
    end
    t.assert_eq(
      colors.cursor == 2 and "│╰─" or "││─",
      table.concat(guides),
      label .. ": path stem stays straight"
    )
  end

  for _, theme in ipairs({ "rosepine-dawn", "rosepine-main", "vsc-light-modern", "vsc-dark-modern" }) do
    ui:lua("dot.context.theme.apply_theme({ theme = ..., transparency = false })", theme)
    for _, input in ipairs({ { "Vj", "V" }, { "vj", "v" }, { "v<C-v>j3l", vim.keycode("<C-v>") } }) do
      move(2)
      visible_guides(theme .. " Normal")
      ui:rpc("nvim_input", input[1])
      ui:wait_until(function()
        return ui:lua("return vim.api.nvim_get_mode().mode == ...", input[2])
      end, 10000)
      visible_guides(theme .. " " .. input[2])
      ui:rpc("nvim_input", "<Esc>")
      ui:wait_until(function()
        return ui:lua("return vim.api.nvim_get_mode().mode:sub(1, 1) == 'n'")
      end, 10000)
      visible_guides(theme .. " after Visual")
    end
    local foreground = ui:lua("return vim.api.nvim_get_hl(0, { name = 'm_ex_indent', link = false }).fg")
    local path_foreground = ui:lua("return vim.api.nvim_get_hl(0, { name = 'm_ex_indent_path', link = false }).fg")
    move(4)
    ui:rpc("nvim_command", "redraw!")
    local location = assert(grid:find("a.lua"))
    local cells = grid.grids[location.grid].rows[location.row + 1]
    for col = 1, location.col do
      if cells[col][1] == "│" or cells[col][1] == "├" or cells[col][1] == "─" then
        t.assert_eq(
          cells[col][1] == "│" and path_foreground or foreground,
          grid.highlights[cells[col][2]].foreground,
          theme .. ": only the path to the top-level sibling changes color"
        )
      end
    end
  end
  ui:lua([=[
    local future = session.state:dispatch({ kind = "set_cursor", node = view:frame():node_at(3) })
    assert(vim.wait(10000, function() return future:is_done() end))
    assert(vim.wait(10000, function()
      return view:frame():header().cursor_row == 3 and not view._busy and not view._latest
    end))
  ]=])
  ui:lua([=[
    vim.api.nvim_win_set_cursor(view.winnr, {3, 23})
    vim.api.nvim_win_call(view.winnr, function() vim.cmd("normal! zs") end)
  ]=])
  ui:rpc("nvim_command", "redraw!")
  local tail = assert(grid:find("scroll.lua"))
  local cells = grid.grids[tail.grid].rows[tail.row + 1]
  for col = 1, tail.col do
    t.assert_false(
      vim.tbl_contains({ "│", "╰", "├", "─" }, cells[col][1]),
      "a clipped guide covers the filename"
    )
  end
  t.assert_eq(0, ui:lua("return #errors"))
  ui:lua("widget:dispose()")
end)

t:test("real UI subscribes to diagnostics and Git ignore with independent name and icon colors", function()
  local path = vim.fn.tempname()
  assert(vim.uv.fs_mkdir(path, 448))
  vim.fn.writefile({ "content" }, path .. "/a.lua")
  vim.fn.writefile({ "content" }, path .. "/b.py")
  vim.fn.writefile({ "b.py" }, path .. "/.gitignore")
  local initialized = vim.system({ "git", "-C", path, "init", "-q" }, { text = true }):wait()
  t.assert_eq(0, initialized.code, initialized.stderr)
  local ui = require("__test__.support.ui").new()
  t:defer(function()
    ui:close()
    vim.fn.delete(path, "rf")
  end)
  explorer.start_ui(ui, { width = 100, height = 30, path = path, git_repo = true })
  ui:lua(
    [=[
    local path = ...
    errors, drawn, colors, icons, glyphs = {}, {}, {}, {}, {}
    local explorer_ns = vim.api.nvim_create_namespace("era.explorer")
    local annotation_ns = vim.api.nvim_create_namespace("ux.filetree.annotations")
    local mark = vim.api.nvim_buf_set_extmark
    vim.api.nvim_buf_set_extmark = function(bufnr, ns, row, col, options)
      if ns == explorer_ns then
        if options.hl_group and not options.virt_text then colors[row + 1] = options.hl_group end
        if options.virt_text then
          icons[row + 1] = options.virt_text[1][2]
          glyphs[row + 1] = options.virt_text[1][1]
        end
      elseif ns == annotation_ns and options.virt_text then
        for _, chunk in ipairs(options.virt_text) do drawn[chunk[1]] = true end
      end
      return mark(bufnr, ns, row, col, options)
    end
    widget = require("era.m.explorer.widget").new({
      name = "attached-test", root = path,
      o_flag_hidden = stl.c.Observable.from_value(false),
    })
    widget:focus()
    assert(vim.wait(10000, function()
      local view = widget._views[vim.api.nvim_get_current_tabpage()]
      return view and view:frame() and view:frame():header().row_count == 2
    end))
    session, view = widget:context()
    namespace = vim.api.nvim_create_namespace("explorer-live-diagnostics")
    buffers = {}
    for _, name in ipairs({ "a.lua", "b.py" }) do
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_name(bufnr, path .. "/" .. name)
      buffers[#buffers + 1] = bufnr
      vim.diagnostic.set(namespace, bufnr, {
        { lnum = 0, col = 0, severity = 1, message = "error" },
        { lnum = 0, col = 0, severity = 2, message = "warning" },
        { lnum = 0, col = 0, severity = 3, message = "info" },
        { lnum = 0, col = 0, severity = 4, message = "hint" },
      })
    end
  ]=],
    path
  )
  ui:wait_until(function()
    ui:rpc("nvim_command", "redraw")
    return ui:lua(
      "return colors[1] == 'DiagnosticError' and colors[2] == 'm_ex_ignored' and drawn[' E:1'] and drawn[' W:1']"
    )
  end, 10000)
  t.assert_false(ui:lua("return drawn[' I:1'] == true or drawn[' H:1'] == true"))
  t.assert_true(ui:lua("return icons[1] ~= nil and icons[1] ~= colors[1]"))
  t.assert_eq("m_ex_ignored", ui:lua("return icons[2]"))
  t.assert_eq(0, ui:lua("return #errors"))
  ui:lua([=[
    vim.diagnostic.reset(namespace)
    assert(vim.wait(10000, function()
      return view._filetree_annotations and view._filetree_annotations.rows[1].diagnostics[1] == 0
    end))
    drawn = {}
  ]=])
  ui:rpc("nvim_command", "redraw")
  t.assert_false(ui:lua("return drawn[' E:1'] == true"))
  local source_revision, quiet_since = nil, vim.uv.hrtime()
  ui:wait_until(function()
    local current = ui:lua(
      "return { session.data:source():revision(), session.data:native():is_busy() or session._subscriptions._running }"
    )
    if current[1] ~= source_revision or current[2] then
      source_revision, quiet_since = current[1], vim.uv.hrtime()
    end
    return vim.uv.hrtime() - quiet_since > 300000000
  end, 10000)
  for _, options in ipairs({ { git_refresh = true }, {}, { background = true } }) do
    local before = ui:lua(
      [=[
      local options = ...
      explorer_tabnr = vim.api.nvim_get_current_tabpage()
      local before = { session.data:source():revision(), vim.api.nvim_buf_get_changedtick(view.bufnr) }
      if options.background then vim.cmd.tabnew() end
      colors = {}
      ignore_revision = session.data:native():annotation_revision()
      require("era.m.git.ignore").clear()
      if options.git_refresh then
        require("era.m.git.state").o_refreshed:next({generation=999,change_scope="unknown"})
      end
      return before
    ]=],
      options
    )
    if options.background then
      ui:wait_until(function()
        return ui:lua(
          "return session.data:native():annotation_revision() ~= ignore_revision and not session._subscriptions._running"
        )
      end, 10000)
      ui:lua("vim.api.nvim_set_current_tabpage(explorer_tabnr)")
    end
    ui:wait_until(function()
      ui:rpc("nvim_command", "redraw")
      return ui:lua(
        [=[
        local path = ...
        local cache = view._filetree_annotations
        return require("era.m.git.ignore").is_ignored(path .. "/b.py")
          and cache and bit.band(cache.rows[2].git,256) ~= 0 and colors[2] == "m_ex_ignored"
          and not session._subscriptions._running
      ]=],
        path
      )
    end, 10000, "clearing ignore cache must requery the viewport without a manual refresh")
    t.assert_eq(before[1], ui:lua("return session.data:source():revision()"))
    t.assert_eq(before[2], ui:lua("return vim.api.nvim_buf_get_changedtick(view.bufnr)"))
  end
  ui:lua(
    [=[
    local path = ...
    assert(vim.uv.fs_mkdir(path .. "/lsp", 448))
    assert(vim.uv.fs_mkdir(path .. "/plain", 448))
    widget:refresh()
    assert(vim.wait(10000, function() return view:frame():header().row_count == 4 end))
    vim.api.nvim_win_set_cursor(view.winnr, {1, 0})
    vim.api.nvim_win_call(view.winnr, function() vim.cmd("normal! zt") end)
    colors, icons = {}, {}
  ]=],
    path
  )
  ui:wait_until(function()
    ui:rpc("nvim_command", "redraw")
    return ui:lua(
      "return icons[1] == 'MiniIconsGreen' and icons[2] == 'm_ft_dirname' and colors[1] == 'm_ft_filename' and colors[2] == 'm_ft_filename'"
    )
  end, 10000)
  for _, expanded in ipairs({ true, false, true }) do
    ui:lua("widget._action:activate()")
    ui:wait_until(function()
      ui:rpc("nvim_command", "redraw")
      return ui:lua(
        [[
        local expanded = ...
        local expected = expanded and stl.icon.filetype.FolderEmptyOpen or stl.fileicon.get_directory_icon('lsp')
        return view:frame():rows(1,1).expanded[1] == expanded and glyphs[1] == expected
      ]],
        expanded
      )
    end, 10000, "an empty directory's icon must follow expansion even when row layout is unchanged")
  end
  ui:lua("widget:dispose()")
end)

t:run()
