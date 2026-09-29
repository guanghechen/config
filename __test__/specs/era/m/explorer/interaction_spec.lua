---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.m.explorer.interaction" ---@type string

local fixture = require("__test__.support.explorer").new("era.m.explorer.interaction")
local t, await, write, directory = fixture.t, fixture.await, fixture.write, fixture.directory

t:patch_table(dot.context.explorer.trash, "snapshot", function()
  return false
end)

---@param key                           string
---@return nil
local function press(key)
  vim.api.nvim_feedkeys(vim.keycode(key), "xt", false)
end

---@param session                       era.m.explorer.Session
---@param node                          ?string
---@param purpose                       ?string
---@return nil
local function assert_selection(session, node, purpose)
  local value = await(session.state:inspect_selection())
  t.assert_eq(node and 1 or 0, value.subtree_roots:len())
  if node then
    t.assert_eq(node, value.subtree_roots:get(1))
  end
  t.assert_eq(purpose, session.state:status().selection_purpose)
end

t:test("Enter and l open the cursor while explicit open uses and preserves the logical selection", function()
  local path = directory()
  write(path .. "/a")
  write(path .. "/b")
  assert(vim.uv.fs_mkdir(path .. "/dir", 448))
  write(path .. "/dir/file")
  local target = vim.api.nvim_get_current_win()
  t:patch_table(dot.win, "pick_sourcefile", function()
    return target
  end)
  local widget = fixture.widget(path)
  local session, view = widget:context()
  local a = fixture.cursor(widget, path .. "/a")
  await(widget._action:mark("copy"))
  for _, step in ipairs({ { "l", "b" }, { "o<CR>", "a" }, { "<CR>", "b" } }) do
    widget:focus()
    fixture.cursor(widget, path .. "/b")
    press(step[1])
    t.wait_until(function()
      return vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(target)) == vim.uv.fs_realpath(path .. "/" .. step[2])
    end, 10000)
    assert_selection(session, a:node(), "copy")
  end
  widget:focus()
  local dir = fixture.cursor(widget, path .. "/dir")
  for _, step in ipairs({ { "l", true }, { "<CR>", false } }) do
    press(step[1])
    t.wait_until(function()
      local row = view:frame():position(dir:node())
      return view:frame():rows(row, row).expanded[1] == step[2]
    end, 10000)
    t.assert_eq(vim.uv.fs_realpath(path .. "/b"), vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(target)))
    assert_selection(session, a:node(), "copy")
  end
end)

