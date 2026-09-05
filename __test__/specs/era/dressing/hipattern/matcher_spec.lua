--- Run with: nvim -l __test__/run.lua __test__/specs/era/dressing/hipattern/matcher_spec.lua

local harness = require("__test__.support.harness")

local t = harness.new("era.dressing.hipattern.matcher")
local matcher = require("era.dressing.hipattern.matcher")

---@param decorations                   era.dressing.hipattern.IDecoration[]
---@param kind                          "highlight"|"inline_color"
---@param coll                          integer
---@return era.dressing.hipattern.IDecoration|nil
local function get_decoration(decorations, kind, coll)
  for _, decoration in ipairs(decorations) do
    if decoration.kind == kind and decoration.coll == coll then
      return decoration
    end
  end
  return nil
end

t:test("matches standalone keywords only", function()
  local decorations = matcher.match("TODO TODO1 ERROR", "lua")
  t.assert_eq(2, #decorations, "keyword count")

  local todo = get_decoration(decorations, "highlight", 0)
  local err = get_decoration(decorations, "highlight", 11)
  t.assert_eq("f_hipattern_todo", todo and todo.hlgroup, "todo group")
  t.assert_eq(4, todo and todo.colr, "todo range")
  t.assert_eq("f_hipattern_error", err and err.hlgroup, "error group")
end)

t:test("matches long and shorthand hex colors", function()
  local decorations = matcher.match("#12AbEf #0f8", "lua")
  t.assert_eq(2, #decorations, "color count")

  local long = get_decoration(decorations, "inline_color", 0)
  local short = get_decoration(decorations, "inline_color", 8)
  t.assert_eq("#12AbEf", long and long.color, "long color")
  t.assert_eq("#00ff88", short and short.color, "short color")
end)

t:test("limits rgb and hsl colors to css filetypes", function()
  local line = "rgb(255, 0, 16) hsl(120, 100%, 50%)"
  t.assert_eq(0, #matcher.match(line, "lua"), "lua colors")

  local decorations = matcher.match(line, "css")
  t.assert_eq(2, #decorations, "css colors")
  t.assert_eq("#ff0010", decorations[1].color, "rgb color")
  t.assert_eq("#00ff00", decorations[2].color, "hsl color")
end)

t:test("ignores invalid css channel ranges", function()
  local decorations = matcher.match("rgb(256, 0, 0) hsl(0, 101%, 50%)", "css")
  t.assert_eq(0, #decorations, "invalid colors")
end)

t:test("matches tailwind colors only in configured filetypes", function()
  t.assert_eq(0, #matcher.match("bg-red-500", "lua"), "lua tailwind")

  local decorations = matcher.match("hover:bg-red-500", "typescript")
  t.assert_eq(1, #decorations, "tailwind count")
  t.assert_eq("#EF4444", decorations[1].color, "tailwind color")
end)

t:test("highlights markdown titled separator content", function()
  local decorations = matcher.match("---Release Notes---", "markdown")
  t.assert_eq(1, #decorations, "separator count")
  t.assert_eq(3, decorations[1].coll, "separator start")
  t.assert_eq(16, decorations[1].colr, "separator end")
  t.assert_eq("f_md_titled_separator", decorations[1].hlgroup, "separator group")
  t.assert_eq(0, #matcher.match("---Release Notes---", "lua"), "lua separator")
end)

t:run()
