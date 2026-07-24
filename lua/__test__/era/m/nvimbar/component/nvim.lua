---@diagnostic disable: undefined-global

local harness = require("__test__.harness")

local t = harness.new("era.m.nvimbar.component.nvim")

---@param message                       string
---@return era.m.nvimbar.component.nvim
local function setup(message)
  t:patch_global("dot", {
    state = {
      status = {
        msg_transient = {
          snapshot = function()
            return message
          end,
        },
      },
    },
  })
  t:patch_global("stl", {
    nvim = {
      fn = {
        btn = function(text)
          return text
        end,
        txt = function(text)
          return text
        end,
      },
    },
  })

  return assert(loadfile("lua/era/m/nvimbar/component/nvim.lua"))()
end

t:test("transient messages keep both ends when truncated", function()
  local nvim = setup("0123456789")
  local component = nvim.msg_transient("f_sl")

  local text, _, full = component.render({}, 5)

  t.assert_eq("01…89", text, "truncated message")
  t.assert_false(full, "truncated result")
end)

t:test("transient truncation respects display width", function()
  local nvim = setup("甲乙丙丁")
  local component = nvim.msg_transient("f_sl")

  local text = component.render({}, 5)

  t.assert_eq("甲…丁", text, "wide character message")
  t.assert_eq(5, vim.api.nvim_strwidth(text), "display width")
end)

t:test("transient messages remain intact when space is available", function()
  local nvim = setup("ready")
  local component = nvim.msg_transient("f_sl")

  local text, _, full = component.render({}, 5)

  t.assert_eq("ready", text, "full message")
  t.assert_true(full, "full result")
end)

t:test("transient messages stay hidden when only an ellipsis would fit", function()
  local nvim = setup("0123456789")
  local component = nvim.msg_transient("f_sl")

  local text = component.render({}, 4)

  t.assert_eq("", text, "narrow message")
end)

t:run()
