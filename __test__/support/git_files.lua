---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.support.git_files" ---@type string

local git = require("__test__.support.git")
local harness = require("__test__.support.harness")

local M = {}

---@param root                          string
---@param path                          string
---@param lines                         string[]
---@return nil
function M.write(root, path, lines)
  vim.fn.mkdir(yoz.canonical_path.dirname(root .. "/" .. path, false), "p")
  vim.fn.writefile(lines, root .. "/" .. path)
end

---A repository with a committed file in a directory, a second file beside it and one outside it.
---@param t                             __test__.support.Harness
---@param unborn                        ?boolean
---@return string
function M.repo(t, unborn)
  local root = git.repo(t)
  if not unborn then
    M.write(root, "dir/mixed.lua", { "one", "two", "three" })
    M.write(root, "dir/second.lua", { "base" })
    M.write(root, "outside.lua", { "base" })
    git.run(root, { "add", "." })
    git.run(root, { "commit", "-qm", "fixture" })
  end
  return root
end

---@param t                             table
---@param root                          string
---@return table
function M.widget(t, root)
  local state = { root = root, warnings = {}, errors = {}, refreshed = stl.c.Observable.from_value(0) }
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
  t:patch_table(stl.reporter, "warn", function(value)
    state.warnings[#state.warnings + 1] = value
  end)
  t:patch_table(stl.reporter, "error", function(value)
    state.errors[#state.errors + 1] = value
  end)
  state.widget = require("era.m.git_files").new()
  t:defer(function()
    state.widget:dispose()
    state.refreshed:dispose()
    t.assert_eq(0, #state.errors, vim.inspect(state.errors))
  end)
  return state
end

---@param widget                        era.m.git_files.Widget
---@return nil
function M.ready(widget)
  assert(
    vim.wait(10000, function()
      return widget._request == nil
    end, 1),
    "Git Files refresh timed out"
  )
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
