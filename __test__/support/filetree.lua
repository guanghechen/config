---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.support.filetree" ---@type string

local harness = require("__test__.support.harness")
local bootstrap = require("__test__.support.bootstrap")

---@class __test__.support.filetree.Fixture
---@field t                             __test__.support.Harness
---@field native                        table
---@field filetree                      table
---@field await                         fun(future: stl.c.Future): any
---@field write                         fun(path: string): nil
---@field directory                     fun(): string

local M = {}

---@param name                          string
---@return __test__.support.filetree.Fixture
function M.new(name)
  local t = harness.new(name)
  local system = vim.uv.os_uname().sysname
  local library = system == "Windows_NT" and "yoz.dll" or (system == "Darwin" and "libyoz.dylib" or "libyoz.so")
  local native = assert(package.loadlib("rust/target/debug/" .. library, "luaopen_yoz"))()
  bootstrap.with_yoz(t, native)
  bootstrap.with_stl(t, {
    c = { Future = require("stl.c.future") },
    nvim = { fn = require("stl.nvim.fn") },
    reporter = {
      warn = function() end,
      error = function(options)
        error(options.message)
      end,
    },
  })
  local filetree = require("ux.filetree")

  ---@param future                      stl.c.Future
  ---@return any
  local function await(future)
    t.wait_until(function()
      return future:is_done()
    end, 10000)
    t.assert_false(future:is_failed(), future:get_error())
    local value = future:get_result()
    t.assert_false(type(value) == "table" and value.kind == "Rejected", vim.inspect(value))
    return value
  end

  ---@param path                        string
  ---@return nil
  local function write(path)
    local fd = assert(vim.uv.fs_open(path, "w", 384))
    assert(vim.uv.fs_write(fd, "test", 0))
    assert(vim.uv.fs_close(fd))
  end

  ---@return string
  local function directory()
    local path = vim.fn.tempname()
    assert(vim.uv.fs_mkdir(path, 448))
    t:defer(function()
      vim.fn.delete(path, "rf")
    end)
    return path
  end
  return { t = t, native = native, filetree = filetree, await = await, write = write, directory = directory }
end

return M
