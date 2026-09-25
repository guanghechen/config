---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.m.explorer.runtime" ---@type string

local fixture = require("__test__.support.explorer").new("era.m.explorer.runtime")
local t, await = fixture.t, fixture.await
local Git = require("era.m.git.state")

---@param widget                        era.m.explorer.Widget
---@param name                          string
---@return ux.filetree.IAnnotation|nil
local function annotation(widget, name)
  local _, view = widget:context()
  local frame, cache = view:frame(), view._filetree_annotations
  if not cache or cache.frame ~= frame:id() then
    return nil
  end
  for row, label in ipairs(frame:rows(1, frame:header().row_count).labels) do
    if label == name then
      return cache.rows[row - cache.first + 1]
    end
  end
  return nil
end

t:test("real Git queries and OS watch update staged, modified, untracked and ignored rows", function()
  local path = fixture.directory()
  for _, name in ipairs({ "a.lua", "b.lua", "c.lua" }) do
    fixture.write(path .. "/" .. name)
  end
  vim.fn.writefile({ "b.lua" }, path .. "/.gitignore")
  for _, args in ipairs({ { "init", "-q" }, { "add", "a.lua", ".gitignore" } }) do
    local command = { "git", "-C", path }
    vim.list_extend(command, args)
    local result = vim.system(command, { text = true }):wait()
    t.assert_eq(0, result.code, result.stderr)
  end
  t:patch_table(dot.path, "is_git_repo", function()
    return true
  end)
  Git.setup()
  t:defer(function()
    vim.api.nvim_del_augroup_by_name("DotModuleGitState")
  end)
  local widget = fixture.widget(path, { o_flag_hidden = stl.c.Observable.from_value(false) })
  local session, view = widget:context()
  local codes = yoz.git.codes
  t.wait_until(function()
    local a, b, c = annotation(widget, "a.lua"), annotation(widget, "b.lua"), annotation(widget, "c.lua")
    return a
      and b
      and c
      and bit.band(a.git, codes.A) ~= 0
      and bit.band(b.git, codes["!"]) ~= 0
      and bit.band(c.git, codes["?"]) ~= 0
      and session.data:watch_status().directories > 0
  end, 10000, "initial Git query and ignore preload did not reach the Explorer")
  local generation = Git.o_refreshed:snapshot().generation
  vim.fn.writefile({ "external change" }, path .. "/a.lua")
  assert(vim.uv.fs_rename(path .. "/c.lua", path .. "/renamed.lua"))
  t.wait_until(function()
    local a, renamed = annotation(widget, "a.lua"), annotation(widget, "renamed.lua")
    return a
      and renamed
      and a.staged
      and a.unstaged
      and bit.band(a.git, codes.M) ~= 0
      and bit.band(renamed.git, codes["?"]) ~= 0
      and not annotation(widget, "c.lua")
      and Git.o_refreshed:snapshot().generation > generation
  end, 10000, "external filesystem changes must drive a real Git refresh")

  local staged = vim.system({ "git", "-C", path, "add", "a.lua" }, { text = true }):wait()
  t.assert_eq(0, staged.code, staged.stderr)
  await(Git.refresh_index())
  t.wait_until(function()
    local a = annotation(widget, "a.lua")
    return a and a.staged and not a.unstaged
  end, 10000)

  -- Returning from an external editor invalidates both positive and negative ignore entries.
  vim.fn.writefile({ "renamed.lua" }, path .. "/.gitignore")
  vim.api.nvim_exec_autocmds("FocusGained", {})
  t.wait_until(function()
    local b, renamed = annotation(widget, "b.lua"), annotation(widget, "renamed.lua")
    return b
      and renamed
      and bit.band(b.git, codes["!"]) == 0
      and bit.band(b.git, codes["?"]) ~= 0
      and bit.band(renamed.git, codes["!"]) ~= 0
  end, 10000)

  fixture.cursor(widget, path .. "/a.lua")
  await(widget._action:operate("move", { rename = true, name = "moved.lua" }))
  fixture.idle(widget)
  t.wait_until(function()
    local moved = annotation(widget, "moved.lua")
    return moved and bit.band(moved.git, codes["?"]) ~= 0 and not annotation(widget, "a.lua")
  end, 10000, "successful native IO must refresh actual Git status")
  local bufnr = view.bufnr
  widget:hide()
  t.wait_until(function()
    return session.data:watch_status().directories == 0 and not session.data._native:is_busy()
  end, 10000)
  t.assert_false(vim.api.nvim_buf_is_valid(bufnr))
  widget:dispose()
  await(Git.refresh(false))
  t.assert_eq(0, #fixture.messages, vim.inspect(fixture.messages))
end)

t:run()
