---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.m.lsp.rust_analyzer" ---@type string

local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")
local t = harness.new("era.m.lsp.rust_analyzer")

bootstrap.with_yoz(t, require("yoz"))
bootstrap.with_stl(t, { env = { HOME_USER = "/unused-home" }, reporter = {} })
bootstrap.with_dot(t, {
  path = {
    join = vim.fs.joinpath,
    normalize = function(path)
      return vim.fs.normalize(path)
    end,
  },
})
bootstrap.with_era(t, {
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
  local root = vim.fn.tempname() ---@type string
  vim.fn.mkdir(root .. "/src", "p")
  t:defer(function()
    vim.fn.delete(root, "rf")
  end)
  root = assert(vim.uv.fs_realpath(root))
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

t:run()
