local bootstrap = require("__test__.support.bootstrap")
local fs = require("__test__.support.fs")
local harness = require("__test__.support.harness")
local lsp = require("__test__.support.lsp")
local t = harness.new()

t:patch_global("yoz", require("yoz"))
bootstrap.with_global(t, "stl", { env = { PATH_SEP = "/", IS_WIN = false }, fs = require("stl.fs") })
bootstrap.with_global(t, "era", {
  m = {
    lsp = {
      event = {
        get_capabilities = vim.lsp.protocol.make_client_capabilities,
        on_attach = function() end,
        bindkeys = function() end,
      },
    },
  },
})

local native = dofile("lsp/tsc.lua")

---@return string
local function project()
  local root = t:tempdir()
  fs.write(root .. "/pnpm-lock.yaml", {})
  return root
end

t:test("native command has no PATH fallback if the project executable disappears", function()
  local root = project()
  local binpath = lsp.install_typescript(root, "7.0.2")
  local starts = lsp.record_starts(t)
  native.cmd({}, { root_dir = root })
  t.assert_eq(root, starts[1].cwd, "native cwd")
  t.assert_eq(binpath, starts[1].args[1], "project executable")
  t.assert_eq("--lsp", starts[1].args[2], "native mode")
  t.assert_eq("--stdio", starts[1].args[3], "stdio transport")
  assert(vim.uv.fs_unlink(binpath))
  t.assert_false(pcall(native.cmd, {}, { root_dir = root }), "no fallback to global executable")
end)

t:test("native source actions are bound to their own client", function()
  local keymaps
  t:patch_table(era.m.lsp.event, "bindkeys", function(_, _, value)
    keymaps = value
  end)
  native.on_attach({ id = 42 }, 1)
  local requested
  t:patch_table(vim.lsp.buf, "code_action", function(opts)
    requested = opts
  end)
  for index, kind in ipairs({ "source.organizeImports", "source.removeUnusedImports", "source.fixAll" }) do
    keymaps[index].callback()
    t.assert_eq(kind, requested.context.only[1], "native action kind")
    t.assert_true(requested.filter({}, 42), "native client accepted")
    t.assert_false(requested.filter({}, 99), "Biome client excluded")
  end
end)

t:run()
