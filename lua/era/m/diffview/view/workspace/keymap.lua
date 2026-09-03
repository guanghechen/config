---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.diffview.view.workspace.keymap" ---@type string

local action = require("era.m.diffview.view.workspace.action")
local git_visual = require("era.m.git.visual")

---Workspace view keymaps.
---@class era.m.diffview.view.workspace.keymap
local M = {}

---@param ctx                            era.m.diffview.view.workspace.IContext
---@param workspace_callback             fun(ctx: era.m.diffview.view.workspace.IContext): any
---@param history_action                 string|nil
local function dispatch_preview(ctx, workspace_callback, history_action)
  if ctx.layout and ctx.layout.preview_source == "history" then
    if ctx.history and history_action then
      return require("era.m.diffview.view.commits.action")[history_action](ctx.history)
    end
    return
  end
  return workspace_callback(ctx)
end

---@param ctx                            era.m.diffview.view.workspace.IContext
local function refresh_workspace(ctx)
  ctx.state:request_refresh()
  if ctx.history then
    stl.async.run(function()
      require("era.m.diffview.view.commits.action").refresh(ctx.history)
    end)
  end
end

---Generate keymaps for changes buffer
---@param ctx                            era.m.diffview.view.workspace.IContext
---@return stl.t.IKeymap[]
function M.gen_changes(ctx)
  ---@type stl.t.IKeymap[]
  return {
    { modes = { "n" }, key = "<2-LeftMouse>", desc = "diffview(workspace): Select entry / Toggle directory", callback = function() action.select(ctx) end },
    { modes = { "n" }, key = "<ScrollWheelDown>", desc = "diffview(workspace): Scroll window under mouse down", callback = function() action.scroll_mouse("down") end },
    { modes = { "n" }, key = "<ScrollWheelUp>", desc = "diffview(workspace): Scroll window under mouse up", callback = function() action.scroll_mouse("up") end },
    { modes = { "n" }, key = "<C-j>", desc = "diffview(workspace): Next file diff", callback = function() action.goto_next_entry(ctx) end },
    { modes = { "n" }, key = "<C-k>", desc = "diffview(workspace): Prev file diff", callback = function() action.goto_prev_entry(ctx) end },
    { modes = { "n" }, key = "<CR>", desc = "diffview(workspace): Select entry / Toggle directory", callback = function() action.select(ctx) end },
    { modes = { "n" }, key = "J", desc = "diffview(workspace): Next entry and select", callback = function() action.next_entry(ctx) end },
    { modes = { "n" }, key = "K", desc = "diffview(workspace): Previous entry and select", callback = function() action.prev_entry(ctx) end },
    { modes = { "n" }, key = "[i", desc = "diffview(workspace): Go to parent node", callback = function() action.goto_parent_node() end },
    { modes = { "n" }, key = "]i", desc = "diffview(workspace): Go to last child/sibling", callback = function() action.goto_last_child_or_sibling() end },
    { modes = { "n" }, key = "gf", desc = "diffview(workspace): Open file in previous tab", callback = function() action.goto_file(ctx) end },
    { modes = { "n" }, key = "gF", desc = "diffview(workspace): Open file in new tab", callback = function() action.goto_file_tab(ctx) end },
    { modes = { "n" }, key = "gr", desc = "diffview(workspace): Reset file (discard changes)", callback = function() action.reset(ctx) end },
    { modes = { "n" }, key = "gs", desc = "diffview(workspace): Stage file / directory", callback = function() action.stage(ctx) end },
    { modes = { "n" }, key = "gu", desc = "diffview(workspace): Unstage file / directory", callback = function() action.unstage(ctx) end },
    { modes = { "n" }, key = "g?", desc = "diffview(workspace): Show keymap help", callback = function() action.show_help(ctx) end },
    { modes = { "n" }, key = "oc", desc = "diffview(workspace): Copy filepath", callback = function() action.copy_filepath() end },
    { modes = { "n" }, key = "q", desc = "diffview(workspace): Close diffview", callback = function() action.close(ctx) end },
    { modes = { "n" }, key = "t1", desc = "diffview(workspace): Toggle viewtype (tree/list)", callback = function() action.toggle_viewtype(ctx) end },
    { modes = { "n" }, key = "t2", desc = "diffview(workspace): Toggle compact directory paths", callback = function() action.toggle_foldempty(ctx) end },
    { modes = { "n" }, key = "t3", desc = "diffview(workspace): Toggle default diff folds", callback = function() action.toggle_default_folds(ctx) end },
    { modes = { "n" }, key = "t4", desc = "diffview(workspace): Toggle untracked files", callback = function() action.toggle_untracked(ctx) end },
    { modes = { "n" }, key = "za", desc = "diffview(workspace): Toggle fold", callback = function() action.toggle_fold(ctx) end },
    { modes = { "n" }, key = "zc", desc = "diffview(workspace): Close fold", callback = function() action.close_fold(ctx) end },
    { modes = { "n" }, key = "zC", desc = "diffview(workspace): Close all diff folds", callback = function() action.close_all_folds(ctx) end },
    { modes = { "n" }, key = "zM", desc = "diffview(workspace): Close all diff folds", callback = function() action.close_all_folds(ctx) end },
    { modes = { "n" }, key = "zo", desc = "diffview(workspace): Open fold", callback = function() action.open_fold(ctx) end },
    { modes = { "n" }, key = "zO", desc = "diffview(workspace): Open all diff folds", callback = function() action.open_all_folds(ctx) end },
    { modes = { "n" }, key = "zR", desc = "diffview(workspace): Open all diff folds", callback = function() action.open_all_folds(ctx) end },
    { modes = { "n" }, key = "<C-a>r", desc = "diffview(workspace): Refresh", callback = function() refresh_workspace(ctx) end, aliases = { "<D-r>", "<M-r>" } },
  }
