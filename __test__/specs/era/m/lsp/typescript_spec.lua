---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.m.lsp.typescript" ---@type string

local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")
local t = harness.new("era.m.lsp.typescript")

bootstrap.with_yoz(t, require("yoz"))
bootstrap.with_stl(t, { env = { PATH_SEP = "/", IS_WIN = false }, fs = require("stl.fs") })
bootstrap.with_era(t, {
  m = {
    lsp = {
      event = {
        get_capabilities = vim.lsp.protocol.make_client_capabilities,
        before_init = function() end,
        on_attach = function() end,
        bindkeys = function() end,
      },
    },
  },
})

local TypeScript = require("era.m.lsp.typescript")
local native = dofile("lsp/tsc.lua")
local vtsls = dofile("lsp/vtsls.lua")

---@return string
local function project()
  local root = vim.fn.tempname() ---@type string
  vim.fn.mkdir(root, "p")
  root = assert(vim.uv.fs_realpath(root))
  t:defer(function()
    vim.fn.delete(root, "rf")
  end)
  vim.fn.writefile({}, root .. "/pnpm-lock.yaml")
  return root
end

---@param root                          string
---@param version                       string
---@return string binpath
local function install_typescript(root, version)
  vim.fn.mkdir(root .. "/node_modules/typescript/lib", "p")
  vim.fn.mkdir(root .. "/node_modules/.bin", "p")
  vim.fn.writefile(
    { vim.json.encode({ name = "typescript", version = version }) },
    root .. "/node_modules/typescript/package.json"
  )
  if tonumber(version:match("^(%d+)")) < 7 then
    vim.fn.writefile({}, root .. "/node_modules/typescript/lib/tsserver.js")
  end
  local binpath = root .. "/node_modules/.bin/" .. (stl.env.IS_WIN and "tsc.cmd" or "tsc")
  vim.fn.writefile({ "#!/bin/sh", "exit 0" }, binpath)
  assert(vim.uv.fs_chmod(binpath, 493))
  return binpath
end

---@param filepath                      string
---@param expected                      "tsc"|"vtsls"|"denols"
---@param rootdir                       ?string
---@return nil
local function assert_route(filepath, expected, rootdir)
  local bufnr = vim.api.nvim_create_buf(false, false)
  t:defer(function()
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)
  vim.api.nvim_buf_set_name(bufnr, filepath)
  for name, config in pairs({ tsc = native, vtsls = vtsls }) do
    local called = false
    config.root_dir(bufnr, function(dir)
      called = true
      t.assert_eq(rootdir, dir, name .. " root")
    end)
    t.assert_eq(name == expected, called, name .. " attachment eligibility")
  end
end

t:test("project TypeScript 7 uses native LSP while TypeScript 5 and 6 use vtsls", function()
  for _, version in ipairs({ "7.0.2", "7.1.0-dev.20260912", "6.0.3", "5.9.3" }) do
    local root = project()
    local binpath = install_typescript(root, version)
    local resolved = TypeScript.resolve(root)
    local expected = version:sub(1, 1) == "7" and "tsc" or "vtsls"
    t.assert_eq(expected, resolved.server, "TypeScript " .. version)
    if expected == "tsc" then
      t.assert_eq(binpath, resolved.binpath, "project executable")
      t.assert_nil(resolved.tsdk, "no legacy SDK")
    else
      t.assert_nil(resolved.binpath, "no native executable")
      t.assert_eq(root .. "/node_modules/typescript/lib", resolved.tsdk, "legacy SDK")
    end
    assert_route(root .. "/main.ts", expected, root)
  end
end)

t:test("an installed global tsc never enables native LSP without project TypeScript", function()
  local root = project()
  local original_executable = vim.fn.executable
  t:patch_table(vim.fn, "executable", function(path)
    if path == "tsc" or path == "tsc.cmd" then
      error("global tsc must not be queried")
    end
    return original_executable(path)
  end)
  local global = root .. "/global"
  vim.fn.mkdir(global, "p")
  vim.fn.writefile({ "#!/bin/sh", "echo 'Version 7.0.2'" }, global .. "/tsc")
  assert(vim.uv.fs_chmod(global .. "/tsc", 493))
  local original_path = vim.env.PATH
  vim.env.PATH = global .. ":" .. original_path
  t:defer(function()
    vim.env.PATH = original_path
  end)
  assert_route(root .. "/main.ts", "vtsls", root)
end)

