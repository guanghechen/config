local harness = require("__test__.support.harness")
require("ark.bootstrap").setup()

local t = harness.new("era.dressing.statusline.loading")
local Nvimbar = require("era.m.nvimbar.nvimbar")

t:test("statusline initializes components lazily without activating optional backends", function()
  local errors, bars = {}, {}
  t:patch_table(stl.reporter, "error", function(report)
    errors[#errors + 1] = report
  end)
  local new = Nvimbar.new
  t:patch_table(Nvimbar, "new", function(props)
    local bar = new(props)
    bars[#bars + 1] = bar
    t:defer(function()
      bar:dispose()
    end)
    return bar
  end)

  local statusline = require("era.dressing.statusline")
  for module in pairs(package.loaded) do
    t.assert_false(module:match("^era%.m%.nvimbar%.component%."), "eager component: " .. module)
  end
  statusline.dressing()
  local bar = assert(bars[1])
  for _, placed in ipairs(bar._components) do
    t.assert_eq("queued", placed.runtime.status, "initial refresh only queues work")
    t.assert_nil(placed.runtime.definition)
  end
  t.wait_until(function()
    for _, placed in ipairs(bar._components) do
      if placed.runtime.status == "queued" or placed.runtime.status == "running" then
        return false
      end
    end
    return true
  end, 3000, "initial components settle")
  t.assert_eq(0, #errors, vim.inspect(errors))
  for _, module in ipairs({
    "era.m.lsp",
    "era.m.lsp.diagnostic",
    "vim.lsp.client",
    "lint",
    "era.m.ai.state",
    "era.m.git.state",
    "era.m.git.hunk",
  }) do
    t.assert_nil(package.loaded[module], "optional backend: " .. module)
  end
  for _, placed in ipairs(bar._components) do
    t.assert_eq("ready", placed.runtime.status, placed.runtime.definition.name)
  end
  t.assert_true(bar:render():find("NORMAL", 1, true) ~= nil)
end)

t:run()
