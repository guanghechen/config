local harness = require("__test__.support.harness")

local t = harness.new()

t:test("theme candidates, registry, and scheme files stay symmetric", function()
  t:patch_global("stl", {
    icon = {
      diagnostic = {
        Error_alt = "",
        Hint_alt = "",
        Information_alt = "",
        Warning_alt = "",
      },
      ui = {
        ArrowPresent = "",
        Selected = "",
        SelectedCurrent = "",
        Telescope = "",
      },
    },
  })
  t:patch_table(vim.fn, "sign_define", function() end)

  local themes = assert(loadfile("lua/dot/var.lua"))().themes ---@type string[]
  local schemes = assert(loadfile("lua/dot/init.lua"))().theme.scheme.__mods ---@type table<string, string>
  local registered = 0

  for _ in pairs(schemes) do
    registered = registered + 1
  end
  t.assert_eq(#themes, registered, "registered scheme count")

  for _, theme in ipairs(themes) do
    local module = schemes[theme]
    t.assert_true(type(module) == "string", "missing registry entry for " .. theme)

    local filepath = "lua/" .. module:gsub("%.", "/") .. ".lua"
    local scheme = assert(loadfile(filepath))() ---@type stl.t.theme.IScheme
    local fullname = scheme.variant == nil and scheme.theme or string.format("%s-%s", scheme.theme, scheme.variant)
    t.assert_eq(theme, fullname, "scheme identity for " .. filepath)
    t.assert_true(type(scheme.palette.unified) == "table", "missing unified palette for " .. theme)
    t.assert_true(type(scheme.palette[scheme.theme]) == "table", "missing family palette for " .. theme)

    if scheme.opposite ~= nil then
      local opposite = string.format("%s-%s", scheme.theme, scheme.opposite)
      t.assert_true(type(schemes[opposite]) == "string", "missing opposite scheme for " .. theme)
    end
  end
end)

t:run()
