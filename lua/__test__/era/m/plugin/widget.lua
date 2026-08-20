---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/era/m/plugin/widget.lua

local harness = require("__test__.harness")
require("ark.bootstrap").setup()
local Widget = require("era.m.plugin.widget")

local t = harness.new("era.m.plugin.widget")

t:test("title buttons resolve their mode by text column", function()
  local view = {
    state = { mode = "profile" },
    win_opts = { width = 132 },
  } ---@type era.m.plugin.View
  local widget = Widget.new(view)
  widget:__title__()

  local line = 2 ---@type integer
  local text = (" "):rep(widget.padding)
  for _, segment in ipairs(widget._lines[line]) do
    text = text .. segment.str
  end

  local expected = {
    Home = "home",
    Profile = "profile",
    Install = "install",
    Update = "update",
    Clean = "clean",
  } ---@type table<string, era.m.plugin.ViewModeEnum>

  for label, mode in pairs(expected) do
    local col = assert(text:find(label, 1, true)) ---@type integer
    t.assert_eq(mode, widget:get_mode_at(line, col), label .. " button")
  end

  t.assert_nil(widget:get_mode_at(1, 1), "non-title line")
  t.assert_nil(widget:get_mode_at(line, #text + 1), "outside title")
end)

t:run()
