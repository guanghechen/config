local harness = require("__test__.support.harness")

local t = harness.new()

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
  local text = component.render(component.refresh({}), {}, 5)

  t.assert_eq("01…89", text, "truncated message")
end)

t:test("transient truncation respects display width", function()
  local nvim = setup("甲乙丙丁")
  local component = nvim.msg_transient("f_sl")

  ---@diagnostic disable-next-line: missing-fields
  local text = component.render(component.refresh({}), {}, 5)

  t.assert_eq("甲…丁", text, "wide character message")
  t.assert_eq(5, vim.api.nvim_strwidth(text), "display width")
end)

t:test("transient messages remain intact when space is available", function()
  local nvim = setup("ready")
  local component = nvim.msg_transient("f_sl")

  ---@diagnostic disable-next-line: missing-fields
  local text = component.render(component.refresh({}), {}, 5)

  t.assert_eq("ready", text, "full message")
end)

t:test("transient messages stay hidden when only an ellipsis would fit", function()
  local nvim = setup("0123456789")
  local component = nvim.msg_transient("f_sl")

  ---@diagnostic disable-next-line: missing-fields
  local text = component.render(component.refresh({}), {}, 4)

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
  t.assert_eq("2,1 All", component.refresh({}).text, "initial command message")
  now = 10
  ---@diagnostic disable-next-line: missing-parameter
  t.assert_eq("2,1 All", component.refresh({}).text, "persistent command message")
end)

t:test("search count renders at the right edge for its source window", function()
  local nvim = setup("", "foo", "2/10")
  local component = nvim.search_count("f_wl")
  ---@diagnostic disable-next-line: missing-fields
  local context = { winnr = 42 } ---@type era.m.nvimbar.INvimbarContext

  t.assert_true(component.condition(context), "source window")
  local text = component.render(component.refresh(context), context, 20)
  t.assert_eq(" S foo 2/10", text, "search state")

  ---@diagnostic disable-next-line: missing-fields
  t.assert_false(component.condition({ winnr = 43 }), "other window")
end)

t:test("search count preserves native boundary forms without brackets", function()
  local nvim = setup("", "foo", "?/??")
  local component = nvim.search_count("f_wl")
  ---@diagnostic disable-next-line: missing-fields
  local text = component.render(component.refresh({ winnr = 42 }), { winnr = 42 }, 20)

  t.assert_eq(" S foo ?/??", text, "boundary count")
end)

t:test("search pattern remains visible before a count arrives", function()
  local nvim = setup("", "foo", nil)
  local component = nvim.search_count("f_wl")
  ---@diagnostic disable-next-line: missing-fields
  local text = component.render(component.refresh({ winnr = 42 }), { winnr = 42 }, 20)

  t.assert_eq(" S foo", text, "pattern")
end)

t:test("long search patterns truncate without dropping the count", function()
  local nvim = setup("", "abcdefghijkl", "2/10")
  local component = nvim.search_count("f_wl")
  ---@diagnostic disable-next-line: missing-fields
  local text = component.render(component.refresh({ winnr = 42 }), { winnr = 42 }, 12)

  t.assert_eq(" S abc… 2/10", text, "truncated search")
end)

---@param cmd                           string[]
---@return integer bufnr
---@return integer channel
local function open_terminal(cmd)
  local bufnr = vim.api.nvim_create_buf(false, true)
  t:defer(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  local channel = 0 ---@type integer
  vim.api.nvim_buf_call(bufnr, function()
    channel = vim.fn.jobstart(cmd, { term = true })
  end)
  t.assert_true(channel > 0, "terminal job started")
  return bufnr, channel
end

t:test("pid shows the process of a running terminal job", function()
  local component = setup("").pid("right")
  local bufnr, channel = open_terminal({ "sleep", "30" })
  t:defer(function()
    pcall(vim.fn.jobstop, channel)
  end)

  ---@diagnostic disable-next-line: missing-fields
  local text = component.refresh({ bufnr = bufnr }).text ---@type string
  local suffix = " " .. vim.fn.jobpid(channel) ---@type string
  t.assert_eq(suffix, text:sub(-#suffix), "running job")
end)

t:test("pid shows nothing once the terminal job exits", function()
  local component = setup("").pid("right")
  local bufnr, channel = open_terminal({ "sh", "-c", "exit 0" })
  t.assert_eq(0, vim.fn.jobwait({ channel }, 2000)[1], "job exited")

  ---@diagnostic disable-next-line: missing-fields
  t.assert_eq("", component.refresh({ bufnr = bufnr }).text, "exited job")
end)

t:test("pid shows nothing for a buffer without a channel", function()
  local component = setup("").pid("right")
  local bufnr = vim.api.nvim_create_buf(false, true)
  t:defer(function()
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)

  ---@diagnostic disable-next-line: missing-fields
  t.assert_eq("", component.refresh({ bufnr = bufnr }).text, "plain buffer")
end)

t:run()
