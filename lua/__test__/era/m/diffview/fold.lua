---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/era/m/diffview/fold.lua

local harness = require("__test__.harness")

local t = harness.new("era.m.diffview.fold")

t:patch_table(package.loaded, "era.m.diffview.config", {
  BUFOPTS_PANEL = {},
  BUFOPTS_SBS = {},
  TRACKED_WINOPTS = {},
  WINOPTS_SBS = {
    cursorbind = false,
    diff = false,
    foldcolumn = "0",
    foldenable = true,
    foldlevel = 0,
    foldmethod = "manual",
    scrollbind = false,
  },
})
t:patch_table(package.loaded, "era.m.diffview.util", {})

local pane_sbs = assert(loadfile("lua/era/m/diffview/pane/sbs.lua"))()

---@param keymaps                       stl.t.IKeymap[]
---@param key                           string
---@return boolean
local function invoke(keymaps, key)
  for _, candidate in ipairs(keymaps) do
    if candidate.key == key then
      candidate.callback()
      return true
    end
  end
  return false
end

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
  end, 500, "scheduled fold commands")
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

  t:_register_cleanup(function()
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
  end, 500, "expanded diff folds")
  t.assert_eq(panel_winnr, vim.api.nvim_get_current_win(), "panel focus after expand")

  normal(right_winnr, "zM")
  pane_sbs.apply_fold_unchanged_pair(left_winnr, right_winnr, false)
  t.wait_until(function()
    return not is_fold_closed(left_winnr) and not is_fold_closed(right_winnr)
  end, 500, "reapplied expanded diff folds")

  normal(left_winnr, "zR")
  normal(right_winnr, "zM")
  pane_sbs.apply_fold_unchanged_pair(left_winnr, right_winnr, true)
  t.wait_until(function()
    return is_fold_closed(left_winnr) and is_fold_closed(right_winnr)
  end, 500, "collapsed diff folds")
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
  end, 500, "latest fold policy applied")
  wait_for_scheduled()
end)

t:test("fold actions separate the current view from the global default", function()
  local default_fold_unchanged = true
  local dirty_count = 0
  t:patch_global("dot", {
    context = {
      diffview = {
        flag_fold_unchanges = {
          snapshot = function()
            return default_fold_unchanged
          end,
          next = function(_, value)
            default_fold_unchanged = value
          end,
        },
      },
    },
    state = {
      status = {
        dirtier_tabline = {
          mark_dirty = function()
            dirty_count = dirty_count + 1
          end,
        },
      },
    },
  })

  local function verify(kind)
    local applied = {} ---@type boolean[]
    local current = true
    local pane = {
      apply_fold_unchanged_pair = function(_, _, value)
        applied[#applied + 1] = value
      end,
    }
    t:patch_table(package.loaded, "era.m.diffview.data", {})
    t:patch_table(package.loaded, "era.m.diffview.layout", {})
    t:patch_table(package.loaded, "era.m.diffview.pane.sbs", pane)
    if kind == "workspace" then
      t:patch_table(package.loaded, "era.m.diffview.pane.changes", {})
      t:patch_table(package.loaded, "era.m.diffview.util", {})
      t:patch_table(package.loaded, "era.m.diffview.view.workspace.state", {})
      t:patch_table(package.loaded, "era.m.diffview.view.workspace.view", {})
    else
      t:patch_table(package.loaded, "era.m.diffview.config", {})
      t:patch_table(package.loaded, "era.m.diffview.pane.commits", {})
      t:patch_table(package.loaded, "era.m.diffview.view.commits.state", {})
      t:patch_table(package.loaded, "era.m.diffview.view.commits.view", {})
    end

    local action = assert(loadfile("lua/era/m/diffview/view/" .. kind .. "/action.lua"))()
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
    t.assert_true(default_fold_unchanged, kind .. " open preserves default")
    action.close_all_folds(ctx)
    t.assert_true(current, kind .. " current close")
    t.assert_true(default_fold_unchanged, kind .. " close preserves default")
    action.toggle_default_folds(ctx)
    t.assert_false(current, kind .. " default applied to current")
    t.assert_false(default_fold_unchanged, kind .. " default toggled")
    t.assert_eq("false,true,false", table.concat(vim.tbl_map(tostring, applied), ","), kind .. " applied policies")

    default_fold_unchanged = true
  end

  verify("workspace")
  verify("commits")
  t.assert_eq(2, dirty_count, "both defaults dirty the tabline")
end)

t:test("workspace status assigns fold default to flag 3 and untracked to flag 4", function()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local previous_filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr }) ---@type string
  vim.api.nvim_set_option_value("filetype", "diffview-changes-test", { buf = bufnr })
  t:_register_cleanup(function()
    vim.api.nvim_set_option_value("filetype", previous_filetype, { buf = bufnr })
  end)

  t:patch_global("stl", {
    icon = {
      git = { Git = "G" },
      symbols = {
        flag_fold = "F",
        flag_fold_empty_path = "E",
        flag_list = "L",
        flag_tree = "T",
        flag_untracked = "U",
      },
    },
    nvim = {
      fn = {
        btn = function(text)
          return text
        end,
        txt = function(text)
          return text
        end,
      },
      win = {
        is_float = function()
          return false
        end,
      },
    },
  })
  t:patch_global("dot", {
    G = {
      register_anonymous_fn = function()
        return "dot.G.test"
      end,
    },
    context = {
      diffview = {
        flag_fold_unchanges = {
          snapshot = function()
            return true
          end,
        },
        flag_foldempty = {
          snapshot = function()
            return true
          end,
        },
        flag_panel_viewtype = {
          snapshot = function()
            return "tree"
          end,
        },
        flag_untracked = {
          snapshot = function()
            return true
          end,
        },
      },
    },
  })
  t:patch_table(package.loaded, "era.m.diffview.config", { FT = { CHANGES = "diffview-changes-test" } })
  t:patch_table(package.loaded, "era.m.diffview.view.workspace.state", {
    get = function()
      return {
        get_entries = function()
          return {}
        end,
      }
    end,
  })
  t:patch_table(package.loaded, "era.m.diffview.view.workspace.view", {
    get_layout = function()
      return {}
    end,
    get_visible_entries = function(entries)
      return entries
    end,
  })

  local tabline = assert(loadfile("lua/era/m/diffview/view/workspace/tabline.lua"))()
  local text = tabline.status_component().render({}, 120)
  t.assert_true(text:find("F³", 1, true) ~= nil, "fold default flag")
  t.assert_true(text:find("U⁴", 1, true) ~= nil, "untracked flag")
