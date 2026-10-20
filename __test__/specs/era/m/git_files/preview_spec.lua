require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local support = require("__test__.support.git_files")
local git = require("__test__.support.git")

---@return table
local function fixture()
  -- Nvim 0.12 without a UI overruns the tabline buffers once 'columns' grows, corrupting the heap and
  -- crashing later; the preview needs the width but not the tabline.
  local showtabline, columns = vim.o.showtabline, vim.o.columns
  vim.o.showtabline = 0
  vim.o.columns = 150
  t:defer(function()
    vim.o.columns = columns
    vim.o.showtabline = showtabline
  end)
  local root = support.repo(t)
  support.write(root, "dir/mixed.lua", { "one", "two", "three", "only-staged" })
  git.run(root, { "add", "dir/mixed.lua" })
  support.write(root, "dir/mixed.lua", { "one", "two", "three", "only-staged", "only-unstaged" })
  local state = support.widget(t, root)
  state.widget._preview_enabled = false
  state.widget:toggle()
  support.ready(state.widget)
  return state
end

---@param command                       string[]
---@return boolean
local function is_preview(command)
  return vim.tbl_contains(command, "--unified=3")
end

---@param preview                       era.m.git_files.Preview
---@param line                          string
---@return boolean
local function contains(preview, line)
  for _, row in ipairs(preview._rows) do
    if row.kind == "add" and row.text == line then
      return true
    end
  end
  return false
end

t:test("disabled preview launches no diff and enabled preview follows the selected side", function()
  local state = fixture()
  local widget, count = state.widget, 0
  local system = vim.system
  t:patch_table(vim, "system", function(command, options, callback)
    if is_preview(command) then
      count = count + 1
    end
    return system(command, options, callback)
  end)
  support.cursor(widget, "unstaged", "dir/mixed.lua")
  vim.wait(180, function()
    return false
  end, 5)
  t.assert_eq(0, count)
  widget:toggle_preview()
  t.assert_true(widget.preview.surface:isvisible())
  t.wait_until(function()
    return contains(widget.preview, "only-unstaged")
  end, 5000)
  t.assert_false(contains(widget.preview, "only-staged"))
  support.cursor(widget, "staged", "dir/mixed.lua")
  t.wait_until(function()
    return contains(widget.preview, "only-staged")
  end, 5000)
  t.assert_false(contains(widget.preview, "only-unstaged"))
  t.assert_eq(2, count)
  widget:toggle_preview()
  support.cursor(widget, "unstaged", "dir/mixed.lua")
  vim.wait(180, function()
    return false
  end, 5)
  t.assert_eq(2, count)
end)

t:test("untracked diff accepts Git's exit status one and preserves the index", function()
  local state = fixture()
  support.write(state.root, "new file.lua", { "untracked-line" })
  t.await(state.widget:refresh(false))
  support.ready(state.widget)
  local before = git.run(state.root, { "ls-files", "--stage", "-z" })
  support.cursor(state.widget, "unstaged", "new file.lua")
  state.widget:toggle_preview()
  t.wait_until(function()
    return contains(state.widget.preview, "untracked-line")
  end, 5000)
  t.assert_eq(before, git.run(state.root, { "ls-files", "--stage", "-z" }))
end)

t:test("late preview output cannot replace a newer target or write after closing", function()
  local state = fixture()
  local widget, requests, killed = state.widget, {}, 0
  local system = vim.system
  t:patch_table(vim, "system", function(command, options, callback)
    if not is_preview(command) then
      return system(command, options, callback)
    end
    requests[#requests + 1] = { options = options, callback = callback }
    return {
      kill = function()
        killed = killed + 1
      end,
    }
  end)
  support.cursor(widget, "unstaged", "dir/mixed.lua")
  widget:toggle_preview()
  t.wait_until(function()
    return #requests == 1
  end, 3000)
  support.cursor(widget, "staged", "dir/mixed.lua")
  t.wait_until(function()
    return #requests == 2
  end, 3000)
  t.assert_eq(1, killed)
  requests[2].options.stdout(nil, "@@ -0,0 +1 @@\n+newer\n")
  requests[2].callback({ code = 0, stderr = "" })
  t.wait_until(function()
    return contains(widget.preview, "newer")
  end, 1000)
  requests[1].options.stdout(nil, "@@ -0,0 +1 @@\n+older\n")
  requests[1].callback({ code = 0, stderr = "" })
  vim.wait(20, function()
    return false
  end, 1)
  t.assert_true(contains(widget.preview, "newer"))
  support.cursor(widget, "unstaged", "dir/mixed.lua")
  t.wait_until(function()
    return #requests == 3
  end, 3000)
  widget:hide()
  local callback = assert(widget.preview._statuscolumn:match("dot%.G%.([%w_]+)"))
  widget:dispose()
  t.assert_nil(dot.G[callback], "disposing the preview releases its statuscolumn callback")
  requests[3].options.stdout(nil, "@@ -0,0 +1 @@\n+closed\n")
  requests[3].callback({ code = 0, stderr = "" })
  vim.wait(180, function()
    return false
  end, 5)
  t.assert_false(widget:isvisible())
  t.assert_false(contains(widget.preview, "closed"))
  t.assert_eq(2, killed)
end)

t:run()