end

---Generate keymaps for sbs (side-by-side) buffers
---@param ctx                            era.m.diffview.view.workspace.IContext
---@return stl.t.IKeymap[]
function M.gen_sbs(ctx)
  ---@type stl.t.IKeymap[]
  local keymaps = {
    { modes = { "n" }, key = "<C-j>", desc = "diffview(workspace): Next file diff", callback = function() dispatch_preview(ctx, action.goto_next_entry, "goto_next_commit") end },
    { modes = { "n" }, key = "<C-k>", desc = "diffview(workspace): Prev file diff", callback = function() dispatch_preview(ctx, action.goto_prev_entry, "goto_prev_commit") end },
    { modes = { "n" }, key = "gf", desc = "diffview(workspace): Open file in previous tab", callback = function() dispatch_preview(ctx, action.goto_file, "goto_file") end },
    { modes = { "n" }, key = "gF", desc = "diffview(workspace): Open file in new tab", callback = function() dispatch_preview(ctx, action.goto_file_tab, "goto_file_tab") end },
    { modes = { "n" }, key = "g?", desc = "diffview(workspace): Show keymap help", callback = function() action.show_help(ctx) end },
    { modes = { "n" }, key = "za", desc = "diffview(workspace): Toggle panel collapse", callback = function() dispatch_preview(ctx, action.sbs_toggle_collapse, "sbs_toggle_expand") end },
    { modes = { "n" }, key = "zc", desc = "diffview(workspace): Collapse panel item", callback = function() dispatch_preview(ctx, action.sbs_collapse, "sbs_collapse") end },
    { modes = { "n" }, key = "zo", desc = "diffview(workspace): Expand panel item", callback = function() dispatch_preview(ctx, action.sbs_expand, "sbs_expand") end },
    { modes = { "n" }, key = "zC", desc = "diffview(workspace): Close all diff folds", callback = function() dispatch_preview(ctx, action.close_all_folds, "close_all_folds") end },
    { modes = { "n" }, key = "zM", desc = "diffview(workspace): Close all diff folds", callback = function() dispatch_preview(ctx, action.close_all_folds, "close_all_folds") end },
    { modes = { "n" }, key = "zO", desc = "diffview(workspace): Open all diff folds", callback = function() dispatch_preview(ctx, action.open_all_folds, "open_all_folds") end },
    { modes = { "n" }, key = "zR", desc = "diffview(workspace): Open all diff folds", callback = function() dispatch_preview(ctx, action.open_all_folds, "open_all_folds") end },
    { modes = { "n" }, key = "t3", desc = "diffview(workspace): Toggle default diff folds", callback = function() dispatch_preview(ctx, action.toggle_default_folds, "toggle_default_folds") end },
    { modes = { "n" }, key = "t4", desc = "diffview(workspace): Toggle untracked files", callback = function() action.toggle_untracked(ctx) end },
    { modes = { "n" }, key = "<C-a>r", desc = "diffview(workspace): Refresh", callback = function() refresh_workspace(ctx) end, aliases = { "<D-r>", "<M-r>" } },
  }

  if ctx.layout == nil or ctx.layout.preview_source ~= "history" then
    vim.list_extend(keymaps, {
      { modes = { "n" }, key = "gs", desc = "diffview(workspace): Stage file", callback = function() action.stage(ctx) end },
      { modes = { "n" }, key = "gu", desc = "diffview(workspace): Unstage file", callback = function() action.unstage(ctx) end },
      { modes = { "n" }, key = "ghu", desc = "diffview(workspace): Unstage selected index line", callback = function() action.unstage_hunk(ctx) end },
      { modes = { "x" }, key = "ghu", desc = "diffview(workspace): Unstage selected index lines", callback = function() local start_lnum, end_lnum = stl.nvim.buf.retrieve_visual_lnum_range() local future = action.unstage_hunk(ctx, { start_lnum, end_lnum }) if future then git_visual.leave_on_success(future) end end },
    })
  end

  return keymaps
