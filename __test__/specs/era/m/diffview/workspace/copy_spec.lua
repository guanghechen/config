require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local diffview = require("__test__.support.diffview")
local action = require("era.m.diffview.view.workspace.action")

t:test("Changes copy the absolute filepath of the file row at the cursor", function()
  local root = diffview.committed(t, { ["src/main.lua"] = { "main" } })
  diffview.write(root, "src/main.lua", { "changed" })
  local session = diffview.open_workspace(t)
  local selections = {} ---@type era.fn.select_copy_filepath.IParams[]
  t:patch_table(era.fn, "select_copy_filepath", function(params)
    selections[#selections + 1] = params
  end)

  diffview.cursor_on(session, "unstaged", "src/main.lua")
  action.copy_filepath()
  t.assert_eq(1, #selections, "selection count")
  t.assert_eq(root .. "/src/main.lua", selections[1].filepath, "absolute filepath")
  t.assert_eq("cursor", selections[1].relative, "popup anchor")
  t.assert_eq(1, selections[1].row, "popup row")
  t.assert_eq(4, selections[1].col, "popup column")

  diffview.cursor_on(session, "unstaged", "src")
  action.copy_filepath()
  t.assert_eq(1, #selections, "non-file row ignored")
end)

t:run()
