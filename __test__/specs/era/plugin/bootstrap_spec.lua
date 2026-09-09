---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.plugin.bootstrap" ---@type string

local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")
local t = harness.new("era.plugin host policy")
local plugin_names = {
  "blink.cmp",
  "blink.pairs",
  "conform.nvim",
  "flash.nvim",
  "friendly-snippets",
  "mason.nvim",
  "nvim-lint",
  "nvim-treesitter",
  "nvim-treesitter-context",
  "render-markdown.nvim",
} ---@type string[]

for _, host in ipairs({ "neovim", "neovide", "vscode", "yozvim", "yui" }) do
  t:test(host .. " enables only its intended plugins", function()
    local specs = {} ---@type era.m.plugin.IPluginSpec[]
    t:patch_table(vim, "g", host == "neovim" and {} or { [host] = true })
    bootstrap.with_runtime(t, {
      dot = {
        context = {
          plugin = {
            treesitter_context = {
              snapshot = function()
                return true
              end,
            },
          },
        },
      },
      era = {
        m = {
          plugin = {
            setup = function(value)
              specs = value
            end,
          },
        },
      },
      stl = {
        reporter = {
          error = function(report)
            error(report.message)
          end,
        },
      },
    })
    for _, name in ipairs(plugin_names) do
      local module = "era.plugin." .. name:gsub("%.nvim$", ""):gsub("%.", "-")
      t:patch_table(package.loaded, module, {})
    end

    assert(loadfile("lua/era/plugin.lua"))()

    t.assert_eq(#plugin_names, #specs, "all plugin policies are checked")
    for index, spec in ipairs(specs) do
      t.assert_eq(plugin_names[index], spec.name, "plugin order")
      local enabled = host == "neovim" or host == "neovide" or (host == "vscode" and spec.name == "flash.nvim")
      t.assert_eq(enabled, spec.cond(), host .. ": " .. spec.name)
    end
  end)
end

t:run()
