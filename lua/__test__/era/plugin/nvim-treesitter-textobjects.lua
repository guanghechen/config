---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/era/plugin/nvim-treesitter-textobjects.lua

local bootstrap = require("__test__.bootstrap")
local harness = require("__test__.harness")

local t = harness.new("era.plugin.nvim-treesitter-textobjects")

local configured_keymaps = nil ---@type stl.t.IKeymap[]|nil
bootstrap.with_stl(t, {
  nvim = {
    fn = {
      bindkeys = function(keymaps)
        configured_keymaps = keymaps
      end,
    },
  },
})

local spec = require("era.plugin.nvim-treesitter-textobjects")

---@param modes                         string|string[]|nil
---@return string[]
local function normalize_modes(modes)
  if type(modes) == "string" then
    return { modes }
  end
  return modes or { "n" }
end

t:test("textobjects is key-lazy and owns the dependency on treesitter", function()
  t.assert_nil(spec.event, "eager event")
  t.assert_eq(1, #(spec.dependencies or {}), "dependency count")
  t.assert_eq("nvim-treesitter", spec.dependencies and spec.dependencies[1], "dependency")
  t.assert_true(type(spec.keys) == "table" and #spec.keys > 0, "proxy keys")
end)

t:test("proxy keys cover every configured mapping", function()
  t:patch_table(package.loaded, "nvim-treesitter-textobjects", { setup = function() end })
  t:patch_table(package.loaded, "nvim-treesitter-textobjects.select", { select_textobject = function() end })
  t:patch_table(package.loaded, "nvim-treesitter-textobjects.move", {
    goto_next_start = function() end,
    goto_next_end = function() end,
    goto_previous_start = function() end,
    goto_previous_end = function() end,
  })

  spec.config(spec, spec.opts)

  local expected = {} ---@type table<string, string|boolean>
  local expected_count = 0
  for _, key in ipairs(spec.keys) do
    for _, mode in ipairs(normalize_modes(key.mode)) do
      expected[mode .. "\0" .. key.lhs] = key.desc or false
      expected_count = expected_count + 1
    end
  end

  local actual = {} ---@type table<string, string|boolean>
  local actual_count = 0
  for _, keymap in ipairs(configured_keymaps or {}) do
    for _, mode in ipairs(normalize_modes(keymap.modes)) do
      actual[mode .. "\0" .. keymap.key] = keymap.desc or false
      actual_count = actual_count + 1
    end
  end

  t.assert_eq(expected_count, actual_count, "mapping count")
  for id, desc in pairs(expected) do
    t.assert_eq(desc, actual[id], "mapping " .. id)
  end
end)

t:run()
