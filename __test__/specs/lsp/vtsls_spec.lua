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

local vtsls = dofile("lsp/vtsls.lua")

---@return string
local function project()
  local root = t:tempdir()
  fs.write(root .. "/pnpm-lock.yaml", {})
  return root
end

t:test("vtsls SDK follows its workspace instead of the editor cwd", function()
  local root = project()
  local legacy = root .. "/legacy"
  lsp.install_typescript(root, "7.0.2")
  lsp.install_typescript(legacy, "6.0.3")
  local cwd = vim.fn.getcwd()
  vim.api.nvim_set_current_dir(root)
  t:defer(function()
    vim.api.nvim_set_current_dir(cwd)
  end)

  local config = vim.deepcopy(vtsls)
  config.root_dir = legacy
  config.before_init({}, config)
  t.assert_eq(legacy .. "/node_modules/typescript/lib", config.settings.typescript.tsdk, "workspace SDK")
  t.assert_true(config.settings.vtsls.autoUseWorkspaceTsdk, "use legacy workspace SDK")

  config.root_dir = nil
  config.before_init({}, config)
  t.assert_nil(config.settings.typescript.tsdk, "standalone SDK is not borrowed from cwd")
  t.assert_false(config.settings.vtsls.autoUseWorkspaceTsdk, "standalone bundled SDK")
end)

t:run()
