require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local diffview = require("__test__.support.diffview")
local pane_sbs = require("era.m.diffview.pane.sbs")

---@param winnr                         integer
---@param command                       string
local function normal(winnr, command)
  vim.api.nvim_win_call(winnr, function()
    vim.cmd("normal! " .. command)
  end)
end

---@param winnr                         integer
---@return boolean
local function is_fold_closed(winnr)
  return vim.api.nvim_win_call(winnr, function()
    return vim.fn.foldclosed(1) ~= -1
  end)
end

---@param winnr                         integer
---@param lines                         string[]
---@return integer
local function setup_fold_buffer(winnr, lines)
  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_win_set_buf(winnr, bufnr)
  vim.api.nvim_set_option_value("foldenable", true, { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("foldmethod", "manual", { win = winnr, scope = "local" })
  vim.api.nvim_win_call(winnr, function()
    vim.cmd("1,3fold")
  end)
  return bufnr
end

local function wait_for_scheduled()
  local done = false
  vim.schedule(function()
    vim.schedule(function()
      done = true
    end)
  end)
  t.wait_until(function()
    return done
  end, 5000, "scheduled fold commands")
end

t:test("side-by-side fold policy is deterministic and preserves panel focus", function()
  local panel_winnr = vim.api.nvim_get_current_win() ---@type integer
  local original_panel_bufnr = vim.api.nvim_win_get_buf(panel_winnr) ---@type integer
  vim.cmd("belowright split")
  local left_winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.cmd("belowright split")
  local right_winnr = vim.api.nvim_get_current_win() ---@type integer
  local lines = { "one", "two", "three", "four", "five" }
  local panel_bufnr = setup_fold_buffer(panel_winnr, lines) ---@type integer
  local left_bufnr = setup_fold_buffer(left_winnr, lines) ---@type integer
  local right_bufnr = setup_fold_buffer(right_winnr, lines) ---@type integer
  normal(panel_winnr, "zR")

  ---@diagnostic disable-next-line: invisible
  t:defer(function()
    for _, winnr in ipairs({ right_winnr, left_winnr }) do
      if vim.api.nvim_win_is_valid(winnr) then
        vim.api.nvim_win_close(winnr, true)
      end
    end
    if vim.api.nvim_win_is_valid(panel_winnr) then
      vim.api.nvim_win_set_buf(panel_winnr, original_panel_bufnr)
    end
    for _, bufnr in ipairs({ right_bufnr, left_bufnr, panel_bufnr }) do
      if vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_delete(bufnr, { force = true })
      end
    end
    if vim.api.nvim_win_is_valid(panel_winnr) then
      vim.api.nvim_set_current_win(panel_winnr)
    end
  end)

  normal(left_winnr, "zM")
  normal(right_winnr, "zM")
  vim.api.nvim_set_current_win(panel_winnr)
  pane_sbs.apply_fold_unchanged_pair(left_winnr, right_winnr, false)
  t.wait_until(function()
    return not is_fold_closed(left_winnr) and not is_fold_closed(right_winnr)
  end, 5000, "expanded diff folds")
  t.assert_eq(panel_winnr, vim.api.nvim_get_current_win(), "panel focus after expand")

  normal(right_winnr, "zM")
  pane_sbs.apply_fold_unchanged_pair(left_winnr, right_winnr, false)
  t.wait_until(function()
    return not is_fold_closed(left_winnr) and not is_fold_closed(right_winnr)
  end, 5000, "reapplied expanded diff folds")

  normal(left_winnr, "zR")
  normal(right_winnr, "zM")
  pane_sbs.apply_fold_unchanged_pair(left_winnr, right_winnr, true)
  t.wait_until(function()
    return is_fold_closed(left_winnr) and is_fold_closed(right_winnr)
  end, 5000, "collapsed diff folds")
  wait_for_scheduled()
  t.assert_eq(panel_winnr, vim.api.nvim_get_current_win(), "panel focus after collapse")
  t.assert_false(is_fold_closed(panel_winnr), "panel folds unchanged")

  local fold_unchanged = true
  pane_sbs.__apply_buffers__(left_winnr, right_winnr, left_bufnr, right_bufnr, {
    get_fold_unchanged = function()
      return fold_unchanged
    end,
  })
  fold_unchanged = false
  t.wait_until(function()
    return not is_fold_closed(left_winnr) and not is_fold_closed(right_winnr)
  end, 5000, "latest fold policy applied")
  wait_for_scheduled()
end)

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

t:test("workspace status assigns fold default to flag 3 and untracked to flag 4", function()
  diffview.repository(t)
  local session = diffview.open_workspace(t)

  local tabline = require("era.m.diffview.view.workspace.tabline")
  local component = tabline.status_component()
  local context = { tabnr = session.tabnr }
  local text = component.render(component.refresh(context), context, 120)
  t.assert_true(text:find(stl.icon.symbols.flag_fold .. "³", 1, true) ~= nil, "fold default flag")
  t.assert_true(text:find(stl.icon.symbols.flag_untracked .. "⁴", 1, true) ~= nil, "untracked flag")
end)

t:run()
