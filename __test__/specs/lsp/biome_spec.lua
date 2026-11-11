local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")
local lsp = require("__test__.support.lsp")
local t = harness.new()

t:patch_global("yoz", require("yoz"))
bootstrap.with_global(t, "stl", {
  env = { PATH_SEP = "/", IS_WIN = false },
  fs = require("stl.fs"),
})
bootstrap.with_global(t, "era", {
  m = {
    lsp = {
      fn = require("era.m.lsp.fn"),
      event = { get_capabilities = vim.lsp.protocol.make_client_capabilities },
    },
  },
})

local biome = dofile("lsp/biome.lua")

t:test("Biome-only projects root the Biome workspace at their config", function()
  for _, name in ipairs({ "biome.json", "biome.jsonc" }) do
    local root, bufnr = lsp.project(t, { [name] = "{}", ["pnpm-lock.yaml"] = "", ["package.json"] = "{}" })
    t.assert_eq(root, lsp.root_dir(biome, bufnr), "Biome workspace")
  end
end)

t:test("ESLint-only projects have no Biome workspace", function()
  local _, bufnr = lsp.project(t, { ["pnpm-lock.yaml"] = "", ["eslint.config.mjs"] = "export default []" })
  t.assert_nil(lsp.root_dir(biome, bufnr), "Biome has no workspace")
end)

t:test("nearest Biome config wins regardless of JSON or JSONC extension", function()
  local root, bufnr = lsp.project(t, { ["biome.json"] = "{}", ["src/biome.jsonc"] = "{}" })
  t.assert_eq(root .. "/src", lsp.root_dir(biome, bufnr), "nested workspace")
end)

t:test("LSP uses the project binary from an ancestor of the Biome config", function()
  local root, bufnr = lsp.project(t, { ["node_modules/.bin/biome"] = "#!/bin/sh", ["src/biome.jsonc"] = "{}" })
  assert(vim.uv.fs_chmod(root .. "/node_modules/.bin/biome", 493))
  local starts = lsp.record_starts(t)
  biome.cmd({}, { root_dir = lsp.root_dir(biome, bufnr) })
  t.assert_eq(root .. "/node_modules/.bin/biome", starts[1].args[1], "project binary")
  t.assert_eq("lsp-proxy", starts[1].args[2], "LSP subcommand")
  t.assert_eq(root .. "/src", starts[1].cwd, "workspace working directory")
end)

t:test("LSP falls back to the runtime PATH without a project binary", function()
  local root = lsp.project(t, { ["biome.json"] = "{}" })
  local starts = lsp.record_starts(t)
  biome.cmd({}, { root_dir = root })
  t.assert_eq("biome", starts[1].args[1], "PATH binary")
end)

t:test("package-local Biome binaries keep separate clients under an inherited config", function()
  local root, bufnr = lsp.project(t, {
    ["biome.json"] = "{}",
    ["packages/a/node_modules/.bin/biome"] = "#!/bin/sh",
    ["packages/b/node_modules/.bin/biome"] = "#!/bin/sh",
  })
  local starts = lsp.record_starts(t)
  for _, name in ipairs({ "a", "b" }) do
    local package_root = root .. "/packages/" .. name
    local binpath = package_root .. "/node_modules/.bin/biome"
    assert(vim.uv.fs_chmod(binpath, 493))
    vim.api.nvim_buf_set_name(bufnr, package_root .. "/main.ts")
    local rootdir = lsp.root_dir(biome, bufnr)
    t.assert_eq(package_root, rootdir, "package workspace")
    biome.cmd({}, { root_dir = rootdir })
    t.assert_eq(binpath, starts[#starts].args[1], "package binary")
  end
end)

t:test("non-executable package binaries keep the workspace of the inherited config", function()
  local root, bufnr = lsp.project(t, {
    ["biome.json"] = "{}",
    ["node_modules/.bin/biome"] = "#!/bin/sh",
    ["src/node_modules/.bin/biome"] = "",
  })
  assert(vim.uv.fs_chmod(root .. "/node_modules/.bin/biome", 493))
  t.assert_eq(root, lsp.root_dir(biome, bufnr), "ancestor workspace")
end)

t:run()
