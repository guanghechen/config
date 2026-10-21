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
  for _, key in ipairs({ "t3", "zC", "zO" }) do
    assert(find(sbs, key), "side-by-side " .. key).callback()
  end
  t.assert_eq(
    "open_all_folds,close_all_folds,open_all_folds,close_all_folds,open_all_folds,close_all_folds,"
      .. "toggle_default_folds,close_all_folds,open_all_folds",
    diffview.names(calls),
    "commits fold commands"
  )
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

t:test("help keeps mappings with the same key in different modes", function()
  t:patch_table(keymap, "gen_commits", function()
    return { { modes = { "n" }, key = "test", desc = "normal", callback = function() end } }
  end)
  t:patch_table(keymap, "gen_filetree", function()
    return { { modes = { "x" }, key = "test", desc = "visual", callback = function() end } }
  end)
  t:patch_table(keymap, "gen_sbs", function()
    return {}
  end)

  local modes = {} ---@type table<string, boolean>
  for _, mapping in ipairs(keymap.get_help_keymaps(diffview.commits_context({}), diffview.recorder())) do
    for _, mode in ipairs(mapping.modes) do
      modes[mode] = true
    end
  end
  t.assert_true(modes.n, "normal mapping")
  t.assert_true(modes.x, "visual mapping")
end)

t:run()
