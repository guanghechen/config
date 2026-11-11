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

for _, case in ipairs({
  {
    name = "transient messages keep both ends when truncated",
    message = "0123456789",
    width = 5,
    text = "01…89",
    label = "truncated message",
  },
  {
    name = "transient truncation respects display width",
    message = "甲乙丙丁",
    width = 5,
    text = "甲…丁",
    label = "wide character message",
    display_width = 5,
  },
  {
    name = "transient messages remain intact when space is available",
    message = "ready",
    width = 5,
    text = "ready",
    label = "full message",
  },
  {
    name = "transient messages stay hidden when only an ellipsis would fit",
    message = "0123456789",
    width = 4,
    text = "",
    label = "narrow message",
  },
}) do
  t:test(case.name, function()
    local nvim = setup(case.message)
    local component = nvim.msg_transient("f_sl")

    ---@diagnostic disable-next-line: missing-fields
    local text = component.render(component.refresh({}), {}, case.width)

    t.assert_eq(case.text, text, case.label)
    if case.display_width ~= nil then
      t.assert_eq(case.display_width, vim.api.nvim_strwidth(text), "display width")
    end
  end)
end

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

for _, case in ipairs({
  {
    name = "search count renders at the right edge for its source window",
    pattern = "foo",
    count = "2/10",
    width = 20,
    text = " S foo 2/10",
    label = "search state",
    -- Only the window the search state belongs to shows it.
    source_window = true,
  },
  {
    name = "search count preserves native boundary forms without brackets",
    pattern = "foo",
    count = "?/??",
    width = 20,
    text = " S foo ?/??",
    label = "boundary count",
  },
  {
    name = "search pattern remains visible before a count arrives",
    pattern = "foo",
    width = 20,
    text = " S foo",
    label = "pattern",
  },
  {
    name = "long search patterns truncate without dropping the count",
    pattern = "abcdefghijkl",
    count = "2/10",
    width = 12,
    text = " S abc… 2/10",
    label = "truncated search",
  },
}) do
  t:test(case.name, function()
    local nvim = setup("", case.pattern, case.count)
    local component = nvim.search_count("f_wl")
    ---@diagnostic disable-next-line: missing-fields
    local context = { winnr = 42 } ---@type era.m.nvimbar.INvimbarContext

    if case.source_window then
      t.assert_true(component.condition(context), "source window")
    end
    local text = component.render(component.refresh(context), context, case.width)
    t.assert_eq(case.text, text, case.label)
    if case.source_window then
      ---@diagnostic disable-next-line: missing-fields
      t.assert_false(component.condition({ winnr = 43 }), "other window")
    end
  end)
end

---@param cmd                           string[]
---@return integer bufnr
---@return integer channel
local function open_terminal(cmd)
  local bufnr = t:buffer()
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
  local bufnr = t:buffer()

  ---@diagnostic disable-next-line: missing-fields
  t.assert_eq("", component.refresh({ bufnr = bufnr }).text, "plain buffer")
end)

t:run()
