---@diagnostic disable: undefined-global
--- Test for era.m.lsp.fn module
--- Run with: nvim -l lua/__test__/era/m/lsp/fn.lua

local bootstrap = require("__test__.bootstrap")
local harness = require("__test__.harness")

local t = harness.new("era.m.lsp.fn")

bootstrap.with_stl(t, {
  env = {
    HOME_NVIM_DATA = "/__nvim_test_data__",
    PATH_SEP = "/",
    IS_HEADLESS = true,
  },
})

local mason_loads = 0 ---@type integer
t:patch_table(package.preload, "mason", function()
  mason_loads = mason_loads + 1
  return {}
end)
t:patch_table(package.loaded, "mason", nil)

local Fn = require("era.m.lsp.fn")

t:test("locate_mason_pkg_path: resolves the conventional path without loading Mason", function()
  local filepath = Fn.locate_mason_pkg_path("vue-language-server", "node_modules/@vue/language-server", true)

  t.assert_eq(
    "/__nvim_test_data__/mason/packages/vue-language-server/node_modules/@vue/language-server",
    filepath,
    "package path"
  )
  t.assert_eq(0, mason_loads, "Mason load count")
end)

t:run()
