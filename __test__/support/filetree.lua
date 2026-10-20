---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.support.filetree" ---@type string

local harness = require("__test__.support.harness")
local bootstrap = require("__test__.support.bootstrap")
local treeview = require("__test__.support.treeview")

---@class __test__.support.filetree.Fixture
---@field t                             __test__.support.Harness
---@field native                        table
---@field filetree                      table
---@field await                         fun(future: stl.c.Future): any
---@field write                         fun(path: string): nil

local M = {}

---@return __test__.support.filetree.Fixture
function M.new()
  local t = harness.new()
  local native = bootstrap.with_native(t)

  ---@param path                        string
  ---@return nil
  local function write(path)
    local fd = assert(vim.uv.fs_open(path, "w", 384))
    assert(vim.uv.fs_write(fd, "test", 0))
    assert(vim.uv.fs_close(fd))
  end

  return { t = t, native = native, filetree = require("ux.filetree"), await = treeview.await, write = write }
end

return M
