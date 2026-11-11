---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.support.filetree" ---@type string

local bootstrap = require("__test__.support.bootstrap")
local fs = require("__test__.support.fs")
local treeview = require("__test__.support.treeview")

---@class __test__.support.filetree.Fixture
---@field t                             __test__.support.Harness
---@field native                        table
---@field filetree                      table
---@field await                         fun(future: stl.c.Future): any
---@field write                         fun(path: string): nil
---@field attach                        fun(state: ux.treeview.State, options: ?ux.treeview.IViewOptions): ux.filetree.View

local M = {}

---Loads the native library for the suite of `t`.
---@param t                             __test__.support.Harness
---@return __test__.support.filetree.Fixture
function M.new(t)
  local native = bootstrap.with_native(t)
  local filetree = require("ux.filetree")

  ---@param path                        string
  ---@return nil
  local function write(path)
    fs.write(path, "test")
  end

  ---Attaches a Filetree view of `state` with `options`, detached when the case ends.
  ---@param state                       ux.treeview.State
  ---@param options                     ?ux.treeview.IViewOptions
  ---@return ux.filetree.View
  local function attach(state, options)
    local view = filetree.attach(state, options)
    t:defer(function()
      view:detach()
    end)
    return view
  end

  return { t = t, native = native, filetree = filetree, await = treeview.await, write = write, attach = attach }
end

return M
