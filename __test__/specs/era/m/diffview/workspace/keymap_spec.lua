require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local diffview = require("__test__.support.diffview")
local keymap = require("era.m.diffview.view.workspace.keymap")

---@param keymaps                       stl.t.IKeymap[]
---@param key                           string
---@param mode                          ?string
---@return stl.t.IKeymap|nil
local function find(keymaps, key, mode)
  for _, mapping in ipairs(keymaps) do
    if mapping.key == key and (mode == nil or vim.list_contains(mapping.modes, mode)) then
      return mapping
    end
  end
end

---Both Changes buffers, as the workspace layout holds them; the case deletes them.
---@return era.m.diffview.view.workspace.IContext
local function changes_context()
  local staged = vim.api.nvim_create_buf(false, true)
  local unstaged = vim.api.nvim_create_buf(false, true)
  t:defer(function()
    vim.api.nvim_buf_delete(staged, { force = true })
    vim.api.nvim_buf_delete(unstaged, { force = true })
  end)
  return diffview.workspace_context({
    layout = {
      changes = {
        staged = { stage_type = "staged", bufnr = staged },
        unstaged = { stage_type = "unstaged", bufnr = unstaged },
      },
    },
  })
end

---Asserts that both Changes buffers map `keys` in Normal mode.
---@param ctx                           era.m.diffview.view.workspace.IContext
---@param keys                          string[]
---@return nil
local function assert_installed(ctx, keys)
  for _, pane in ipairs({ ctx.layout.changes.staged, ctx.layout.changes.unstaged }) do
    local mapped = {} ---@type table<string, boolean>
    for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(pane.bufnr, "n")) do
      mapped[mapping.lhs] = true
    end
    for _, key in ipairs(keys) do
      t.assert_true(mapped[key], key .. " installed in " .. pane.stage_type)
    end
  end
end

---@param bufnr                         integer
---@param key                           string
---@return boolean
local function has_buffer_keymap(bufnr, key)
  for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(bufnr, "n")) do
    if mapping.lhs == key then
      return true
    end
  end
  return false
end

t:test("side-by-side gs and gu stage and unstage the whole file, and both Changes buffers map them", function()
  local action, calls = diffview.recorder()
  local sbs = keymap.gen_sbs(diffview.workspace_context({ layout = {} }), action, diffview.recorder())
  assert(find(sbs, "gs")).callback()
  assert(find(sbs, "gu")).callback()
  t.assert_eq("stage,unstage", diffview.names(calls))

  local ctx = changes_context()
  keymap.setup_changes(ctx, action)
  assert_installed(ctx, { "gs", "gu" })
end)

t:test("side-by-side keys expose workspace mutations only for a Changes preview", function()
  local action, calls = diffview.recorder()
  local history_action, history_calls = diffview.recorder()
  local history = diffview.commits_context({})
  local ctx = diffview.workspace_context({ layout = { preview_source = "history" }, history = history })

  local for_history = keymap.gen_sbs(ctx, action, history_action)
  t.assert_nil(find(for_history, "gs"), "History preview excludes workspace mutation")
  assert(find(for_history, "<C-j>")).callback()
  t.assert_eq("goto_next_commit", diffview.names(history_calls), "History navigation")
  t.assert_true(history_calls[1].args[1] == history, "History context")

  ctx.layout.preview_source = "changes"
  local for_changes = keymap.gen_sbs(ctx, action, history_action)
  assert(find(for_changes, "gs")).callback()
  assert(find(for_changes, "<C-j>")).callback()
  t.assert_eq("stage,goto_next_entry", diffview.names(calls), "Changes preview")
end)

