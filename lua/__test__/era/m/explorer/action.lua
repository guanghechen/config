---@diagnostic disable: undefined-global
--- Test for era.m.explorer.action module
--- Run with: nvim -l lua/__test__/era/m/explorer/action.lua

local harness = require("__test__.harness")
local Action = require("era.m.explorer.action")

local t = harness.new("era.m.explorer.action")

---@param input                         string|nil
---@param cursor_filepath               string|nil
---@param parent_filepath               string|nil
---@return table
local function run_create_file(input, cursor_filepath, parent_filepath)
  local calls = {
    create_filepath = nil,
    default_input = nil,
    opened_filepath = nil,
    rendered = false,
    refreshed = false,
    synced_filepath = nil,
  }

  t:patch_global("stl", {
    os = {
      path = {
        normalize = function(filepath, keep_trailing_slash)
          local normalized = filepath:gsub("\\", "/"):gsub("/+", "/")
          if keep_trailing_slash == false and normalized ~= "/" then
            normalized = normalized:gsub("/+$", "")
          end
          return normalized
        end,
      },
    },
  })

  t:patch_global("yoz", {
    canonical_path = {
      to_os_path = function(filepath)
        return filepath
      end,
    },
  })

  t:patch_global("dot", {
    tab = {
      retrieve_winnr_sourcefile = function()
        return nil
      end,
    },
    win = {
      open_filepath = function(_, filepath)
        calls.opened_filepath = filepath
      end,
    },
  })

  t:patch_table(vim.ui, "input", function(options, callback)
    calls.default_input = options.default
    callback(input)
  end)

  t:patch_table(vim, "schedule", function(callback)
    callback()
  end)

  local ctx = {
    get_cursor_filepath = function()
      return cursor_filepath or "/project/"
    end,
    get_parent_filepath = function(filepath)
      if parent_filepath ~= nil then
        return parent_filepath
      end
      local target = filepath:sub(-1) == "/" and filepath:sub(1, -2) or filepath
      local parent = target:match("^(.*/)[^/]+$")
      return parent or "/"
    end,
    render = function()
      calls.rendered = true
    end,
    resource_manager = {
      create = function(_, filepath)
        calls.create_filepath = filepath
        return {
          filepath = filepath,
          nodetype = filepath:sub(-1) == "/" and "D" or "F",
          nodename = filepath:match("([^/]+)/?$") or "",
        }
      end,
    },
    sync_cursor_to_filepath = function(filepath)
      calls.synced_filepath = filepath
    end,
    tree = {
      o_root_filepath = {
        snapshot = function()
          return "/project/"
        end,
      },
      refresh = function(_, force)
        calls.refreshed = force == true
      end,
      toggle_expanded = function() end,
    },
  }

  Action.new(ctx):create_file()
  return calls
end

----------------------------------------------------------------------------------------------------
-- create_file tests
----------------------------------------------------------------------------------------------------

t:test("create_file: file focus keeps a trailing slash in the parent prompt", function()
  local calls = run_create_file(nil, "/project/src/main.lua", "/project/src")
  t.assert_eq("src/", calls.default_input, "default input")
end)

t:test("create_file: trailing slash creates directory path", function()
  local calls = run_create_file("foo/")
  t.assert_eq("/project/foo/", calls.create_filepath, "created filepath")
  t.assert_eq("/project/foo/", calls.synced_filepath, "synced filepath")
  t.assert_true(calls.refreshed, "tree should refresh")
  t.assert_true(calls.rendered, "view should render")
  t.assert_nil(calls.opened_filepath, "directory should not open as file")
end)

t:test("create_file: nested trailing slash creates directory path", function()
  local calls = run_create_file("foo/bar/")
  t.assert_eq("/project/foo/bar/", calls.create_filepath, "created filepath")
  t.assert_eq("/project/foo/bar/", calls.synced_filepath, "synced filepath")
  t.assert_nil(calls.opened_filepath, "directory should not open as file")
end)

t:test("create_file: no trailing slash creates file path", function()
  local calls = run_create_file("foo")
  t.assert_eq("/project/foo", calls.create_filepath, "created filepath")
  t.assert_eq("/project/foo", calls.synced_filepath, "synced filepath")
  t.assert_eq("/project/foo", calls.opened_filepath, "file should open")
end)

