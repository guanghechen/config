---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/era/m/diffview/workspace_winline.lua

local harness = require("__test__.harness")

local t = harness.new("era.m.diffview.workspace_winline")
local on_state_change = nil ---@type function|nil
local nvimbar_props = nil ---@type table|nil
local placements = {} ---@type table[]
local render_count = 0
local meta = {} ---@type dot.win.IMeta

local nvimbar = {
  isdisposed = function()
    return false
  end,
  place = function(self, position, component, priority)
    placements[#placements + 1] = { position = position, component = component, priority = priority }
    return self
  end,
  render = function()
    render_count = render_count + 1
  end,
}

t:patch_global("stl", {
  fn = {
    falsy = function()
      return false
    end,
    observe = function(_, callback)
      on_state_change = callback
    end,
  },
  icon = {
    git = { Git = "G" },
    ui = { TabPage = "P" },
  },
  nvim = {
    fn = {
      txt = function(text)
        return text
      end,
    },
  },
})
t:patch_global("dot", {
  win = {
    resolve = function()
      return meta
    end,
  },
})
t:patch_global("era", {
  m = {
    nvimbar = {
      Nvimbar = {
        new = function(props)
          nvimbar_props = props
          return nvimbar
        end,
      },
      component = {
        nvim = {
          search_count = function(position)
            t.assert_eq("f_wl", position, "search position")
            return { name = "nvim:search_count" }
          end,
        },
      },
    },
  },
})

local page = 1
local total = 12
local state = {
  commits_page = {},
  commits_total = {},
  get_commits_page = function()
    return page
  end,
  get_commits_page_count = function()
    return math.max(1, math.ceil(total / 50))
  end,
  get_commits_total = function()
    return total
  end,
}

t:test("History winline renders and follows pagination state", function()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local previous_winbar = vim.api.nvim_get_option_value("winbar", { win = winnr }) ---@type string
  local winline = assert(loadfile("lua/era/m/diffview/view/workspace/winline.lua"))()
  local ctx = {
    layout = { tabnr = vim.api.nvim_get_current_tabpage(), commits_winnr = winnr, title = "History" },
    state = state,
  }
  winline.setup(ctx)

  t.assert_eq(2, #placements, "component count")
  t.assert_eq("diffview:history_status", placements[1].component.name, "History status component")
  t.assert_eq("nvim:search_count", placements[2].component.name, "search component")
  t.assert_eq(1, render_count, "initial render")
  t.assert_true(meta.winline.nvimbar == nvimbar, "window owns nvimbar")

  local text = winline.status_component(ctx).render({}, 80)
  t.assert_eq(" History G 12 │ P 1/1 ", text, "initial status")

  page = 2
  total = 120
  assert(on_state_change)()
  t.assert_eq(2, render_count, "state-triggered render")
  text = winline.status_component(ctx).render({}, 80)
  t.assert_eq(" History G 120 │ P 2/3 ", text, "updated status")

  assert(nvimbar_props).on_fulfilled("rendered winline")
  t.assert_eq("rendered winline", vim.api.nvim_get_option_value("winbar", { win = winnr }), "fulfilled winline")

  vim.api.nvim_set_option_value("winbar", previous_winbar, { win = winnr, scope = "local" })
end)

t:run()
