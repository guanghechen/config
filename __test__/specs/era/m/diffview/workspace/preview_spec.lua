require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local diffview = require("__test__.support.diffview")
local pane_sbs = require("era.m.diffview.pane.sbs")
local view = require("era.m.diffview.view.workspace.view")

t:test("workspace visibility filters untracked files without mutating the snapshot", function()
  local tracked = { filepath = "tracked.lua", stage_type = "unstaged", status = "M" }
  local untracked = { filepath = "untracked.lua", stage_type = "unstaged", status = "?" }
  local entries = { tracked, untracked }
  local flag_untracked = dot.context.diffview.flag_untracked
  local initial = flag_untracked:snapshot() ---@type boolean
  t:defer(function()
    flag_untracked:next(initial)
  end)

  flag_untracked:next(false)
  local visible = view.get_visible_entries(entries)
  t.assert_eq(1, #visible, "filtered count")
  t.assert_eq(tracked, visible[1], "tracked entry retained")
  t.assert_eq(2, #entries, "source snapshot retained")

  flag_untracked:next(true)
  t.assert_eq(entries, view.get_visible_entries(entries), "visible projection reuses the complete snapshot")
end)

t:test("workspace preview generation makes the latest request the sole writer", function()
  local requests = {} ---@type era.m.diffview.pane.sbs.IOpenDiffOpts[]
  local clear_is_current = nil ---@type (fun(): boolean)|nil
  local fold_unchanged = false
  t:patch_table(pane_sbs, "clear", function(_, _, opts)
    clear_is_current = opts.is_current
  end)
  t:patch_table(pane_sbs, "open_diff_entry", function(opts)
    requests[#requests + 1] = opts
  end)

  local left_winnr, right_winnr = diffview.sbs_windows(t)
  local disposed = false
  local ctx = diffview.workspace_context({
    layout = {
      tabnr = vim.api.nvim_get_current_tabpage(),
      layout_type = 1,
      sbs_left_winnr = left_winnr,
      sbs_right_winnr = right_winnr,
      preview_generation = 0,
    },
    state = {
      get_fold_unchanged = function()
        return fold_unchanged
      end,
      is_disposed = function()
        return disposed
      end,
    },
  })

  view.open_entry(ctx, { filepath = "a.lua", stage_type = "staged", status = "M" }, nil, {
    preserve_view = true,
  })
  view.open_entry(ctx, { filepath = "b.lua", stage_type = "staged", status = "M" })

  t.assert_false(requests[1].is_current(), "older request invalidated")
  t.assert_true(requests[2].is_current(), "latest request current")
  t.assert_true(requests[1].preserve_view, "preserve option forwarded")
  t.assert_false(requests[1].get_fold_unchanged(), "initial fold policy")
  fold_unchanged = true
  t.assert_true(requests[1].get_fold_unchanged(), "latest fold policy")

  disposed = true
  t.assert_false(requests[2].is_current(), "disposed workspace invalidates preview")
  disposed = false

  view.clear_sbs(ctx)
  t.assert_false(requests[2].is_current(), "clear invalidates open request")
  t.assert_true(assert(clear_is_current)(), "clear owns latest generation")
end)

t:test("workspace view binds keymaps after replacing null buffers", function()
  diffview.repository(t)
  local session = diffview.open_workspace(t)
  local lyt = session.layout
  view.clear_sbs(session)
  local mapped = {} ---@type integer[]
  local setup_sbs = session.setup_sbs
  t:patch_table(session, "setup_sbs", function(self, bufnr)
    mapped[#mapped + 1] = bufnr
    return setup_sbs(self, bufnr)
  end)

  local entry = assert(session.state:find_entry("a.txt", "unstaged"))
  stl.async.run(function()
    view.open_entry(session, entry)
  end)
  t.wait_until(function()
    return #mapped == 2
  end, 10000, "both previews mapped")

  t.assert_eq(vim.api.nvim_win_get_buf(lyt.sbs_left_winnr), mapped[1], "left replacement")
  t.assert_eq(vim.api.nvim_win_get_buf(lyt.sbs_right_winnr), mapped[2], "right replacement")
end)

t:run()
