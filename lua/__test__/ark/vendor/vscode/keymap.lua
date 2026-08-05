---@diagnostic disable: undefined-global
--- Test for ark.vendor.vscode.keymap module
--- Run with: nvim -l lua/__test__/ark/vendor/vscode/keymap.lua

local harness = require("__test__.harness")

local t = harness.new("ark.vendor.vscode.keymap")

---@param action                        string
---@return string
local function action_callback(action)
  return "<cmd>lua require('vscode').action('" .. action .. "')<cr>"
end

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
  t.assert_eq(action_callback("workbench.action.quickOpen"), mapping.callback, "VSCode action")
end)

t:test("uses the Lua API for undo and redo", function()
  local mappings = setup()

  t.assert_eq(action_callback("undo"), mappings["u"].callback, "undo")
  t.assert_eq(action_callback("redo"), mappings["<C-r>"].callback, "redo")
end)

t:test("keeps core leader mappings aligned with native intent", function()
  local mappings = setup()
  local expected = {
    ["<leader>:"] = "workbench.action.showCommands",
    ["<leader>2"] = "workbench.view.search",
    ["<leader>3"] = "workbench.view.scm",
    ["<leader>bH"] = "workbench.action.closeEditorsToTheLeft",
    ["<leader>bL"] = "workbench.action.closeEditorsToTheRight",
    ["<leader>qq"] = "workbench.action.closeWindow",
    ["<leader>sc"] = "workbench.action.findInFiles",
    ["<leader>sf"] = "actions.find",
    ["<leader>sw"] = "workbench.action.findInFiles",
    ["<leader>t0"] = "workbench.action.lastEditorInGroup",
    ["<leader>tn"] = "workbench.action.files.newUntitledFile",
    ["<leader>xD"] = "workbench.actions.view.problems",
  } ---@type table<string, string>

  for key, vscode_action in pairs(expected) do
    t.assert_eq(action_callback(vscode_action), mappings[key].callback, key)
  end

  for index = 1, 9 do
    local key = "<leader>t" .. index
    t.assert_eq(action_callback("workbench.action.openEditorAtIndex" .. index), mappings[key].callback, key)
  end
end)

t:run()
