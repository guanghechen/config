---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/era/m/diffview/commits_tabline.lua

local bootstrap = require("__test__.bootstrap")
local harness = require("__test__.harness")

local t = harness.new("era.m.diffview.commits_tabline")
local layout = nil ---@type era.m.diffview.view.commits.ILayout|nil

local function observable(value)
  return {
    snapshot = function()
      return value
    end,
    next = function(_, next_value)
      value = next_value
    end,
  }
end

bootstrap.with_global(t, "stl", {
  icon = {
    git = { Git = "G" },
    symbols = {
      flag_fold = "F",
      flag_fold_empty_path = "E",
      flag_layout_1 = "L",
      flag_layout_2 = "L",
      flag_layout_3 = "L",
      flag_layout_4 = "L",
      flag_layout_5 = "L",
      flag_list = "I",
      flag_tree = "T",
    },
    ui = { Search = "S" },
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
    win = {
      is_float = function()
        return false
      end,
    },
  },
})
bootstrap.with_global(t, "dot", {
  G = {
    register_anonymous_fn = function()
      return "dot.G.test"
    end,
  },
  context = {
    diffview = {
      flag_fold_unchanges = observable(true),
      flag_foldempty = observable(true),
      flag_panel_viewtype = observable("tree"),
    },
  },
  state = {
    status = {
      dirtier_tabline = { mark_dirty = function() end },
    },
  },
})

local state = {
  get_commits = function()
    return {}
  end,
  get_commits_page = function()
    return 1
  end,
  get_commits_page_count = function()
    return 1
  end,
  get_commits_total = function()
    return 12
  end,
  get_current_commit = function()
    return nil
  end,
}

t:patch_table(package.loaded, "era.m.diffview.config", { COMMITS_PER_PAGE = 50 })
t:patch_table(package.loaded, "era.m.diffview.view.commits.state", {
  get = function()
    return state
  end,
})
t:patch_table(package.loaded, "era.m.diffview.view.commits.view", {
  get_layout = function()
    return layout
  end,
  render_commits = function() end,
})
t:patch_table(package.loaded, "era.m.diffview.pane.sbs", {
  apply_fold_unchanged_pair = function() end,
})

local tabline = assert(loadfile("lua/era/m/diffview/view/commits/tabline.lua"))()

t:test("layout 3 renders status buttons against the left SBS pane", function()
  local sbs_left_winnr = vim.api.nvim_get_current_win()
  layout = {
    tabnr = vim.api.nvim_get_current_tabpage(),
    layout_type = 3,
    commits_winnr = nil,
    sbs_left_winnr = sbs_left_winnr,
  }

  local text = tabline.status_component().render({}, 120)

  t.assert_true(text:find("L₃", 1, true) ~= nil, "layout button")
  t.assert_true(text:find("F³", 1, true) ~= nil, "fold default button")
end)

t:test("commits pane remains the preferred status width", function()
  vim.cmd("tabnew")
  local commits_winnr = vim.api.nvim_get_current_win()
  vim.cmd("rightbelow vsplit")
  local sbs_left_winnr = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_width(commits_winnr, 10)

  layout = {
    tabnr = vim.api.nvim_get_current_tabpage(),
    layout_type = 2,
    commits_winnr = commits_winnr,
    sbs_left_winnr = sbs_left_winnr,
  }

  local text = tabline.status_component().render({}, 120)
  local commits_width = vim.api.nvim_win_get_width(commits_winnr)

  t.assert_true(vim.api.nvim_strwidth(text) <= commits_width, "status width")
  vim.cmd("tabclose!")
end)

t:run()
