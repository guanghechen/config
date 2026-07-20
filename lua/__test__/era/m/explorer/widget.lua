---@diagnostic disable: undefined-global
--- Test for era.m.explorer.widget module
--- Run with: nvim -l lua/__test__/era/m/explorer/widget.lua

local bootstrap = require("__test__.bootstrap")
local harness = require("__test__.harness")

local t = harness.new("era.m.explorer.widget")

---@return table
local function new_observable()
  local subscribers = {} ---@type table[]
  return {
    subscribe = function(_, subscriber)
      subscribers[#subscribers + 1] = subscriber
      return { unsubscribe = function() end }
    end,
    next = function(_, value)
      for _, subscriber in ipairs(subscribers) do
        subscriber:next(value)
      end
    end,
  }
end

local Subscriber = {}

function Subscriber.new(props)
  return {
    next = function(_, value)
      props.on_next(value)
    end,
  }
end

local o_flag_selected = new_observable()
local o_flag_viewtype = new_observable()
local o_git_refreshed = new_observable()
local o_ignored_refreshed = new_observable()

bootstrap.with_runtime(t, {
  dot = {
    context = {
      explorer = {
        flag_selected = o_flag_selected,
        flag_viewtype = o_flag_viewtype,
      },
    },
    path = {
      normalize = function(filepath, keep_trailing_slash)
        local normalized = filepath:gsub("\\", "/"):gsub("/+", "/") ---@type string
        if keep_trailing_slash == false and normalized ~= "/" then
          normalized = normalized:gsub("/+$", "")
        end
        return normalized
      end,
    },
  },
  era = {
    m = {
      git = {
        state = {
          o_ignored_refreshed = o_ignored_refreshed,
          o_refreshed = o_git_refreshed,
        },
      },
      lsp = {
        diagnostic = {
          subscribe_all = function()
            return { unsubscribe = function() end }
          end,
        },
      },
    },
  },
  stl = {
    c = {
      Subscriber = Subscriber,
    },
    env = {
      PATH_SEP = "/",
    },
  },
})

local Widget = require("era.m.explorer.widget")

t:test("ignored refresh: updates any visible tab and filters unaffected paths", function()
  local valid_wins = { [101] = true } ---@type table<integer, boolean>
  t:patch_table(vim.api, "nvim_get_current_tabpage", function()
    return 2
  end)
  t:patch_table(vim.api, "nvim_win_is_valid", function(winnr)
    return valid_wins[winnr] == true
  end)

  local tree = {
    o_flag_foldempty = new_observable(),
    o_flag_hidden = new_observable(),
    o_root_filepath = new_observable(),
  }
  local renders = 0 ---@type integer
  local widget = setmetatable({
    _o_width = new_observable(),
    _render_result = {
      filepath_to_lnum = {
        ["/project/dir/"] = 2,
        ["/project/file"] = 1,
      },
    },
    _resource_manager = {},
    _subscriptions = {},
    _tab_wins = { [1] = 101 },
    _tree = tree,
    __render__ = function()
      renders = renders + 1
    end,
  }, Widget)

  widget:__setup_subscriptions__()

  o_ignored_refreshed:next({ "/project/file" })
  t.assert_eq(1, renders, "off-current-tab visible window should render")

  o_ignored_refreshed:next({ "/other/stale" })
  t.assert_eq(1, renders, "unaffected path should not render")

  o_ignored_refreshed:next({ "/project/dir" })
  t.assert_eq(2, renders, "directory path should match its trailing-slash render key")

  o_ignored_refreshed:next({ "/project/file", "/project/dir" })
  t.assert_eq(3, renders, "one event should render at most once")

  valid_wins[101] = false
  o_ignored_refreshed:next({ "/project/file" })
  t.assert_eq(3, renders, "fully hidden widget should not render")
end)

t:run()
