---@diagnostic disable: undefined-global
--- Test for era.m.explorer.widget module
--- Run with: nvim -l lua/__test__/era/m/explorer/widget.lua

local bootstrap = require("__test__.bootstrap")
local harness = require("__test__.harness")

local t = harness.new("era.m.explorer.widget")

---@param initial_value                any
---@return table
local function new_observable(initial_value)
  local subscribers = {} ---@type table[]
  local ignore_initial = nil ---@type boolean|nil
  local value = initial_value
  return {
    get_ignore_initial = function()
      return ignore_initial
    end,
    subscribe = function(_, subscriber, next_ignore_initial)
      ignore_initial = next_ignore_initial
      subscribers[#subscribers + 1] = subscriber
      return { unsubscribe = function() end }
    end,
    snapshot = function()
      return value
    end,
    next = function(_, next_value)
      value = next_value
      for _, subscriber in ipairs(subscribers) do
        subscriber:next(next_value)
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

---@param tab_wins                     table<integer, integer>
---@return era.m.explorer.Widget, table
local function new_hide_widget(tab_wins)
  local calls = { mark_all_dirty = 0, pause_watch = 0 }
  local widget = setmetatable({
    _o_width = new_observable(),
    _resource_manager = {
      pause_watch = function()
        calls.pause_watch = calls.pause_watch + 1
      end,
    },
    _tab_wins = tab_wins,
    _tree = {
      mark_all_dirty = function()
        calls.mark_all_dirty = calls.mark_all_dirty + 1
      end,
    },
  }, Widget)
  return widget, calls
end

---@param callback                     fun(): nil
local function with_invalid_windows(callback)
  t:patch_table(vim.api, "nvim_win_is_valid", function()
    return false
  end)
  callback()
end

t:test("hide: invalidates the tree when the last watched window closes", function()
  with_invalid_windows(function()
    local widget, calls = new_hide_widget({ [1] = 101 })

    widget:hide(1)
    t.assert_eq(1, calls.pause_watch, "last window should pause watchers")
    t.assert_eq(1, calls.mark_all_dirty, "last window should invalidate the tree snapshot")

    widget:hide(1)
    t.assert_eq(1, calls.pause_watch, "repeated hide should not pause watchers again")
    t.assert_eq(1, calls.mark_all_dirty, "repeated hide should not invalidate the tree again")
  end)
end)

t:test("hide: preserves watcher coverage while another window remains", function()
  with_invalid_windows(function()
    local widget, calls = new_hide_widget({ [1] = 101, [2] = 102 })

    widget:hide(1)
    t.assert_eq(0, calls.pause_watch, "remaining window should keep watchers active")
    t.assert_eq(0, calls.mark_all_dirty, "remaining window should keep the tree snapshot valid")

    widget:hide(2)
    t.assert_eq(1, calls.pause_watch, "closing the remaining window should pause watchers")
    t.assert_eq(1, calls.mark_all_dirty, "closing the remaining window should invalidate the tree")
  end)
end)

---@param initial_root                 string
---@param attach_ok                    boolean|nil
---@return era.m.explorer.Widget, table
local function new_reveal_widget(initial_root, attach_ok)
  local calls = {
    attach = 0,
    expand_path = 0,
    focus = 0,
    refresh = 0,
    render = 0,
  }
  local tree = {
    o_cursor_filepath = new_observable(initial_root),
    o_root_filepath = new_observable(initial_root),
    prev_root_filepath = nil,
  }

  function tree:attach(filepath)
    calls.attach = calls.attach + 1
    calls.attached_filepath = filepath
    return attach_ok ~= false
  end

  function tree:expand_path(filepath)
    calls.expand_path = calls.expand_path + 1
    calls.expanded_filepath = filepath
  end

  function tree:refresh()
    calls.refresh = calls.refresh + 1
  end

  local widget = setmetatable({
    _tree = tree,
    __get_parent_filepath__ = function(_, filepath)
      return filepath:match("^(.*/)[^/]+/?$")
    end,
    __render__ = function()
      calls.render = calls.render + 1
    end,
  }, Widget)

  widget.focus = function(self)
    calls.focus = calls.focus + 1
    self._tree:refresh(false)
    self:__render__()
  end

  return widget, calls
end

t:test("reveal: refreshes and renders once after preparing the target", function()
  local widget, calls = new_reveal_widget("/project/")

  widget:reveal("/project/src/main.lua")

  t.assert_eq(0, calls.attach, "same-root reveal should not attach a new root")
  t.assert_eq(1, calls.expand_path, "target path should expand once")
  t.assert_eq("/project/src/", calls.expanded_filepath)
  t.assert_eq("/project/src/main.lua", widget._tree.o_cursor_filepath:snapshot())
  t.assert_eq(1, calls.focus, "reveal should focus once")
  t.assert_eq(1, calls.refresh, "reveal should refresh once")
  t.assert_eq(1, calls.render, "reveal should render once")
end)

t:test("reveal: changes root without an intermediate refresh", function()
  local widget, calls = new_reveal_widget("/project/")

  widget:reveal("/outside/main.lua")

  t.assert_eq(1, calls.attach, "cross-root reveal should attach once")
  t.assert_eq("/outside/", calls.attached_filepath)
  t.assert_eq("/project/", widget._tree.prev_root_filepath)
  t.assert_eq("/outside/", widget._tree.o_root_filepath:snapshot())
  t.assert_eq("/outside/", calls.expanded_filepath)
  t.assert_eq(1, calls.focus, "cross-root reveal should focus once")
  t.assert_eq(1, calls.refresh, "cross-root reveal should refresh once")
  t.assert_eq(1, calls.render, "cross-root reveal should render once")
end)

t:test("reveal: preserves the current root when attach fails", function()
  local widget, calls = new_reveal_widget("/project/", false)

  widget:reveal("/missing/main.lua")

  t.assert_eq(1, calls.attach, "failed root should be attempted once")
  t.assert_eq("/project/", widget._tree.o_root_filepath:snapshot())
  t.assert_eq(nil, widget._tree.prev_root_filepath)
  t.assert_eq(0, calls.expand_path, "failed root should abort target expansion")
  t.assert_eq(1, calls.focus, "failed reveal should preserve focus behavior")
  t.assert_eq(1, calls.refresh, "failed reveal should refresh the current root once")
  t.assert_eq(1, calls.render, "failed reveal should render the current root once")
end)

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
  t.assert_eq(true, tree.o_flag_hidden:get_ignore_initial(), "initial hidden state should not refresh the tree")

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
