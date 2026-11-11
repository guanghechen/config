---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.support.git_files" ---@type string

local bootstrap = require("__test__.support.bootstrap")
local fs = require("__test__.support.fs")
local git = require("__test__.support.git")
local Grid = require("__test__.support.ui_grid")
local harness = require("__test__.support.harness")
local UI = require("__test__.support.ui")

local M = {}

---A child of `t` with the full runtime and `root` as its Git workspace, which records reported errors in `errors`. In
---the child, `open(fields)` opens the Git Files widget as `widget` after setting `fields` on it, and
---`stub_status(data, staged, unstaged)` makes Git status report `data` with those changed files.
---@param t                             __test__.support.Harness
---@param width                         integer
---@param height                        integer
---@param root                          string
---@return __test__.support.UI
---@return table grid
function M.surface(t, width, height, root)
  local ui = UI.open(t)
  local grid = Grid.new(ui)
  ui:start({ width = width, height = height, runtime = "ark" })
  ui:lua(
    [[
    local root = ...
    support = require("__test__.support.git_files")
    errors = {}
    stl.reporter.error = function(value) errors[#errors + 1] = value end
    era.m.git.state.refresh_index = function() return stl.c.Future.resolve() end
    dot.path.workspace = function() return root end
    dot.path.is_git_repo = function() return true end
    function open(fields)
      widget = require("era.m.git_files").new()
      for key, value in pairs(fields or {}) do widget[key] = value end
      widget:toggle()
      support.ready(widget)
    end
    function stub_status(data, staged, unstaged)
      era.m.git.status.collect = function()
        return stl.c.Future.resolve({ export = function() return data end, changed_files = function() return staged, unstaged end })
      end
    end
  ]],
    root
  )
  return ui, grid
end

---The screen row of the pane border titled `label`, or "" while the screen shows no such title.
---@param grid                          table
---@param label                         string
---@return string
function M.border_text(grid, label)
  local title = grid:find(" " .. label)
  return title and grid:row_text(title) or ""
end

---The Git metadata and column widths of `path` in the current frame of `tree`.
---@param tree                          era.view.GitFiles
---@param path                          string
---@return era.view.git_files.IMetadata
---@return era.view.git_files.IColumnWidths
function M.metadata(tree, path)
  local frame = tree:frame()
  local fields = frame:node(frame:source():id(require("era.view.result_paths").key(path))).fields
  return fields.git, fields.git_columns
end

---A repository with a committed file in a directory, a second file beside it and one outside it.
---@param t                             __test__.support.Harness
---@param unborn                        ?boolean
---@return string
function M.repo(t, unborn)
  local root = git.repo(t)
  if not unborn then
    fs.write(root .. "/dir/mixed.lua", { "one", "two", "three" })
    fs.write(root .. "/dir/second.lua", { "base" })
    fs.write(root .. "/outside.lua", { "base" })
    git.commit(root, "fixture")
  end
  return root
end

---The `repo` fixture with `staged` written and staged, then `unstaged` written over the worktree, so a path in both
---is partially staged.
---@param t                             __test__.support.Harness
---@param staged                        table<string, string[]> Lines by path.
---@param unstaged                      table<string, string[]> Lines by path.
---@return string
function M.changes(t, staged, unstaged)
  local root = M.repo(t)
  for path, lines in pairs(staged) do
    fs.write(root .. "/" .. path, lines)
    git.run(root, { "add", "--", path })
  end
  for path, lines in pairs(unstaged) do
    fs.write(root .. "/" .. path, lines)
  end
  return root
end

---A Git Files widget on `root` as `widget`, with the reports since in `warnings` and `errors`. It is disposed when the
---case ends, which fails if anything reported an error.
---@param t                             __test__.support.Harness
---@param root                          string
---@return table
function M.widget(t, root)
  local reports = bootstrap.with_reporter(t)
  local state = {
    root = root,
    warnings = reports.warn,
    errors = reports.error,
    refreshed = stl.c.Observable.from_value(0),
  }
  t:patch_table(dot.path, "workspace", function()
    return state.root
  end)
  t:patch_table(dot.path, "is_git_repo", function()
    return true
  end)
  t:patch_table(era.m.git.state, "o_refreshed", state.refreshed)
  t:patch_table(era.m.git.state, "refresh_index", function()
    return stl.c.Future.resolve()
  end)
  state.widget = require("era.m.git_files").new()
  t:defer(function()
    state.widget:dispose()
    state.refreshed:dispose()
    t.assert_eq(0, #state.errors, vim.inspect(state.errors))
  end)
  return state
end

---Waits until `widget` has finished refreshing and its trees are ready.
---@param widget                        era.m.git_files.Widget
---@return nil
function M.ready(widget)
  harness.wait_until(function()
    return widget._request == nil
  end, 10000, "Git Files refresh timed out")
  assert(not widget._failed, "Git Files refresh failed")
  for _, pane in pairs(widget.panes) do
    harness.await(pane.tree:ready())
  end
end

---@param widget                        era.m.git_files.Widget
---@param scope                         era.view.git_files.Scope
---@param path                          string
---@return nil
function M.cursor(widget, scope, path)
  M.ready(widget)
  local pane = widget.panes[scope]
  local row = assert(
    pane.tree:retrieve_lnum(require("era.view.result_paths").key(widget._root .. "/" .. path)),
    "missing visible Git path: " .. path
  )
  widget:focus(scope)
  vim.api.nvim_win_set_cursor(assert(pane.result:get_winnr()), { row, 0 })
  vim.cmd("doautocmd CursorMoved")
  harness.await(pane.tree:ready())
end

return M
