local harness = require("__test__.support.harness")
local bootstrap = require("__test__.support.bootstrap")
local Future = require("stl.c.future")
local t = harness.new("era.m.explorer.winbar")

bootstrap.with_runtime(t, {
  stl = {
    fn = { noop = function() end },
    env = { PATH_SEP = "/" },
    nvim = { fn = {
      txt = function(text)
        return text
      end,
    } },
    reporter = {
      error = function(details)
        error(vim.inspect(details))
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

local Widget = require("era.m.explorer.widget")

local function setup()
  local showtabline = vim.o.showtabline
  t:defer(function()
    vim.o.showtabline = showtabline
  end)
  vim.o.showtabline = 0
  local bufnr = vim.api.nvim_create_buf(false, true)
  t:defer(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  local winnr = vim.api.nvim_open_win(bufnr, false, { relative = "editor", row = 1, col = 1, width = 50, height = 5 })
  t:defer(function()
    if vim.api.nvim_win_is_valid(winnr) then
      vim.api.nvim_win_close(winnr, true)
    end
  end)
  local jobs = {}
  t:patch_table(package.loaded, "era.m.nvimbar.component.explorer", {
    winbar = function()
      return {
        name = "explorer:winbar",
        refresh = function(_, token)
          local future, resolve = Future.new_with_resolver({ token = token })
          jobs[#jobs + 1] = { future = future, resolve = resolve }
          return future
        end,
      }
    end,
  })
  local widget = setmetatable({
    fullname = "test-explorer",
    _bufnr = bufnr,
    _disposed = false,
    _unregister_fns = {},
    _tab_wins = { [vim.api.nvim_get_current_tabpage()] = winnr },
    _tree = {},
    __get_flags__ = function()
      return {}
    end,
  }, Widget)
  widget._nvimbar = widget:__create_nvimbar__()
  t:defer(function()
    widget._nvimbar:dispose()
  end)
  return widget, winnr, jobs
end

---@return nil
local function wait_for_publication(widget)
  t.wait_until(function()
    return not widget._nvimbar._publish_scheduled
  end, 1000)
end

t:test("hiding cancels queued work and showing again refreshes the winbar", function()
  local widget, winnr, jobs = setup()
  widget:__update_winbar__()
  vim.o.showtabline = 2
  widget:__update_winbar__()
  t.wait_until(function()
    return not widget._nvimbar._components[1].runtime._queued
  end, 1000)
  wait_for_publication(widget)
  t.assert_eq(0, #jobs, "hidden components do not start fetching")
  t.assert_eq("", vim.api.nvim_get_option_value("winbar", { win = winnr }))

  vim.o.showtabline = 0
  widget:__update_winbar__()
  t.wait_until(function()
    return #jobs == 1
  end, 1000)
  jobs[1].resolve({ text = "Explorer", hltext = "Explorer" })
  t.wait_until(function()
    return vim.api.nvim_get_option_value("winbar", { win = winnr }):find("Explorer", 1, true) ~= nil
  end, 1000)
end)

t:test("hiding cancels an in-flight refresh and rejects late output", function()
  local widget, winnr, jobs = setup()
  widget:__update_winbar__()
  t.wait_until(function()
    return #jobs == 1
  end, 1000)
  vim.o.showtabline = 2
  widget:__update_winbar__()
  t.assert_true(jobs[1].future:is_failed(), "hiding cancels the provider token")
  jobs[1].resolve({ text = "late", hltext = "late" })
  wait_for_publication(widget)
  t.assert_eq("", vim.api.nvim_get_option_value("winbar", { win = winnr }))
end)

t:test("a completed snapshot cannot restore a winbar hidden before publication", function()
  local widget, winnr, jobs = setup()
  widget:__update_winbar__()
  t.wait_until(function()
    return #jobs == 1
  end, 1000)
  jobs[1].resolve({ text = "stale", hltext = "stale" })
  vim.o.showtabline = 2
  widget:__update_winbar__()
  wait_for_publication(widget)
  t.assert_eq("", vim.api.nvim_get_option_value("winbar", { win = winnr }))
end)

t:test("a replaced window buffer retains its own winbar", function()
  local widget, winnr, jobs = setup()
  widget:__update_winbar__()
  t.wait_until(function()
    return #jobs == 1
  end, 1000)
  jobs[1].resolve({ text = "Explorer", hltext = "Explorer" })
  local bufnr = vim.api.nvim_create_buf(false, true)
  t:defer(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  vim.api.nvim_win_set_buf(winnr, bufnr)
  vim.api.nvim_set_option_value("winbar", "other owner", { win = winnr, scope = "local" })
  wait_for_publication(widget)
  t.assert_eq("other owner", vim.api.nvim_get_option_value("winbar", { win = winnr }))
  vim.o.showtabline = 2
  widget:__update_winbar__()
  t.assert_eq("other owner", vim.api.nvim_get_option_value("winbar", { win = winnr }), "hide respects ownership")
end)

t:test("disposing the widget releases its bar and cancels pending data", function()
  local widget, _, jobs = setup()
  ---@cast widget any
  widget._subscriptions = {}
  widget._augroup = -1
  widget.__invalidate_render__ = function() end
  widget._tree = { dispose = function() end }
  widget._resource_manager = { dispose = function() end }
  widget:__update_winbar__()
  t.wait_until(function()
    return #jobs == 1
  end, 1000)
  widget:dispose()
  t.assert_true(widget._nvimbar:isdisposed())
  t.assert_true(jobs[1].future:is_failed())
  jobs[1].resolve({ text = "late", hltext = "late" })
  wait_for_publication(widget)
end)

t:run()
