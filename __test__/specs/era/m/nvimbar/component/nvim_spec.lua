--- Run with: nvim -l __test__/run.lua __test__/specs/era/m/nvimbar/component/nvim_spec.lua
---@diagnostic disable: undefined-global

local harness = require("__test__.support.harness")

local t = harness.new("era.m.nvimbar.component.nvim")

---@param message                       string
---@param search_pattern                string|nil
---@param search_count                  string|nil
---@return era.m.nvimbar.component.nvim
local function setup(message, search_pattern, search_count)
  t:patch_global("dot", {
    state = {
      status = {
        msg_command = {
          snapshot = function()
            return message
          end,
        },
        msg_transient = {
          snapshot = function()
            return message
          end,
        },
        get_search = function(winnr)
          if winnr == 42 then
            return search_pattern, search_count
          end
        end,
      },
    },
  })
  t:patch_global("stl", {
    icon = {
      ui = {
        Search = "S",
      },
    },
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

  ---@diagnostic disable-next-line: missing-fields
  local text, _, full = component.render({}, 5)

  t.assert_eq("01…89", text, "truncated message")
  t.assert_false(full, "truncated result")
end)

t:test("transient truncation respects display width", function()
  local nvim = setup("甲乙丙丁")
  local component = nvim.msg_transient("f_sl")

  ---@diagnostic disable-next-line: missing-fields
  local text = component.render({}, 5)

  t.assert_eq("甲…丁", text, "wide character message")
  t.assert_eq(5, vim.api.nvim_strwidth(text), "display width")
end)

t:test("transient messages remain intact when space is available", function()
  local nvim = setup("ready")
  local component = nvim.msg_transient("f_sl")

  ---@diagnostic disable-next-line: missing-fields
  local text, _, full = component.render({}, 5)

  t.assert_eq("ready", text, "full message")
  t.assert_true(full, "full result")
end)

t:test("transient messages stay hidden when only an ellipsis would fit", function()
  local nvim = setup("0123456789")
  local component = nvim.msg_transient("f_sl")

  ---@diagnostic disable-next-line: missing-fields
  local text = component.render({}, 4)

  t.assert_eq("", text, "narrow message")
end)

t:test("command messages remain visible until the API clears them", function()
  local nvim = setup("2,1 All")
  local now = 0
  t:patch_table(os, "time", function()
    return now
  end)
  local component = nvim.msg_command("f_sl")

  ---@diagnostic disable-next-line: missing-parameter
  t.assert_eq("2,1 All", component.render(), "initial command message")
  now = 10
  ---@diagnostic disable-next-line: missing-parameter
  t.assert_eq("2,1 All", component.render(), "persistent command message")
end)

t:test("search count renders at the right edge for its source window", function()
  local nvim = setup("", "foo", "2/10")
  local component = nvim.search_count("f_wl")
  ---@diagnostic disable-next-line: missing-fields
  local context = { winnr = 42 } ---@type era.m.nvimbar.INvimbarContext

  t.assert_true(component.condition(context, 20), "source window")
  local text, _, full = component.render(context, 20)
  t.assert_eq(" S foo 2/10", text, "search state")
  t.assert_true(full, "atomic result")

  ---@diagnostic disable-next-line: missing-fields
  t.assert_false(component.condition({ winnr = 43 }, 20), "other window")
end)

t:test("search count preserves native boundary forms without brackets", function()
  local nvim = setup("", "foo", "?/??")
  local component = nvim.search_count("f_wl")
  ---@diagnostic disable-next-line: missing-fields
  local text = component.render({ winnr = 42 }, 20)

  t.assert_eq(" S foo ?/??", text, "boundary count")
end)

t:test("search pattern remains visible before a count arrives", function()
  local nvim = setup("", "foo", nil)
  local component = nvim.search_count("f_wl")
  ---@diagnostic disable-next-line: missing-fields
  local text = component.render({ winnr = 42 }, 20)

  t.assert_eq(" S foo", text, "pattern")
end)

t:test("long search patterns truncate without dropping the count", function()
  local nvim = setup("", "abcdefghijkl", "2/10")
  local component = nvim.search_count("f_wl")
  ---@diagnostic disable-next-line: missing-fields
  local text, _, full = component.render({ winnr = 42 }, 12)

  t.assert_eq(" S abc… 2/10", text, "truncated search")
  t.assert_false(full, "truncated result")
end)

t:run()
