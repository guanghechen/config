---@diagnostic disable: undefined-global

local harness = require("__test__.harness")

local t = harness.new("stl.reporter")

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

t:run()