t:test("the nearest installed version wins in mixed-version monorepos", function()
  for _, versions in ipairs({ { "7.0.2", "6.0.3", "vtsls" }, { "6.0.3", "7.0.2", "tsc" } }) do
    local root = project()
    local package_root = root .. "/packages/app"
    install_typescript(root, versions[1])
    install_typescript(package_root, versions[2])
    assert_route(package_root .. "/main.ts", versions[3], package_root)
  end
end)

t:test("missing executables and invalid nearest installations fall back without searching parents", function()
  for _, kind in ipairs({ "missing-bin", "invalid-json", "invalid-version", "missing-package-json", "broken-symlink" }) do
    local root = project()
    install_typescript(root, "7.0.2")
    local package_root = root .. "/packages/app"
    local binpath = install_typescript(package_root, "7.0.2")
    local package_dir = package_root .. "/node_modules/typescript"
    if kind == "missing-bin" then
      assert(vim.uv.fs_unlink(binpath))
    elseif kind == "invalid-json" then
      vim.fn.writefile({ "{" }, package_dir .. "/package.json")
    elseif kind == "invalid-version" then
      vim.fn.writefile({ '{"name":"typescript","version":"unknown"}' }, package_dir .. "/package.json")
    elseif kind == "missing-package-json" then
      assert(vim.uv.fs_unlink(package_dir .. "/package.json"))
    else
      vim.fn.delete(package_dir, "rf")
      assert(vim.uv.fs_symlink(package_root .. "/missing", package_dir))
    end
    assert_route(package_root .. "/main.ts", "vtsls", package_root)
  end
end)

t:test("dependency lookup stops at the project boundary", function()
  local root = project()
  install_typescript(root, "7.0.2")
  for _, marker in ipairs({ "pnpm-lock.yaml", ".git" }) do
    local nested = root .. "/nested-" .. marker:gsub("%W", "")
    vim.fn.mkdir(nested, "p")
    vim.fn.writefile({}, nested .. "/" .. marker)
    local resolved = TypeScript.resolve(nested)
    t.assert_eq("vtsls", resolved.server, marker .. " boundary")
    t.assert_eq(nested, resolved.root_dir, marker .. " workspace")
  end
end)

t:test("Deno roots remain excluded even when TypeScript 7 is installed", function()
  local root = project()
  install_typescript(root, "7.0.2")
  vim.fn.writefile({ "{}" }, root .. "/deno.json")
  assert_route(root .. "/main.ts", "denols", root)
end)

t:test("pnpm-style symlinks and Windows command shims resolve locally", function()
  for _, windows in ipairs({ false, true }) do
    local restore = t:patch_table(stl.env, "IS_WIN", windows)
    local root = project()
    local binpath = install_typescript(root, "7.0.2")
    assert(vim.uv.fs_rename(root .. "/node_modules/typescript", root .. "/typescript-store"))
    assert(vim.uv.fs_symlink(root .. "/typescript-store", root .. "/node_modules/typescript"))
    t.assert_eq(binpath, TypeScript.resolve(root).binpath, "local shim")
    restore()
  end
end)

