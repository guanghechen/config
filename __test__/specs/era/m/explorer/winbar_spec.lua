local t = require("__test__.support.harness").new()
local fixture = require("__test__.support.explorer").new(t)
local fs = require("__test__.support.fs")
local await, write = fixture.await, fixture.write

t:test("winbar follows display root and four fixed flags when tabline is hidden", function()
  local before = vim.o.showtabline
  t:defer(function()
    vim.o.showtabline = before
  end)
  vim.o.showtabline = 0
  local path = t:tempdir()
  write(path .. "/.hidden")
  write(path .. "/visible")
  local widget = fixture.widget(path)
  local _, view = widget:context()
  local winbar = vim.api.nvim_get_option_value("winbar", { win = view.winnr })
  t.assert_true(
    winbar:find(vim.fs.basename(path), 1, true) ~= nil,
    "winbar="
      .. vim.inspect(winbar)
      .. ", showtabline="
      .. vim.o.showtabline
      .. ", cached="
      .. tostring(widget._titles[view.winnr])
  )
  for _, callback in ipairs(widget._callbacks) do
    t.assert_true(winbar:find(callback, 1, true) ~= nil)
  end
  local _, enabled = winbar:gsub("f_wl_explorer_flag_blue", "")
  t.assert_eq(3, enabled)
  widget:toggle_flag(4)
  t.wait_until(function()
    return view:frame():header().row_count == 1
  end, 10000)
  winbar = vim.api.nvim_get_option_value("winbar", { win = view.winnr })
  _, enabled = winbar:gsub("f_wl_explorer_flag_blue", "")
  t.assert_eq(2, enabled)
  widget:toggle_flag(2)
  t.wait_until(function()
    return view:frame():header().mode == "list"
  end, 10000)
  local compact = widget._options[3]:snapshot()
  widget:toggle_flag(3)
  t.assert_eq(compact, widget._options[3]:snapshot())
  vim.o.showtabline = 2
  widget:render_winbar()
  t.assert_eq("", vim.api.nvim_get_option_value("winbar", { win = view.winnr }))
end)

t:test("tabline visibility and Explorer OptionSet settle without a redraw feedback loop", function()
  local path = t:tempdir()
  write(path .. "/file")
  local ui = require("__test__.support.ui").open(t, { width = 80, height = 24 })
  ui:lua(
    [=[
    local path = ...
    local fixture = require("__test__.support.explorer").new(require("__test__.support.harness").new())
    vim.o.showtabline = 0
    local widget = fixture.widget(path)
    winbar_probe = { widget = widget, shown = false, renders = 0 }
    local render = widget.render_winbar
    widget.render_winbar = function(self)
      winbar_probe.renders = winbar_probe.renders + 1
      render(self)
    end
    era.widget.explorer.widget = widget
    dot.context.flight.devmode:next(false, { silent = true })
    dot.tab.resolve = function()
      return { bufs = winbar_probe.shown and { 1, 2 } or { 1 } }
    end
    -- Keep real tabline visibility, Observable delivery and OptionSet; omit bar data providers.
    era.m.nvimbar.Nvimbar = {
      new = function()
        return { place = function(self) return self end, refresh = function() end }
      end,
    }
    require("era.dressing.tabline").dressing()
  ]=],
    path
  )

  for _, shown in ipairs({ false, true, false }) do
    ui:lua("winbar_probe.shown = ...; dot.state.status.dirtier_tabline:mark_dirty()", shown)
    ui:wait_until(function()
      return ui:rpc("nvim_get_option_value", "showtabline", {}) == (shown and 2 or 0)
    end, 5000)
    -- A redraw feedback loop never goes quiet, while the toggle's own redraws may still run under load.
    local before, quiet_since = -1, vim.uv.hrtime()
    ui:wait_until(function()
      local renders = ui:lua("return winbar_probe.renders")
      if renders ~= before then
        before, quiet_since = renders, vim.uv.hrtime()
      end
      return vim.uv.hrtime() - quiet_since >= 150e6
    end, 5000, "idle redraws must settle")
    local title = ui:lua("return vim.api.nvim_get_option_value('winbar', {win = winbar_probe.widget:get_winnr()})")
    t.assert_true(shown and title == "" or not shown and title:find(vim.fs.basename(path), 1, true) ~= nil)
    ui:lua("vim.o.ignorecase = not vim.o.ignorecase")
    t.assert_eq(before, ui:lua("return winbar_probe.renders"), "unrelated options do not redraw")
  end
end)

