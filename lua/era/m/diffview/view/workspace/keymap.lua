---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.diffview.view.workspace.keymap" ---@type string

local action = require("era.m.diffview.view.workspace.action")

---Workspace view keymaps.
---@class era.m.diffview.view.workspace.keymap
local M = {}

----------------------------------------------------------------------------------------------------

---Generate keymaps for changes buffer
---@param ctx                            era.m.diffview.view.workspace.IContext
---@return stl.t.IKeymap[]
function M.gen_changes(ctx)
  ---@type stl.t.IKeymap[]
  return {
    { modes = { "n" }, key = "<2-LeftMouse>", desc = "diffview(workspace): Select entry / Toggle directory", callback = function() action.select(ctx) end },
    { modes = { "n" }, key = "<C-j>", desc = "diffview(workspace): Next file diff", callback = function() action.goto_next_entry(ctx) end },
    { modes = { "n" }, key = "<C-k>", desc = "diffview(workspace): Prev file diff", callback = function() action.goto_prev_entry(ctx) end },
    { modes = { "n" }, key = "<CR>", desc = "diffview(workspace): Select entry / Toggle directory", callback = function() action.select(ctx) end },
    { modes = { "n" }, key = "J", desc = "diffview(workspace): Next entry and select", callback = function() action.next_entry(ctx) end },
    { modes = { "n" }, key = "K", desc = "diffview(workspace): Previous entry and select", callback = function() action.prev_entry(ctx) end },
    { modes = { "n" }, key = "gf", desc = "diffview(workspace): Open file in previous tab", callback = function() action.goto_file(ctx) end },
    { modes = { "n" }, key = "gF", desc = "diffview(workspace): Open file in new tab", callback = function() action.goto_file_tab(ctx) end },
    { modes = { "n" }, key = "gr", desc = "diffview(workspace): Reset file (discard changes)", callback = function() action.reset(ctx) end },
    { modes = { "n" }, key = "gs", desc = "diffview(workspace): Stage file", callback = function() action.stage(ctx) end },
    { modes = { "n" }, key = "gu", desc = "diffview(workspace): Unstage file", callback = function() action.unstage(ctx) end },
    { modes = { "n" }, key = "g?", desc = "diffview(workspace): Show keymap help", callback = function() action.show_help(ctx) end },
    { modes = { "n" }, key = "q", desc = "diffview(workspace): Close diffview", callback = function() action.close(ctx) end },
    { modes = { "n" }, key = "t1", desc = "diffview(workspace): Toggle viewtype (tree/list)", callback = function() action.toggle_viewtype(ctx) end },
    { modes = { "n" }, key = "t2", desc = "diffview(workspace): Toggle fold empty dirs", callback = function() action.toggle_foldempty(ctx) end },
    { modes = { "n" }, key = "t3", desc = "diffview(workspace): Toggle fold unchanged hunks", callback = function() action.toggle_fold_unchanged(ctx) end },
    { modes = { "n" }, key = "za", desc = "diffview(workspace): Toggle fold", callback = function() action.toggle_fold(ctx) end },
    { modes = { "n" }, key = "zc", desc = "diffview(workspace): Close fold", callback = function() action.close_fold(ctx) end },
    { modes = { "n" }, key = "zC", desc = "diffview(workspace): Close all folds", callback = function() action.close_all_folds(ctx) end },
    { modes = { "n" }, key = "zM", desc = "diffview(workspace): Close all folds", callback = function() action.close_all_folds(ctx) end },
    { modes = { "n" }, key = "zo", desc = "diffview(workspace): Open fold", callback = function() action.open_fold(ctx) end },
    { modes = { "n" }, key = "zO", desc = "diffview(workspace): Open all folds", callback = function() action.open_all_folds(ctx) end },
    { modes = { "n" }, key = "zR", desc = "diffview(workspace): Open all folds", callback = function() action.open_all_folds(ctx) end },
    { modes = { "n" }, key = "<C-a>r", desc = "diffview(workspace): Refresh", callback = function() stl.async.run(function() action.refresh(ctx) end) end, aliases = { "<D-r>", "<M-r>" } },
  }
