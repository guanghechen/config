require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local diffview = require("__test__.support.diffview")
local tabline = require("era.m.diffview.view.workspace.tabline")

t:test("workspace status assigns fold default to flag 3 and untracked to flag 4", function()
  diffview.repository(t)
  local session = diffview.open_workspace(t)

  local component = tabline.status_component()
  local context = { tabnr = session.tabnr }
  local text = component.render(component.refresh(context), context, 120)
  t.assert_true(text:find(stl.icon.symbols.flag_fold .. "³", 1, true) ~= nil, "fold default flag")
  t.assert_true(text:find(stl.icon.symbols.flag_untracked .. "⁴", 1, true) ~= nil, "untracked flag")
end)

t:run()