t:test("vtsls SDK follows its workspace instead of the editor cwd", function()
  local root = project()
  local legacy = root .. "/legacy"
  install_typescript(root, "7.0.2")
  install_typescript(legacy, "6.0.3")
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

t:test("native command has no PATH fallback if the project executable disappears", function()
  local root = project()
  local binpath = install_typescript(root, "7.0.2")
  local command
  t:patch_table(vim.lsp.rpc, "start", function(args, _, opts)
    command = args
    t.assert_eq(root, opts.cwd, "native cwd")
    return {}
  end)
  native.cmd({}, { root_dir = root })
  t.assert_eq(binpath, command[1], "project executable")
  t.assert_eq("--lsp", command[2], "native mode")
  t.assert_eq("--stdio", command[3], "stdio transport")
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

t:test("repeated resolution and startup share one metadata read", function()
  local root = project()
  install_typescript(root, "7.0.2")
  vim.fn.mkdir(root .. "/src", "p")
  local reads = 0
  local read_json = stl.fs.read_json
  t:patch_table(stl.fs, "read_json", function(opts)
    reads = reads + 1
    return read_json(opts)
  end)
  for _ = 1, 5 do
    t.assert_eq("tsc", TypeScript.resolve(root .. "/src").server, "native selection")
    t.assert_eq("tsc", TypeScript.get_installation(root).server, "startup installation")
  end
  t.assert_eq(1, reads, "one read for unchanged installation")

  t:patch_table(TypeScript, "resolve", function()
    error("startup must not repeat ancestor discovery")
  end)
  t:patch_table(vim.lsp.rpc, "start", function()
    return {}
  end)
  native.cmd({}, { root_dir = root })
  local config = vim.deepcopy(vtsls)
  config.root_dir = root
  config.before_init({}, config)
  t.assert_eq(1, reads, "startup reuses metadata")
end)

t:test("a transient metadata read failure is retried and the recovered version is cached", function()
  local root = project()
  install_typescript(root, "7.0.2")
  local reads = 0
  local read_json = stl.fs.read_json
  t:patch_table(stl.fs, "read_json", function(opts)
    reads = reads + 1
    if reads == 1 then
      return nil
    end
    return read_json(opts)
  end)

  t.assert_eq("vtsls", TypeScript.resolve(root).server, "safe fallback on failed read")
  t.assert_eq("tsc", TypeScript.get_installation(root).server, "startup retries unchanged metadata")
  t.assert_eq(2, reads, "failed read was retried")
  t.assert_eq("tsc", TypeScript.resolve(root).server, "recovered version remains available")
  t.assert_eq(2, reads, "successful read is cached")
end)

t:test("a failed refresh clears the old version without caching the failure", function()
  local root = project()
  install_typescript(root, "7.0.2")
  t.assert_eq("tsc", TypeScript.resolve(root).server, "initial cached version")
  local filepath = root .. "/node_modules/typescript/package.json"
  local stat = assert(vim.uv.fs_stat(filepath))
  install_typescript(root, "6.0.3")
  assert(vim.uv.fs_utime(filepath, stat.atime.sec, stat.mtime.sec + 1))

  local reads = 0
  local read_json = stl.fs.read_json
  t:patch_table(stl.fs, "read_json", function(opts)
    reads = reads + 1
    return reads > 1 and read_json(opts) or nil
  end)
  local fallback = TypeScript.get_installation(root)
  t.assert_eq("vtsls", fallback.server, "old native version is not reused")
  t.assert_nil(fallback.tsdk, "failed read cannot select a workspace SDK")
  local recovered = TypeScript.get_installation(root)
  t.assert_eq(root .. "/node_modules/typescript/lib", recovered.tsdk, "legacy SDK recovered")
  t.assert_eq(2, reads, "refresh failure was retried")
  TypeScript.get_installation(root)
  t.assert_eq(2, reads, "recovered version is cached")
end)

t:test("metadata cache follows edits, replacement, deletion and recreation", function()
  local root = project()
  install_typescript(root, "7.0.2")
  local filepath = root .. "/node_modules/typescript/package.json"
  t.assert_eq("tsc", TypeScript.resolve(root).server, "initial installation")

  local stat = assert(vim.uv.fs_stat(filepath))
  vim.fn.writefile({ '{"name":"typescript","version":"6.0.3"}' }, filepath)
  assert(vim.uv.fs_utime(filepath, stat.atime.sec, stat.mtime.sec + 1))
  t.assert_eq("vtsls", TypeScript.resolve(root).server, "edited version")

  stat = assert(vim.uv.fs_stat(filepath))
  vim.fn.writefile({ '{"name":"typescript","version":"7.0.2"}' }, filepath .. ".new")
  assert(vim.uv.fs_utime(filepath .. ".new", stat.atime.sec, stat.mtime.sec))
  assert(vim.uv.fs_rename(filepath .. ".new", filepath))
  t.assert_eq("tsc", TypeScript.resolve(root).server, "replacement with equal size and timestamp")

  assert(vim.uv.fs_unlink(filepath))
  t.assert_eq("vtsls", TypeScript.resolve(root).server, "removed package metadata")
  vim.fn.writefile({ '{"name":"typescript","version":"6.0.3"}' }, filepath)
  t.assert_eq("vtsls", TypeScript.resolve(root).server, "recreated legacy package")
end)

t:test("cached versions do not cache root decisions or executable permissions", function()
  local root = project()
  local binpath = install_typescript(root, "7.0.2")
  local nested = root .. "/packages/app"
  vim.fn.mkdir(nested, "p")
  t.assert_eq("tsc", TypeScript.resolve(nested).server, "initial inherited version")
  install_typescript(nested, "6.0.3")
  t.assert_eq("vtsls", TypeScript.resolve(nested).server, "new nearest installation")

  t.assert_eq("tsc", TypeScript.resolve(root).server, "root version")
  assert(vim.uv.fs_chmod(binpath, 420))
  t.assert_eq("vtsls", TypeScript.resolve(root).server, "non-executable entry")
  assert(vim.uv.fs_chmod(binpath, 493))
  vim.fn.writefile({ "{}" }, root .. "/deno.json")
  t.assert_eq("denols", TypeScript.resolve(root).server, "new Deno marker")
end)

t:test("root callbacks share one decision in either order and retry next round", function()
  for _, order in ipairs({ { "tsc", "vtsls" }, { "vtsls", "tsc" } }) do
    local root = project()
    install_typescript(root, "7.0.2")
    local bufnr = vim.api.nvim_create_buf(false, false)
    t:defer(function()
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
    vim.api.nvim_buf_set_name(bufnr, root .. "/main.ts")
    local reads = 0
    local read_json = stl.fs.read_json
    local restore = t:patch_table(stl.fs, "read_json", function(opts)
      reads = reads + 1
      return reads > 1 and read_json(opts) or nil
    end)
    local configs = { tsc = native, vtsls = vtsls }
    for round, expected in ipairs({ "vtsls", "tsc" }) do
      local selected = {}
      for _, name in ipairs(order) do
        configs[name].root_dir(bufnr, function()
          selected[#selected + 1] = name
        end)
      end
      t.assert_eq(1, #selected, "one server per round")
      t.assert_eq(expected, selected[1], "consistent choice after read failure")
      t.assert_eq(round, reads, "one metadata read per round")
    end
    restore()
  end
end)

t:test("an unpaired selection expires before a later activation", function()
  local root = project()
  install_typescript(root, "7.0.2")
  local bufnr = vim.api.nvim_create_buf(false, false)
  t:defer(function()
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)
  vim.api.nvim_buf_set_name(bufnr, root .. "/main.ts")
  local reads = 0
  local read_json = stl.fs.read_json
  t:patch_table(stl.fs, "read_json", function(opts)
    reads = reads + 1
    return reads > 1 and read_json(opts) or nil
  end)
  t.assert_eq("vtsls", TypeScript.select_for_buffer(bufnr, "tsc").server, "temporary fallback")
  local flushed = false
  vim.schedule(function()
    flushed = true
  end)
  t.wait_until(function()
    return flushed
  end, 1000, "selection expiry")
  t.assert_eq("tsc", TypeScript.select_for_buffer(bufnr, "vtsls").server, "fresh later selection")
  t.assert_eq(2, reads, "later activation retries")
end)

t:test("a changed selection detaches only the other TypeScript client from this buffer", function()
  local root = project()
  install_typescript(root, "7.0.2")
  local bufnr = vim.api.nvim_create_buf(false, false)
  t:defer(function()
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)
  vim.api.nvim_buf_set_name(bufnr, root .. "/main.ts")
  t:patch_table(vim.lsp, "get_clients", function(opts)
    t.assert_eq(bufnr, opts.bufnr, "target buffer")
    return { { id = 1, name = "vtsls" }, { id = 2, name = "biome" }, { id = 3, name = "tsc" } }
  end)
  local detached = {}
  t:patch_table(vim.lsp, "buf_detach_client", function(target, client_id)
    t.assert_eq(bufnr, target, "only target buffer is detached")
    detached[#detached + 1] = client_id
  end)
  TypeScript.select_for_buffer(bufnr, "tsc")
  TypeScript.select_for_buffer(bufnr, "vtsls")
  t.assert_eq(1, #detached, "one reconciliation per round")
  t.assert_eq(1, detached[1], "old vtsls client")

  local stat = assert(vim.uv.fs_stat(root .. "/node_modules/typescript/package.json"))
  install_typescript(root, "6.0.3")
  assert(vim.uv.fs_utime(root .. "/node_modules/typescript/package.json", stat.atime.sec, stat.mtime.sec + 1))
  TypeScript.select_for_buffer(bufnr, "tsc")
  t.assert_eq(2, #detached, "one additional reconciliation")
  t.assert_eq(3, detached[2], "old native client")
end)

t:run()
