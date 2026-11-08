local harness = require("__test__.support.harness")
local bootstrap = require("__test__.support.bootstrap")

local t = harness.new()
bootstrap.with_native(t)

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

t:test("details JSON cannot hold still reach vim.notify with the text of a native error", function()
  local text = nil ---@type string|nil
  t:patch_table(vim, "notify", function(message)
    text = message
  end)
  local ok, err = pcall(yoz.string.calc_linewidths, "\255")
  t.assert_false(ok)
  t.assert_eq("userdata", type(err), "a native error")

  require("stl.reporter").error({ from = "spec", message = "draw failed", details = { error = err, callback = print } })

  t.assert_true(text ~= nil and text:find("draw failed", 1, true) ~= nil, "message")
  t.assert_true(text ~= nil and text:find("invalid utf-8", 1, true) ~= nil, "error text")
end)

t:run()
