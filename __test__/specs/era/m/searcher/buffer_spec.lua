local harness = require("__test__.support.harness")
local bootstrap = require("__test__.support.bootstrap")
local t = harness.new("era.m.searcher.buffer")

local errors = {}
bootstrap.with_runtime(t, {
  stl = {
    fn = { noop = function() end },
    nvim = { fn = require("stl.nvim.fn") },
    reporter = {
      error = function(details)
        errors[#errors + 1] = details
      end,
    },
  },
  dot = {
    path = {
      cwd = function()
        return "/project"
      end,
    },
    theme = { hlgroup = { common = {
      resolve_mode = function()
        return "n", "NORMAL"
      end,
    } } },
  },
  yoz = { path = {
    basename = function(path)
      return path:match("[^/]*$")
    end,
  } },
})

local Searcher = require("era.m.searcher.buffer")

local function setup()
  errors = {}
  local state = { index = 1, total = 3, reads = 0 }
  local searcher = setmetatable({ _scheduler_search = { cancel = function() end } }, Searcher)
  local bar = searcher:__create_nvimbar__({
    snapshot = function()
      state.reads = state.reads + 1
      return state.index
    end,
  }, {
    snapshot = function()
      return state.total
    end,
  }, {})
  t:defer(function()
    bar:dispose()
  end)
  return searcher, bar, state
end

local function show(searcher)
  local bufnr = vim.api.nvim_create_buf(false, true)
  t:defer(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  local winnr = vim.api.nvim_open_win(bufnr, false, { relative = "editor", row = 1, col = 1, width = 40, height = 3 })
  t:defer(function()
    if vim.api.nvim_win_is_valid(winnr) then
      vim.api.nvim_win_close(winnr, true)
    end
  end)
  searcher._bufnr_finder, searcher._winnr_finder = bufnr, winnr
  return winnr
end

t:test("winbar refresh before opening the finder is a no-op", function()
  local _, bar, state = setup()
  t.assert_eq(bar, bar:refresh())
  t.assert_eq("", bar:snapshot())
  t.assert_eq(0, state.reads)
  t.assert_eq(0, #errors)
end)

t:test("closing the finder safely drains its queued refresh and publication", function()
  local searcher, bar, state = setup()
  show(searcher)
  local errmsg = vim.v.errmsg
  t:defer(function()
    vim.v.errmsg = errmsg
  end)
  bar:refresh()
  searcher:close()
  t.wait_until(function()
    for _, component in ipairs(bar._components) do
      if component.runtime._queued then
        return false
      end
    end
    return not bar._publish_scheduled
  end, 1000)
  t.assert_eq(errmsg, vim.v.errmsg, "scheduled publication does not report an editor error")
  t.assert_eq(0, #errors, vim.inspect(errors))
  t.assert_eq(0, state.reads, "hidden data providers do not run")
  t.assert_eq("", bar:snapshot())
end)

t:test("a closed finder accepts later refreshes and reopens with current data", function()
  local searcher, bar, state = setup()
  local first_winnr = show(searcher)
  bar:refresh()
  t.wait_until(function()
    return vim.api.nvim_get_option_value("winbar", { win = first_winnr }):find("1 / 3", 1, true) ~= nil
  end, 1000)
  local snapshot = bar:snapshot()
  searcher:close()
  bar:refresh()
  t.assert_eq(snapshot, bar:snapshot(), "closing retains the last published value")
  t.assert_eq("", bar:render(), "a closed finder has no current layout")
  state.index, state.total = 2, 7
  local second_winnr = show(searcher)
  bar:refresh()
  t.wait_until(function()
    return vim.api.nvim_get_option_value("winbar", { win = second_winnr }):find("2 / 7", 1, true) ~= nil
  end, 1000)
  t.assert_eq(0, #errors, vim.inspect(errors))
end)

t:run()
