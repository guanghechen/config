local t = require("__test__.support.harness").new()
local explorer = require("__test__.support.explorer")

t:test("cursor movement and unchanged refresh preserve colors without recalculating icons", function()
  local path = t:tempdir()
  for index = 1, 20 do
    vim.fn.writefile({ "return true" }, path .. "/item-" .. string.format("%02d", index) .. ".lua")
  end
  local tracking, faded, missing, observed = false, {}, {}, 0
  local ui, grid = explorer.open_ui(t, {
    width = 100,
    height = 30,
    path = path,
    on_flush = function(screen)
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
    end,
  })
  ui:lua(
    [=[
    local path = ...
    vim.api.nvim_set_hl(0, "DiagnosticError", { fg = 0xFF0000 })
    vim.api.nvim_set_hl(0, "m_ft_filename", { fg = 0x808080 })
    widget = require("era.m.explorer.widget").new({name="cursor-test",root=path})
    widget:focus()
    session, view = shown(widget, 20)
    await(session.data:set_diagnostics(1,1,1,path .. "/item-01.lua",{1,0,0,0}))
    await(session.data:set_diagnostics(1,2,1,path .. "/item-15.lua",{1,0,0,0}))
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
  ui:wait_lua(
    [[
    return refreshing:is_done() and not refreshing:is_failed()
      and not session.data:native():is_busy()
      and view:frame():header().data_revision ~= ...
  ]],
    10000,
    "an unchanged refresh must publish its loading state",
    previous_revision
  )
  for step = 1, 12 do
    local row = step <= 6 and step + 1 or 13 - step
    ui:rpc("nvim_input", step <= 6 and "j" or "k")
    ui:wait_lua("return view:frame():header().cursor_row == ...", 10000, nil, row)
  end
  vim.wait(80, function()
    return false
  end, 1)
  t.wait_until(function()
    return observed >= 12
  end, 10000, "must observe movement flushes")
  tracking = false
  local counts = ui:lua("return counts")
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
  ui:wait_lua("return view:frame():rows(1,1).labels[1] == 'item-02.lua'", 10000)
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
  local path = t:tempdir()
  for _, name in ipairs({ "first.lua", "second.lua" }) do
    vim.fn.writefile({ "return true" }, path .. "/" .. name)
  end
  local ui, grid = explorer.open_ui(t, { width = 100, height = 30, path = path })
  ui:lua(
    [=[
    local path = ...
    vim.o.showtabline = 2
    widget = require("era.m.explorer.widget").new({name="purpose-markers",root=path})
    widget:focus()
    session, view = shown(widget, 2, function(current_session, current)
      return not current._busy and not current._latest and not current_session.data:native():is_busy()
    end)
    ---@param future                    stl.c.Future
    ---@return any
    function accepted(future)
      local result = await(future)
      assert(result.kind ~= "Rejected", vim.inspect(result))
      return result
    end
    accepted(widget:action():mark("copy"))
    accepted(view:set_cursor(2))
    assert(vim.wait(10000, function() return view:frame():header().cursor_row == 2 and not view._busy end))
    accepted(widget:action():mark("copy"))
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
        accepted(widget:action():cancel_transfer_or_clear_selection())
        mode = "select"
      else
        accepted(widget:action():mark(mode))
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
        if not location or not grid:row_text(location):find(glyph, 1, true) then
          return false
        end
      end
      return true
    end, 5000, mode .. " must repaint both markers without a forced redraw")
  end
  t.assert_true(ui:lua("return reusable > 0"), "exercise the unchanged-row publication path")
  t.assert_eq(0, ui:lua("return writes"), "marker changes do not write body text")
  t.assert_eq(0, ui:lua("return #errors"))
  ui:lua("widget:dispose()")
end)

t:run()
