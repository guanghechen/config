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

t:test("accepting the copy default duplicates the cursor file and cut uses the supplied path", function()
  local path = fixture.directory()
  fixture.write(path .. "/a.lua")
  local widget = fixture.widget(path)
  t:patch_table(vim.ui, "input", function(options, done)
    done(options.default)
  end)
  fixture.cursor(widget, path .. "/a.lua")
  await(widget._action:transfer("copy"))
  fixture.idle(widget)
  t.assert_true(vim.uv.fs_stat(path .. "/a-copy.lua") ~= nil)
  t.assert_true(vim.uv.fs_stat(path .. "/a.lua") ~= nil)
  t:patch_table(vim.ui, "input", function(_, done)
    done(path .. "/moved.lua")
  end)
  fixture.cursor(widget, path .. "/a.lua")
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
  local lock = session.state.lock_selection
  t:patch_table(session.state, "lock_selection", function(state, deadline, revision)
    return state:select_node({ a:node() }, true):then_(function()
      return lock(state, deadline, revision)
    end)
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
  t.assert_true(future:get_error():find("selection revision changed", 1, true) ~= nil)
  t.assert_false(prompted)
  t.assert_false(session:busy())
  selected(widget, "select", 1)
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