end

---Generate History bindings without the standalone commits view's layout controls.
---@param ctx                            era.m.diffview.view.workspace.IContext
---@return stl.t.IKeymap[]
function M.gen_history(ctx)
  local history = ctx.history
  if history == nil then
    return {}
  end

  local commits_action = require("era.m.diffview.view.commits.action")
  local pane_commits = require("era.m.diffview.pane.commits")
  return {
    { modes = { "n" }, key = "<2-LeftMouse>", desc = "diffview(history): Select / Toggle expand", callback = function() commits_action.select(history) end },
    { modes = { "n" }, key = "<ScrollWheelDown>", desc = "diffview(history): Scroll window under mouse down", callback = function() commits_action.scroll_mouse("down") end },
    { modes = { "n" }, key = "<ScrollWheelUp>", desc = "diffview(history): Scroll window under mouse up", callback = function() commits_action.scroll_mouse("up") end },
    { modes = { "n" }, key = "<CR>", desc = "diffview(history): Select / Toggle expand", callback = function() commits_action.select(history) end },
    { modes = { "n" }, key = "<Tab>", desc = "diffview(history): Set as active commit", callback = function() commits_action.set_active_commit(history) end },
    { modes = { "n" }, key = "K", desc = "diffview(history): Show commit details", callback = function() commits_action.show_details(history) end },
    { modes = { "n" }, key = "[[", desc = "diffview(history): Previous page", callback = function() commits_action.prev_page(history) end },
    { modes = { "n" }, key = "]]", desc = "diffview(history): Next page", callback = function() commits_action.next_page(history) end },
    { modes = { "n" }, key = "[i", desc = "diffview(history): Go to parent node", callback = pane_commits.goto_parent_node },
    { modes = { "n" }, key = "]i", desc = "diffview(history): Go to last child/sibling", callback = pane_commits.goto_last_child_or_sibling },
    { modes = { "n" }, key = "g?", desc = "diffview(workspace): Show keymap help", callback = function() action.show_help(ctx) end },
    { modes = { "n" }, key = "gF", desc = "diffview(history): Open file in new tab", callback = function() commits_action.goto_file_tab(history) end },
    { modes = { "n" }, key = "gH", desc = "diffview(history): Collapse all commits", callback = function() commits_action.collapse_all(history) end },
    { modes = { "n" }, key = "gK", desc = "diffview(history): Show commit details", callback = function() commits_action.show_details(history) end },
    { modes = { "n" }, key = "gL", desc = "diffview(history): Expand all commits", callback = function() commits_action.expand_all(history) end },
    { modes = { "n" }, key = "g/", desc = "diffview(history): Search commit", callback = function() commits_action.search_commit(history) end },
    { modes = { "n" }, key = "gR", desc = "diffview(history): Restore file to commit version", callback = function() commits_action.restore_file(history) end },
    { modes = { "n" }, key = "gf", desc = "diffview(history): Open file in previous tab", callback = function() commits_action.goto_file(history) end },
    { modes = { "n" }, key = "gh", desc = "diffview(history): Collapse commit", callback = function() commits_action.collapse(history) end },
    { modes = { "n" }, key = "gl", desc = "diffview(history): Expand commit", callback = function() commits_action.expand(history) end },
    { modes = { "n" }, key = "oo", desc = "diffview(history): Toggle expand commit", callback = function() commits_action.toggle_expand(history) end },
    { modes = { "n" }, key = "t1", desc = "diffview(history): Toggle viewtype (tree/list)", callback = function() commits_action.toggle_viewtype(history) end },
    { modes = { "n" }, key = "t2", desc = "diffview(history): Toggle compact directory paths", callback = function() commits_action.toggle_foldempty(history) end },
    { modes = { "n" }, key = "yy", desc = "diffview(history): Yank commit hash", callback = function() commits_action.yank_hash(history) end },
    { modes = { "n" }, key = "<C-a>r", desc = "diffview(workspace): Refresh", callback = function() refresh_workspace(ctx) end, aliases = { "<D-r>", "<M-r>" } },
    { modes = { "n" }, key = "<C-j>", desc = "diffview(history): Next commit", callback = function() commits_action.goto_next_commit(history) end },
    { modes = { "n" }, key = "<C-k>", desc = "diffview(history): Prev commit", callback = function() commits_action.goto_prev_commit(history) end },
    { modes = { "n" }, key = "zM", desc = "diffview(history): Close all diff folds", callback = function() commits_action.close_all_folds(history) end },
    { modes = { "n" }, key = "zR", desc = "diffview(history): Open all diff folds", callback = function() commits_action.open_all_folds(history) end },
    { modes = { "n" }, key = "t3", desc = "diffview(history): Toggle default diff folds", callback = function() commits_action.toggle_default_folds(history) end },
  }
