---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/era/m/diffview/workspace_winline.lua

local harness = require("__test__.harness")

local t = harness.new("era.m.diffview.workspace_winline")
local on_history_state_change = nil ---@type function|nil
local bars = {} ---@type table<string, table>
local metas = {} ---@type table<integer, dot.win.IMeta>
local show_untracked = true

local function new_nvimbar(props)
  local placements = {} ---@type table[]
  local nvimbar = {
    isdisposed = function()
      return false
    end,
    place = function(self, position, component, priority)
      placements[#placements + 1] = { position = position, component = component, priority = priority }
      return self
    end,
    render = function(self)
      self.render_count = self.render_count + 1
    end,
    render_count = 0,
  }
  bars[props.name] = { nvimbar = nvimbar, placements = placements, props = props }
  return nvimbar
end

t:patch_global("stl", {
  fn = {
    falsy = function()
      return false
    end,
    observe = function(_, callback)
      on_history_state_change = callback
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
  context = {
    diffview = {
      flag_untracked = {
        snapshot = function()
          return show_untracked
        end,
      },
    },
  },
  win = {
    resolve = function(winnr)
      return metas[winnr]
    end,
    render_winline = function(winnr)
      local winline = metas[winnr] and metas[winnr].winline or nil
      if not winline then
        return
      end
      winline.nvimbar:render()
      for _, nvimbar in pairs(winline.forks or {}) do
        nvimbar:render()
      end
    end,
  },
})
t:patch_global("era", {
  m = {
    nvimbar = {
      Nvimbar = { new = new_nvimbar },
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
local history_state = {
  commits_page = {},
  commits_total = {},
  get_commits_page = function()
    return page
  end,
  get_commits_page_count = function()
    return math.max(1, math.ceil(total / 100))
  end,
  get_commits_total = function()
    return total
  end,
}
local entries = {
  { filepath = "staged.lua", stage_type = "staged", status = "M" },
  { filepath = "unstaged.lua", stage_type = "unstaged", status = "M" },
  { filepath = "untracked.lua", stage_type = "unstaged", status = "?" },
}
local workspace_state = {
  get_entries = function()
    return entries
  end,
}

t:test("Changes delegates dirty winline renders to its window-owned nvimbar", function()
  local filetype = assert(loadfile("lua/stl/filetype.lua"))()
  t.assert_true(filetype.has_external_winline(filetype.DIFFVIEW_CHANGES), "external Changes winline")
end)

t:test("workspace sidebar winlines own pane labels and search count", function()
  local staged_winnr = vim.api.nvim_get_current_win() ---@type integer
  local previous_winbar = vim.api.nvim_get_option_value("winbar", { win = staged_winnr }) ---@type string
  vim.cmd("belowright split")
  local unstaged_winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.cmd("belowright split")
  local history_winnr = vim.api.nvim_get_current_win() ---@type integer
  for _, winnr in ipairs({ staged_winnr, unstaged_winnr, history_winnr }) do
    metas[winnr] = {}
  end

  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local history = {
    layout = { tabnr = tabnr, commits_winnr = history_winnr, title = "History" },
    state = history_state,
  }
  local ctx = {
    layout = {
      tabnr = tabnr,
      changes = {
        staged = { stage_type = "staged", winnr = staged_winnr },
        unstaged = { stage_type = "unstaged", winnr = unstaged_winnr },
      },
    },
    state = workspace_state,
    history = history,
  }

  local winline = assert(loadfile("lua/era/m/diffview/view/workspace/winline.lua"))()
  winline.setup(ctx)

  local staged = assert(bars["diffview_staged#" .. tabnr .. "#winbar"])
  local unstaged = assert(bars["diffview_unstaged#" .. tabnr .. "#winbar"])
  local history_bar = assert(bars["diffview_history#" .. tabnr .. "#winbar"])
  for _, bar in ipairs({ staged, unstaged, history_bar }) do
    t.assert_eq(2, #bar.placements, "status and search components")
    t.assert_eq("nvim:search_count", bar.placements[2].component.name, "search component")
    t.assert_eq(1, bar.nvimbar.render_count, "initial render")
  end
  t.assert_eq("diffview:staged_status", staged.placements[1].component.name, "Staged status component")
  t.assert_eq("diffview:unstaged_status", unstaged.placements[1].component.name, "Unstaged status component")
  t.assert_eq("diffview:history_status", history_bar.placements[1].component.name, "History status component")

  local text = winline.changes_status_component(ctx, "staged").render({}, 80)
  t.assert_eq(" G Staged (1) ", text, "Staged label")
  text = winline.changes_status_component(ctx, "unstaged").render({}, 80)
  t.assert_eq(" G Unstaged (2) ", text, "Unstaged label")
  show_untracked = false
  text = winline.changes_status_component(ctx, "unstaged").render({}, 80)
  t.assert_eq(" G Unstaged (1) ", text, "hidden untracked entry excluded")

  text = winline.history_status_component(history).render({}, 80)
  t.assert_eq(" History G 12 │ P 1/1 ", text, "initial History status")
  page = 2
  total = 120
  assert(on_history_state_change)()
  t.assert_eq(2, history_bar.nvimbar.render_count, "History state-triggered render")
  text = winline.history_status_component(history).render({}, 80)
  t.assert_eq(" History G 120 │ P 2/2 ", text, "updated History status")

  staged.props.on_fulfilled("rendered Staged winline")
  unstaged.props.on_fulfilled("rendered Unstaged winline")
  history_bar.props.on_fulfilled("rendered History winline")
  t.assert_eq(
    "rendered Staged winline",
    vim.api.nvim_get_option_value("winbar", { win = staged_winnr }),
    "Staged winline applied"
  )
  t.assert_eq(
    "rendered Unstaged winline",
    vim.api.nvim_get_option_value("winbar", { win = unstaged_winnr }),
    "Unstaged winline applied"
  )
  t.assert_eq(
    "rendered History winline",
    vim.api.nvim_get_option_value("winbar", { win = history_winnr }),
    "History winline applied"
  )

  vim.api.nvim_set_current_win(staged_winnr)
  vim.cmd("belowright split")
  local fork_winnr = vim.api.nvim_get_current_win() ---@type integer
  metas[fork_winnr] = {}
  local staged_winline = assert(metas[staged_winnr].winline)
  local fork_nvimbar = assert(assert(staged_winline.fork)(fork_winnr))
  staged_winline.forks = { [fork_winnr] = fork_nvimbar }
  winline.render_changes(ctx)

  local fork = assert(bars[string.format("diffview_staged#%d#winbar#fork#%d", tabnr, fork_winnr)])
  t.assert_eq(1, fork.nvimbar.render_count, "source render reaches Winline fork")
  fork.props.on_fulfilled("rendered forked Staged winline")
  t.assert_eq(
    "rendered forked Staged winline",
    vim.api.nvim_get_option_value("winbar", { win = fork_winnr }),
    "fork owns its target winbar"
  )

  vim.api.nvim_win_close(fork_winnr, true)
  vim.api.nvim_win_close(history_winnr, true)
  vim.api.nvim_win_close(unstaged_winnr, true)
  vim.api.nvim_set_option_value("winbar", previous_winbar, { win = staged_winnr, scope = "local" })
end)

t:run()
