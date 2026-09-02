---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.diffview.view.commits.keymap" ---@type string

local action = require("era.m.diffview.view.commits.action")
local pane_commits = require("era.m.diffview.pane.commits")

---Commits view keymaps.
---@class era.m.diffview.view.commits.keymap
local M = {}

----------------------------------------------------------------------------------------------------
-- Keymap generators
----------------------------------------------------------------------------------------------------

---Generate cross-pane keymaps (shared by all panes)
---@param ctx                            era.m.diffview.view.commits.IContext
---@return stl.t.IKeymap[]
function M.gen_cross_pane(ctx)
  ---@type stl.t.IKeymap[]
  return {
    { modes = { "n" }, key = "<C-a>r", desc = "diffview(commits): Refresh", callback = function() stl.async.run(function() action.refresh(ctx) end) end, aliases = { "<D-r>", "<M-r>" } },
    { modes = { "n" }, key = "<C-j>", desc = "diffview(commits): Next commit", callback = function() action.goto_next_commit(ctx) end },
    { modes = { "n" }, key = "<C-k>", desc = "diffview(commits): Prev commit", callback = function() action.goto_prev_commit(ctx) end },
    { modes = { "n" }, key = "P", desc = "diffview(commits): Previous layout", callback = function() action.prev_layout(ctx) end },
    { modes = { "n" }, key = "p1", desc = "diffview(commits): Layout 1: 󰯋 commits top + sbs", callback = function() action.switch_to_layout(ctx, 1) end },
    { modes = { "n" }, key = "p2", desc = "diffview(commits): Layout 2: 󰕭 commits left + sbs", callback = function() action.switch_to_layout(ctx, 2) end },
    { modes = { "n" }, key = "p3", desc = "diffview(commits): Layout 3: 󰯌 sbs only", callback = function() action.switch_to_layout(ctx, 3) end },
    { modes = { "n" }, key = "p4", desc = "diffview(commits): Layout 4: 󰊢 commits only", callback = function() action.switch_to_layout(ctx, 4) end },
    { modes = { "n" }, key = "p5", desc = "diffview(commits): Layout 5: 󰙅 commits + filetree", callback = function() action.switch_to_layout(ctx, 5) end },
    { modes = { "n" }, key = "pp", desc = "diffview(commits): Next layout", callback = function() action.cycle_layout(ctx) end },
    { modes = { "n" }, key = "zM", desc = "diffview(commits): Close all diff folds", callback = function() action.close_all_folds(ctx) end },
    { modes = { "n" }, key = "zR", desc = "diffview(commits): Open all diff folds", callback = function() action.open_all_folds(ctx) end },
    { modes = { "n" }, key = "t3", desc = "diffview(commits): Toggle default diff folds", callback = function() action.toggle_default_folds(ctx) end },
  }
end