t:test("normal ghu unstages at the cursor and visual ghu the selected lines", function()
  local ranges = {} ---@type table[]
  local action = {
    unstage_hunk = function(_, range)
      ranges[#ranges + 1] = range or {}
      return stl.c.Future.resolve({ ok = true })
    end,
  }
  t:patch_table(stl.nvim.buf, "retrieve_visual_lnum_range", function()
    return 4, 6
  end)

  local sbs = keymap.gen_sbs(diffview.workspace_context({ layout = {} }), action, diffview.recorder())
  assert(find(sbs, "ghu", "n")).callback()
  assert(find(sbs, "ghu", "x")).callback()
  t.assert_eq(0, #ranges[1], "normal cursor range")
  t.assert_eq(4, ranges[2][1], "visual start")
  t.assert_eq(6, ranges[2][2], "visual end")
end)

t:test("visual ghu exits only after a successful unstage", function()
  local resolve_unstage = nil ---@type (fun(result: table): nil)|nil
  local action = {
    unstage_hunk = function()
      local future, resolve = stl.c.Future.new_with_resolver()
      resolve_unstage = resolve
      return future
    end,
  }
  t:patch_table(stl.nvim.buf, "retrieve_visual_lnum_range", function()
    return 1, 1
  end)
  local visual =
    assert(find(keymap.gen_sbs(diffview.workspace_context({ layout = {} }), action, diffview.recorder()), "ghu", "x"))

  local test_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  t:defer(function()
    vim.api.nvim_buf_delete(test_bufnr, { force = true })
  end)
  vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, { "one", "two" })
  vim.api.nvim_win_set_buf(0, test_bufnr)

  vim.cmd("normal! V")
  visual.callback()
  t.assert_eq("V", vim.fn.mode(), "selection while pending")
  assert(resolve_unstage)({ ok = true })
  t.assert_eq("n", vim.fn.mode(), "selection cleared after success")

  vim.cmd("normal! V")
  visual.callback()
  assert(resolve_unstage)({ ok = false, err = "failed" })
  t.assert_eq("V", vim.fn.mode(), "selection retained after failure")
  vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)

  vim.cmd("normal! ggV")
  visual.callback()
  vim.cmd("normal! j")
  vim.api.nvim_exec_autocmds("CursorMoved", { buffer = test_bufnr })
  vim.cmd("normal! k")
  assert(resolve_unstage)({ ok = true })
  t.assert_eq("V", vim.fn.mode(), "changed then restored selection retained after success")
  vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)

  vim.cmd("normal! V")
  visual.callback()
  local resolve_older_unstage = assert(resolve_unstage)
  visual.callback()
  local resolve_newer_unstage = assert(resolve_unstage)
  resolve_older_unstage({ ok = true })
  t.assert_eq("V", vim.fn.mode(), "older unstage keeps newer selection")
  resolve_newer_unstage({ ok = true })
  t.assert_eq("n", vim.fn.mode(), "newer unstage clears unchanged selection")
end)

t:test("fold keys control the current view while t3 changes the default", function()
  local action, calls = diffview.recorder()
  local ctx = diffview.workspace_context({ layout = {} })
  local changes = keymap.gen_changes(ctx, action)
  local sbs = keymap.gen_sbs(ctx, action, diffview.recorder())
  for _, key in ipairs({ "zR", "zM", "zO", "zC", "t3", "t4" }) do
    assert(find(changes, key), "Changes " .. key).callback()
  end
  for _, key in ipairs({ "zR", "zM", "zO", "zC" }) do
    assert(find(sbs, key), "side-by-side " .. key).callback()
  end
  t.assert_eq(
    "open_all_folds,close_all_folds,open_all_folds,close_all_folds,toggle_default_folds,toggle_untracked,"
      .. "open_all_folds,close_all_folds,open_all_folds,close_all_folds",
    diffview.names(calls),
    "workspace fold commands"
  )
end)

