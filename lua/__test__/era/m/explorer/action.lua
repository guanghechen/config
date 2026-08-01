---@diagnostic disable: undefined-global
--- Test for era.m.explorer.action module
--- Run with: nvim -l lua/__test__/era/m/explorer/action.lua

local harness = require("__test__.harness")
local Action = require("era.m.explorer.action")

local t = harness.new("era.m.explorer.action")

---@param input                         string
---@return table
local function run_create_file(input)
  local calls = {
    create_filepath = nil,
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
        to_os = function(filepath)
          return filepath
        end,
      },
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

  t:patch_table(vim.ui, "input", function(_, callback)
    callback(input)
  end)

  t:patch_table(vim, "schedule", function(callback)
    callback()
  end)

  local ctx = {
    get_cursor_filepath = function()
      return "/project/"
    end,
    get_parent_filepath = function(filepath)
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

t:test("cut refreshes the tree without deleting the moved source again", function()
  local remove_calls = 0
  local moved_to
  t:patch_global("stl", {
    os = {
      path = {
        normalize = function(filepath)
          return filepath
        end,
        to_os = function(filepath)
          return filepath
        end,
      },
    },
  })
  t:patch_table(vim.ui, "input", function(_, callback)
    callback("/project/target.txt")
  end)
  t:patch_table(vim, "schedule", function(callback)
    callback()
  end)

  local ctx = {
    get_cursor_filepath = function()
      return "/project/source.txt"
    end,
    refresh = function() end,
    resource_manager = {
      move = function(_, _, target)
        moved_to = target
        return true
      end,
    },
    sync_cursor_to_filepath = function() end,
    tree = {
      get_selected_nodes = function()
        return {}
      end,
      refresh = function() end,
      remove = function()
        remove_calls = remove_calls + 1
      end,
    },
  }

  Action.new(ctx):cut()

  t.assert_eq("/project/target.txt", moved_to, "move target")
  t.assert_eq(0, remove_calls, "post-move remove calls")
end)

t:test("move_selected refreshes without deleting moved sources again", function()
  local remove_calls = 0
  local moved_to
  t:patch_global("stl", {
    icon = { symbols = { selection_copy = "C", selection_cut = "X" } },
    os = {
      path = {
        normalize = function(filepath)
          return filepath:gsub("/+", "/")
        end,
        to_os = function(filepath)
          return filepath
        end,
      },
    },
    reporter = {
      error = function() end,
      info = function() end,
      warn = function() end,
    },
  })
  t:patch_global("dot", {
    path = {
      cwd = function()
        return "/project"
      end,
      join = function(left, right)
        return left:gsub("/+$", "") .. "/" .. right:gsub("^/+", "")
      end,
      relative = function(base, filepath)
        local prefix = base:gsub("/+$", "") .. "/"
        return filepath:sub(1, #prefix) == prefix and filepath:sub(#prefix + 1) or filepath
      end,
      resolve = function(_, filepath)
        return filepath
      end,
    },
  })
  t:patch_global("yoz", {
    path = {
      is_absolute = function(filepath)
        return filepath:sub(1, 1) == "/"
      end,
    },
  })
  t:patch_global("era", {
    view = {
      Act = {
        new = function(props)
          return {
            open = function()
              props.on_confirm("/target")
            end,
          }
        end,
      },
    },
  })
  t:patch_table(vim, "schedule", function(callback)
    callback()
  end)

  local node = { filepath = "/project/a.txt", nodetype = "F" }
  local ctx = {
    fullname = "test",
    refresh = function() end,
    resource_manager = {
      move = function(_, _, target)
        moved_to = target
        return true
      end,
    },
    tree = {
      clear_selection = function() end,
      get_common_ancestor_path = function()
        return "/project/"
      end,
      get_selected_nodes = function()
        return { node }
      end,
      refresh = function() end,
      remove = function()
        remove_calls = remove_calls + 1
      end,
    },
  }

  Action.new(ctx):move_selected()

  t.assert_eq("/target/a.txt", moved_to, "move target")
  t.assert_eq(0, remove_calls, "post-move remove calls")
end)

t:run()