t:test("root scan failures preserve cached rows and shared views report each transition once", function()
  if stl.env.IS_WIN or vim.uv.getuid() == 0 then
    t.skip("chmod cannot deny directory reads to root or on Windows")
  end
  local before_tabline = vim.o.showtabline
  vim.o.showtabline = 0
  t:defer(function()
    vim.o.showtabline = before_tabline
  end)
  local path = t:tempdir()
  for _, name in ipairs({ "a", "b", "c" }) do
    write(path .. "/" .. name)
  end
  local widget = fixture.widget(path)
  local session, view = widget:context()
  local second = fixture.widget(path, { session = session })
  t:defer(function()
    vim.uv.fs_chmod(path, 448)
  end)
  local before = #fixture.messages
  local root = session:root():node()
  for attempt = 1, 2 do
    assert(vim.uv.fs_chmod(path, 0))
    await(widget:refresh())
    t.wait_until(function()
      local node = session.data:source():node(root)
      return node.error ~= nil
        and session.data:native():is_settled()
        and #fixture.messages == before + attempt
        and session.state:native():applicable(view:frame())
    end, 10000)
    t.assert_eq(3, view:frame():header().row_count)
    t.assert_eq("read failed · cached · R", widget:status_text())
    t.assert_eq(widget:status_text(), second:status_text())
    t.assert_true(fixture.messages[#fixture.messages]:find("PermissionDenied", 1, true) ~= nil)
    t.assert_true(vim.api.nvim_get_option_value("winbar", { win = view.winnr }):find("read failed", 1, true) ~= nil)
    for _, width in ipairs({ 12, 30 }) do
      widget:set_width(width)
      t.wait_until(function()
        return vim.api.nvim_win_get_width(view.winnr) == width
      end, 5000)
      local title = vim.api.nvim_get_option_value("winbar", { win = view.winnr })
      local text = vim.api.nvim_eval_statusline(title, { winid = view.winnr, use_winbar = true, maxwidth = width }).str
      t.assert_true(text:find(width < 30 and "error" or "read failed", 1, true) ~= nil, text)
      t.assert_true(text:find("R", 1, true) ~= nil, text)
      if width >= 30 then
        t.assert_true(text:find("cached", 1, true) ~= nil, text)
      end
    end
    widget:set_width(30)
    for _ = 1, 3 do
      session:observe_root(view:frame())
      widget:render_winbar()
      second:render_winbar()
    end
    t.assert_eq(before + attempt, #fixture.messages)
    assert(vim.uv.fs_chmod(path, 448))
    await(widget:refresh())
    t.wait_until(function()
      return session.data:native():is_settled()
        and not session.data:source():node(root).error
        and session.state:native():applicable(view:frame())
        and session._reported_root_error == nil
    end, 10000)
    t.assert_eq("", widget:status_text())
    t.assert_eq(3, view:frame():header().row_count)
  end
end)

t:test("root error and retry remain visible after programmatic and native window resize", function()
  if stl.env.IS_WIN or vim.uv.getuid() == 0 then
    t.skip("chmod cannot deny directory reads to root or on Windows")
  end
  local path = t:tempdir()
  write(path .. "/file")
  local ui = require("__test__.support.ui").open(t, { width = 80, height = 24 })
  t:defer(function()
    vim.uv.fs_chmod(path, 448)
  end)
  ui:lua(
    [=[
    local path = ...
    local fixture = require("__test__.support.explorer").new(require("__test__.support.harness").new())
    vim.o.showtabline = 0
    local widget = fixture.widget(path)
    error_resize_probe = { widget = widget, fixture = fixture, renders = 0 }
    local render = widget.render_winbar
    widget.render_winbar = function(self)
      error_resize_probe.renders = error_resize_probe.renders + 1
      render(self)
    end
    widget:set_width(30)
  ]=],
    path
  )
  assert(vim.uv.fs_chmod(path, 0))
  ui:lua("error_resize_probe.fixture.await(error_resize_probe.widget:refresh())")
  ui:wait_lua("return error_resize_probe.widget:status_text() == ...", 10000, nil, "read failed · cached · R")
  for _, native in ipairs({ false, true }) do
    for _, width in ipairs({ 30, 12, 3, 1, 30 }) do
      ui:lua(
        [=[
        local width, native = ...
        local widget = error_resize_probe.widget
        if native then
          vim.api.nvim_win_set_width(widget:get_winnr(), width)
        else
          widget:set_width(width)
        end
      ]=],
        width,
        native
      )
      ui:wait_lua(
        [=[
        local width = ...
        local winnr = error_resize_probe.widget:get_winnr()
        local title = vim.api.nvim_get_option_value("winbar", { win = winnr })
        local text = vim.api.nvim_eval_statusline(title, { winid = winnr, use_winbar = true }).str
        local expected = width == 30 and "read failed · cached · R"
          or width == 12 and "error · R" or width == 3 and "! R" or "!"
        return vim.api.nvim_win_get_width(winnr) == width and text:find(expected, 1, true) ~= nil
      ]=],
        5000,
        "error title must follow resize without an explicit render",
        width
      )
    end
  end
  local renders, stable_since = 0, vim.uv.hrtime()
  ui:wait_until(function()
    local current = ui:lua("return error_resize_probe.renders")
    if current ~= renders then
      renders, stable_since = current, vim.uv.hrtime()
    end
    return vim.uv.hrtime() - stable_since >= 400000000
  end, 10000, "resize redraws must settle")
end)

t:test("an empty failed root is distinct from empty success and changing root clears its status", function()
  if stl.env.IS_WIN or vim.uv.getuid() == 0 then
    t.skip("chmod cannot deny directory reads to root or on Windows")
  end
  local path = t:tempdir()
  local target = t:tempdir()
  write(target .. "/visible")
  local widget = fixture.widget(path)
  local session, view = widget:context()
  local root = session:root():node()
  t:defer(function()
    vim.uv.fs_chmod(path, 448)
  end)
  assert(vim.uv.fs_chmod(path, 0))
  await(widget:refresh())
  t.wait_until(function()
    return session.data:native():is_settled()
      and session.data:source():node(root).error ~= nil
      and session._reported_root_error ~= nil
  end, 10000)
  t.assert_eq(0, view:frame():header().row_count)
  t.assert_eq("read failed · R retry", widget:status_text())
  await(widget:set_root(target))
  t.wait_until(function()
    return session:root(view:frame()):path() == target
      and view:frame():header().row_count == 1
      and session._reported_root_error == nil
  end, 10000)
  t.assert_eq("", widget:status_text())
  t.assert_true(session.data:source():node(root).error ~= nil, "another root's error remains a Source fact")
end)

t:test("replacing an Explorer buffer releases its window and late cleanup preserves the reopened pane", function()
  local path = t:tempdir()
  write(path .. "/a")
  local widget = fixture.widget(path)
  local _, view = widget:context()
  local winnr = view.winnr
  local bufnr = t:buffer(nil, { listed = true })
  t:defer(function()
    if vim.api.nvim_win_is_valid(winnr) then
      vim.api.nvim_win_close(winnr, true)
    end
  end)
  -- 'winfixbuf' refuses a plain switch; :buffer! still forces one.
  vim.api.nvim_win_call(winnr, function()
    vim.cmd.buffer({ args = { tostring(bufnr) }, bang = true })
  end)
  vim.api.nvim_set_option_value("winbar", "other owner", { win = winnr })
  vim.api.nvim_set_option_value("winhighlight", "Normal:Normal", { win = winnr })
  vim.api.nvim_set_option_value("cursorline", false, { win = winnr })
  local width = vim.api.nvim_win_get_width(winnr)
  widget:toggle_flag(4)
  widget:render_winbar()
  widget:set_width(width + 5)
  t.assert_eq("other owner", vim.api.nvim_get_option_value("winbar", { win = winnr }))
  t.assert_eq("Normal:Normal", vim.api.nvim_get_option_value("winhighlight", { win = winnr }))
  t.assert_false(vim.api.nvim_get_option_value("cursorline", { win = winnr }))
  t.assert_false(vim.api.nvim_get_option_value("winfixbuf", { win = winnr }), "the released window is not pinned")
  t.assert_eq(width, vim.api.nvim_win_get_width(winnr))
  t.assert_false(widget:isvisible())
  widget:hide()
  t.assert_true(vim.api.nvim_win_is_valid(winnr))
  t.assert_eq(bufnr, vim.api.nvim_win_get_buf(winnr))

  local reopened = widget:focus()
  t.assert_true(reopened ~= winnr)
  fixture.shown(widget)
  view:detach()
  vim.api.nvim_win_close(winnr, true)
  t.assert_eq(reopened, widget:get_winnr())
  local _, current = widget:context()
  t.assert_true(current:frame() ~= nil)
  t.assert_eq(reopened, current.winnr)
end)

t:test("progress uses processed items and readable byte units before paths and flags", function()
  local before = vim.o.showtabline
  vim.o.showtabline = 0
  t:defer(function()
    vim.o.showtabline = before
  end)
  local widget = fixture.widget(t:tempdir())
  local session, view = widget:context()
  t:patch_table(session, "job", {})
  t:patch_table(session, "operation", "copy")
  for _, case in ipairs({
    { 0, "0 B" },
    { 4, "4 B" },
    { 1023, "1023 B" },
    { 1024, "1.0 KiB" },
    { 1048576, "1.0 MiB" },
    { 1073741824, "1.0 GiB" },
  }) do
    t:patch_table(session, "progress", { phase = "working", processed = 17, results = 0, bytes = case[1] })
    local text, priority = widget:status_text()
    t.assert_eq("copy 17 items / " .. case[2], text)
    t.assert_eq("progress", priority)
    widget:render_winbar()
    local title = vim.api.nvim_get_option_value("winbar", { win = view.winnr })
    local rendered = vim.api.nvim_eval_statusline(title, { winid = view.winnr, use_winbar = true }).str
    t.assert_true(rendered:find(text, 1, true) ~= nil, rendered)
  end
  for _, phase in ipairs({ "preparing", "reading", "publishing", "cleanup" }) do
    t:patch_table(session, "progress", { phase = phase, processed = 17, results = 0, bytes = 4 })
    t.assert_eq(phase .. " 17 items / 4 B", widget:status_text())
  end
end)

for _, contents in ipairs({ "", "test" }) do
  t:test(
    (contents == "" and "empty" or "small") .. " files show progress before their directory result is published",
    function()
      local before = vim.o.showtabline
      vim.o.showtabline = 0
      t:defer(function()
        vim.o.showtabline = before
      end)
      local path = t:tempdir()
      assert(vim.uv.fs_mkdir(path .. "/source", 448))
      assert(vim.uv.fs_mkdir(path .. "/destination", 448))
      for index = 1, 1000 do
        local fd = assert(vim.uv.fs_open(path .. "/source/" .. index, "wx", 384))
        assert(vim.uv.fs_write(fd, contents, 0))
        assert(vim.uv.fs_close(fd))
      end
      local widget = fixture.widget(path)
      fixture.cursor(widget, path .. "/source")
      local session, view = widget:context()
      local notify = session.notify
      local observations = {}
      t:patch_table(session, "notify", function(self)
        notify(self)
        local progress = self.progress
        if self.job and progress and not progress.terminal and progress.processed > 0 and progress.results == 0 then
          local title = vim.api.nvim_get_option_value("winbar", { win = view.winnr })
          observations[#observations + 1] = {
            processed = progress.processed,
            bytes = progress.bytes,
            text = vim.api.nvim_eval_statusline(title, { winid = view.winnr, use_winbar = true }).str,
          }
        end
      end)
      local job = await(session:operate(view, { kind = "copy_to_directory", path = path .. "/destination" }))
      fixture.idle(widget)
      local status = job:status()
      t.assert_eq("complete", status.phase)
      t.assert_eq(1001, status.processed)
      t.assert_eq(1, status.results)
      t.assert_eq(1000 * #contents, status.bytes)
      t.assert_true(#observations > 0, "a compacted result count must not hide running work")
      for _, progress in ipairs(observations) do
        t.assert_true(progress.text:find(tostring(progress.processed), 1, true) ~= nil, progress.text)
        t.assert_true(progress.text:find(contents == "" and "0 B" or "B", 1, true) ~= nil, progress.text)
        if contents ~= "" then
          t.assert_true(progress.bytes > 0)
        end
      end
      for index = 1, 1000 do
        t.assert_eq(contents, fs.read(path .. "/destination/source/" .. index))
      end
    end
  )
end

t:run()
