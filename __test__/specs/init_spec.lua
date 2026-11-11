local harness = require("__test__.support.harness")
local t = harness.new()

for _, case in ipairs({
  { flags = {}, vendor = "neovim" },
  { flags = { vscode = true }, vendor = "vscode" },
  { flags = { neovide = true }, vendor = "neovide" },
  { flags = { yozvim = true }, vendor = "yozvim" },
  { flags = { yuivim = true }, vendor = "yuivim" },
  { flags = { yuivim = false }, vendor = "neovim" },
  { flags = { yuivim = true, yozvim = true }, vendor = "yuivim" },
  { flags = { yuivim = true, neovide = true }, vendor = "neovide" },
  { flags = { yuivim = true, vscode = true }, vendor = "vscode" },
}) do
  t:test("routes " .. vim.inspect(case.flags) .. " to " .. case.vendor, function()
    local calls = {} ---@type string[]
    t:patch_table(vim, "g", vim.deepcopy(case.flags))
    t:patch_global("require", function(name)
      calls[#calls + 1] = name
      if name == "ark.bootstrap" then
        return {
          setup = function()
            calls[#calls + 1] = "bootstrap.setup"
          end,
        }
      end
      return true
    end)

    assert(loadfile("init.lua"))()

    t.assert_same(
      { "ark.bootstrap", "bootstrap.setup", "ark.vendor." .. case.vendor },
      calls,
      "one vendor is selected after bootstrap"
    )
    t.assert_same(case.flags, vim.g, "host identity is not rewritten")
  end)
end

t:run()
