local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")
local t = harness.new()

t:patch_global("yoz", require("yoz"))
bootstrap.with_global(t, "stl", { env = { HOME_USER = "/unused-home" }, reporter = {} })
bootstrap.with_global(t, "dot", {
  path = {
    join = vim.fs.joinpath,
    normalize = function(path)
      return vim.fs.normalize(path)
    end,
  },
})
bootstrap.with_global(t, "era", {
  m = {
    lsp = {
      event = { get_capabilities = vim.lsp.protocol.make_client_capabilities },
    },
  },
})

local config = dofile("lsp/rust_analyzer.lua")

---@return string
---@return integer
local function project()
  local root = t:tempdir()
  vim.fn.mkdir(root .. "/src", "p")
  vim.fn.writefile({ "[package]", 'name = "fixture"', 'version = "0.1.0"' }, root .. "/Cargo.toml")
  local bufnr = vim.api.nvim_create_buf(false, false)
  t:defer(function()
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)
  vim.api.nvim_buf_set_name(bufnr, root .. "/src/lib.rs")
  return root, bufnr
end

t:test("configured sysroot sources reuse an existing Rust workspace without invoking cargo", function()
  local root, bufnr = project()
  local library = root .. "/toolchain/lib/rustlib/src/rust/library"
  vim.fn.mkdir(library .. "/std/src", "p")
  vim.api.nvim_buf_set_name(bufnr, library .. "/std/src/lib.rs")
  t:patch_table(vim.lsp, "get_clients", function()
    return { { config = { root_dir = root .. "/workspace" } } }
  end)
  t:patch_table(vim, "system", function()
    error("library lookup must not invoke cargo")
  end)

  for _, cargo in ipairs({ { sysrootSrc = library }, { sysroot = root .. "/toolchain" } }) do
    t:patch_table(vim.lsp, "config", { rust_analyzer = { settings = { ["rust-analyzer"] = { cargo = cargo } } } })
    local resolved
    config.root_dir(bufnr, function(rootdir)
      resolved = rootdir
    end)
    t.assert_eq(root .. "/workspace", resolved, "existing client root")
  end
end)

t:test("a Cargo project reports a missing executable without starting metadata", function()
  local _, bufnr = project()
  t:patch_table(vim.lsp, "config", { rust_analyzer = { settings = {} } })
  t:patch_table(vim.fn, "executable", function(command)
    t.assert_eq("cargo", command)
    return 0
  end)
  t:patch_table(vim, "system", function()
    error("missing cargo must not be spawned")
  end)
  local warning
  t:patch_table(stl.reporter, "warn", function(message)
    warning = message
  end)
  local resolved = false
  config.root_dir(bufnr, function()
    resolved = true
  end)
  t.assert_false(resolved, "server is not started")
  t.assert_eq("root_dir", warning.subject)
  t.assert_eq("cargo executable not found.", warning.message)
end)

t:test("inlay hints are requested again each time rust-analyzer becomes ready", function()
  local refreshed = {} ---@type integer[]
  t:patch_table(vim.lsp.handlers, "workspace/inlayHint/refresh", function(_, _, ctx)
    refreshed[#refreshed + 1] = ctx.client_id
    return vim.NIL
  end)
  local on_server_status = config.handlers["experimental/serverStatus"]
  local ctx = { client_id = 7, method = "experimental/serverStatus" }

  on_server_status(nil, { health = "ok", quiescent = false }, ctx)
  t.assert_same({}, refreshed, "a busy server")
  on_server_status(nil, { health = "ok", quiescent = true }, ctx)
  t.assert_same({ 7 }, refreshed, "the server became ready")
  on_server_status(nil, { health = "ok", quiescent = true }, ctx)
  t.assert_same({ 7 }, refreshed, "the server stays ready")
  on_server_status(nil, { health = "ok", quiescent = false }, ctx)
  on_server_status(nil, { health = "ok", quiescent = true }, ctx)
  t.assert_same({ 7, 7 }, refreshed, "ready again after reloading the workspace")
end)

t:run()
