---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.m.lsp.biome" ---@type string

local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")
local t = harness.new("era.m.lsp.biome")

bootstrap.with_yoz(t, require("yoz"))
bootstrap.with_stl(t, {
  env = { PATH_SEP = "/", IS_WIN = false },
  fs = require("stl.fs"),
})
bootstrap.with_era(t, {
  m = {
    lsp = {
      fn = require("era.m.lsp.fn"),
      event = { get_capabilities = vim.lsp.protocol.make_client_capabilities },
    },
  },
})

local biome = dofile("lsp/biome.lua")
local eslint = dofile("lsp/eslint.lua")

---@param files                         table<string, string>
---@return string
---@return integer
local function project(files)
  local root = vim.fn.tempname() ---@type string
  vim.fn.mkdir(root .. "/src", "p")
  root = assert(vim.uv.fs_realpath(root))
  t:defer(function()
    vim.fn.delete(root, "rf")
  end)
  for name, content in pairs(files) do
    vim.fn.mkdir(vim.fs.dirname(root .. "/" .. name), "p")
    vim.fn.writefile({ content }, root .. "/" .. name)
  end

  local bufnr = vim.api.nvim_create_buf(false, false) ---@type integer
  t:defer(function()
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)
  vim.api.nvim_buf_set_name(bufnr, root .. "/src/main.ts")
  return root, bufnr
end

---@param config                        vim.lsp.Config
---@param bufnr                         integer
---@return string|nil
local function lsp_root(config, bufnr)
  local root = nil ---@type string|nil
  config.root_dir(bufnr, function(dir)
    root = dir
  end)
  return root
end

t:test("Biome-only projects do not start ESLint because of a lockfile", function()
  for _, name in ipairs({ "biome.json", "biome.jsonc" }) do
    local root, bufnr = project({ [name] = "{}", ["pnpm-lock.yaml"] = "", ["package.json"] = "{}" })
    t.assert_eq(root, lsp_root(biome, bufnr), "Biome workspace")
    t.assert_nil(lsp_root(eslint, bufnr), "ESLint stays disabled")
  end
end)

t:test("ESLint-only projects retain their existing root", function()
  local root, bufnr = project({ ["pnpm-lock.yaml"] = "", ["eslint.config.mjs"] = "export default []" })
  t.assert_eq(root, lsp_root(eslint, bufnr), "ESLint workspace")
  t.assert_nil(lsp_root(biome, bufnr), "Biome has no workspace")
end)

t:test("explicit ESLint configuration keeps both servers available during migration", function()
  for _, name in ipairs({ "eslint.config.mjs", "eslint.config.mts", ".eslintrc.yml" }) do
    local root, bufnr = project({ ["biome.json"] = "{}", ["pnpm-lock.yaml"] = "", [name] = "" })
    t.assert_eq(root, lsp_root(eslint, bufnr), "mixed workspace: " .. name)
  end
end)

t:test("legacy eslintConfig is detected above a nested package.json", function()
  local root, bufnr = project({
    ["biome.json"] = "{}",
    ["package.json"] = '{"eslintConfig":{}}',
    ["src/package.json"] = "{}",
  })
  t.assert_eq(root, lsp_root(eslint, bufnr), "legacy ESLint workspace without lockfile")
end)

t:test("invalid package metadata does not enable ESLint in a Biome project", function()
  local _, bufnr = project({ ["biome.json"] = "{}", ["package.json"] = "{" })
  t.assert_nil(lsp_root(eslint, bufnr), "invalid package metadata")
end)

t:test("nearest Biome config wins regardless of JSON or JSONC extension", function()
  local root, bufnr = project({ ["biome.json"] = "{}", ["src/biome.jsonc"] = "{}" })
  t.assert_eq(root .. "/src", lsp_root(biome, bufnr), "nested workspace")
end)

t:test("Deno projects retain the ESLint exclusion during migration", function()
  local _, bufnr = project({ ["deno.json"] = "{}", ["biome.json"] = "{}", ["eslint.config.js"] = "" })
  t.assert_nil(lsp_root(eslint, bufnr), "Deno exclusion")
end)

