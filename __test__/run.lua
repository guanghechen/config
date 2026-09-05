---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.run" ---@type string

-- Both the runner and each suite start from this checkout, independent of CWD
-- and the user's installed Neovim configuration.
local source = assert(vim.uv.fs_realpath(debug.getinfo(1, "S").source:sub(2))) ---@type string
local root = vim.fs.dirname(vim.fs.dirname(source)) ---@type string
local runtime = assert(vim.env.VIMRUNTIME) ---@type string
-- Neovim may install built-in parsers separately from $VIMRUNTIME.
local runtime_paths = { root, runtime, vim.api.nvim__get_lib_dir() } ---@type string[]
vim.api.nvim_set_current_dir(root)
vim.opt.runtimepath = runtime_paths
vim.opt.packpath = runtime_paths
package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path

if arg[1] == "--suite" then
  -- Internal subprocess entry. A spec must finish through harness:run(); an
  -- empty file or a forgotten run call must not report a successful suite.
  local suite = assert(arg[2], "missing suite path") ---@type string
  assert(arg[3] == nil and suite:match("_spec%.lua$"), "expected one *_spec.lua path")
  arg = { [0] = suite }
  dofile(suite)
  error("suite returned without calling harness:run(): " .. suite, 0)
end

require("__test__.support.runner").main(arg)
