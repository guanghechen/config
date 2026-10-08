---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.m.explorer.icons" ---@type string

local fixture = require("__test__.support.explorer").new("era.m.explorer.icons")
local t, await = fixture.t, fixture.await
local icons = require("era.m.explorer.icons")

---@param widget                        era.m.explorer.Widget
---@param previous                      ?era.m.explorer.IIconCache
---@param first                         ?integer
---@param last                          ?integer
---@return era.m.explorer.IIcons
local function prepare(widget, previous, first, last)
  local session, view = widget:context()
  local frame = view:frame()
  return await(
    icons.prepare(session, frame, frame:rows(first or 1, last or frame:header().row_count), previous, function()
      return true
    end)
  )
end

t:test("offscreen insertion and metadata refresh reuse visible icons", function()
  local path = fixture.directory()
  for index = 1, 80 do
    fixture.write(path .. string.format("/item-%03d.lua", index))
  end
  local widget = fixture.widget(path)
  local counts = {}
  local original = stl.fileicon.get_file_icon
  t:patch_table(stl.fileicon, "get_file_icon", function(name, ...)
    counts[name] = (counts[name] or 0) + 1
    return original(name, ...)
  end)
  fixture.write(path .. "/zzz.lua")
  vim.fn.writefile({ "changed metadata" }, path .. "/item-001.lua")
  await(widget:refresh())
  fixture.idle(widget)
  local session, view = widget:context()
  t.wait_until(function()
    local header = view:frame():header()
    return header.row_count == 81 and header.data_revision == session.data:source():revision()
  end, 10000)
  t.assert_eq(nil, next(counts), "unrelated additions and file metadata cannot invalidate visible filetype icons")
end)

t:test("ancestor rename preserves identity while invalidating full-path filetype icons", function()
  local path = fixture.directory()
  assert(vim.uv.fs_mkdir(path .. "/before", 448))
  fixture.write(path .. "/before/sample")
  local match = vim.filetype.match
  t:patch_table(vim.filetype, "match", function(options)
    if options.filename == path .. "/before/sample" then
      return "rust"
    elseif options.filename == path .. "/after/sample" then
      return "python"
    end
    return match(options)
  end)
  local widget = fixture.widget(path)
  await(widget:reveal(path .. "/before/sample"))
  fixture.idle(widget)
  local session, view = widget:context()
  local resource = await(session.data:resolve(path .. "/before/sample"))
  local before = prepare(widget)
  local previous_row = view:frame():position(resource:node())
  t.assert_eq(stl.fileicon.get_filetype_icon("rust"), before.icons[previous_row][1])
  fixture.cursor(widget, path .. "/before")
  await(widget._action:operate({ kind = "rename", name = "after" }))
  fixture.idle(widget)
  local current = await(session.data:resolve(path .. "/after/sample"))
  t.assert_eq(resource:node(), current:node(), "the cache must detect ancestor changes without a new leaf NodeId")
  t.wait_until(function()
    return session.data:inspect(view:frame():source(), current:node()):path() == path .. "/after/sample"
  end, 10000)
  local after = prepare(widget, before.cache)
  local row = view:frame():position(current:node())
  t.assert_eq(stl.fileicon.get_filetype_icon("python"), after.icons[row][1])
end)

t:test("a retained symlink gets a directory icon when its missing target appears", function()
  if stl.env.IS_WIN then
    return
  end
  local path = fixture.directory()
  assert(vim.uv.fs_symlink("target", path .. "/link"))
  local widget = fixture.widget(path)
  local session, view = widget:context()
  local resource = await(session.data:resolve(path .. "/link"))
  local before = prepare(widget)
  t.assert_false(before.cache.values[resource:node()].directory)
  assert(vim.uv.fs_mkdir(path .. "/target", 448))
  await(widget:refresh())
  fixture.idle(widget)
  local current = await(session.data:resolve(path .. "/link"))
  t.assert_eq(resource:node(), current:node())
  t.wait_until(function()
    return session.data:inspect(view:frame():source(), current:node()):info().directory
  end, 10000)
  local after = prepare(widget, before.cache)
  local row = view:frame():position(current:node())
  t.assert_true(after.cache.values[current:node()].directory)
  t.assert_true(after.links[row])
  t.assert_eq("m_ft_dirname", after.icons[row][2])
end)