t:test("LSP uses the project binary from an ancestor of the Biome config", function()
  local root, bufnr = project({ ["node_modules/.bin/biome"] = "#!/bin/sh", ["src/biome.jsonc"] = "{}" })
  assert(vim.uv.fs_chmod(root .. "/node_modules/.bin/biome", 493))
  local command = nil ---@type string[]|nil
  local cwd = nil ---@type string|nil
  t:patch_table(vim.lsp.rpc, "start", function(args, _, opts)
    command = args
    cwd = opts.cwd
    return {}
  end)
  biome.cmd({}, { root_dir = lsp_root(biome, bufnr) })
  t.assert_eq(root .. "/node_modules/.bin/biome", command[1], "project binary")
  t.assert_eq("lsp-proxy", command[2], "LSP subcommand")
  t.assert_eq(root .. "/src", cwd, "workspace working directory")
end)

t:test("LSP falls back to the runtime PATH without a project binary", function()
  local root = project({ ["biome.json"] = "{}" })
  local command = nil ---@type string[]|nil
  t:patch_table(vim.lsp.rpc, "start", function(args)
    command = args
    return {}
  end)
  biome.cmd({}, { root_dir = root })
  t.assert_eq("biome", command[1], "PATH binary")
end)

t:test("package-local Biome binaries keep separate clients under an inherited config", function()
  local root, bufnr = project({
    ["biome.json"] = "{}",
    ["packages/a/node_modules/.bin/biome"] = "#!/bin/sh",
    ["packages/b/node_modules/.bin/biome"] = "#!/bin/sh",
  })
  local command = nil ---@type string[]|nil
  t:patch_table(vim.lsp.rpc, "start", function(args)
    command = args
    return {}
  end)
  for _, name in ipairs({ "a", "b" }) do
    local package_root = root .. "/packages/" .. name
    local binpath = package_root .. "/node_modules/.bin/biome"
    assert(vim.uv.fs_chmod(binpath, 493))
    vim.api.nvim_buf_set_name(bufnr, package_root .. "/main.ts")
    local rootdir = lsp_root(biome, bufnr)
    t.assert_eq(package_root, rootdir, "package workspace")
    biome.cmd({}, { root_dir = rootdir })
    t.assert_eq(binpath, command[1], "package binary")
  end
end)

t:test("non-executable package binaries do not shadow a working ancestor binary", function()
  local root, bufnr = project({
    ["biome.json"] = "{}",
    ["node_modules/.bin/biome"] = "#!/bin/sh",
    ["src/node_modules/.bin/biome"] = "",
  })
  local binpath = root .. "/node_modules/.bin/biome"
  assert(vim.uv.fs_chmod(binpath, 493))
  t.assert_eq(root, lsp_root(biome, bufnr), "ancestor workspace")
  t.assert_eq(binpath, era.m.lsp.fn.locate_node_bin(root .. "/src", "biome"), "executable ancestor")
end)

t:test("symlinked ESLint configuration and package metadata retain ESLint", function()
  for _, name in ipairs({ "eslint.config.mjs", "package.json" }) do
    local root, bufnr = project({
      ["biome.json"] = "{}",
      ["pnpm-lock.yaml"] = "",
      ["config/shared"] = name == "package.json" and '{"eslintConfig":{}}' or "export default []",
    })
    assert(vim.uv.fs_symlink(root .. "/config/shared", root .. "/" .. name))
    t.assert_eq(root, lsp_root(eslint, bufnr), "symlinked " .. name)
  end
end)

t:test("broken symlinks and directories are not ESLint configurations", function()
  local root, bufnr = project({ ["biome.json"] = "{}", ["eslint.config.js/placeholder"] = "" })
  assert(vim.uv.fs_symlink(root .. "/missing", root .. "/eslint.config.mjs"))
  t.assert_nil(lsp_root(eslint, bufnr), "no valid ESLint config")
end)

t:run()
