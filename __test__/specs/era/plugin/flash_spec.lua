--- Run with: nvim -l __test__/run.lua __test__/specs/era/plugin/flash_spec.lua
---@diagnostic disable: undefined-global

local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

local t = harness.new("era.plugin.flash")

bootstrap.with_stl(t, {
  filetype = {
    get_no_flash_filetypes = function()
      return {}
    end,
  },
})

local spec = require("era.plugin.flash")

t:test("flash is loaded only by its proxy keys", function()
  t.assert_nil(spec.event, "eager event")
  t.assert_true(type(spec.keys) == "table" and #spec.keys > 0, "proxy keys")

  local search_keys = { ["/"] = false, ["?"] = false }
  for _, key in ipairs(spec.keys) do
    if search_keys[key.lhs] ~= nil then
      t.assert_nil(key.rhs, "native search replay for " .. key.lhs)
      search_keys[key.lhs] = true
    else
      t.assert_true(type(key.rhs) == "function", "proxy callback for " .. key.lhs)
    end
  end
  t.assert_true(search_keys["/"], "forward search proxy")
  t.assert_true(search_keys["?"], "backward search proxy")
end)

t:run()