t:test("Changes keys scroll the window under the mouse, and side-by-side buffers keep the wheel", function()
  local action, calls = diffview.recorder()
  local ctx = diffview.workspace_context({ layout = {} })
  local changes = keymap.gen_changes(ctx, action)
  assert(find(changes, "<ScrollWheelDown>")).callback()
  assert(find(changes, "<ScrollWheelUp>")).callback()
  t.assert_nil(find(changes, "<C-d>"), "keyboard down")
  t.assert_nil(find(changes, "<C-u>"), "keyboard up")
  t.assert_eq("down,up", calls[1].args[1] .. "," .. calls[2].args[1], "scroll directions")

  local sbs = keymap.gen_sbs(ctx, action, diffview.recorder())
  t.assert_nil(find(sbs, "<ScrollWheelDown>"), "side-by-side wheel down")
  t.assert_nil(find(sbs, "<ScrollWheelUp>"), "side-by-side wheel up")

  -- A preview buffer carries the side-by-side keys of every view that shows it.
  local shared_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  t:defer(function()
    vim.api.nvim_buf_delete(shared_bufnr, { force = true })
  end)
  local sbs_keymap = require("era.m.diffview.view.sbs_keymap")
  local commits_keymap = require("era.m.diffview.view.commits.keymap")
  local function unresolved()
    return nil
  end
  sbs_keymap.setup(sbs, shared_bufnr, unresolved)
  sbs_keymap.setup(commits_keymap.gen_sbs(diffview.commits_context({}), diffview.recorder()), shared_bufnr, unresolved)
  t.assert_false(has_buffer_keymap(shared_bufnr, "<ScrollWheelDown>"), "shared side-by-side wheel mapping")
end)

t:test("History keys exclude standalone layout controls", function()
  local keymaps =
    keymap.gen_history(diffview.workspace_context({ history = {} }), diffview.recorder(), diffview.recorder())
  t.assert_true(find(keymaps, "K") ~= nil, "History details")
  t.assert_true(find(keymaps, "yy") ~= nil, "History commit hash")
  for _, key in ipairs({ "P", "p1", "p2", "p3", "p4", "p5", "pp", "t0" }) do
    t.assert_nil(find(keymaps, key), "standalone layout key " .. key)
  end
end)

t:test("help keeps normal and visual mappings for the same key", function()
  local ctx = diffview.workspace_context({ layout = {}, history = {} })
  local modes = {} ---@type table<string, boolean>
  for _, mapping in ipairs(keymap.get_help_keymaps(ctx, diffview.recorder(), diffview.recorder())) do
    if mapping.key == "ghu" then
      for _, mode in ipairs(mapping.modes) do
        modes[mode] = true
      end
    end
  end
  t.assert_true(modes.n, "normal ghu")
  t.assert_true(modes.x, "visual ghu")
end)

t:test("shared side-by-side mappings do not retain their installation context", function()
  local sbs_keymap = require("era.m.diffview.view.sbs_keymap")
  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  t:defer(function()
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)
  local retained = setmetatable({}, { __mode = "v" })
  local function install()
    local ctx = { payload = "installation context" }
    retained.ctx = ctx
    local probe = {
      modes = { "n" },
      key = "gz",
      desc = "gc probe",
      callback = function()
        return ctx
      end,
    }
    sbs_keymap.setup({ probe }, bufnr, function()
      return nil
    end)
  end

  install()
  collectgarbage("collect")
  collectgarbage("collect")
  t.assert_nil(retained.ctx, "installation context")
end)

t:test("the refresh key refreshes the session from every workspace pane", function()
  local refreshes = 0
  local ctx = diffview.workspace_context({
    layout = {},
    history = {},
    refresh = function()
      refreshes = refreshes + 1
    end,
  })
  local action, history_action = diffview.recorder(), diffview.recorder()
  for _, keymaps in ipairs({
    keymap.gen_changes(ctx, action),
    keymap.gen_sbs(ctx, action, history_action),
    keymap.gen_history(ctx, action, history_action),
  }) do
    assert(find(keymaps, "<C-a>r")).callback()
  end
  t.assert_eq(3, refreshes)
end)

t:test("Changes keys route explorer-style tree navigation and copy filepath in both buffers", function()
  local action, calls = diffview.recorder()
  local changes = keymap.gen_changes(diffview.workspace_context({}), action)
  for _, key in ipairs({ "[i", "]i", "oc" }) do
    assert(find(changes, key)).callback()
  end
  t.assert_eq("goto_parent_node,goto_last_child_or_sibling,copy_filepath", diffview.names(calls))

  local ctx = changes_context()
  keymap.setup_changes(ctx, action)
  assert_installed(ctx, { "[i", "]i", "oc" })
end)

t:run()
