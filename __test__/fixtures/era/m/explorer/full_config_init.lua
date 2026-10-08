---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.fixtures.era.m.explorer.full_config_init" ---@type string

local root = assert(vim.g.explorer_test_root)
local directory = assert(vim.g.explorer_test_directory)
vim.env.GIT_OPTIONAL_LOCKS = "0"
vim.api.nvim_set_current_dir(directory .. "/files")
vim.opt.runtimepath = { root, vim.env.VIMRUNTIME, vim.api.nvim__get_lib_dir() }
vim.opt.packpath = vim.opt.runtimepath:get()
local suffix = vim.uv.os_uname().sysname == "Windows_NT" and "dll" or "so"
package.cpath = root .. "/lua/?." .. suffix .. ";" .. package.cpath
local library = vim.g.explorer_test_library or vim.env.NVIM_EXPLORER_BENCH_NATIVE
yoz = library and assert(package.loadlib(library, "luaopen_yoz"))() or require("yoz")
package.loaded.yoz = yoz
stl, dot = require("stl"), require("dot")
require("era.m.plugin.state").options.lockfile = root .. "/lazy-lock.json"
if vim.g.explorer_test_capture then
  explorer_bench_startup_errors = {}
  local report = stl.reporter.error
  stl.reporter.error = function(value)
    explorer_bench_startup_errors[#explorer_bench_startup_errors + 1] = value.message
    report(value)
  end
end

-- Keep full runtime services while directing workspace state and file operations to owned fixtures.
---@return string
dot.path.workspace = function()
  return directory .. "/files"
end
---@param filename                      string
---@return string
dot.path.locate_workspace_filepath = function(filename)
  return directory .. "/state/" .. filename
end
local setup_context = dot.setup_context
---@return nil
dot.setup_context = function()
  setup_context({ editor = directory .. "/state/editor.json", workspace = directory .. "/state/workspace.json" })
  dot.context.behavior.auto_im:next(false)
  dot.context.explorer.trash:next(false)
end
