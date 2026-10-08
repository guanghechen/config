---@diagnostic disable-next-line: unused-local
local __module_name__ = "ux.filetree" ---@type string

local async = require("ux.treeview.async")
local Treeview = require("ux.treeview")
local Data = require("ux.filetree.data")
local annotations = require("ux.filetree.annotations")

local M = {}

---@param path                          string
---@param options                       ?ux.filetree.IOptions
---@return stl.c.Future
function M.open(path, options)
  local native = (rawget(_G, "yoz") or require("yoz")).ux.filetree
  return async.run(native.open(path)):map(function(value)
    if type(value) ~= "userdata" then
      return value
    end
    return Data.new(value, options)
  end)
end

---@param state                         ux.treeview.State
---@param options                       ?ux.treeview.IViewOptions
---@return ux.filetree.View
function M.attach(state, options)
  local native = assert(state._data._filetree_native, "Filetree views require Filetree data")
  local on_attach = options and options.on_attach
  options = vim.tbl_extend("force", options or {}, {
    on_attach = function(view)
      annotations.attach(view)
      if on_attach then
        on_attach(view)
      end
    end,
    prepare_frame = function(view, frame, first, last)
      return annotations.prepare(view, native, frame, first, last)
    end,
  })
  return Treeview.attach(state, options)
end

return M