t:test("scroll preparation keeps only its viewport and invalidated work stops before the next lookup", function()
  local path = fixture.directory()
  for index = 1, 80 do
    fixture.write(path .. string.format("/item-%03d.lua", index))
  end
  local widget = fixture.widget(path)
  local first = prepare(widget, nil, 1, 10)
  local second = prepare(widget, first.cache, 70, 80)
  local session, view = widget:context()
  t.assert_eq(11, vim.tbl_count(second.cache.values))
  t.assert_eq(nil, second.cache.values[view:frame():node_at(1)])
  local current, queries = true, 0
  t:patch_table(stl.fileicon, "get_file_icon", function()
    queries = queries + 1
    current = false
    return "X", "Normal", false
  end)
  local frame = view:frame()
  local result = await(icons.prepare(session, frame, frame:rows(1, 10), nil, function()
    return current
  end))
  t.assert_eq(false, result)
  t.assert_eq(1, queries, "invalidation must stop further icon lookups and cannot publish a partial cache")
end)

t:test("real scrolling and theme changes prepare icons outside redraw without rewriting text", function()
  local path = fixture.directory()
  local ui = require("__test__.support.ui").new()
  t:defer(function()
    ui:close()
  end)
  ui:rpc("nvim_ui_attach", 100, 30, { rgb = true, ext_linegrid = true })
  ui:rpc(
    "nvim_exec_lua",
    [[
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
      local drawing = false
      local provider = vim.api.nvim_set_decoration_provider
      vim.api.nvim_set_decoration_provider = function(namespace, callbacks)
        for event, callback in pairs(callbacks) do
          callbacks[event] = function(...)
            local previous = drawing
            drawing = true
            local ok, value = pcall(callback, ...)
            drawing = previous
            assert(ok, value)
            return value
          end
        end
        return provider(namespace, callbacks)
      end
      glyph, queries, drawn, empty_redraws = "A", 0, {}, 0
      stl.fileicon.get_file_icon = function()
        assert(not drawing, "filetype icons were resolved during redraw")
        local view = widget and widget._views[vim.api.nvim_get_current_tabpage()]
        if view and view:frame() and view:frame():header().row_count == 0 then
          empty_redraws = empty_redraws + 1
          vim.cmd.redraw()
        end
        queries = queries + 1
        return glyph, "Normal", false
      end
      local namespace = vim.api.nvim_create_namespace("era.explorer")
      local mark = vim.api.nvim_buf_set_extmark
      vim.api.nvim_buf_set_extmark = function(bufnr, ns, row, col, options)
        if ns == namespace and options.priority == 121 then
          drawn[row + 1] = options.virt_text[1][1]
        end
        return mark(bufnr, ns, row, col, options)
      end
      widget = require("era.m.explorer.widget").new({ name = "viewport-icons", root = path })
      widget:focus()
      assert(vim.wait(10000, function()
        local view = widget._views[vim.api.nvim_get_current_tabpage()]
        return view and view:frame() and view:frame():header().row_count == 0 and not view:status().preparing
      end, 1))
      for index = 1, 100 do
        vim.fn.writefile({ "test" }, path .. string.format("/item-%03d.lua", index))
      end
      widget:refresh()
      assert(vim.wait(10000, function()
        local view = widget._views[vim.api.nvim_get_current_tabpage()]
        return view and view:frame() and view:frame():header().row_count == 100 and not view:status().preparing
      end, 1))
      session, view = widget:context()
      writes = 0
      local lines = vim.api.nvim_buf_set_lines
      vim.api.nvim_buf_set_lines = function(bufnr, ...)
        if bufnr == view.bufnr then writes = writes + 1 end
        return lines(bufnr, ...)
      end
    ]],
    { assert(vim.uv.cwd()), path }
  )
  t.wait_until(function()
    return ui:rpc("nvim_exec_lua", "return drawn[1] == 'A'", {})
  end, 10000)
  t.assert_true(ui:rpc("nvim_exec_lua", "return empty_redraws", {}) > 0)
  ui:rpc("nvim_input", "65G")
  t.wait_until(function()
    return ui:rpc(
      "nvim_exec_lua",
      "return drawn[65] == 'A' and view:frame():header().cursor_row == 65 and not view:status().preparing",
      {}
    )
  end, 10000, "typed scrolling must prepare the new viewport")
  ui:rpc("nvim_command", "normal! zt")
  t.wait_until(function()
    return ui:rpc("nvim_exec_lua", "return drawn[90] == 'A' and not view:status().preparing", {})
  end, 10000, "scrolling below a fixed cursor must prepare its newly visible rows")
  ui:rpc("nvim_command", "normal! zb")
  t.wait_until(function()
    return ui:rpc(
      "nvim_exec_lua",
      [[
        local first = vim.api.nvim_win_call(view.winnr, vim.fn.winsaveview).topline
        return first < 65 and drawn[first] == "A" and not view:status().preparing
      ]],
      {}
    )
  end, 10000, "viewport changes without cursor movement must also prepare icons")
  local before = ui:rpc("nvim_exec_lua", "return queries", {})
  ui:rpc(
    "nvim_exec_lua",
    [[
      glyph, drawn = "B", {}
      vim.api.nvim_exec_autocmds("ColorScheme", { pattern = "viewport-test" })
    ]],
    {}
  )
  t.wait_until(function()
    return ui:rpc("nvim_exec_lua", "return drawn[65] == 'B' and not view:status().preparing", {})
  end, 10000, "theme changes must invalidate the committed icon cache")
  t.assert_true(ui:rpc("nvim_exec_lua", "return queries", {}) > before)
  t.assert_eq(0, ui:rpc("nvim_exec_lua", "return writes", {}))
  t.assert_eq(0, ui:rpc("nvim_exec_lua", "return #errors", {}))
  ui:rpc("nvim_exec_lua", "widget:dispose()", {})
end)

