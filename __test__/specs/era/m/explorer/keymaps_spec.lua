---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.m.explorer.keymaps" ---@type string

local fixture = require("__test__.support.explorer").new("era.m.explorer.keymaps")
local t, await = fixture.t, fixture.await

---@param widget                        era.m.explorer.Widget
---@param keys                          string
---@return nil
local function press(widget, keys)
  local _, view = widget:context()
  vim.api.nvim_set_current_win(view.winnr)
  vim.api.nvim_feedkeys(vim.keycode(keys), "xt", false)
end

---@param widget                        era.m.explorer.Widget
---@param mode                          ?string
---@param count                         integer
---@return nil
local function selected(widget, mode, count)
  local session, view = widget:context()
  t.wait_until(function()
    local frame = view:frame()
    return session.state._native:applicable(frame)
      and session:mode(frame) == mode
      and frame:header().summary.known_roots == count
  end, 10000, "unexpected selection after a keypress")
end

t:test("copy and cut prompt for a path without selection and mark an existing selection", function()
  local path = fixture.directory()
  fixture.write(path .. "/a.lua")
  fixture.write(path .. "/b.lua")
  local widget = fixture.widget(path)
  local prompts = {}
  t:patch_table(vim.ui, "input", function(options, done)
    prompts[#prompts + 1] = options
    done(nil)
  end)
  for index, keys in ipairs({ "c", "x" }) do
    fixture.cursor(widget, path .. "/a.lua")
    press(widget, keys)
    t.wait_until(function()
      return #prompts == index
    end, 10000)
    fixture.idle(widget)
    local name = keys == "c" and "a-copy.lua" or "a.lua"
    t.assert_eq(dot.path.relative(dot.path.cwd(), path .. "/" .. name, "/"), prompts[index].default)
    selected(widget, nil, 0)
  end
  press(widget, "<Tab>")
  selected(widget, "select", 1)
  press(widget, "c")
  selected(widget, "copy", 1)
  press(widget, "x")
  selected(widget, "cut", 1)
  fixture.cursor(widget, path .. "/b.lua")
  press(widget, "c")
  selected(widget, "copy", 2)
  t.assert_eq(2, #prompts, "marked sources must not open a path prompt")
end)

t:test("normal mark batches retain key-time targets while frame publication is delayed", function()
  local path = fixture.directory()
  for _, name in ipairs({ "a", "b", "c" }) do
    fixture.write(path .. "/" .. name)
  end
  local widget = fixture.widget(path)
  fixture.cursor(widget, path .. "/a")
  fixture.idle(widget)
  local session, view = widget:context()
  local frame = view:frame()
  local resume = t:patch_table(view, "_poll", function() end)
  press(widget, "<Tab><Tab>")
  t.assert_eq(0, await(session.state:inspect_selection()).summary.known_roots)
  press(widget, "<Tab>j<Tab>")
  local result = await(session.state:inspect_selection())
  t.assert_eq(2, result.summary.known_roots)
  t.assert_eq(frame, view:frame())
  local nodes = result.subtree_roots:slice(1, 2)
  local paths = {}
  for _, node in ipairs(nodes) do
    paths[#paths + 1] = session.data:inspect(result.source, node):path()
  end
  table.sort(paths)
  t.assert_true(vim.deep_equal({ path .. "/a", path .. "/b" }, paths))
  resume()
  view:_poll()
  selected(widget, "select", 2)
  t.assert_eq(0, #fixture.messages)
end)

t:test("fold batches use preceding commits and a manual cursor move keeps its own target", function()
  local path = fixture.directory()
  vim.fn.mkdir(path .. "/a/child/leaf", "p")
  vim.fn.mkdir(path .. "/b/nested", "p")
  fixture.write(path .. "/a/child/leaf/file")
  fixture.write(path .. "/b/nested/file")
  local widget = fixture.widget(path, { o_flag_foldempty = stl.c.Observable.from_value(false) })
  await(widget:reveal(path .. "/a/child/leaf/file"))
  await(widget:reveal(path .. "/b/nested/file"))
  local session, view = widget:context()
  local a = await(session.data:resolve(path .. "/a"))
  local b = await(session.data:resolve(path .. "/b"))
  local child = fixture.cursor(widget, path .. "/a/child")
  fixture.idle(widget)
  for _, keys in ipairs({ "ll", "zz" }) do
    press(widget, keys)
    await(session.state:inspect_selection())
    fixture.idle(widget)
    local frame = view:frame()
    local row = frame:position(child:node())
    t.assert_true(frame:rows(row, row).expanded[1])
  end
  press(widget, "hh")
  await(session.state:inspect_selection())
  fixture.idle(widget)
  local frame = view:frame()
  t.assert_eq(nil, frame:position(child:node()))
  local row = frame:position(a:node())
  t.assert_false(frame:rows(row, row).expanded[1])
  local resume = t:patch_table(view, "_poll", function() end)
  vim.api.nvim_win_set_cursor(view.winnr, { row, 0 })
  press(widget, "l")
  vim.api.nvim_win_set_cursor(view.winnr, { frame:position(b:node()), 0 })
  press(widget, "h")
  await(session.state:inspect_selection())
  resume()
  view:_poll()
  fixture.idle(widget)
  frame = view:frame()
  row = frame:position(a:node())
  t.assert_true(frame:rows(row, row).expanded[1])
  row = frame:position(b:node())
  t.assert_false(frame:rows(row, row).expanded[1])
  t.assert_eq(0, #fixture.messages)
end)

t:test("a rejected mark is reported once and late replies do not reopen a disposed view", function()
  local path = fixture.directory()
  fixture.write(path .. "/a")
  local widget = fixture.widget(path)
  local session, view = widget:context()
  local task = await(session.state:lock_selection())
  local before = #fixture.messages
  press(widget, "<Tab>")
  t.wait_until(function()
    return view._submission == nil and #fixture.messages > before
  end, 10000)
  t.assert_eq(before + 1, #fixture.messages)
  await(task:unlock())
  local first = widget._action:mark("select")
  local second = widget._action:mark("select")
  widget:dispose()
  await(first)
  await(second)
  t.assert_true(view._closed)
  t.assert_false(vim.api.nvim_buf_is_valid(view.bufnr))
  t.assert_eq(before + 1, #fixture.messages)
end)

t:test("explicit mark keys and Tab preserve a selected item when leaving copy or cut", function()
  local path = fixture.directory()
  fixture.write(path .. "/a")
  fixture.write(path .. "/b")
  local widget = fixture.widget(path)
  local _, view = widget:context()
  fixture.cursor(widget, path .. "/a")
  press(widget, "mc")
  selected(widget, "copy", 1)
  local revision = view:frame():header().selection_revision
  press(widget, "mx")
  selected(widget, "cut", 1)
  press(widget, "ms")
  selected(widget, "select", 1)
  t.assert_eq(revision, view:frame():header().selection_revision, "changing purpose must preserve the selection stamp")
  press(widget, "mc")
  selected(widget, "copy", 1)
  press(widget, "<Tab>")
  selected(widget, "select", 1)
  t.assert_eq(revision, view:frame():header().selection_revision)
  press(widget, "<Tab>")
  selected(widget, nil, 0)
  press(widget, "mx")
  selected(widget, "cut", 1)
  fixture.cursor(widget, path .. "/b")
  press(widget, "<Tab>")
  selected(widget, "select", 2)
  press(widget, "ms")
  selected(widget, "select", 1)
end)

t:test("double Escape cancels transfer before clearing selection and handles queued copy", function()
  local path = fixture.directory()
  fixture.write(path .. "/a")
  fixture.write(path .. "/b")
  local widget = fixture.widget(path)
  local session, view = widget:context()
  local peer = fixture.widget(path, { session = session })
  local _, peer_view = peer:context()
  widget:focus()
  for _, purpose in ipairs({ "copy", "cut" }) do
    local a = fixture.cursor(widget, path .. "/a")
    await(widget._action:mark(purpose))
    selected(widget, purpose, 1)
    local revision = view:frame():header().selection_revision
    fixture.cursor(widget, path .. "/b")
    if purpose == "copy" then
      vim.cmd.normal({ args = { "V" }, bang = true })
    end
    press(widget, "<Esc><Esc>")
    selected(widget, "select", 1)
    t.wait_until(function()
      return session:mode(peer_view:frame()) == "select"
    end, 10000)
    t.assert_eq("n", vim.api.nvim_get_mode().mode)
    t.assert_eq(revision, view:frame():header().selection_revision)
    t.assert_eq(a:node(), await(session.state:inspect_selection()).subtree_roots:get(1))
    press(widget, "<Esc><Esc>")
    selected(widget, nil, 0)
  end
  fixture.cursor(widget, path .. "/a")
  press(widget, "y<Esc><Esc>")
  selected(widget, "select", 1)
end)

t:test("double Escape preserves a locked transfer instead of cancelling its task", function()
  local path = fixture.directory()
  fixture.write(path .. "/a")
  local widget = fixture.widget(path)
  local session = widget:context()
  fixture.cursor(widget, path .. "/a")
  await(widget._action:mark("copy"))
  selected(widget, "copy", 1)
  local task = await(session.state:lock_selection())
  t:defer(function()
    await(task:unlock())
  end)
  local before = #fixture.messages
  press(widget, "<Esc><Esc>")
  t.wait_until(function()
    return #fixture.messages > before
  end, 10000)
  t.assert_true(session.state:status().locked)
  selected(widget, "copy", 1)
end)

t:test("accepting the copy default duplicates the cursor file and cut uses the supplied path", function()
  local path = fixture.directory()
  fixture.write(path .. "/a.lua")
  local widget = fixture.widget(path)
  t:patch_table(vim.ui, "input", function(options, done)
    done(options.default)
  end)
  fixture.cursor(widget, path .. "/a.lua")
  selected(widget, nil, 0)
  await(widget._action:transfer("copy"))
  fixture.idle(widget)
  t.assert_true(vim.uv.fs_stat(path .. "/a-copy.lua") ~= nil)
  t.assert_true(vim.uv.fs_stat(path .. "/a.lua") ~= nil)
  t:patch_table(vim.ui, "input", function(_, done)
    done(path .. "/moved.lua")
  end)
  fixture.cursor(widget, path .. "/a.lua")
  selected(widget, nil, 0)
  await(widget._action:transfer("cut"))
  fixture.idle(widget)
  t.assert_nil(vim.uv.fs_stat(path .. "/a.lua"))
  t.assert_true(vim.uv.fs_stat(path .. "/moved.lua") ~= nil)
end)

t:test("a queued selection change cannot turn a cursor path operation into a selected operation", function()
  local path = fixture.directory()
  fixture.write(path .. "/a")
  fixture.write(path .. "/b")
  local widget = fixture.widget(path)
  local session = widget:context()
  local a = fixture.cursor(widget, path .. "/a")
  local notify = session.notify
  local changed = false
  t:patch_table(session, "notify", function(self)
    if self.preparing and not changed then
      changed = true
      self.state:select_node({ a:node() }, true)
    end
    notify(self)
  end)
  local prompted = false
  t:patch_table(vim.ui, "input", function(_, done)
    prompted = true
    done(nil)
  end)
  local future = widget._action:transfer("copy")
  t.wait_until(function()
    return future:is_done()
  end, 10000)
  t.assert_true(future:is_failed())
  t.assert_true(future:get_error():find("selection intent changed", 1, true) ~= nil)
  t.assert_false(prompted)
  t.assert_false(session:busy())
  selected(widget, "select", 1)
end)

t:test("help shows effective Treeview keys, refresh aliases and local overrides without changing selection", function()
  local path = fixture.directory()
  fixture.write(path .. "/file")
  local widget = fixture.widget(path)
  local _, view = widget:context()
  press(widget, "mc")
  selected(widget, "copy", 1)
  ---@type stl.t.IKeymap[]
  local overrides = {
    { modes = { "n", "x" }, key = "[i", desc = "Explorer: custom parent", callback = function() end },
    { modes = { "n", "x" }, key = "g", desc = "wk-trigger", callback = function() end },
  }
  stl.nvim.fn.bindkeys(overrides, { bufnr = view.bufnr, noremap = true, silent = true })
  local Keysheet = require("era.view.keysheet")
  local create, sheet = Keysheet.new, nil
  t:patch_table(Keysheet, "new", function(props)
    sheet = create(props)
    return sheet
  end)
  t:defer(function()
    if sheet then
      sheet:dispose()
    end
  end)
  press(widget, "?")
  t.assert_true(sheet and sheet:isvisible())
  local entries, descriptions = {}, {}
  for _, keymap in ipairs(sheet._keymaps) do
    local key = vim.keycode(keymap.key)
    local id = key .. "\0" .. keymap.desc
    t.assert_nil(descriptions[id], "help must merge the shared Normal/Visual descriptions")
    descriptions[id] = true
    entries[key] = entries[key] or {}
    table.insert(entries[key], keymap)
  end
  local escape = assert(entries[vim.keycode("<Esc><Esc>")])
  t.assert_eq(1, #escape)
  local clear = escape[1]
  t.assert_eq("cancel transfer or clear selection", clear.desc)
  t.assert_eq("n,x", table.concat(clear.modes, ","))
  t.assert_eq(1, #entries["[i"])
  t.assert_eq("custom parent", entries["[i"][1].desc)
  t.assert_eq("n,x", table.concat(entries["[i"][1].modes, ","))
  for _, key in ipairs({ "R", "<C-a>r", "<D-r>", "<M-r>" }) do
    local aliases = assert(entries[vim.keycode(key)])
    t.assert_eq(1, #aliases)
    t.assert_eq("refresh", aliases[1].desc)
  end
  t.assert_eq(2, #entries["c"], "Normal and Visual copy have different actions")
  t.assert_eq("add range to copy selection", entries["c"][2].desc)
  t.assert_eq(2, #entries["y"], "copy aliases keep their Normal and Visual actions")
  t.assert_eq("add range to copy selection", entries["y"][2].desc)
  t.assert_eq("toggle selected-only view", entries["t1"][1].desc)
  t.assert_eq("switch Tree/List view", entries["t2"][1].desc)
  t.assert_eq("toggle directory compression", entries["t3"][1].desc)
  t.assert_eq("toggle hidden files", entries["t4"][1].desc)
  t.assert_nil(entries["g"], "which-key prefix triggers are not Explorer actions")
  local text = table.concat(vim.api.nvim_buf_get_lines(sheet._bufnr, 0, -1, false), "\n")
  t.assert_true(text:find("<Esc><Esc>", 1, true) ~= nil)
  t.assert_true(text:find("<Space>", 1, true) ~= nil)
  t.assert_false(text:find("Explorer:", 1, true) ~= nil)
  sheet:close()
  selected(widget, "copy", 1)
end)

t:test("leader toggle wins over the Space menu with separately typed keys and after which-key", function()
  local path = fixture.directory()
  fixture.write(path .. "/file")
  local ui = require("__test__.support.ui").new()
  t:defer(function()
    ui:close()
  end)
  ui:rpc("nvim_ui_attach", 100, 30, { rgb = true, ext_linegrid = true })
  ui:rpc(
    "nvim_exec_lua",
    [=[
    local root, path = ...
    vim.opt.runtimepath:prepend(root)
    local system = vim.uv.os_uname().sysname
    local library = system == "Windows_NT" and "yoz.dll" or (system == "Darwin" and "libyoz.dylib" or "libyoz.so")
    yoz = assert(package.loadlib(root .. "/rust/target/debug/" .. library, "luaopen_yoz"))()
    stl, dot, era = require("stl"), require("dot"), require("era")
    dot.path.workspace = function() return path end
    dot.path.is_git_repo = function() return false end
    vim.g.mapleader, vim.o.timeoutlen = " ", 300
    errors, menus, toggles = {}, 0, 0
    stl.reporter.warn = function(value) errors[#errors + 1] = value.message end
    stl.reporter.error = stl.reporter.warn
    stl.reporter.info = function() end
    vim.ui.select = function(_, options, done)
      assert(options.prompt == "Explorer actions")
      menus = menus + 1
      menu_at = vim.uv.hrtime()
      done(nil)
    end
    entry = require("era.widget.explorer")
    vim.keymap.set("n", "<leader>1", function()
      toggles = toggles + 1
      entry.toggle()
    end, { desc = "explorer: toggle" })
    whichkey = era.dressing.whichkey
    whichkey.state.setup()
    whichkey.state.enable()
    entry.focus()
    widget = entry.get_widget()
    assert(vim.wait(10000, function()
      local current = widget._views[vim.api.nvim_get_current_tabpage()]
      return current and current:frame() and current:frame():header().row_count == 1
    end))
  ]=],
    { assert(vim.uv.cwd()), path }
  )
  for cycle = 1, 2 do
    ui:rpc("nvim_input", "[")
    t.wait_until(function()
      return ui:rpc("nvim_exec_lua", "return whichkey.state.keys == '['", {})
    end, 10000)
    ui:rpc("nvim_input", "i")
    t.wait_until(function()
      return ui:rpc("nvim_exec_lua", "return whichkey.state.keys == ''", {})
    end, 10000)
    t.assert_eq(0, ui:rpc("nvim_exec_lua", "return vim.fn.maparg(' ', 'n', false, true).nowait", {}))
    t.assert_eq(1, ui:rpc("nvim_exec_lua", "return vim.fn.maparg('z', 'n', false, true).nowait", {}))
    ui:rpc("nvim_input", " ")
    vim.wait(40, function()
      return false
    end, 5)
    ui:rpc("nvim_input", "1")
    t.wait_until(function()
      return ui:rpc(
        "nvim_exec_lua",
        "local expected = ...; return toggles == expected and not widget:isvisible()",
        { cycle * 2 - 1 }
      )
    end, 10000)
    t.assert_eq(0, ui:rpc("nvim_exec_lua", "return menus", {}))
    ui:rpc("nvim_input", " 1")
    t.wait_until(function()
      return ui:rpc(
        "nvim_exec_lua",
        [=[
        local expected = ...
        local view = widget._views[vim.api.nvim_get_current_tabpage()]
        return toggles == expected and view and view:frame() and view:frame():header().row_count == 1
      ]=],
        { cycle * 2 }
      )
    end, 10000)
  end
  ui:rpc("nvim_exec_lua", "menu_started = vim.uv.hrtime()", {})
  ui:rpc("nvim_input", " ")
  t.wait_until(function()
    return ui:rpc("nvim_exec_lua", "return menus == 1", {})
  end, 10000)
  t.assert_true(ui:rpc("nvim_exec_lua", "return menu_at - menu_started >= 200000000", {}))
  t.assert_eq(0, ui:rpc("nvim_exec_lua", "return #errors", {}))
  ui:rpc("nvim_exec_lua", "widget:dispose(); entry.widget = nil; whichkey.state.disable()", {})
end)

t:run()