---@param method                        "jump_parent"|"jump_last_child"
---@param parent_filepath               string|nil
---@param parent_last_child_filepath    string|nil
---@return table
local function run_navigation(method, parent_filepath, parent_last_child_filepath)
  local calls = { cursor = "/project/src/current.lua", synced = nil }
  local ctx = {
    get_cursor_filepath = function()
      return calls.cursor
    end,
    get_navigation_parent_filepath = function()
      return parent_filepath
    end,
    get_navigation_last_child_filepath = function()
      return parent_last_child_filepath
    end,
    sync_cursor_to_filepath = function(filepath)
      calls.synced = filepath
    end,
    tree = {
      o_cursor_filepath = {
        next = function(_, filepath)
          calls.cursor = filepath
        end,
      },
    },
  }

  local action = Action.new(ctx)
  action[method](action)
  return calls
end

t:test("jump parent: focuses the visible parent", function()
  local calls = run_navigation("jump_parent", "/project/src/", nil)

  t.assert_eq("/project/src/", calls.cursor)
  t.assert_eq("/project/src/", calls.synced)
end)

t:test("jump parent: keeps the cursor when the visible parent is the hidden root", function()
  local calls = run_navigation("jump_parent", nil, nil)

  t.assert_eq("/project/src/current.lua", calls.cursor)
  t.assert_nil(calls.synced)
end)

t:test("jump last child: focuses the resolved child or sibling", function()
  local calls = run_navigation("jump_last_child", nil, "/project/src/z.lua")

  t.assert_eq("/project/src/z.lua", calls.cursor)
  t.assert_eq("/project/src/z.lua", calls.synced)
end)

local function normalize(filepath, keep_trailing_slash)
  local normalized = filepath:gsub("\\", "/"):gsub("/+", "/") ---@type string
  if keep_trailing_slash == false and normalized ~= "/" then
    normalized = normalized:gsub("/+$", "")
  elseif keep_trailing_slash == true and normalized:sub(-1) ~= "/" then
    normalized = normalized .. "/"
  end
  return normalized
end

