require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local pane_sbs = require("era.m.diffview.pane.sbs")

t:test("fold actions separate the current view from the global default", function()
  local default = dot.context.diffview.flag_fold_unchanges
  local initial = default:snapshot() ---@type boolean
  t:defer(function()
    default:next(initial)
  end)
  local dirty_count = 0
  t:patch_table(dot.state.status.dirtier_tabline, "mark_dirty", function()
    dirty_count = dirty_count + 1
  end)
  local applied = {} ---@type boolean[]
  t:patch_table(pane_sbs, "apply_fold_unchanged_pair", function(_, _, value)
    applied[#applied + 1] = value
  end)

  for _, kind in ipairs({ "workspace", "commits" }) do
    default:next(true)
    applied = {}
    local current = true
    local action = require("era.m.diffview.view." .. kind .. ".action")
    local ctx = {
      layout = { sbs_left_winnr = 11, sbs_right_winnr = 12 },
      state = {
        set_fold_unchanged = function(_, value)
          current = value
        end,
      },
    }

    action.open_all_folds(ctx)
    t.assert_false(current, kind .. " current open")
    t.assert_true(default:snapshot(), kind .. " open preserves default")
    action.close_all_folds(ctx)
    t.assert_true(current, kind .. " current close")
    t.assert_true(default:snapshot(), kind .. " close preserves default")
    action.toggle_default_folds(ctx)
    t.assert_false(current, kind .. " default applied to current")
    t.assert_false(default:snapshot(), kind .. " default toggled")
    t.assert_eq("false,true,false", table.concat(vim.tbl_map(tostring, applied), ","), kind .. " applied policies")
  end
  t.assert_eq(2, dirty_count, "both defaults dirty the tabline")
end)

t:run()
