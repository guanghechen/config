--- Run with: nvim -l __test__/run.lua __test__/specs/dot/theme_spec.lua
---@diagnostic disable: undefined-global

local harness = require("__test__.support.harness")

local t = harness.new("dot.theme")

package.path = "lua/?.lua;lua/?/init.lua;" .. package.path
package.cpath = "lua/?.so;" .. package.cpath

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

t:test("registered themes apply through the highlight pipeline", function()
  t:patch_global("yoz", require("yoz"))
  t:patch_global("stl", require("stl"))
  t:patch_global("dot", require("dot"))

  for _, theme in ipairs(dot.var.themes) do
    for _, transparency in ipairs({ false, true }) do
      local scheme = dot.context.theme.apply_theme({
        theme = theme,
        transparency = transparency,
      })
      t.assert_true(type(scheme) == "table", "failed to apply " .. theme)
    end
  end

  local applied ---@type dot.context.theme.ILoadThemeParams|nil
  t:patch_table(dot.context.theme, "apply_theme", function(params)
    applied = params
  end)
  dot.context.theme.reload_theme()
  t.assert_eq(dot.context.theme.theme:snapshot(), applied and applied.theme, "reload theme")
  t.assert_eq(dot.context.theme.transparency:snapshot(), applied and applied.transparency, "reload transparency")
end)

t:run()
