---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.fuzzy.init" ---@type string

-- Runs through --cmd before the measured checkout's init.lua. Loads the measured native library and
-- keeps workspace state, frecency and history inside the run's own directories.
local root = assert(vim.g.fuzzy_bench_root)
local harness = assert(vim.g.fuzzy_bench_harness)
local workspace = assert(vim.g.fuzzy_bench_workspace)
local state = assert(vim.g.fuzzy_bench_state)
vim.env.GIT_OPTIONAL_LOCKS = "0"
vim.api.nvim_set_current_dir(workspace)
vim.opt.runtimepath = { root, vim.env.VIMRUNTIME, vim.api.nvim__get_lib_dir() }
vim.opt.packpath = vim.opt.runtimepath:get()
package.path = harness .. "/?.lua;" .. package.path
require("__test__.bench.fuzzy.cpu").prefer_performance_cores()
yoz = assert(package.loadlib(assert(vim.g.fuzzy_bench_library), "luaopen_yoz"))()
package.loaded.yoz = yoz
stl, dot = require("stl"), require("dot")
require("era.m.plugin.state").options.lockfile = root .. "/lazy-lock.json"

---@return string
dot.path.workspace = function()
  return workspace
end
---@param filename                      string
---@return string
dot.path.locate_workspace_filepath = function(filename)
  return state .. "/" .. filename
end
local setup_context = dot.setup_context
---@return nil
dot.setup_context = function()
  setup_context({ editor = state .. "/editor.json", workspace = state .. "/workspace.json" })
  dot.context.behavior.auto_im:next(false)
end
