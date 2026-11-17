require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local diffview = require("__test__.support.diffview")
local fs = require("__test__.support.fs")
local git = require("__test__.support.git")
local action = require("era.m.diffview.view.workspace.action")

t:test("Changes show the details of the file row at the cursor and report a file deleted from the worktree", function()
  local root = diffview.committed(t, { ["src/main.lua"] = { "main" }, ["src/gone.lua"] = { "gone" } })
  fs.write(root .. "/src/main.lua", { "changed" })
  vim.fn.delete(root .. "/src/gone.lua")
  local session = diffview.open_workspace(t)
  local shown = {} ---@type string[]
  t:patch_table(require("era.m.filetree.jobs"), "show_info", function(path)
    shown[#shown + 1] = path
    return stl.c.Future.resolve()
  end)
  local warnings = {} ---@type string[]
  t:patch_table(stl.reporter, "warn", function(report)
    warnings[#warnings + 1] = report.message
  end)

  diffview.cursor_on(session, "unstaged", "src/main.lua")
  action.show_info()
  t.assert_same({ root .. "/src/main.lua" }, shown, "absolute path of the file row")

  diffview.cursor_on(session, "unstaged", "src")
  action.show_info()
  t.assert_eq(1, #shown, "non-file row ignored")

  diffview.cursor_on(session, "unstaged", "src/gone.lua")
  action.show_info()
  t.assert_eq(1, #shown, "a deleted file has no details")
  t.assert_same({ "File does not exist: src/gone.lua" }, warnings)
end)

t:test("a dangling symlink in Changes shows the details of the link itself", function()
  local root = diffview.committed(t, { ["src/main.lua"] = { "main" } })
  assert(vim.uv.fs_symlink(root .. "/missing", root .. "/src/link.lua"))
  git.run(root, { "add", "src/link.lua" })
  local session = diffview.open_workspace(t)
  local shown = {} ---@type string[]
  t:patch_table(require("era.m.filetree.jobs"), "show_info", function(path)
    shown[#shown + 1] = path
    return stl.c.Future.resolve()
  end)

  diffview.cursor_on(session, "staged", "src/link.lua")
  action.show_info()
  t.assert_same({ root .. "/src/link.lua" }, shown)
end)

t:run()
