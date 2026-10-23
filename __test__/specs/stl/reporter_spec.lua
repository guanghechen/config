local harness = require("__test__.support.harness")

local t = harness.new()

t:test("dismiss delegates to notifier group cleanup when supported", function()
  local dismissed = nil ---@type string|nil
  local notifier = setmetatable({
    dismiss_by_group = function(group)
      dismissed = group
    end,
  }, {
    __call = function() end,
  })
  t:patch_table(vim, "notify", notifier)

  require("stl.reporter").dismiss("message:1")

  t.assert_eq("message:1", dismissed, "dismissed group")
end)

t:test("levels reach vim.notify as numbers", function()
  local levels = {} ---@type integer[]
  t:patch_table(vim, "notify", function(_, level)
    levels[#levels + 1] = level
  end)

  local reporter = require("stl.reporter")
  reporter.error({ from = "spec", message = "error" })
  reporter.warn({ from = "spec", message = "warn" })
  reporter.log("WARN", { from = "spec", message = "named" })

  t.assert_same({ vim.log.levels.ERROR, vim.log.levels.WARN, vim.log.levels.WARN }, levels, "notify levels")
end)

t:run()