end

---Generate keymaps for sbs (side-by-side) buffers
---@param ctx                            era.m.diffview.view.workspace.IContext
---@return stl.t.IKeymap[]
function M.gen_sbs(ctx)
  ---@type stl.t.IKeymap[]
  return {
    { modes = { "n" }, key = "<C-j>", desc = "diffview(workspace): Next file diff", callback = function() action.goto_next_entry(ctx) end },
    { modes = { "n" }, key = "<C-k>", desc = "diffview(workspace): Prev file diff", callback = function() action.goto_prev_entry(ctx) end },
    { modes = { "n" }, key = "gf", desc = "diffview(workspace): Open file in previous tab", callback = function() action.goto_file(ctx) end },
    { modes = { "n" }, key = "gF", desc = "diffview(workspace): Open file in new tab", callback = function() action.goto_file_tab(ctx) end },
    { modes = { "n" }, key = "g?", desc = "diffview(workspace): Show keymap help", callback = function() action.show_help(ctx) end },
    { modes = { "n" }, key = "za", desc = "diffview(workspace): Toggle panel collapse", callback = function() action.sbs_toggle_collapse(ctx) end },
    { modes = { "n" }, key = "zc", desc = "diffview(workspace): Collapse panel item", callback = function() action.sbs_collapse(ctx) end },
    { modes = { "n" }, key = "zo", desc = "diffview(workspace): Expand panel item", callback = function() action.sbs_expand(ctx) end },
    { modes = { "n" }, key = "zC", desc = "diffview(workspace): Close all folds", callback = function() action.close_all_folds(ctx) end },
    { modes = { "n" }, key = "zM", desc = "diffview(workspace): Close all folds", callback = function() action.close_all_folds(ctx) end },
    { modes = { "n" }, key = "zO", desc = "diffview(workspace): Open all folds", callback = function() action.open_all_folds(ctx) end },
    { modes = { "n" }, key = "zR", desc = "diffview(workspace): Open all folds", callback = function() action.open_all_folds(ctx) end },
    { modes = { "n" }, key = "t3", desc = "diffview(workspace): Toggle fold unchanged hunks", callback = function() action.toggle_fold_unchanged(ctx) end },
    { modes = { "n" }, key = "<C-a>r", desc = "diffview(workspace): Refresh", callback = function() stl.async.run(function() action.refresh(ctx) end) end, aliases = { "<D-r>", "<M-r>" } },
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

---Setup keymaps for changes buffer
---@param ctx                            era.m.diffview.view.workspace.IContext
function M.setup_changes(ctx)
  local lyt = ctx.layout
  if not lyt.changes_bufnr or not vim.api.nvim_buf_is_valid(lyt.changes_bufnr) then
    return
  end

  local keymaps = M.gen_changes(ctx)
  apply_keymaps(lyt.changes_bufnr, keymaps)
end

---Setup keymaps for sbs buffers
---@param ctx                            era.m.diffview.view.workspace.IContext
---@param bufnr                          integer
function M.setup_sbs(ctx, bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local keymaps = M.gen_sbs(ctx)
  apply_keymaps(bufnr, keymaps)
end

----------------------------------------------------------------------------------------------------

---Get all keymaps for help display
---@param ctx                            era.m.diffview.view.workspace.IContext
---@return stl.t.IKeymap[]
function M.get_help_keymaps(ctx)
  local all = {} ---@type stl.t.IKeymap[]
  local seen = {} ---@type table<string, boolean>

  for _, km in ipairs(M.gen_changes(ctx)) do
    if not seen[km.key] then
      seen[km.key] = true
      all[#all + 1] = km
    end
  end

  for _, km in ipairs(M.gen_sbs(ctx)) do
    if not seen[km.key] then
      seen[km.key] = true
      all[#all + 1] = km
    end
  end

  return all
end

return M