t:test("a superseded first publication reuses completed icon work without publishing old rows", function()
  local path = fixture.directory()
  for index = 1, 20 do
    fixture.write(path .. string.format("/item-%03d.lua", index))
  end
  local widget = fixture.widget(path)
  local session = widget:context()
  local resource = await(session.data:resolve(path .. "/item-001.lua"))
  widget:hide()
  local hold, pending, prepared, queries = true, {}, 0, 0
  local annotations = require("ux.filetree.annotations")
  local original_annotations = annotations.prepare
  t:patch_table(annotations, "prepare", function(...)
    if not hold then
      return original_annotations(...)
    end
    return require("stl.c.future").new(function(resolve)
      pending[#pending + 1] = resolve
    end)
  end)
  local original_icons = icons.prepare
  t:patch_table(icons, "prepare", function(...)
    return original_icons(...):map(function(value)
      prepared = prepared + 1
      return value
    end)
  end)
  local icon = stl.fileicon.get_file_icon
  t:patch_table(stl.fileicon, "get_file_icon", function(...)
    queries = queries + 1
    return icon(...)
  end)
  widget:focus()
  t.wait_until(function()
    return #pending == 1 and prepared == 1
  end, 10000)
  local initial = queries
  t.assert_true(initial > 0)
  await(session.state:select_node({ resource:node() }, false))
  pending[1](function() end)
  t.wait_until(function()
    return #pending == 2 and prepared == 2
  end, 10000)
  t.assert_eq(initial, queries, "retargeting must reuse completed values after validating their resource inputs")
  hold = false
  pending[2](function() end)
  fixture.idle(widget)
  local _, view = widget:context()
  t.assert_true(view:frame():rows(1, 1).marked[1])
  t.assert_eq(initial, queries)
end)

t:run()