end

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

---Setup keymaps for both Changes buffers.
---@param ctx                            era.m.diffview.view.workspace.IContext
function M.setup_changes(ctx)
  local keymaps = M.gen_changes(ctx)
  for _, pane in ipairs(require("era.m.diffview.view.workspace.view").get_changes_panes(ctx.layout)) do
    if pane.bufnr and vim.api.nvim_buf_is_valid(pane.bufnr) then
      apply_keymaps(pane.bufnr, keymaps)
    end
  end
end

---Setup keymaps for sbs buffers
---@param ctx                            era.m.diffview.view.workspace.IContext
---@param bufnr                          integer
function M.setup_sbs(ctx, bufnr)
  require("era.m.diffview.view.sbs_keymap").setup_workspace(ctx, bufnr)
end

---@param ctx                            era.m.diffview.view.workspace.IContext
function M.setup_history(ctx)
  local bufnr = ctx.layout.history.commits_bufnr ---@type integer|nil
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  apply_keymaps(bufnr, M.gen_history(ctx))
end

----------------------------------------------------------------------------------------------------

---Get all keymaps for help display
---@param ctx                            era.m.diffview.view.workspace.IContext
---@return stl.t.IKeymap[]
function M.get_help_keymaps(ctx)
  local all = {} ---@type stl.t.IKeymap[]
  local seen = {} ---@type table<string, boolean>

  for _, keymaps in ipairs({ M.gen_changes(ctx), M.gen_sbs(ctx), M.gen_history(ctx) }) do
    for _, km in ipairs(keymaps) do
      local unseen_modes = {} ---@type string[]
      for _, mode in ipairs(km.modes) do
        local identity = mode .. "\0" .. km.key ---@type string
        if not seen[identity] then
          seen[identity] = true
          unseen_modes[#unseen_modes + 1] = mode
        end
      end
      if #unseen_modes == #km.modes then
        all[#all + 1] = km
      elseif #unseen_modes > 0 then
        all[#all + 1] = vim.tbl_extend("force", {}, km, { modes = unseen_modes })
      end
    end
  end

  return all
end

return M