---@param props                         table
---@return era.m.explorer.Action
---@return table
---@return fun(filepath: string): nil
---@return fun(filepath: string): boolean
local function setup_transfer(props)
  local calls = {
    copies = {},
    moves = {},
    removes = {},
    reports = {},
    canonical_descendant = 0,
    clear_selection = 0,
    normalize = 0,
    refresh = 0,
    tree_refresh = 0,
  }
  local cursor = props.cursor ---@type string
  local resources = props.resources ---@type table<string, era.m.explorer.resource.INode>
  local tree_nodes = props.tree_nodes or {} ---@type table<string, era.m.explorer.Node>
  local selected_nodes = {} ---@type era.m.explorer.Node[]
  local selected_filepaths = {} ---@type table<string, boolean>
  for _, node in ipairs(props.selected_nodes or {}) do
    selected_nodes[#selected_nodes + 1] = node
    selected_filepaths[node.filepath] = true
    tree_nodes[node.filepath] = tree_nodes[node.filepath] or node
  end
  local failed_targets = props.failed_targets or {} ---@type table<string, boolean>
  local partial_targets = props.partial_targets or {} ---@type table<string, boolean>
  local failed_removals = props.failed_removals or {} ---@type table<string, boolean>

  local function report(options)
    calls.reports[#calls.reports + 1] = options
  end

  t:patch_global("stl", {
    os = {
      path = {
        normalize = function(filepath, keep_trailing_slash)
          calls.normalize = calls.normalize + 1
          return normalize(filepath, keep_trailing_slash)
        end,
      },
    },
    reporter = {
      error = report,
      info = report,
      warn = report,
    },
  })
  t:patch_global("yoz", {
    canonical_path = {
      is_descendant = function(from, to)
        calls.canonical_descendant = calls.canonical_descendant + 1
        from = normalize(from, false)
        to = normalize(to, false)
        return to == from or to:sub(1, #from + 1) == from .. "/"
      end,
      to_os_path = function(filepath)
        return filepath
      end,
    },
  })
  t:patch_table(vim, "schedule", function(callback)
    callback()
  end)
  t:patch_table(vim.api, "nvim_feedkeys", function() end)

  local resource_manager = {
    locate = function(_, filepath)
      return resources[filepath] or resources[normalize(filepath, false)] or resources[normalize(filepath, true)]
    end,
    copy = function(_, source, target)
      calls.copies[#calls.copies + 1] = { source = source, target = target }
      if partial_targets[target] then
        return "partial_failure"
      end
      if failed_targets[target] then
        return "retryable_failure"
      end
      resources[target] = {
        filepath = target,
        nodename = target:match("([^/]+)/?$") or "",
        nodetype = target:sub(-1) == "/" and "D" or "F",
      }
      return "success"
    end,
    move = function(_, source, target)
      calls.moves[#calls.moves + 1] = { source = source, target = target }
      if failed_targets[target] then
        return false
      end
      resources[source] = nil
      resources[target] = {
        filepath = target,
        nodename = target:match("([^/]+)/?$") or "",
        nodetype = target:sub(-1) == "/" and "D" or "F",
      }
      return true
    end,
  }

  local ctx = {
    fullname = "test",
    get_cursor_filepath = function()
      return cursor
    end,
    get_parent_filepath = function(filepath)
      local target = normalize(filepath, false)
      return target:match("^(.*/)[^/]+$") or "/"
    end,
    get_visual_nodes = function()
      return props.visual_nodes or {}
    end,
    refresh = function()
      calls.refresh = calls.refresh + 1
    end,
    resource_manager = resource_manager,
    sync_cursor_to_filepath = function() end,
    tree = {
      clear_selection = function()
        calls.clear_selection = calls.clear_selection + 1
        selected_nodes = {}
        selected_filepaths = {}
      end,
      get_selected_nodes = function()
        local result = {} ---@type era.m.explorer.Node[]
        for _, node in ipairs(selected_nodes) do
          result[#result + 1] = node
        end
        return result
      end,
      is_selected = function(_, filepath)
        return selected_filepaths[filepath] == true
      end,
      locate = function(_, filepath)
        return tree_nodes[filepath]
      end,
      remove = function(_, filepath)
        calls.removes[#calls.removes + 1] = filepath
        if failed_removals[filepath] then
          return false
        end

        tree_nodes[filepath] = nil
        resources[filepath] = nil
        for i, node in ipairs(selected_nodes) do
          if node.filepath == filepath then
            table.remove(selected_nodes, i)
            selected_filepaths[filepath] = nil
            break
          end
        end
        return true
      end,
      refresh = function()
        calls.tree_refresh = calls.tree_refresh + 1
      end,
      toggle_selected = function(_, filepath, force_selected)
        local is_selected = selected_filepaths[filepath] == true
        local should_select = force_selected == "select" or (force_selected == nil and not is_selected)
        if should_select == is_selected then
          return
        end

        if should_select then
          local node = tree_nodes[filepath]
          if node ~= nil then
            selected_nodes[#selected_nodes + 1] = node
            selected_filepaths[filepath] = true
          end
          return
        end

        for i, node in ipairs(selected_nodes) do
          if node.filepath == filepath then
            table.remove(selected_nodes, i)
            selected_filepaths[filepath] = nil
            return
          end
        end
      end,
    },
  }

  return Action.new(ctx),
    calls,
    function(filepath)
      cursor = filepath
    end,
    function(filepath)
      return selected_filepaths[filepath] == true
    end
end

t:test("transfer: stage includes the selection and focused item", function()
  local selected_nodes = {
    { filepath = "/project/src/a.txt", nodename = "a.txt", nodetype = "F" },
    { filepath = "/project/test/b.txt", nodename = "b.txt", nodetype = "F" },
  }
  local focused = { filepath = "/project/focused.txt", nodename = "focused.txt", nodetype = "F" }
  local action, _, _, is_selected = setup_transfer({
    cursor = focused.filepath,
    resources = {},
    selected_nodes = selected_nodes,
    tree_nodes = { [focused.filepath] = focused },
  })

  action:cut()

  local pending = action:get_pending_transfer()
  t.assert_true(pending ~= nil, "pending transfer")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq("move", pending.mode, "pending mode")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq(3, #pending.sources, "pending source count")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_true(pending.source_filepaths["/project/src/a.txt"], "pending source map")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_true(pending.source_filepaths[focused.filepath], "focused source")
  t.assert_true(is_selected(focused.filepath), "focused selection")
end)

t:test("transfer: visual stage includes the existing selection", function()
  local selected = { filepath = "/project/alpha.txt", nodename = "alpha.txt", nodetype = "F" }
  local visual = { filepath = "/project/bravo.txt", nodename = "bravo.txt", nodetype = "F" }
  local action = setup_transfer({
    cursor = visual.filepath,
    resources = {},
    selected_nodes = { selected },
    tree_nodes = { [visual.filepath] = visual },
    visual_nodes = { visual },
  })

  action:stage_transfer_visual("copy")

  local pending = action:get_pending_transfer()
  t.assert_true(pending ~= nil, "pending transfer")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq("copy", pending.mode, "pending mode")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq(2, #pending.sources, "pending source count")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_true(pending.source_filepaths[selected.filepath], "selected source")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_true(pending.source_filepaths[visual.filepath], "visual source")
end)

t:test("transfer: tab adds focused item to pending mode and selection", function()
  local first = { filepath = "/project/alpha.txt", nodename = "alpha.txt", nodetype = "F" }
  local second = { filepath = "/project/bravo.txt", nodename = "bravo.txt", nodetype = "F" }
  local action, _, set_cursor, is_selected = setup_transfer({
    cursor = first.filepath,
    resources = {},
    tree_nodes = { [first.filepath] = first, [second.filepath] = second },
  })

  action:stage_transfer("move")
  set_cursor(second.filepath)
  action:select_toggle()

  local pending = action:get_pending_transfer()
  t.assert_true(pending ~= nil, "pending transfer")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq("move", pending.mode, "inherited mode")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq(2, #pending.sources, "pending source count")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_true(pending.source_filepaths[first.filepath], "first source")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_true(pending.source_filepaths[second.filepath], "new source")
  t.assert_true(is_selected(first.filepath), "original pending selection")
  t.assert_true(is_selected(second.filepath), "new selection")
end)

t:test("transfer: unselecting the final item clears pending mode", function()
  local node = { filepath = "/project/alpha.txt", nodename = "alpha.txt", nodetype = "F" }
  local action = setup_transfer({
    cursor = node.filepath,
    resources = {},
    selected_nodes = { node },
  })

  action:cut()
  action:select_toggle()

  t.assert_nil(action:get_pending_transfer(), "pending transfer")
end)

t:test("transfer: unselecting a child removes its collapsed ancestor source", function()
  local parent = { filepath = "/project/dir/", nodename = "dir", nodetype = "D" }
  local child = { filepath = "/project/dir/alpha.txt", nodename = "alpha.txt", nodetype = "F" }
  local action, _, set_cursor, is_selected = setup_transfer({
    cursor = child.filepath,
    resources = {},
    tree_nodes = { [parent.filepath] = parent, [child.filepath] = child },
    visual_nodes = { parent },
  })

  action:select_toggle()
  set_cursor(parent.filepath)
  action:stage_transfer_visual("move")

  local pending = action:get_pending_transfer()
  t.assert_true(pending ~= nil, "pending transfer before cancellation")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq(1, #pending.sources, "collapsed source count")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_true(pending.source_filepaths[parent.filepath], "collapsed ancestor source")

  set_cursor(child.filepath)
  action:select_toggle()

  t.assert_false(is_selected(child.filepath), "child selection")
  t.assert_nil(action:get_pending_transfer(), "pending transfer")
end)

t:test("transfer: copy replaces an unselected cut item with focused item", function()
  local cut = { filepath = "/project/alpha.txt", nodename = "alpha.txt", nodetype = "F" }
  local focused = { filepath = "/project/bravo.txt", nodename = "bravo.txt", nodetype = "F" }
  local action, _, set_cursor = setup_transfer({
    cursor = cut.filepath,
    resources = {},
    tree_nodes = { [cut.filepath] = cut, [focused.filepath] = focused },
  })

  action:cut()
  set_cursor(focused.filepath)
  action:copy()

  local pending = action:get_pending_transfer()
  t.assert_true(pending ~= nil, "pending transfer")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq("copy", pending.mode, "pending mode")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq(1, #pending.sources, "pending source count")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_false(pending.source_filepaths[cut.filepath] == true, "old cut source")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_true(pending.source_filepaths[focused.filepath], "focused copy source")
end)

t:test("transfer: copy includes promoted pending selection and focused item", function()
  local old_cut = { filepath = "/project/alpha.txt", nodename = "alpha.txt", nodetype = "F" }
  local selected = { filepath = "/project/bravo.txt", nodename = "bravo.txt", nodetype = "F" }
  local focused = { filepath = "/project/charlie.txt", nodename = "charlie.txt", nodetype = "F" }
  local action, _, set_cursor, is_selected = setup_transfer({
    cursor = old_cut.filepath,
    resources = {},
    tree_nodes = {
      [old_cut.filepath] = old_cut,
      [selected.filepath] = selected,
      [focused.filepath] = focused,
    },
  })

  action:stage_transfer("move")
  set_cursor(selected.filepath)
  action:select_toggle()
  set_cursor(focused.filepath)
  action:copy()

  local pending = action:get_pending_transfer()
  t.assert_true(pending ~= nil, "pending transfer")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq("copy", pending.mode, "pending mode")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq(3, #pending.sources, "pending source count")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_true(pending.source_filepaths[old_cut.filepath], "promoted copy source")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_true(pending.source_filepaths[selected.filepath], "selected copy source")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_true(pending.source_filepaths[focused.filepath], "focused copy source")
  t.assert_true(is_selected(old_cut.filepath), "promoted selection")
  t.assert_true(is_selected(focused.filepath), "focused selection")
end)

t:test("transfer: copy cancels focused item already marked copy", function()
  local source = { filepath = "/project/alpha.txt", nodename = "alpha.txt", nodetype = "F" }
  local action = setup_transfer({
    cursor = source.filepath,
    resources = {},
    tree_nodes = { [source.filepath] = source },
  })
  local copy_as_called = false ---@type boolean
  action.copy_as = function()
    copy_as_called = true
  end

  action:stage_transfer("copy")
  action:copy()

  t.assert_false(copy_as_called, "copy as")
  t.assert_nil(action:get_pending_transfer(), "pending transfer")
end)

t:test("transfer: copy cancellation keeps other selected copy items", function()
  local selected = { filepath = "/project/alpha.txt", nodename = "alpha.txt", nodetype = "F" }
  local focused = { filepath = "/project/bravo.txt", nodename = "bravo.txt", nodetype = "F" }
  local action, _, _, is_selected = setup_transfer({
    cursor = focused.filepath,
    resources = {},
    selected_nodes = { selected },
    tree_nodes = { [focused.filepath] = focused },
  })

  action:copy()
  action:copy()

  local pending = action:get_pending_transfer()
  t.assert_true(pending ~= nil, "pending transfer")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq(1, #pending.sources, "pending source count")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_true(pending.source_filepaths[selected.filepath], "remaining copy source")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_false(pending.source_filepaths[focused.filepath] == true, "cancelled copy source")
  t.assert_true(is_selected(selected.filepath), "remaining selection")
  t.assert_false(is_selected(focused.filepath), "cancelled selection")
end)

t:test("transfer: cut cancels focused item already marked cut", function()
  local source = { filepath = "/project/alpha.txt", nodename = "alpha.txt", nodetype = "F" }
  local action = setup_transfer({
    cursor = source.filepath,
    resources = {},
    tree_nodes = { [source.filepath] = source },
  })

  action:cut()
  action:cut()

  t.assert_nil(action:get_pending_transfer(), "pending transfer")
end)

t:test("transfer: deleting a focused pending source clears it", function()
  local source = { filepath = "/project/alpha.txt", nodename = "alpha.txt", nodetype = "F" }
  local action, calls = setup_transfer({
    cursor = source.filepath,
    resources = { [source.filepath] = source },
    tree_nodes = { [source.filepath] = source },
  })
  t:patch_table(vim.ui, "input", function(_, callback)
    callback("y")
  end)

  action:cut()
  action:delete()

  t.assert_eq(1, #calls.removes, "remove count")
  t.assert_nil(action:get_pending_transfer(), "pending transfer")
end)

t:test("transfer: partial selected delete clears selection and pending", function()
  local deleted = { filepath = "/project/alpha.txt", nodename = "alpha.txt", nodetype = "F" }
  local retained = { filepath = "/project/bravo.txt", nodename = "bravo.txt", nodetype = "F" }
  local action, calls = setup_transfer({
    cursor = deleted.filepath,
    failed_removals = { [retained.filepath] = true },
    resources = { [deleted.filepath] = deleted, [retained.filepath] = retained },
    selected_nodes = { deleted, retained },
  })
  t:patch_table(vim.ui, "input", function(_, callback)
    callback("y")
  end)

  action:cut()
  action:delete()

  t.assert_eq(1, calls.clear_selection, "selection clear count")
  t.assert_nil(action:get_pending_transfer(), "pending transfer")
end)

t:test("transfer: renaming an ancestor removes only covered pending sources", function()
  local parent = { filepath = "/project/dir/", nodename = "dir", nodetype = "D" }
  local child = { filepath = "/project/dir/alpha.txt", nodename = "alpha.txt", nodetype = "F" }
  local unrelated = { filepath = "/project/bravo.txt", nodename = "bravo.txt", nodetype = "F" }
  local action, _, set_cursor = setup_transfer({
    cursor = child.filepath,
    resources = {
      [parent.filepath] = parent,
      [child.filepath] = child,
      [unrelated.filepath] = unrelated,
    },
    selected_nodes = { child, unrelated },
    tree_nodes = { [parent.filepath] = parent },
  })
  t:patch_table(vim.ui, "input", function(_, callback)
    callback("renamed")
  end)

  action:cut()
  set_cursor(parent.filepath)
  action:rename()

  local pending = action:get_pending_transfer()
  t.assert_true(pending ~= nil, "pending transfer")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq(1, #pending.sources, "pending source count")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_true(pending.source_filepaths[unrelated.filepath], "unrelated source")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_false(pending.source_filepaths[child.filepath] == true, "renamed descendant source")
end)

t:test("transfer: paste uses target directory and source basenames without a prompt", function()
  local nodes = {
    { filepath = "/project/src/a.txt", nodename = "a.txt", nodetype = "F" },
    { filepath = "/project/test/b.txt", nodename = "b.txt", nodetype = "F" },
  }
  local resources = {
    ["/project/src/a.txt"] = nodes[1],
    ["/project/test/b.txt"] = nodes[2],
    ["/target/"] = { filepath = "/target/", nodename = "target", nodetype = "D" },
  }
  local action, calls, set_cursor = setup_transfer({
    cursor = nodes[1].filepath,
    resources = resources,
    selected_nodes = nodes,
  })
  t:patch_table(vim.ui, "input", function()
    error("paste must not open an input prompt")
  end)

  action:stage_transfer("copy")
  set_cursor("/target/")
  action:paste()

  t.assert_eq(2, #calls.copies, "copy count")
  t.assert_eq("/target/a.txt", calls.copies[1].target, "first basename target")
  t.assert_eq("/target/b.txt", calls.copies[2].target, "second basename target")
  t.assert_eq(0, calls.normalize, "canonical transfer normalization count")
  t.assert_eq(1, calls.clear_selection, "selection clear count")
  t.assert_nil(action:get_pending_transfer(), "pending transfer after success")
end)

t:test("transfer: preflight conflict aborts the whole batch", function()
  local source = { filepath = "/project/a.txt", nodename = "a.txt", nodetype = "F" }
  local resources = {
    [source.filepath] = source,
    ["/target/"] = { filepath = "/target/", nodename = "target", nodetype = "D" },
    ["/target/a.txt"] = { filepath = "/target/a.txt", nodename = "a.txt", nodetype = "F" },
  }
  local action, calls, set_cursor = setup_transfer({
    cursor = source.filepath,
    resources = resources,
    tree_nodes = { [source.filepath] = source },
  })

  action:stage_transfer("move")
  set_cursor("/target/")
  action:paste()

  t.assert_eq(0, #calls.moves, "move count")
  t.assert_true(action:get_pending_transfer() ~= nil, "pending transfer retained")
  t.assert_eq(1, #calls.reports, "conflict report count")
end)

t:test("transfer: duplicate basenames abort before any write", function()
  local nodes = {
    { filepath = "/project/src/config.lua", nodename = "config.lua", nodetype = "F" },
    { filepath = "/project/test/config.lua/", nodename = "config.lua", nodetype = "D" },
  }
  local resources = {
    [nodes[1].filepath] = nodes[1],
    [nodes[2].filepath] = nodes[2],
    ["/target/"] = { filepath = "/target/", nodename = "target", nodetype = "D" },
  }
  local action, calls, set_cursor = setup_transfer({
    cursor = nodes[1].filepath,
    resources = resources,
    selected_nodes = nodes,
  })

  action:stage_transfer("copy")
  set_cursor("/target/")
  action:paste()

  t.assert_eq(0, #calls.copies, "copy count")
  t.assert_eq(0, calls.normalize, "canonical transfer normalization count")
  t.assert_true(action:get_pending_transfer() ~= nil, "pending transfer retained")
end)

t:test("transfer: rejects copying a directory into its descendant", function()
  local source = { filepath = "/project/dir/", nodename = "dir", nodetype = "D" }
  local resources = {
    [source.filepath] = source,
    ["/project/dir/child/"] = { filepath = "/project/dir/child/", nodename = "child", nodetype = "D" },
  }
  local action, calls, set_cursor = setup_transfer({
    cursor = source.filepath,
    resources = resources,
    tree_nodes = { [source.filepath] = source },
  })

  action:stage_transfer("copy")
  set_cursor("/project/dir/child/")
  action:paste()

  t.assert_eq(0, #calls.copies, "copy count")
  t.assert_eq(0, calls.normalize, "canonical transfer normalization count")
  t.assert_true(calls.canonical_descendant > 0, "canonical descendant check")
  t.assert_true(action:get_pending_transfer() ~= nil, "pending transfer retained")
end)

t:test("transfer: partial failure retains only failed sources", function()
  local nodes = {
    { filepath = "/project/a.txt", nodename = "a.txt", nodetype = "F" },
    { filepath = "/project/b.txt", nodename = "b.txt", nodetype = "F" },
  }
  local resources = {
    [nodes[1].filepath] = nodes[1],
    [nodes[2].filepath] = nodes[2],
    ["/target/"] = { filepath = "/target/", nodename = "target", nodetype = "D" },
  }
  local action, calls, set_cursor = setup_transfer({
    cursor = nodes[1].filepath,
    failed_targets = { ["/target/b.txt"] = true },
    resources = resources,
    selected_nodes = nodes,
  })

  action:stage_transfer("move")
  set_cursor("/target/")
  action:paste()

  local pending = action:get_pending_transfer()
  t.assert_true(pending ~= nil, "failed pending transfer")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq(1, #pending.sources, "failed source count")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq("/project/b.txt", pending.sources[1].filepath, "failed source")
  t.assert_eq(1, calls.clear_selection, "selection clear count")
end)

t:test("transfer: copy retains only retryable failures and exposes partial targets", function()
  local nodes = {
    { filepath = "/project/a.txt", nodename = "a.txt", nodetype = "F" },
    { filepath = "/project/b.txt", nodename = "b.txt", nodetype = "F" },
    { filepath = "/project/c.txt", nodename = "c.txt", nodetype = "F" },
  }
  local resources = {
    [nodes[1].filepath] = nodes[1],
    [nodes[2].filepath] = nodes[2],
    [nodes[3].filepath] = nodes[3],
    ["/target/"] = { filepath = "/target/", nodename = "target", nodetype = "D" },
  }
  local action, calls, set_cursor = setup_transfer({
    cursor = nodes[1].filepath,
    failed_targets = { ["/target/b.txt"] = true },
    partial_targets = { ["/target/c.txt"] = true },
    resources = resources,
    selected_nodes = nodes,
  })

  action:stage_transfer("copy")
  local refresh_before_paste = calls.refresh ---@type integer
  set_cursor("/target/")
  action:paste()

  local pending = action:get_pending_transfer()
  t.assert_true(pending ~= nil, "retryable pending transfer")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq(1, #pending.sources, "retryable source count")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq(nodes[2].filepath, pending.sources[1].filepath, "retryable source")
  t.assert_eq(1, calls.clear_selection, "selection clear count")
  t.assert_eq(1, calls.tree_refresh, "tree refresh count")
  t.assert_eq(refresh_before_paste + 1, calls.refresh, "view refresh count")
  t.assert_eq(1, #calls.reports, "summary report count")
  t.assert_eq("/target/c.txt", calls.reports[1].details.partial_targets[1], "partial target detail")
end)

---@param method                        "copy"|"copy_as"|"rename"
---@param input                         string
---@param options                       table|nil
---@return table
local function run_name_action(method, input, options)
  options = options or {}
  local calls = {
    default = nil,
    copied_to = nil,
    moved_to = nil,
    reports = {},
    refresh = 0,
    synced_to = nil,
    tree_refresh = 0,
  }
  local node = options.node or { filepath = "/project/src/source.lua", nodename = "source.lua", nodetype = "F" } ---@type era.m.explorer.Node

  t:patch_global("stl", {
    os = {
      path = {
        normalize = normalize,
      },
    },
    reporter = {
      error = function(options)
        calls.reports[#calls.reports + 1] = options
      end,
      info = function(options)
        calls.reports[#calls.reports + 1] = options
      end,
    },
  })
  t:patch_global("yoz", {
    canonical_path = {
      is_descendant = function(from, to)
        from = normalize(from, false)
        to = normalize(to, false)
        return to == from or to:sub(1, #from + 1) == from .. "/"
      end,
      to_os_path = function(filepath)
        return filepath
      end,
    },
    path = {
      extname = function(filepath)
        return filepath:match("(%.[^./]+)$") or ""
      end,
    },
  })
  t:patch_global("dot", {
    path = {
      cwd = function()
        return "/project"
      end,
      relative = function(_, filepath)
        return filepath:sub(#"/project/" + 1)
      end,
      resolve = function(cwd, filepath)
        if filepath:sub(1, 1) == "/" then
          return filepath
        end
        return cwd .. "/" .. filepath
      end,
    },
  })
  t:patch_table(vim.ui, "input", function(options, callback)
    calls.default = options.default
    callback(input)
  end)
  t:patch_table(vim, "schedule", function(callback)
    callback()
  end)

  local ctx = {
    fullname = "test",
    get_cursor_filepath = function()
      return node.filepath
    end,
    get_parent_filepath = function()
      return options.parent_filepath or "/project/src"
    end,
    refresh = function()
      calls.refresh = calls.refresh + 1
    end,
    resource_manager = {
      copy = function(_, _, target)
        calls.copied_to = target
        return options.copy_status or "success"
      end,
      move = function(_, _, target)
        calls.moved_to = target
        return true
      end,
    },
    sync_cursor_to_filepath = function(filepath)
      calls.synced_to = filepath
    end,
    tree = {
      get_selected_nodes = function()
        return {}
      end,
      locate = function()
        return node
      end,
      refresh = function()
        calls.tree_refresh = calls.tree_refresh + 1
      end,
    },
  }

  local action = Action.new(ctx)
  action[method](action)
  return calls
end

t:test("copy: without selection accepts a cwd-relative copy-as path", function()
  local calls = run_name_action("copy", "target/peer.lua")

  t.assert_eq("src/source-copy.lua", calls.default, "suggested copy path")
  t.assert_eq("/project/target/peer.lua", calls.copied_to, "copy target")
  t.assert_eq("/project/target/peer.lua", calls.synced_to, "synced copy target")
end)

t:test("copy: copy-as rejects a directory target inside the source", function()
  local calls = run_name_action("copy_as", "src/nested-copy/", {
    node = { filepath = "/project/src/", nodename = "src", nodetype = "D" },
    parent_filepath = "/project",
  })

  t.assert_nil(calls.copied_to, "copy target")
  t.assert_eq(1, #calls.reports, "validation report count")
end)

t:test("copy: copy-as refreshes an unresolved partial target without focusing it", function()
  local calls = run_name_action("copy_as", "target/peer.lua", { copy_status = "partial_failure" })

  t.assert_eq("/project/target/peer.lua", calls.copied_to, "copy target")
  t.assert_eq(1, calls.tree_refresh, "tree refresh count")
  t.assert_eq(1, calls.refresh, "view refresh count")
  t.assert_nil(calls.synced_to, "partial target should not receive focus")
  t.assert_eq(1, #calls.reports, "partial failure report count")
end)

t:test("rename: rejects path separators instead of moving across directories", function()
  local calls = run_name_action("rename", "nested/peer.lua")

  t.assert_nil(calls.moved_to, "move target")
  t.assert_eq(1, #calls.reports, "validation report count")
end)

t:test("rename: joins a parent without trailing slash", function()
  local calls = run_name_action("rename", "peer.lua")

  t.assert_eq("/project/src/peer.lua", calls.moved_to, "move target")
  t.assert_eq("/project/src/peer.lua", calls.synced_to, "synced rename target")
end)

t:run()
