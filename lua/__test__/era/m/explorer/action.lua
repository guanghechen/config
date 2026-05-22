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

t:run()
