require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local diffview = require("__test__.support.diffview")
local keymap = require("era.m.diffview.view.commits.keymap")

---@param keymaps                       stl.t.IKeymap[]
---@param key                           string
---@return stl.t.IKeymap|nil
local function find(keymaps, key)
  for _, mapping in ipairs(keymaps) do
    if mapping.key == key then
      return mapping
    end
  end
end

t:test("commit keys expose cross-page search, copy filepath and directory folds", function()
  local keymaps = keymap.gen_commits(diffview.commits_context({}), diffview.recorder())
  t.assert_true(find(keymaps, "g/") ~= nil, "g/ search keymap")
  t.assert_true(find(keymaps, "oc") ~= nil, "oc copy path keymap")
  for _, key in ipairs({ "za", "zc", "zo" }) do
    t.assert_true(find(keymaps, key) ~= nil, "directory fold keymap " .. key)
  end
end)

t:test("the commits pane sets the active commit with s, keeps <Tab> inert and shows details with oi", function()
  local action, calls = diffview.recorder()
  local keymaps = keymap.gen_commits(diffview.commits_context({}), action)
  assert(find(keymaps, "s")).callback()
  t.assert_eq("set_active_commit", diffview.names(calls))
  t.assert_eq(stl.fn.noop, assert(find(keymaps, "<Tab>")).callback, "<Tab> skips the global jump")
  assert(find(keymaps, "oi")).callback()
  t.assert_eq("set_active_commit,show_details", diffview.names(calls), "oi shows the commit details")
end)

t:test("the commit and file panes close with q and move with l and h, without oo", function()
  local action, calls = diffview.recorder()
  local ctx = diffview.commits_context({})
  local commits, files = keymap.gen_commits(ctx, action), keymap.gen_filetree(ctx, action)
  for _, key in ipairs({ "l", "h", "q" }) do
    assert(find(commits, key)).callback()
  end
  for _, key in ipairs({ "l", "q" }) do
    assert(find(files, key)).callback()
  end
  t.assert_eq("expand_or_select,collapse_or_parent,close,view_diff,close", diffview.names(calls))
  t.assert_eq(require("era.m.diffview.pane.filetree").goto_parent_node, assert(find(files, "h")).callback, "files h")
  t.assert_nil(find(commits, "oo"), "commits oo")
end)

t:test("every pane exposes the current view's fold commands", function()
  local action, calls = diffview.recorder()
  local ctx = diffview.commits_context({})
  for _, keymaps in ipairs({
    keymap.gen_commits(ctx, action),
    keymap.gen_filetree(ctx, action),
    keymap.gen_sbs(ctx, action),
  }) do
    assert(find(keymaps, "zR"), "pane zR").callback()
    assert(find(keymaps, "zM"), "pane zM").callback()
  end
  local sbs = keymap.gen_sbs(ctx, action)
  for _, key in ipairs({ "tz", "zC", "zO" }) do
    assert(find(sbs, key), "side-by-side " .. key).callback()
  end
  t.assert_eq(
    "open_all_folds,close_all_folds,open_all_folds,close_all_folds,open_all_folds,close_all_folds,"
      .. "toggle_default_folds,close_all_folds,open_all_folds",
    diffview.names(calls),
    "commits fold commands"
  )
end)

t:test("the commits pane toggles with the shared keys, and only the p keys switch layouts", function()
  local action, calls = diffview.recorder()
  local commits = keymap.gen_commits(diffview.commits_context({}), action)
  for _, key in ipairs({ "t2", "t3", "tz" }) do
    assert(find(commits, key), "commits " .. key).callback()
  end
  t.assert_eq("toggle_viewtype,toggle_foldempty,toggle_default_folds", diffview.names(calls))
  t.assert_nil(find(commits, "t0"), "no layout key among the toggles")
  t.assert_true(find(commits, "pp") ~= nil, "pp cycles the layouts")
end)

t:test("commit and file panes scroll the window under the mouse, and side-by-side buffers keep the wheel", function()
  local action, calls = diffview.recorder()
  local ctx = diffview.commits_context({})
  for _, keymaps in ipairs({ keymap.gen_commits(ctx, action), keymap.gen_filetree(ctx, action) }) do
    assert(find(keymaps, "<ScrollWheelDown>")).callback()
    assert(find(keymaps, "<ScrollWheelUp>")).callback()
    t.assert_nil(find(keymaps, "<C-d>"), "keyboard down")
    t.assert_nil(find(keymaps, "<C-u>"), "keyboard up")
  end
  local directions = {} ---@type string[]
  for _, call in ipairs(calls) do
    directions[#directions + 1] = call.args[1]
  end
  t.assert_eq("down,up,down,up", table.concat(directions, ","), "scroll directions")

  local sbs = keymap.gen_sbs(ctx, action)
  t.assert_nil(find(sbs, "<ScrollWheelDown>"), "side-by-side wheel down")
  t.assert_nil(find(sbs, "<ScrollWheelUp>"), "side-by-side wheel up")
end)

t:test("g? in every commits pane shows the keymap help of the pane it is pressed in", function()
  local shown = {} ---@type era.view.keysheet.IBufferProps[]
  t:patch_table(require("era.view.keysheet"), "for_buffer", function(props)
    shown[#shown + 1] = props
    return { open = function() end }
  end)
  local action = require("era.m.diffview.view.commits.action")
  local ctx = diffview.commits_context({})
  for _, keymaps in ipairs({
    keymap.gen_commits(ctx, action),
    keymap.gen_filetree(ctx, action),
    keymap.gen_sbs(ctx, action),
  }) do
    assert(find(keymaps, "g?")).callback()
  end
  t.assert_eq(3, #shown)
  for _, props in ipairs(shown) do
    t.assert_eq(vim.api.nvim_get_current_buf(), props.bufnr)
  end
end)

t:test("commits panes get mouse mappings each time they are created", function()
  diffview.repository(t)
  local session = diffview.open_log(t, { layout = 5 })
  local view = require("era.m.diffview.view.commits.view")
  local lyt = session.layout

  local first_commits_bufnr = assert(lyt.commits_bufnr) ---@type integer
  t.assert_true(diffview.mapping(first_commits_bufnr, "<ScrollWheelDown>") ~= nil, "initial commits mapping")
  view.hide_commits(lyt)
  t.assert_false(vim.api.nvim_buf_is_valid(first_commits_bufnr), "hidden commits buffer wiped")
  view.show_commits(session)
  t.assert_true(diffview.mapping(assert(lyt.commits_bufnr), "<ScrollWheelDown>") ~= nil, "recreated commits mapping")

  local first_filetree_bufnr = assert(lyt.filetree_bufnr) ---@type integer
  t.assert_true(diffview.mapping(first_filetree_bufnr, "<ScrollWheelDown>") ~= nil, "initial filetree mapping")
  view.hide_filetree(lyt)
  t.assert_false(vim.api.nvim_buf_is_valid(first_filetree_bufnr), "hidden filetree buffer wiped")
  view.show_filetree(session)
  t.assert_true(diffview.mapping(assert(lyt.filetree_bufnr), "<ScrollWheelDown>") ~= nil, "recreated filetree mapping")
end)

t:run()
