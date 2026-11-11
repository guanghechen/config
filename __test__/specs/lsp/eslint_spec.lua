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

local eslint = dofile("lsp/eslint.lua")

t:test("Biome-only projects do not start ESLint because of a lockfile", function()
  for _, name in ipairs({ "biome.json", "biome.jsonc" }) do
    local _, bufnr = lsp.project(t, { [name] = "{}", ["pnpm-lock.yaml"] = "", ["package.json"] = "{}" })
    t.assert_nil(lsp.root_dir(eslint, bufnr), "ESLint stays disabled")
  end
end)

t:test("ESLint-only projects retain their existing root", function()
  local root, bufnr = lsp.project(t, { ["pnpm-lock.yaml"] = "", ["eslint.config.mjs"] = "export default []" })
  t.assert_eq(root, lsp.root_dir(eslint, bufnr), "ESLint workspace")
end)

t:test("explicit ESLint configuration keeps both servers available during migration", function()
  for _, name in ipairs({ "eslint.config.mjs", "eslint.config.mts", ".eslintrc.yml" }) do
    local root, bufnr = lsp.project(t, { ["biome.json"] = "{}", ["pnpm-lock.yaml"] = "", [name] = "" })
    t.assert_eq(root, lsp.root_dir(eslint, bufnr), "mixed workspace: " .. name)
  end
end)

t:test("legacy eslintConfig is detected above a nested package.json", function()
  local root, bufnr = lsp.project(t, {
    ["biome.json"] = "{}",
    ["package.json"] = '{"eslintConfig":{}}',
    ["src/package.json"] = "{}",
  })
  t.assert_eq(root, lsp.root_dir(eslint, bufnr), "legacy ESLint workspace without lockfile")
end)

t:test("invalid package metadata does not enable ESLint in a Biome project", function()
  local _, bufnr = lsp.project(t, { ["biome.json"] = "{}", ["package.json"] = "{" })
  t.assert_nil(lsp.root_dir(eslint, bufnr), "invalid package metadata")
end)

t:test("Deno projects retain the ESLint exclusion during migration", function()
  local _, bufnr = lsp.project(t, { ["deno.json"] = "{}", ["biome.json"] = "{}", ["eslint.config.js"] = "" })
  t.assert_nil(lsp.root_dir(eslint, bufnr), "Deno exclusion")
end)

t:test("symlinked ESLint configuration and package metadata retain ESLint", function()
  for _, name in ipairs({ "eslint.config.mjs", "package.json" }) do
    local root, bufnr = lsp.project(t, {
      ["biome.json"] = "{}",
      ["pnpm-lock.yaml"] = "",
      ["config/shared"] = name == "package.json" and '{"eslintConfig":{}}' or "export default []",
    })
    assert(vim.uv.fs_symlink(root .. "/config/shared", root .. "/" .. name))
    t.assert_eq(root, lsp.root_dir(eslint, bufnr), "symlinked " .. name)
  end
end)

t:test("broken symlinks and directories are not ESLint configurations", function()
  local root, bufnr = lsp.project(t, { ["biome.json"] = "{}", ["eslint.config.js/placeholder"] = "" })
  assert(vim.uv.fs_symlink(root .. "/missing", root .. "/eslint.config.mjs"))
  t.assert_nil(lsp.root_dir(eslint, bufnr), "no valid ESLint config")
end)

t:run()
