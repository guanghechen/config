---@diagnostic disable: undefined-global
--- Test for era.m.explorer.widget module
--- Run with: nvim -l lua/__test__/era/m/explorer/widget.lua

local bootstrap = require("__test__.bootstrap")
local harness = require("__test__.harness")
local treeview_layout = require("stl.view.treeview.layout")

local t = harness.new("era.m.explorer.widget")
local normalize_calls = 0 ---@type integer

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
        normalize_calls = normalize_calls + 1
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
    _render_generation = 0,
    _render_result = { deferred_file_icons = { {} } },
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
    t.assert_eq(1, widget._render_generation, "last window should invalidate deferred decoration")
    t.assert_eq(0, #widget._render_result.deferred_file_icons, "last window should release deferred decoration")

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
    t.assert_eq(0, widget._render_generation, "remaining window should preserve deferred decoration")

    widget:hide(2)
    t.assert_eq(1, calls.pause_watch, "closing the remaining window should pause watchers")
    t.assert_eq(1, calls.mark_all_dirty, "closing the remaining window should invalidate the tree")
  end)
end)

---@return era.m.explorer.Widget, fun(): fun()[]
local function new_scheduled_icon_widget()
  local scheduled = {} ---@type fun()[]
  t:patch_table(vim, "schedule", function(callback)
    scheduled[#scheduled + 1] = callback
  end)
  t:patch_table(vim.api, "nvim_buf_is_valid", function()
    return true
  end)

  local widget = setmetatable({
    _disposed = false,
    _render_generation = 0,
    _render_result = nil,
    _tab_wins = { [1] = 101 },
    _view = {},
    fullname = "test-explorer",
  }, Widget)
  return widget, function()
    return scheduled
  end
end

t:test("file icons: stale generation cannot update the current render", function()
  local widget, get_scheduled = new_scheduled_icon_widget()
  local updated = {} ---@type string[]
  widget._view.update_file_icons = function(_, _, result)
    updated[#updated + 1] = result.id
  end

  local stale = { id = "stale", deferred_file_icons = { {} } }
  local stale_generation = widget:__invalidate_render__()
  widget._render_result = stale
  widget:__schedule_file_icons__(1, stale, stale_generation)

  local current = { id = "current", deferred_file_icons = { {} } }
  local current_generation = widget:__invalidate_render__()
  widget._render_result = current
  widget:__schedule_file_icons__(1, current, current_generation)

  local scheduled = get_scheduled()
  t.assert_eq(2, #scheduled, "scheduled callback count")
  scheduled[1]()
  scheduled[2]()

  t.assert_eq(1, #updated, "current update count")
  t.assert_eq("current", updated[1], "only the current generation should update icons")
  t.assert_eq(0, #current.deferred_file_icons, "completed render should release deferred icons")
end)

t:test("file icons: decoration yields between bounded batches", function()
  local widget, get_scheduled = new_scheduled_icon_widget()
  local batches = {} ---@type integer[][]
  widget._view.update_file_icons = function(_, _, _, index_start, index_end)
    batches[#batches + 1] = { index_start, index_end }
  end

  local icons = {} ---@type table[]
  for _ = 1, 65 do
    icons[#icons + 1] = {}
  end
  local result = { deferred_file_icons = icons }
  local generation = widget:__invalidate_render__()
  widget._render_result = result
  widget:__schedule_file_icons__(1, result, generation)

  local scheduled = get_scheduled()
  t.assert_eq(1, #scheduled, "first batch should be scheduled")
  scheduled[1]()
  t.assert_eq(1, #batches, "first batch count")
  t.assert_eq(1, batches[1][1], "first batch start")
  t.assert_eq(64, batches[1][2], "first batch end")
  t.assert_eq(2, #scheduled, "remaining icons should schedule another event-loop turn")
  scheduled[2]()
  t.assert_eq(2, #batches, "all batch count")
  t.assert_eq(65, batches[2][1], "second batch start")
  t.assert_eq(65, batches[2][2], "second batch end")
  t.assert_eq(0, #result.deferred_file_icons, "completed batches should release deferred icons")
end)

t:test("file icons: hidden widgets release decoration without scheduling", function()
  local widget, get_scheduled = new_scheduled_icon_widget()
  widget._tab_wins = {}

  local result = { deferred_file_icons = { {} } }
  local generation = widget:__invalidate_render__()
  widget._render_result = result
  widget:__schedule_file_icons__(1, result, generation)

  t.assert_eq(0, #get_scheduled(), "hidden widget should not schedule decoration")
  t.assert_eq(0, #result.deferred_file_icons, "hidden widget should release deferred icons")
end)

---@param initial_root                 string
---@param attach_ok                    boolean|nil
---@param alias_filepath               string|nil
---@return era.m.explorer.Widget, table
local function new_reveal_widget(initial_root, attach_ok, alias_filepath)
  local calls = {
    attach = 0,
    expand_path = 0,
    focus = 0,
    refresh = 0,
    resolve_root_alias = 0,
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
    _resource_manager = {
      resolve_root_alias = function(_, root_filepath, target_filepath)
        calls.resolve_root_alias = calls.resolve_root_alias + 1
        calls.alias_root_filepath = root_filepath
        calls.alias_target_filepath = target_filepath
        return alias_filepath
      end,
    },
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
  t.assert_eq(0, calls.resolve_root_alias, "same-root reveal should skip alias resolution")
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
  t.assert_eq(1, calls.resolve_root_alias, "cross-root reveal should try the current root aliases")
  t.assert_eq("/outside/", calls.attached_filepath)
  t.assert_eq("/project/", widget._tree.prev_root_filepath)
  t.assert_eq("/outside/", widget._tree.o_root_filepath:snapshot())
  t.assert_eq("/outside/", calls.expanded_filepath)
  t.assert_eq(1, calls.focus, "cross-root reveal should focus once")
  t.assert_eq(1, calls.refresh, "cross-root reveal should refresh once")
  t.assert_eq(1, calls.render, "cross-root reveal should render once")
end)

t:test("reveal: preserves the root when the canonical target has a logical alias", function()
  local widget, calls = new_reveal_widget("/project/", nil, "/project/local/main.lua")

  widget:reveal("/physical/local/main.lua")

  t.assert_eq(1, calls.resolve_root_alias, "canonical target should resolve once")
  t.assert_eq("/project/", calls.alias_root_filepath)
  t.assert_eq("/physical/local/main.lua", calls.alias_target_filepath)
  t.assert_eq(0, calls.attach, "logical alias should preserve the current root")
  t.assert_eq("/project/local/", calls.expanded_filepath)
  t.assert_eq("/project/local/main.lua", widget._tree.o_cursor_filepath:snapshot())
  t.assert_eq(1, calls.focus, "logical reveal should focus once")
  t.assert_eq(1, calls.refresh, "logical reveal should refresh once")
  t.assert_eq(1, calls.render, "logical reveal should render once")
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

t:test("parent filepath: directory parents keep a trailing slash", function()
  t:patch_table(dot.path, "dirname", function()
    return "/project/src"
  end)

  local widget = setmetatable({}, Widget)

  t.assert_eq("/project/src/", widget:__get_parent_filepath__("/project/src/main.lua"))
end)

t:test("navigation: resolves the visible parent, last child, and last sibling", function()
  local layout = treeview_layout.layout({
    roots = { "/project/src/", "/project/README.md" },
    children = function(filepath)
      return filepath == "/project/src/" and { "/project/src/a.lua", "/project/src/z.lua" } or {}
    end,
  })
  local widget = setmetatable({
    _render_result = {
      layout = layout,
    },
  }, Widget)

  t.assert_eq("/project/src/", widget:__get_navigation_parent_filepath__("/project/src/a.lua"))
  t.assert_eq("/project/src/z.lua", widget:__get_navigation_last_child_filepath__("/project/src/a.lua"))
  t.assert_nil(widget:__get_navigation_parent_filepath__("/project/src/"))
  t.assert_eq("/project/src/z.lua", widget:__get_navigation_last_child_filepath__("/project/src/"))
  t.assert_eq("/project/README.md", widget:__get_navigation_last_child_filepath__("/project/README.md"))
end)

t:test("navigation: consumes canonical render filepaths without normalization", function()
  local cursor = { 1, 0 } ---@type integer[]
  t:patch_table(vim.api, "nvim_win_is_valid", function()
    return true
  end)
  t:patch_table(vim.api, "nvim_win_get_cursor", function()
    return cursor
  end)
  t:patch_table(vim.api, "nvim_win_set_cursor", function(_, next_cursor)
    cursor = next_cursor
  end)

  local o_cursor_filepath = new_observable()
  local layout = treeview_layout.layout({
    roots = { "/project/src/", "/project/src/main.lua" },
    children = function()
      return {}
    end,
  })
  local widget = setmetatable({
    _render_result = {
      lines = { "dir", "file" },
      layout = layout,
    },
    _tree = { o_cursor_filepath = o_cursor_filepath },
    _tab_wins = { [1] = 101 },
  }, Widget)

  local filepaths = {} ---@type string[]
  normalize_calls = 0
  local found = widget:__goto_matching_file_or_dir__("next", function(filepath)
    filepaths[#filepaths + 1] = filepath
    return true
  end)

  t.assert_true(found, "matching item")
  t.assert_eq(0, normalize_calls, "canonical navigation filepath normalization count")
  t.assert_eq("/project/src", filepaths[1], "directory matcher filepath")
  t.assert_eq("/project/src/main.lua", filepaths[2], "file matcher filepath")
  t.assert_eq("/project/src/main.lua", o_cursor_filepath:snapshot(), "selected filepath")
  t.assert_eq(2, cursor[1], "selected line")
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
  local layout = treeview_layout.layout({
    roots = { "/project/file", "/project/dir/" },
    children = function()
      return {}
    end,
  })
  local widget = setmetatable({
    _o_width = new_observable(),
    _render_result = {
      layout = layout,
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