end)

t:test("workspace fold keys control the current view while t3 changes the default", function()
  local calls = {} ---@type string[]
  t:patch_table(package.loaded, "era.m.diffview.view.workspace.action", {
    open_all_folds = function()
      calls[#calls + 1] = "open"
    end,
    close_all_folds = function()
      calls[#calls + 1] = "close"
    end,
    toggle_untracked = function()
      calls[#calls + 1] = "untracked"
    end,
    toggle_default_folds = function()
      calls[#calls + 1] = "default"
    end,
  })
  t:patch_table(package.loaded, "era.m.git.visual", {})

  local keymap = assert(loadfile("lua/era/m/diffview/view/workspace/keymap.lua"))()
  local ctx = {} ---@type era.m.diffview.view.workspace.IContext

  local changes = keymap.gen_changes(ctx)
  local sbs = keymap.gen_sbs(ctx)
  t.assert_true(invoke(changes, "zR"), "Changes zR")
  t.assert_true(invoke(changes, "zM"), "Changes zM")
  t.assert_true(invoke(changes, "zO"), "Changes zO alias")
  t.assert_true(invoke(changes, "zC"), "Changes zC alias")
  t.assert_true(invoke(changes, "t3"), "Changes fold default")
  t.assert_true(invoke(changes, "t4"), "Changes untracked flag")
  t.assert_true(invoke(sbs, "zR"), "SBS zR")
  t.assert_true(invoke(sbs, "zM"), "SBS zM")
  t.assert_true(invoke(sbs, "zO"), "SBS zO alias")
  t.assert_true(invoke(sbs, "zC"), "SBS zC alias")
  t.assert_eq(
    "open,close,open,close,default,untracked,open,close,open,close",
    table.concat(calls, ","),
    "workspace fold commands"
  )
end)

t:test("commits exposes current-view fold commands from every pane", function()
  local calls = {} ---@type string[]
  t:patch_table(package.loaded, "era.m.diffview.view.commits.action", {
    open_all_folds = function()
      calls[#calls + 1] = "open"
    end,
    close_all_folds = function()
      calls[#calls + 1] = "close"
    end,
    toggle_default_folds = function()
      calls[#calls + 1] = "default"
    end,
  })
  t:patch_table(package.loaded, "era.m.diffview.pane.commits", {})

  local keymap = assert(loadfile("lua/era/m/diffview/view/commits/keymap.lua"))()
  local ctx = {} ---@type era.m.diffview.view.commits.IContext

  for _, keymaps in ipairs({ keymap.gen_commits(ctx), keymap.gen_filetree(ctx), keymap.gen_sbs(ctx) }) do
    t.assert_true(invoke(keymaps, "zR"), "pane zR")
    t.assert_true(invoke(keymaps, "zM"), "pane zM")
  end
  t.assert_true(invoke(keymap.gen_sbs(ctx), "t3"), "SBS t3")
  t.assert_true(invoke(keymap.gen_sbs(ctx), "zC"), "SBS zC alias")
  t.assert_true(invoke(keymap.gen_sbs(ctx), "zO"), "SBS zO alias")
  t.assert_eq("open,close,open,close,open,close,default,close,open", table.concat(calls, ","), "commits fold commands")
end)

t:run()
