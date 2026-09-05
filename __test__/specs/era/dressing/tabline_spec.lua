--- Run with: nvim -l __test__/run.lua era/dressing/tabline_spec.lua
---@diagnostic disable: undefined-global

local harness = require("__test__.support.harness")
local enums = require("stl.e")
local module_name = "era.dressing.tabline"
local t = harness.new(module_name)

local function setup()
  local runtime = {
    bufnrs = { 1 },
    devmode = false,
    subscribers = {},
    bars = {},
    explorer_redraws = 0,
    dirty_winnrs = {},
  }
  local tabnr = vim.api.nvim_get_current_tabpage()
  local previous_tabtype = vim.t[tabnr].tabtype
  local previous_tabline = vim.api.nvim_get_option_value("tabline", {})
  local previous_showtabline = vim.api.nvim_get_option_value("showtabline", {})
  t:defer(function()
    vim.t[tabnr].tabtype = previous_tabtype
    vim.api.nvim_set_option_value("tabline", previous_tabline, {})
    vim.api.nvim_set_option_value("showtabline", previous_showtabline, {})
  end)
  vim.t[tabnr].tabtype = nil

  local component = setmetatable({}, {
    __index = function()
      return setmetatable({}, {
        __index = function()
          return function()
            return {}
          end
        end,
      })
    end,
  })

  t:patch_global("stl", {
    e = enums,
    filetype = require("stl.filetype"),
    icon = { symbols = { sep_left = "[", sep_right = "]" } },
    c = { Subscriber = {
      new = function(props)
        return props
      end,
    } },
    fn = {
      falsy = function()
        return false
      end,
    },
    nvim = { fn = {
      txt = function(text)
        return text
      end,
    } },
  })
  t:patch_global("dot", {
    context = { flight = { devmode = {
      snapshot = function()
        return runtime.devmode
      end,
    } } },
    tab = {
      resolve = function(current_tabnr, create)
        t.assert_eq(vim.api.nvim_get_current_tabpage(), current_tabnr, "current tab metadata")
        t.assert_false(create, "metadata lookup does not create state")
        return { bufs = runtime.bufnrs }
      end,
    },
    state = {
      status = {
        dirtier_tabline = {
          subscribe = function(_, subscriber)
            runtime.subscribers[#runtime.subscribers + 1] = subscriber
            subscriber.on_next()
          end,
        },
        dirty_winline_nr = {
          next = function(_, winnr)
            runtime.dirty_winnrs[#runtime.dirty_winnrs + 1] = winnr
          end,
        },
      },
    },
  })
  t:patch_global("era", require("era"))
  t:patch_table(era.widget, "explorer", {
    widget = {
      has_win_in_tab = function()
        return true
      end,
      render_winbar = function()
        runtime.explorer_redraws = runtime.explorer_redraws + 1
      end,
    },
  })
  t:patch_table(era.m, "nvimbar", {
    component = component,
    Nvimbar = {
      new = function(props)
        local bar = { render_count = 0 }
        function bar:place()
          return self
        end
        function bar:render()
          self.render_count = self.render_count + 1
        end
        function bar:snapshot()
          return props.name
        end
        function bar:fulfill()
          props.on_fulfilled()
        end
        runtime.bars[props.name] = bar
        return bar
      end,
    },
  })
  t:patch_table(package.loaded, module_name, nil)
  t.assert_eq(module_name, era.dressing.__mods.tabline, "module registration")
  t.assert_nil(era.m.__mods.tabline, "old registration removed")
  local Tabline = era.dressing.tabline

  runtime.refresh = function()
    for _, subscriber in ipairs(runtime.subscribers) do
      subscriber.on_next()
    end
  end
  return runtime, Tabline
end

t:test("dressing subscribes once and preserves visibility transition state", function()
  local runtime, Tabline = setup()
  runtime.bufnrs = { 1, 2 }
  Tabline.dressing()
  Tabline.dressing()
  t.assert_eq(1, #runtime.subscribers, "dirty subscriptions")
  t.assert_eq(1, runtime.bars.tabline.render_count, "initial render count")
  t.assert_eq(1, runtime.explorer_redraws, "initial explorer redraw")
  t.assert_eq(2, vim.api.nvim_get_option_value("showtabline", {}), "visible tabline")

  runtime.refresh()
  t.assert_eq(2, runtime.bars.tabline.render_count, "one render per refresh")
  t.assert_eq(1, runtime.explorer_redraws, "no redraw without a visibility change")

  runtime.bufnrs = { 1 }
  runtime.refresh()
  t.assert_eq(0, vim.api.nvim_get_option_value("showtabline", {}), "hidden tabline")
  t.assert_eq(2, runtime.explorer_redraws, "explorer redraw on hide")
  local winnrs = vim.api.nvim_list_wins()
  t.assert_true(vim.deep_equal(winnrs, runtime.dirty_winnrs), "winline refresh after hiding")

  Tabline.dressing()
  runtime.refresh()
  t.assert_eq(1, #runtime.subscribers, "subscription preserved while hidden")
  t.assert_eq(2, runtime.explorer_redraws, "hidden tabline does not redraw again")
  t.assert_eq(#winnrs, #runtime.dirty_winnrs, "windows invalidated once")

  runtime.bufnrs = { 1, 2 }
  runtime.refresh()
  t.assert_eq(2, vim.api.nvim_get_option_value("showtabline", {}), "tabline visible again")
  t.assert_eq(3, runtime.explorer_redraws, "explorer redraw on show")
end)

t:test("dressing initializes once while hidden and responds to devmode changes", function()
  local runtime, Tabline = setup()
  Tabline.dressing()
  Tabline.dressing()
  t.assert_eq(1, #runtime.subscribers, "subscriptions while initially hidden")
  t.assert_eq(0, runtime.bars.tabline.render_count, "hidden tabline is not rendered")
  t.assert_eq(0, vim.api.nvim_get_option_value("showtabline", {}), "initially hidden")

  runtime.devmode = true
  runtime.refresh()
  t.assert_eq(2, vim.api.nvim_get_option_value("showtabline", {}), "devmode shows tabline")
  t.assert_eq(1, runtime.bars.tabline.render_count, "devmode render")
  runtime.devmode = false
  runtime.refresh()
  t.assert_eq(0, vim.api.nvim_get_option_value("showtabline", {}), "hidden after leaving devmode")
end)

t:test("custom factories remain lazy and are reused across initialization and tab types", function()
  local runtime, Tabline = setup()
  local factory_calls, render_count = 0, 0
  Tabline.register(enums.TabTypeEnum.DIFFVIEW_WORKSPACE, function()
    factory_calls = factory_calls + 1
    return {
      render = function()
        render_count = render_count + 1
      end,
    }
  end)
  local function duplicate_factory()
    error("duplicate factory must not replace the existing registration")
  end
  Tabline.register(enums.TabTypeEnum.DIFFVIEW_WORKSPACE, duplicate_factory)
  Tabline.dressing()
  t.assert_eq(0, factory_calls, "factory stays lazy on the normal tab")

  vim.t.tabtype = enums.TabTypeEnum.DIFFVIEW_WORKSPACE
  runtime.refresh()
  t.assert_eq(1, factory_calls, "factory called on first matching render")
  t.assert_eq(1, render_count, "first custom render")
  Tabline.register(enums.TabTypeEnum.DIFFVIEW_WORKSPACE, duplicate_factory)
  Tabline.dressing()
  runtime.refresh()
  t.assert_eq(1, factory_calls, "factory result reused")
  t.assert_eq(2, render_count, "one custom render per refresh")

  vim.t.tabtype = enums.TabTypeEnum.NORMAL
  runtime.refresh()
  vim.t.tabtype = enums.TabTypeEnum.DIFFVIEW_WORKSPACE
  runtime.refresh()
  t.assert_eq(1, factory_calls, "factory result survives tab-type changes")
  t.assert_eq(3, render_count, "custom renderer reused after returning")
end)

t:test("normal and maximize results only update the matching tab type", function()
  local runtime, Tabline = setup()
  runtime.bufnrs = { 1, 2 }
  Tabline.dressing()
  local normal = runtime.bars.tabline
  normal:fulfill()
  t.assert_eq("tabline", vim.api.nvim_get_option_value("tabline", {}), "normal result")
  t.assert_nil(runtime.bars.tabline_maximize, "maximize renderer stays lazy")

  vim.t.tabtype = enums.TabTypeEnum.MAXIMIZE
  runtime.refresh()
  local maximize = runtime.bars.tabline_maximize
  maximize:fulfill()
  normal:fulfill()
  t.assert_eq("tabline_maximize", vim.api.nvim_get_option_value("tabline", {}), "stale normal result ignored")

  vim.t.tabtype = enums.TabTypeEnum.NORMAL
  runtime.refresh()
  normal:fulfill()
  maximize:fulfill()
  t.assert_eq("tabline", vim.api.nvim_get_option_value("tabline", {}), "stale maximize result ignored")
  vim.t.tabtype = enums.TabTypeEnum.MAXIMIZE
  runtime.refresh()
  t.assert_eq(maximize, runtime.bars.tabline_maximize, "maximize renderer reused")
  t.assert_eq(2, maximize.render_count, "maximize render count")
end)

t:run()