t:test("Visual oa exports its forward or backward range with or without existing copy marks", function()
  for _, case in ipairs({
    { keys = "Vj", marked = false },
    { keys = "Vk", marked = true },
    { keys = "v<C-v>j", marked = false },
    { keys = "V<C-v>k", marked = true },
  }) do
    local marked = case.marked
    local path = directory()
    for _, name in ipairs({ "a", "b", "c" }) do
      write(path .. "/" .. name)
    end
    local widget = fixture.widget(path)
    local session, view = widget:context()
    local a = fixture.cursor(widget, path .. "/a")
    if marked then
      await(widget._action:mark("copy"))
    end
    fixture.cursor(widget, path .. (marked and "/c" or "/b"))
    vim.cmd.normal({ args = { vim.keycode(case.keys) }, bang = true })
    local locations
    t:patch_table(era.fn, "add_locations_to_ai", function(value)
      locations = value
    end)
    press("oa")
    t.wait_until(function()
      return locations ~= nil and not view:_visual_mode()
    end, 10000)
    t.assert_eq(2, #locations)
    t.assert_eq(path .. "/b", locations[1].filepath)
    t.assert_eq(path .. "/c", locations[2].filepath)
    assert_selection(session, marked and a:node() or nil, marked and "copy" or nil)
    widget:dispose()
  end
end)

t:test("Visual d captures its range before confirmation and preserves unrelated cut marks", function()
  for _, case in ipairs({
    { keys = "Vj", marked = false },
    { keys = "Vk", marked = true },
    { keys = "v<C-v>j", marked = false },
    { keys = "V<C-v>k", marked = true },
  }) do
    local marked = case.marked
    local path = directory()
    for _, name in ipairs({ "a", "b", "c" }) do
      write(path .. "/" .. name)
    end
    local widget = fixture.widget(path)
    local session = widget:context()
    local a = fixture.cursor(widget, path .. "/a")
    if marked then
      await(widget._action:mark("cut"))
    end
    fixture.cursor(widget, path .. (marked and "/c" or "/b"))
    vim.cmd.normal({ args = { vim.keycode(case.keys) }, bang = true })
    local confirm, prompt
    t:patch_table(vim.ui, "input", function(options, done)
      prompt = options.prompt
      confirm = function()
        done("y")
      end
    end)
    press("d")
    t.wait_until(function()
      return confirm ~= nil
    end, 10000)
    t.assert_eq('Permanently delete 2 items?\n"b"\n"c"', prompt)
    t.assert_true(session.state:status().locked)
    assert_selection(session, marked and a:node() or nil, marked and "cut" or nil)
    vim.cmd.normal({ args = { vim.keycode("<Esc>") }, bang = true })
    fixture.cursor(widget, path .. "/a")
    confirm()
    fixture.idle(widget)
    t.assert_true(vim.uv.fs_stat(path .. "/a") ~= nil)
    t.assert_eq(nil, vim.uv.fs_stat(path .. "/b"))
    t.assert_eq(nil, vim.uv.fs_stat(path .. "/c"))
    assert_selection(session, marked and a:node() or nil, marked and "cut" or nil)
    widget:dispose()
  end
end)

t:test("Visual copy aliases, cut and toggle apply to their ranges and preserve unrelated marks", function()
  local path = directory()
  for _, name in ipairs({ "a", "b", "c" }) do
    write(path .. "/" .. name)
  end
  local widget = fixture.widget(path)
  local session, view = widget:context()
  t:defer(function()
    vim.cmd.normal({ args = { vim.keycode("<Esc>") }, bang = true })
  end)
  local a = fixture.cursor(widget, path .. "/a")
  await(widget._action:mark("copy"))
  for _, case in ipairs({
    { cursor = "b", keys = "v<C-v>j", action = "c", purpose = "copy", count = 3 },
    { cursor = "c", keys = "V<C-v>k", action = "x", purpose = "cut", count = 3 },
    { cursor = "b", keys = "Vj", action = "y", purpose = "copy", count = 3 },
    { cursor = "c", keys = "V<C-v>k", action = "x", purpose = "cut", count = 3 },
    { cursor = "b", keys = "v<C-v>j", action = "<Tab>", purpose = "cut", count = 1 },
  }) do
    fixture.cursor(widget, path .. "/" .. case.cursor)
    vim.cmd.normal({ args = { vim.keycode(case.keys) }, bang = true })
    press(case.action)
    local value = await(session.state:inspect_selection())
    t.assert_eq(case.count, value.subtree_roots:len(), case.action .. " must use the complete Visual-block range")
    t.assert_eq(case.purpose, session.state:status().selection_purpose)
    t.wait_until(function()
      return vim.api.nvim_get_mode().mode == "n" and session.state._native:applicable(view:frame())
    end, 10000)
  end
  assert_selection(session, a:node(), "cut")
end)

t:test("cancelling Visual delete preserves files and Normal d still consumes the logical selection", function()
  local path = directory()
  for _, name in ipairs({ "a", "b", "c" }) do
    write(path .. "/" .. name)
  end
  local widget = fixture.widget(path)
  local session, view = widget:context()
  local a = fixture.cursor(widget, path .. "/a")
  await(widget._action:mark("cut"))
  fixture.cursor(widget, path .. "/b")
  vim.cmd.normal({ args = { "Vj" }, bang = true })
  t:patch_table(vim.ui, "input", function(options, done)
    t.assert_eq('Permanently delete 2 items?\n"b"\n"c"', options.prompt)
    done(nil)
  end)
  press("d")
  fixture.idle(widget)
  t.assert_eq(nil, view:_visual_mode())
  for _, name in ipairs({ "a", "b", "c" }) do
    t.assert_true(vim.uv.fs_stat(path .. "/" .. name) ~= nil)
  end
  assert_selection(session, a:node(), "cut")
  t:patch_table(vim.ui, "input", function(options, done)
    t.assert_eq('Permanently delete "a"?', options.prompt)
    done("y")
  end)
  press("d")
  fixture.idle(widget)
  t.assert_eq(nil, vim.uv.fs_stat(path .. "/a"))
  t.assert_true(vim.uv.fs_stat(path .. "/b") ~= nil)
  t.assert_true(vim.uv.fs_stat(path .. "/c") ~= nil)
  assert_selection(session, nil, nil)
end)

t:test("Visual AI and delete treat a directory with its visible child as one subtree", function()
  local path = directory()
  write(path .. "/a")
  assert(vim.uv.fs_mkdir(path .. "/dir", 448))
  write(path .. "/dir/file")
  local widget = fixture.widget(path)
  local session, view = widget:context()
  local a = fixture.cursor(widget, path .. "/a")
  await(widget._action:mark("copy"))
  await(widget:reveal(path .. "/dir/file"))
  local child = await(session.data:resolve(path .. "/dir/file"))
  ---@return nil
  local function select_directory()
    local dir = fixture.cursor(widget, path .. "/dir")
    -- Reveal commits native state before the pane necessarily publishes its new rows/cursor.
    t.wait_until(function()
      local frame = view:frame()
      local row = frame:position(dir:node())
      return row
        and frame:position(child:node()) == row + 1
        and frame:header().cursor == dir:node()
        and session.state._native:applicable(frame)
    end, 10000, "the directory and its child must be displayed before entering Visual mode")
    vim.cmd.normal({ args = { "Vj" }, bang = true })
  end
  select_directory()
  local locations
  t:patch_table(era.fn, "add_locations_to_ai", function(value)
    locations = value
  end)
  press("oa")
  t.wait_until(function()
    return locations ~= nil and not view:_visual_mode()
  end, 10000)
  t.assert_eq(1, #locations)
  t.assert_eq(path .. "/dir", locations[1].filepath)
  assert_selection(session, a:node(), "copy")
  select_directory()
  t:patch_table(vim.ui, "input", function(options, done)
    t.assert_eq('Permanently delete "dir/"?', options.prompt)
    done("y")
  end)
  press("d")
  fixture.idle(widget)
  t.assert_eq(nil, vim.uv.fs_stat(path .. "/dir"))
  t.assert_true(vim.uv.fs_stat(path .. "/a") ~= nil)
  assert_selection(session, a:node(), "copy")
end)

t:test("a path replaced while Visual delete awaits confirmation is not retargeted", function()
  local path = directory()
  for _, name in ipairs({ "a", "b", "c" }) do
    write(path .. "/" .. name)
  end
  local widget = fixture.widget(path)
  local session = widget:context()
  local a = fixture.cursor(widget, path .. "/a")
  await(widget._action:mark("copy"))
  fixture.cursor(widget, path .. "/b")
  vim.cmd.normal({ args = { "Vj" }, bang = true })
  local confirm
  t:patch_table(vim.ui, "input", function(_, done)
    confirm = function()
      done("y")
    end
  end)
  press("d")
  t.wait_until(function()
    return confirm ~= nil
  end, 10000)
  assert(vim.uv.fs_rename(path .. "/b", path .. "/saved"))
  write(path .. "/b")
  confirm()
  fixture.idle(widget)
  t.assert_true(vim.uv.fs_stat(path .. "/a") ~= nil)
  t.assert_true(vim.uv.fs_stat(path .. "/b") ~= nil)
  t.assert_true(vim.uv.fs_stat(path .. "/saved") ~= nil)
  t.assert_eq(nil, vim.uv.fs_stat(path .. "/c"))
  t.assert_eq(1, session._counts.failed)
  assert_selection(session, a:node(), "copy")
end)

t:test("delete confirmation bounds named prompts and cancellation preserves all sources", function()
  local path = directory()
  for _, name in ipairs({ "a", "b", "c", "d", "e", "f", "g" }) do
    write(path .. "/" .. name)
  end
  local widget = fixture.widget(path)
  local session, view = widget:context()
  fixture.cursor(widget, path .. "/a")
  vim.cmd.normal({ args = { "V6j" }, bang = true })
  local marked = await(widget._action:mark("copy"))
  t.wait_until(function()
    return session.state._native:applicable(view:frame(), marked.revisions.commit)
  end, 10000)
  for _, trash in ipairs({ false, true }) do
    t:patch_table(dot.context.explorer.trash, "snapshot", function()
      return trash
    end)
    local prompt
    t:patch_table(vim.ui, "input", function(options, done)
      t.assert_eq("confirmation", options.inputtype)
      prompt = options.prompt
      done(nil)
    end)
    await(widget._action:delete())
    t.assert_eq(
      (trash and "Trash " or "Permanently delete ") .. '7 items?\n"a"\n"b"\n"c"\n"d"\n"e"\nand 2 more',
      prompt
    )
    t.assert_eq(7, await(session.state:inspect_selection()).subtree_roots:len())
    t.assert_eq("copy", session:mode())
    t.assert_false(session:busy())
    for _, name in ipairs({ "a", "b", "c", "d", "e", "f", "g" }) do
      t.assert_true(vim.uv.fs_stat(path .. "/" .. name) ~= nil)
    end
  end
end)

t:run()
