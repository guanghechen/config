local root = vim.uv.cwd()
vim.opt.runtimepath = { root, vim.env.VIMRUNTIME, vim.api.nvim__get_lib_dir() }
package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path

local harness = require("__test__.support.harness")
local bootstrap = require("__test__.support.bootstrap")
local runtime = require("__test__.fixtures.era.dressing.statusline.runtime")
local t = harness.new("era.dressing.statusline.exit")
local errors = runtime.setup(t, {
  python = {
    env = function(position)
      return require("era.m.nvimbar.component.python").env(position)
    end,
  },
})
bootstrap.with_dot(t, {
  G = {
    register_anonymous_fn = function()
      return "dot.G.noop"
    end,
  },
  context = {
    lsp = {
      python_venv_path = {
        snapshot = function()
          return "/project/venv"
        end,
      },
      get_python_bin_path = function()
        return vim.v.progpath
      end,
    },
  },
})

local process = nil ---@type vim.SystemObj|nil
local system = vim.system
t:patch_table(vim, "system", function(command, opts, callback)
  t.assert_eq("--version", command[2], "Python version probe")
  -- Neovim supplies a slow, cancellable process without requiring a Python installation.
  process = system({
    vim.v.progpath,
    "--headless",
    "-u",
    "NONE",
    "-i",
    "NONE",
    "-n",
    "-c",
    "sleep 10",
    "-c",
    "qa!",
  }, opts, callback)
  vim.fn.writefile({ tostring(process.pid) }, assert(vim.env.NVIMBAR_TEST_RESULT))
  return process
end)

require("era.dressing.statusline").dressing()
t.wait_until(function()
  return process ~= nil
end, 3000, "the Python probe starts before quitting")
t.assert_true(vim.uv.kill(assert(process).pid, 0), "the probe is still running")
vim.api.nvim_create_autocmd("VimLeavePre", {
  once = true,
  callback = function()
    t.assert_eq(0, #errors, vim.inspect(errors))
  end,
})
vim.cmd("qa!")
