--- Run with: nvim -l __test__/run.lua __test__/specs/era/m/lsp/fn_spec.lua
---@diagnostic disable: undefined-global
--- Test for era.m.lsp.fn module

local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

local t = harness.new("era.m.lsp.fn")

bootstrap.with_stl(t, {
  env = {
    HOME_NVIM_DATA = "/__nvim_test_data__",
    PATH_SEP = "/",
    IS_HEADLESS = true,
  },
})
bootstrap.with_yoz(t, {
  path = {
    is_exist = function(filepath)
      return vim.uv.fs_stat(filepath) ~= nil
    end,
  },
})

local mason_loads = 0 ---@type integer
t:patch_table(package.preload, "mason", function()
  mason_loads = mason_loads + 1
  return {}
end)
t:patch_table(package.loaded, "mason", nil)

local Fn = require("era.m.lsp.fn")

t:test("locate_lsp_root: searches from the target file and accepts directory markers", function()
  local root = vim.fn.tempname() ---@type string
  local repo_a = root .. "/repo-a" ---@type string
  local repo_b = root .. "/repo-b" ---@type string
  vim.fn.mkdir(repo_a, "p")
  vim.fn.mkdir(repo_b .. "/src", "p")
  vim.fn.mkdir(repo_b .. "/.git", "p")
  vim.fn.writefile({}, repo_a .. "/package.json")
  vim.fn.writefile({}, repo_b .. "/src/app.ts")

  local rootdir, marker = Fn.locate_lsp_root(repo_b .. "/src/app.ts", { "package.json", ".git" })

  t.assert_eq(repo_b, rootdir, "target repo root")
  t.assert_eq(repo_b .. "/.git", marker, "directory marker")
  vim.fn.delete(root, "rf")
end)

t:test("locate_lsp_root: preserves the search root for nested markers", function()
  local root = vim.fn.tempname() ---@type string
  vim.fn.mkdir(root .. "/theme/static_src", "p")
  vim.fn.mkdir(root .. "/src", "p")
  vim.fn.writefile({}, root .. "/theme/static_src/tailwind.config.js")
  vim.fn.writefile({}, root .. "/src/app.css")

  local rootdir, marker = Fn.locate_lsp_root(root .. "/src/app.css", { "theme/static_src/tailwind.config.js" })

  t.assert_eq(root, rootdir, "project root")
  t.assert_eq(root .. "/theme/static_src/tailwind.config.js", marker, "nested marker")
  vim.fn.delete(root, "rf")
end)

t:test("locate_js_project_root: keeps Node and Deno roots mutually exclusive", function()
  local root = vim.fn.tempname() ---@type string
  local node = root .. "/node" ---@type string
  local deno = root .. "/deno" ---@type string
  local node_outer = root .. "/node-outer" ---@type string
  local deno_inner = node_outer .. "/packages/deno" ---@type string
  local deno_outer = root .. "/deno-outer" ---@type string
  local node_inner = deno_outer .. "/packages/node" ---@type string
  local deno_config_outer = root .. "/deno-config-outer" ---@type string
  local deno_jsonc_inner = deno_config_outer .. "/packages/deno" ---@type string
  local mixed_config = root .. "/mixed-config" ---@type string
  local mixed_lock = root .. "/mixed-lock" ---@type string
  local standalone = root .. "/standalone" ---@type string

  for _, dirpath in ipairs({
    node,
    deno,
    deno_inner,
    node_inner,
    deno_jsonc_inner,
    mixed_config,
    mixed_lock,
    standalone,
  }) do
    vim.fn.mkdir(dirpath .. "/src", "p")
    vim.fn.writefile({}, dirpath .. "/src/index.ts")
  end
  vim.fn.writefile({}, node .. "/package-lock.json")
  vim.fn.writefile({}, deno .. "/deno.json")
  vim.fn.writefile({}, node_outer .. "/package-lock.json")
  vim.fn.writefile({}, deno_inner .. "/deno.json")
  vim.fn.writefile({}, deno_outer .. "/deno.json")
  vim.fn.writefile({}, node_inner .. "/package-lock.json")
  vim.fn.writefile({}, deno_config_outer .. "/deno.json")
  vim.fn.writefile({}, deno_jsonc_inner .. "/deno.jsonc")
  vim.fn.writefile({}, deno_jsonc_inner .. "/package-lock.json")
  vim.fn.writefile({}, mixed_config .. "/package-lock.json")
  vim.fn.writefile({}, mixed_config .. "/deno.json")
  vim.fn.writefile({}, mixed_lock .. "/package-lock.json")
  vim.fn.writefile({}, mixed_lock .. "/deno.lock")

  local rootdir, project_type = Fn.locate_js_project_root(node .. "/src/index.ts")
  t.assert_eq(node, rootdir, "Node root")
  t.assert_eq("node", project_type, "Node project type")

  rootdir, project_type = Fn.locate_js_project_root(deno .. "/src/index.ts")
  t.assert_eq(deno, rootdir, "Deno root")
  t.assert_eq("deno", project_type, "Deno project type")

  rootdir, project_type = Fn.locate_js_project_root(deno_inner .. "/src/index.ts")
  t.assert_eq(deno_inner, rootdir, "nested Deno root")
  t.assert_eq("deno", project_type, "nested Deno project type")

  rootdir, project_type = Fn.locate_js_project_root(node_inner .. "/src/index.ts")
  t.assert_eq(node_inner, rootdir, "nested Node root")
  t.assert_eq("node", project_type, "nested Node project type")

  rootdir, project_type = Fn.locate_js_project_root(deno_jsonc_inner .. "/src/index.ts")
  t.assert_eq(deno_jsonc_inner, rootdir, "nested deno.jsonc root")
  t.assert_eq("deno", project_type, "nested deno.jsonc project type")

  rootdir, project_type = Fn.locate_js_project_root(mixed_config .. "/src/index.ts")
  t.assert_eq(mixed_config, rootdir, "same-level Deno config root")
  t.assert_eq("deno", project_type, "Deno config precedence")

  rootdir, project_type = Fn.locate_js_project_root(mixed_lock .. "/src/index.ts")
  t.assert_eq(mixed_lock, rootdir, "same-level Node root")
  t.assert_eq("node", project_type, "Node lock precedence")

  rootdir, project_type = Fn.locate_js_project_root(standalone .. "/src/index.ts")
  t.assert_nil(rootdir, "standalone root")
  t.assert_eq("node", project_type, "standalone project type")

  vim.fn.delete(root, "rf")
end)

t:test("locate_mason_pkg_path: resolves the conventional path without loading Mason", function()
  local filepath = Fn.locate_mason_pkg_path("vtsls", "node_modules/@vtsls/language-server", true)

  t.assert_eq("/__nvim_test_data__/mason/packages/vtsls/node_modules/@vtsls/language-server", filepath, "package path")
  t.assert_eq(0, mason_loads, "Mason load count")
end)

t:run()
