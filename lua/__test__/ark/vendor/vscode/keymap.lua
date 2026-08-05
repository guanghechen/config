---@diagnostic disable: undefined-global
--- Test for ark.vendor.vscode.keymap module
--- Run with: nvim -l lua/__test__/ark/vendor/vscode/keymap.lua

local harness = require("__test__.harness")

local t = harness.new("ark.vendor.vscode.keymap")

---@class ark.vendor.vscode.keymap.test.IMapping
---@field modes                         string[]
---@field callback                      string|fun(): nil
---@field desc                          string|nil

---@return table<string, ark.vendor.vscode.keymap.test.IMapping>
local function setup()
  local mappings = {} ---@type table<string, ark.vendor.vscode.keymap.test.IMapping>

  t:patch_global("stl", {
    nvim = {
      fn = {
        make_keys = function(modes, keys, callback, desc)
          local key_list = type(keys) == "string" and { keys } or keys ---@type string[]
          for _, key in ipairs(key_list) do
            mappings[key] = { modes = modes, callback = callback, desc = desc }
          end
        end,
      },
    },
  })
  assert(loadfile("lua/ark/vendor/vscode/keymap.lua"))()
  return mappings
end

t:test("routes file finding through VSCode Quick Open", function()
  local mappings = setup()
  local mapping = mappings["<leader><leader>"]

  t.assert_true(mapping ~= nil, "mapping")
  t.assert_eq("<cmd>lua require('vscode').action('workbench.action.quickOpen')<cr>", mapping.callback, "VSCode action")
end)

t:run()
