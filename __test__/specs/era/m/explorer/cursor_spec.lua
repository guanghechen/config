---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.m.explorer.cursor" ---@type string

local t = require("__test__.support.harness").new("era.m.explorer.cursor")

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
  ui:rpc("nvim_ui_attach", 100, 30, { rgb = true, ext_linegrid = true })
  ui:rpc(
    "nvim_exec_lua",
    [=[
    local root, path = ...
    vim.opt.runtimepath:prepend(root)
    local suffix = vim.uv.os_uname().sysname == "Darwin" and "dylib" or "so"
    yoz = assert(package.loadlib(root .. "/rust/target/debug/libyoz." .. suffix, "luaopen_yoz"))()
    stl, dot, era = require("stl"), require("dot"), require("era")
    dot.path.workspace = function() return path end
    dot.path.is_git_repo = function() return false end
    errors = {}
    stl.reporter.warn = function(value) errors[#errors + 1] = value.message end
    stl.reporter.error = stl.reporter.warn
    stl.reporter.info = function() end
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
    { assert(vim.uv.cwd()), path }
  )
  t.wait_until(function()
    local first, other = grid:find("item-01.lua"), grid:find("item-15.lua")
    return first and other and first.highlight.foreground == 0xFF0000 and other.highlight.foreground == 0xFF0000
  end, 10000)
  ui:rpc("nvim_exec_lua", "counts.icons,counts.writes=0,0", {})
  tracking = true
  local previous_revision = ui:rpc(
    "nvim_exec_lua",
    [[
    local previous = view:frame():header().data_revision
    refreshing = session.data:refresh(session.state)
    return previous
  ]],
    {}
  )
  t.wait_until(function()
    return ui:rpc(
      "nvim_exec_lua",
      [[
      return refreshing:is_done() and not refreshing:is_failed()
        and not session.data._native:is_busy()
        and view:frame():header().data_revision ~= ...
    ]],
      { previous_revision }
    )
  end, 10000, "an unchanged refresh must publish its loading state")
  for step = 1, 12 do
    local row = step <= 6 and step + 1 or 13 - step
    ui:rpc("nvim_input", step <= 6 and "j" or "k")
    t.wait_until(function()
      return ui:rpc("nvim_exec_lua", "return view:frame():header().cursor_row == ...", { row })
    end, 10000)
  end
  vim.wait(80, function()
    return false
  end, 1)
  tracking = false
  local counts = ui:rpc("nvim_exec_lua", "return counts", {})
  t.assert_true(observed >= 12, "must observe movement flushes")
  t.assert_eq(0, #missing, "filenames disappeared during cursor movement")
  t.assert_eq(0, #faded, "filename highlight disappeared during cursor movement: " .. vim.inspect(faded))
  t.assert_eq(0, counts.writes, "cursor movement rewrote the body")
  t.assert_eq(0, counts.icons, "unchanged viewport recomputed filename icons")
  t.assert_eq(0, ui:rpc("nvim_exec_lua", "return #errors", {}))
  ui:rpc(
    "nvim_exec_lua",
    [[
    local path = ...
    assert(vim.uv.fs_rename(path .. "/item-01.lua", path .. "/z-last.lua"))
    widget:refresh()
  ]],
    { path }
  )
  t.wait_until(function()
    return ui:rpc("nvim_exec_lua", "return view:frame():rows(1,1).labels[1] == 'item-02.lua'", {})
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
  ui:rpc(
    "nvim_exec_lua",
    [[
    session.data:set_diagnostics(1,2,2,nil,{0,0,0,0})
  ]],
    {}
  )
  t.wait_until(function()
    local cell = grid:find("item-15.lua")
    return cell and cell.highlight.foreground == 0x808080
  end, 10000, "annotation revisions must invalidate the retained viewport")
  ui:rpc("nvim_exec_lua", "widget:dispose()", {})
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
  ui:rpc("nvim_ui_attach", 100, 30, { rgb = true, ext_linegrid = true })
  ui:rpc(
    "nvim_exec_lua",
    [=[
    local root, path = ...
    vim.opt.runtimepath:prepend(root)
    local suffix = vim.uv.os_uname().sysname == "Darwin" and "dylib" or "so"
    yoz = assert(package.loadlib(root .. "/rust/target/debug/libyoz." .. suffix, "luaopen_yoz"))()
    stl, dot, era = require("stl"), require("dot"), require("era")
    dot.path.workspace = function() return path end
    dot.path.is_git_repo = function() return false end
    errors = {}
    stl.reporter.warn = function(value) errors[#errors + 1] = value.message end
    stl.reporter.error = stl.reporter.warn
    stl.reporter.info = function() end
    vim.o.showtabline = 2
    widget = require("era.m.explorer.widget").new({name="purpose-markers",root=path})
    widget:focus()
    assert(vim.wait(10000, function()
      local current = widget._views[vim.api.nvim_get_current_tabpage()]
      return current and current:frame() and current:frame():header().row_count == 2
        and not current._busy and not current._latest and not widget._session.data._native:is_busy()
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
    { assert(vim.uv.cwd()), path }
  )
  ui:rpc("nvim_command", "redraw!")

  for _, mode in ipairs({ "cut", "copy", "select", "cut", "cancel" }) do
    ui:rpc(
      "nvim_exec_lua",
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
      { mode }
    )
    local glyph = ui:rpc("nvim_exec_lua", "return view._glyphs.selected", {})
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
  t.assert_true(ui:rpc("nvim_exec_lua", "return reusable > 0", {}), "exercise the unchanged-row publication path")
  t.assert_eq(0, ui:rpc("nvim_exec_lua", "return writes", {}), "marker changes do not write body text")
  t.assert_eq(0, ui:rpc("nvim_exec_lua", "return #errors", {}))
  ui:rpc("nvim_exec_lua", "widget:dispose()", {})
end)

t:run()
