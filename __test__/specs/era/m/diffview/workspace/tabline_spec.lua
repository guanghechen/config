require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local diffview = require("__test__.support.diffview")
local tabline = require("era.m.diffview.view.workspace.tabline")

t:test("workspace status marks the fold default and untracked flags with their keys", function()
  diffview.repository(t)
  local session = diffview.open_workspace(t)

  local component = tabline.status_component()
  local context = { tabnr = session.tabnr }
  local text = component.render(component.refresh(context), context, 120)
  t.assert_true(text:find(stl.icon.symbols.flag_fold .. "ᶻ", 1, true) ~= nil, "fold default flag, tz")
  t.assert_true(text:find(stl.icon.symbols.flag_untracked .. "ᵘ", 1, true) ~= nil, "untracked flag, tu")
end)

t:run()
