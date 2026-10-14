---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.support.git_files" ---@type string

local M = {}

---@param root                          string
---@param args                          string[]
---@return string
function M.git(root, args)
  local command = {
    "git",
    "-C",
    root,
    "-c",
    "user.name=Test",
    "-c",
    "user.email=test@example.com",
    "-c",
    "commit.gpgSign=false",
    "-c",
    "core.hooksPath=/dev/null",
  }
  vim.list_extend(command, args)
  local result = vim.system(command, { text = false }):wait()
  assert(result.code == 0, result.stderr)
  return result.stdout or ""
end

---@param root                          string
---@param path                          string
---@param lines                         string[]
---@return nil
function M.write(root, path, lines)
  vim.fn.mkdir(yoz.canonical_path.dirname(root .. "/" .. path, false), "p")
  vim.fn.writefile(lines, root .. "/" .. path)
end

---@param t                             table
---@param unborn                        ?boolean
---@return string
function M.repo(t, unborn)
  local root = vim.fn.tempname()
  vim.fn.mkdir(root, "p")
  root = assert(vim.uv.fs_realpath(root))
  t:defer(function()
    vim.fn.delete(root, "rf")
  end)
  M.git(root, { "init", "-q" })
  if not unborn then
    M.write(root, "dir/mixed.lua", { "one", "two", "three" })
    M.write(root, "dir/second.lua", { "base" })
    M.write(root, "outside.lua", { "base" })
    M.git(root, { "add", "." })
    M.git(root, { "commit", "-qm", "fixture" })
  end
  return root
end

---@param future                        stl.c.Future
---@return any
function M.await(future)
  assert(
    vim.wait(10000, function()
      return future:is_done()
    end, 1),
    "Git Files operation timed out"
  )
  assert(not future:is_failed(), future:get_error())
  return future:get_result()
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
    M.await(pane.tree:ready())
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
  M.await(pane.tree:ready())
end

return M