---Generate keymaps for commits buffer
---@param ctx                            era.m.diffview.view.commits.IContext
---@return stl.t.IKeymap[]
function M.gen_commits(ctx)
  ---@type stl.t.IKeymap[]
  local keymaps = {
    { modes = { "n" }, key = "<2-LeftMouse>", desc = "diffview(commits): Select / Toggle expand", callback = function() action.select(ctx) end },
    { modes = { "n" }, key = "<ScrollWheelDown>", desc = "diffview(commits): Scroll window under mouse down", callback = function() action.scroll_mouse("down") end },
    { modes = { "n" }, key = "<ScrollWheelUp>", desc = "diffview(commits): Scroll window under mouse up", callback = function() action.scroll_mouse("up") end },
    { modes = { "n" }, key = "<CR>", desc = "diffview(commits): Select / Toggle expand", callback = function() action.select(ctx) end },
    { modes = { "n" }, key = "<Tab>", desc = "diffview(commits): Set as active commit", callback = function() action.set_active_commit(ctx) end },
    { modes = { "n" }, key = "K", desc = "diffview(commits): Show commit details", callback = function() action.show_details(ctx) end },
    { modes = { "n" }, key = "[[", desc = "diffview(commits): Previous page", callback = function() action.prev_page(ctx) end },
    { modes = { "n" }, key = "]]", desc = "diffview(commits): Next page", callback = function() action.next_page(ctx) end },
    { modes = { "n" }, key = "[i", desc = "diffview(commits): Go to parent node", callback = pane_commits.goto_parent_node },
    { modes = { "n" }, key = "]i", desc = "diffview(commits): Go to last child/sibling", callback = pane_commits.goto_last_child_or_sibling },
    { modes = { "n" }, key = "g?", desc = "diffview(commits): Show keymap help", callback = function() action.show_help(ctx) end },
    { modes = { "n" }, key = "gF", desc = "diffview(commits): Open file in new tab", callback = function() action.goto_file_tab(ctx) end },
    { modes = { "n" }, key = "gH", desc = "diffview(commits): Collapse all commits", callback = function() action.collapse_all(ctx) end },
    { modes = { "n" }, key = "gK", desc = "diffview(commits): Show commit details", callback = function() action.show_details(ctx) end },
    { modes = { "n" }, key = "gL", desc = "diffview(commits): Expand all commits", callback = function() action.expand_all(ctx) end },
    { modes = { "n" }, key = "g/", desc = "diffview(commits): Search commit", callback = function() action.search_commit(ctx) end },
    { modes = { "n" }, key = "gR", desc = "diffview(commits): Restore file to commit version", callback = function() action.restore_file(ctx) end },
    { modes = { "n" }, key = "gf", desc = "diffview(commits): Open file in previous tab", callback = function() action.goto_file(ctx) end },
    { modes = { "n" }, key = "gh", desc = "diffview(commits): Collapse commit", callback = function() action.collapse(ctx) end },
    { modes = { "n" }, key = "gl", desc = "diffview(commits): Expand commit", callback = function() action.expand(ctx) end },
    { modes = { "n" }, key = "oo", desc = "diffview(commits): Toggle expand commit", callback = function() action.toggle_expand(ctx) end },
    { modes = { "n" }, key = "t0", desc = "diffview(commits): Cycle layout (5 types)", callback = function() action.cycle_layout(ctx) end },
    { modes = { "n" }, key = "t1", desc = "diffview(commits): Toggle viewtype (tree/list)", callback = function() action.toggle_viewtype(ctx) end },
    { modes = { "n" }, key = "t2", desc = "diffview(commits): Toggle compact directory paths", callback = function() action.toggle_foldempty(ctx) end },
    { modes = { "n" }, key = "yy", desc = "diffview(commits): Yank commit hash", callback = function() action.yank_hash(ctx) end },
  }

  -- Append cross-pane keymaps
  for _, km in ipairs(M.gen_cross_pane(ctx)) do
    keymaps[#keymaps + 1] = km
  end

  return keymaps
end

---Generate keymaps for filetree buffer (in commits view)
---@param ctx                            era.m.diffview.view.commits.IContext
---@return stl.t.IKeymap[]
function M.gen_filetree(ctx)
  ---@type stl.t.IKeymap[]
  local keymaps = {
    { modes = { "n" }, key = "<2-LeftMouse>", desc = "diffview(commits): Select file", callback = function() action.view_diff(ctx) end },
    { modes = { "n" }, key = "<ScrollWheelDown>", desc = "diffview(commits): Scroll window under mouse down", callback = function() action.scroll_mouse("down") end },
    { modes = { "n" }, key = "<ScrollWheelUp>", desc = "diffview(commits): Scroll window under mouse up", callback = function() action.scroll_mouse("up") end },
    { modes = { "n" }, key = "<CR>", desc = "diffview(commits): Select file", callback = function() action.view_diff(ctx) end },
    { modes = { "n" }, key = "g?", desc = "diffview(commits): Show keymap help", callback = function() action.show_help(ctx) end },
    { modes = { "n" }, key = "gF", desc = "diffview(commits): Open file in new tab", callback = function() action.goto_file_tab(ctx) end },
    { modes = { "n" }, key = "gR", desc = "diffview(commits): Restore file to commit version", callback = function() action.restore_file(ctx) end },
    { modes = { "n" }, key = "gf", desc = "diffview(commits): Open file in previous tab", callback = function() action.goto_file(ctx) end },
    { modes = { "n" }, key = "t1", desc = "diffview(commits): Toggle viewtype (tree/list)", callback = function() action.toggle_viewtype(ctx) end },
    { modes = { "n" }, key = "t2", desc = "diffview(commits): Toggle compact directory paths", callback = function() action.toggle_foldempty(ctx) end },
  }

  -- Append cross-pane keymaps
  for _, km in ipairs(M.gen_cross_pane(ctx)) do
    keymaps[#keymaps + 1] = km
  end

  return keymaps
end

---Generate keymaps for sbs (side-by-side) buffers
---@param ctx                            era.m.diffview.view.commits.IContext
---@return stl.t.IKeymap[]
function M.gen_sbs(ctx)
  ---@type stl.t.IKeymap[]
  local keymaps = {
    { modes = { "n" }, key = "g?", desc = "diffview(commits): Show keymap help", callback = function() action.show_help(ctx) end },
    { modes = { "n" }, key = "gF", desc = "diffview(commits): Open file in new tab", callback = function() action.goto_file_tab(ctx) end },
    { modes = { "n" }, key = "gf", desc = "diffview(commits): Open file in previous tab", callback = function() action.goto_file(ctx) end },
    { modes = { "n" }, key = "zC", desc = "diffview(commits): Close all diff folds", callback = function() action.close_all_folds(ctx) end },
    { modes = { "n" }, key = "zO", desc = "diffview(commits): Open all diff folds", callback = function() action.open_all_folds(ctx) end },
    { modes = { "n" }, key = "za", desc = "diffview(commits): Toggle expand commit", callback = function() action.sbs_toggle_expand(ctx) end },
    { modes = { "n" }, key = "zc", desc = "diffview(commits): Collapse commit", callback = function() action.sbs_collapse(ctx) end },
    { modes = { "n" }, key = "zo", desc = "diffview(commits): Expand commit", callback = function() action.sbs_expand(ctx) end },
  }

  -- Append cross-pane keymaps
  for _, km in ipairs(M.gen_cross_pane(ctx)) do
    keymaps[#keymaps + 1] = km
  end

  return keymaps
end

----------------------------------------------------------------------------------------------------
-- Keymap application
----------------------------------------------------------------------------------------------------

---Apply keymaps to buffer
---@param bufnr                          integer
---@param keymaps                        stl.t.IKeymap[]
local function apply_keymaps(bufnr, keymaps)
  for _, km in ipairs(keymaps) do
    for _, mode in ipairs(km.modes) do
      vim.keymap.set(mode, km.key, km.callback, {
        buffer = bufnr,
        desc = km.desc,
        nowait = true,
        silent = true,
      })
      -- Apply aliases if any
      if km.aliases then
        for _, alias in ipairs(km.aliases) do
          vim.keymap.set(mode, alias, km.callback, {
            buffer = bufnr,
            desc = km.desc,
            nowait = true,
            silent = true,
          })
        end
      end
    end
  end
end

---Setup keymaps for commits buffer
---@param ctx                            era.m.diffview.view.commits.IContext
function M.setup_commits(ctx)
  local lyt = ctx.layout
  if not lyt.commits_bufnr or not vim.api.nvim_buf_is_valid(lyt.commits_bufnr) then
    return
  end

  local keymaps = M.gen_commits(ctx)
  apply_keymaps(lyt.commits_bufnr, keymaps)
end

---Setup keymaps for filetree buffer
---@param ctx                            era.m.diffview.view.commits.IContext
function M.setup_filetree(ctx)
  local lyt = ctx.layout
  if not lyt.filetree_bufnr or not vim.api.nvim_buf_is_valid(lyt.filetree_bufnr) then
    return
  end

  local keymaps = M.gen_filetree(ctx)
  apply_keymaps(lyt.filetree_bufnr, keymaps)
end

---Setup keymaps for sbs buffers
---@param ctx                            era.m.diffview.view.commits.IContext
---@param bufnr                          integer
function M.setup_sbs(ctx, bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local keymaps = M.gen_sbs(ctx)
  apply_keymaps(bufnr, keymaps)
end

----------------------------------------------------------------------------------------------------
-- Help keymaps
----------------------------------------------------------------------------------------------------

---Get all keymaps for help display
---@param ctx                            era.m.diffview.view.commits.IContext
---@return stl.t.IKeymap[]
function M.get_help_keymaps(ctx)
  local all = {} ---@type stl.t.IKeymap[]
  local seen = {} ---@type table<string, boolean>

  -- Add commits keymaps
  for _, km in ipairs(M.gen_commits(ctx)) do
    if not seen[km.key] then
      seen[km.key] = true
      all[#all + 1] = km
    end
  end

  -- Add filetree keymaps (only if not already added)
  for _, km in ipairs(M.gen_filetree(ctx)) do
    if not seen[km.key] then
      seen[km.key] = true
      all[#all + 1] = km
    end
  end

  -- Add sbs keymaps (only if not already added)
  for _, km in ipairs(M.gen_sbs(ctx)) do
    if not seen[km.key] then
      seen[km.key] = true
      all[#all + 1] = km
    end
  end

  return all
end

return M
