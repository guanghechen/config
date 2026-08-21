---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/era/m/select_focus.lua

local bootstrap = require("__test__.bootstrap")
local harness = require("__test__.harness")

local t = harness.new("era.m.select.focus")

local picker_focused = false
local picker_closed = 0
local picker_props = nil ---@type table|nil

local picker = {
  result = {
    lnum_current = {
      snapshot = function()
        return 1
      end,
    },
  },
  close = function()
    picker_closed = picker_closed + 1
  end,
  focus = function() end,
  isfocused = function()
    return picker_focused
  end,
  reset_data = function() end,
  retrieve = function()
    return nil
  end,
}

bootstrap.with_global(t, "dot", {})
bootstrap.with_global(t, "era", {
  m = {
    picker = {
      ListComposer = {
        new = function(props)
          picker_props = props
          return picker
        end,
      },
    },
  },
})
bootstrap.with_global(t, "stl", {
  c = {
    Observable = {
      from_value = function(value)
        return {
          dispose = function() end,
          snapshot = function()
            return value
          end,
        }
      end,
    },
  },
  fn = {
    observe = function() end,
  },
})

t:patch_table(package.loaded, "era.m.select.view", {})

local select = assert(loadfile("lua/era/m/select/init.lua"))()

---@return integer, integer
local function create_window_pair()
  local origin_winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.cmd("vsplit")
  local other_winnr = vim.api.nvim_get_current_win() ---@type integer
  t:_register_cleanup(function()
    if vim.api.nvim_win_is_valid(other_winnr) then
      vim.api.nvim_win_close(other_winnr, true)
    end
  end)
  vim.api.nvim_set_current_win(origin_winnr)
  return origin_winnr, other_winnr
end

---@param on_choice                     fun(item: any|nil, idx: integer|nil): nil
---@return nil
local function open_select(on_choice)
  picker_props = nil
  picker_closed = 0
  select.select({ "one" }, { prompt = "Focus" }, on_choice)
  t.assert_true(picker_props ~= nil, "picker props")
end

t:test("vim.ui.select preserves a newer focus when the picker no longer owns it", function()
  local _, other_winnr = create_window_pair()
  local selected = nil ---@type string|nil
  open_select(function(item)
    selected = item
  end)

  picker_focused = false
  vim.api.nvim_set_current_win(other_winnr)
  picker_props.on_confirm(picker, { uuid = "1", data = { original_item = "one" } })

  t.assert_eq(other_winnr, vim.api.nvim_get_current_win(), "current window")
  t.assert_eq("one", selected, "selected item")
  t.assert_eq(1, picker_closed, "picker close count")
end)

t:test("vim.ui.select restores its origin while the picker still owns focus", function()
  local origin_winnr, picker_winnr = create_window_pair()
  open_select(function() end)

  picker_focused = true
  vim.api.nvim_set_current_win(picker_winnr)
  picker_props.on_confirm(picker, nil)

  t.assert_eq(origin_winnr, vim.api.nvim_get_current_win(), "origin window")
  t.assert_eq(1, picker_closed, "picker close count")
end)

t:run()
