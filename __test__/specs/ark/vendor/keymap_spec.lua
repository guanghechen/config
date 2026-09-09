---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.ark.vendor.keymap" ---@type string

local harness = require("__test__.support.harness")
require("ark.bootstrap").setup()

local t = harness.new("ark.vendor quit keymaps")
local quit_keys = { " qq", "<C-a>q", "<D-q>", "<M-q>" } ---@type string[]

---@param mode                          string
---@param key                           string
---@return table|nil
local function get_mapping(mode, key)
  local lhs = vim.keycode(key)
  for _, mapping in ipairs(vim.api.nvim_get_keymap(mode)) do
    if vim.keycode(mapping.lhs) == lhs then
      return mapping
    end
  end
  return nil
end

for _, vendor in ipairs({ "common", "neovim", "neovide", "vscode", "yozvim", "yuivim" }) do
  t:test(vendor .. " installs only its owned quit mappings", function()
    for _, name in ipairs({ "vscode", "neovide", "yozvim", "yuivim" }) do
      local previous = vim.g[name]
      vim.g[name] = vendor == name and true or nil
      t:defer(function()
        vim.g[name] = previous
      end)
    end
    for _, mode in ipairs({ "n", "x", "i" }) do
      for _, key in ipairs(quit_keys) do
        if get_mapping(mode, key) then
          vim.keymap.del(mode, key)
        end
      end
    end

    assert(loadfile("lua/ark/keymap.lua"))()
    if vendor ~= "common" then
      local module = "ark.vendor." .. vendor .. ".keymap"
      t:patch_table(package.loaded, "ark.vendor.neovim.keymap", nil)
      t:patch_table(package.loaded, module, nil)
      require(module)
    end

    for _, mode in ipairs({ "n", "x", "i" }) do
      for _, key in ipairs(quit_keys) do
        local mapping = get_mapping(mode, key)
        local expected_rhs = nil ---@type string|nil
        if (vendor == "neovim" or vendor == "neovide") and (mode ~= "i" or key ~= " qq") then
          expected_rhs = "<cmd>qa<cr>"
        elseif vendor == "vscode" and mode ~= "i" and key == " qq" then
          expected_rhs = "<cmd>lua require('vscode').action('workbench.action.closeWindow')<cr>"
        end
        if expected_rhs then
          t.assert_true(mapping ~= nil, mode .. ": " .. key)
          t.assert_eq(vim.keycode(expected_rhs), vim.keycode(mapping.rhs), "vendor quit action")
          t.assert_eq(1, mapping.noremap, "non-recursive mapping")
          t.assert_eq(1, mapping.silent, "silent mapping")
          t.assert_eq(1, mapping.nowait, "immediate mapping")
        else
          t.assert_nil(mapping, vendor .. " must not own " .. mode .. ": " .. key)
        end
      end
    end

    local down = assert(get_mapping("n", "j"))
    t.assert_eq("v:count == 0 ? 'gj' : 'j'", down.rhs, "common navigation is unchanged")
    t.assert_eq(1, down.expr, "expression mappings remain expressions")
  end)
end

t:run()
