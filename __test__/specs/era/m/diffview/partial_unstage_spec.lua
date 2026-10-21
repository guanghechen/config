require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local diffview = require("__test__.support.diffview")
local git = require("__test__.support.git")
local action = require("era.m.diffview.view.workspace.action")
local staging = require("era.m.git.staging")
local util = require("era.m.diffview.util")
local workspace_view = require("era.m.diffview.view.workspace.view")

t:test("workspace action forwards the right-buffer index snapshot", function()
  local root = diffview.committed(t, { ["f.txt"] = { "one", "two", "three", "four" } })
  diffview.write(root, "f.txt", { "one", "INDEX2", "INDEX3", "four" })
  git.run(root, { "add", "f.txt" })
  local session = diffview.open_workspace(t)
  local right_winnr = assert(session.layout.sbs_right_winnr)
  t.wait_until(function()
    local bufnr = vim.api.nvim_win_get_buf(right_winnr)
    return vim.api.nvim_buf_get_name(bufnr) == util.gen_index_bufname("f.txt") and vim.b[bufnr].git_object_name ~= nil
  end, 10000, "the index preview")

  local errors = {} ---@type string[]
  for _, level in ipairs({ "warn", "error" }) do
    t:patch_table(stl.reporter, level, function(report)
      errors[#errors + 1] = report.message
    end)
  end
  local captured = nil ---@type table|nil
  t:patch_table(era.m.git.buffer, "unstage_range", function(opts)
    captured = opts
    return stl.c.Future.resolve({ ok = true })
  end)
  local refreshed, opened = false, false
  t:patch_table(session.state, "request_refresh", function()
    refreshed = true
  end)
  t:patch_table(workspace_view, "open_entry", function()
    opened = true
  end)
  vim.api.nvim_set_current_win(right_winnr)

  local future = action.unstage_hunk(session, { 2, 3 })

  t.assert_true(future ~= nil, "unstage future")
  local unstage_opts = assert(captured, "unstage called")
  t.assert_eq(
    vim.trim(git.run(root, { "rev-parse", ":f.txt" })),
    unstage_opts.expected_index.object_name,
    "object snapshot"
  )
  t.assert_eq("one\nINDEX2\nINDEX3\nfour\n", unstage_opts.expected_index.document.text, "document snapshot")
  t.assert_eq(
    staging.from_buffer(vim.api.nvim_win_get_buf(right_winnr)).text,
    unstage_opts.expected_index.document.text,
    "the document of the right buffer"
  )
  t.assert_eq(2, unstage_opts.range[1], "range start")
  t.assert_eq(3, unstage_opts.range[2], "range end")
  t.assert_true(refreshed, "view refreshed")
  t.assert_false(opened, "refresh owns reopening")
  t.assert_eq(0, #errors, "no errors")
end)

t:test("workspace view binds keymaps after replacing null buffers", function()
  diffview.repository(t)
  local session = diffview.open_workspace(t)
  local lyt = session.layout
  workspace_view.clear_sbs(session)
  local mapped = {} ---@type integer[]
  local setup_sbs = session.setup_sbs
  t:patch_table(session, "setup_sbs", function(self, bufnr)
    mapped[#mapped + 1] = bufnr
    return setup_sbs(self, bufnr)
  end)

  local entry = assert(session.state:find_entry("a.txt", "unstaged"))
  stl.async.run(function()
    workspace_view.open_entry(session, entry)
  end)
  t.wait_until(function()
    return #mapped == 2
  end, 10000, "both previews mapped")

  t.assert_eq(vim.api.nvim_win_get_buf(lyt.sbs_left_winnr), mapped[1], "left replacement")
  t.assert_eq(vim.api.nvim_win_get_buf(lyt.sbs_right_winnr), mapped[2], "right replacement")
end)

t:run()
