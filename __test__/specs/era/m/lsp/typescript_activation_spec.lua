---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.m.lsp.typescript_activation" ---@type string

local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")
local t = harness.new("era.m.lsp.typescript_activation")

bootstrap.with_yoz(t, require("yoz"))
bootstrap.with_stl(t, { env = { PATH_SEP = "/", IS_WIN = false }, fs = require("stl.fs") })
bootstrap.with_era(t, {
  m = {
    lsp = {
      event = {
        get_capabilities = vim.lsp.protocol.make_client_capabilities,
        before_init = function() end,
        on_init = function() end,
        on_attach = function() end,
        bindkeys = function() end,
      },
    },
  },
})

---@return nil
local function flush_scheduled()
  local done = false
  vim.schedule(function()
    done = true
  end)
  t.wait_until(function()
    return done
  end, 1000, "scheduled activation")
end

---@return string
---@return integer
local function setup()
  local root = vim.fn.tempname()
  vim.fn.mkdir(root .. "/node_modules/typescript", "p")
  vim.fn.mkdir(root .. "/node_modules/.bin", "p")
  root = assert(vim.uv.fs_realpath(root))
  t:defer(function()
    vim.fn.delete(root, "rf")
  end)
  vim.fn.writefile({}, root .. "/pnpm-lock.yaml")
  vim.fn.writefile({ '{"name":"typescript","version":"7.0.2"}' }, root .. "/node_modules/typescript/package.json")
  local binpath = root .. "/node_modules/.bin/tsc"
  vim.fn.writefile({ "#!/bin/sh", "exit 0" }, binpath)
  assert(vim.uv.fs_chmod(binpath, 493))

  local native = dofile("lsp/tsc.lua")
  local legacy = dofile("lsp/vtsls.lua")
  legacy.cmd = { binpath, "--stdio" }
  vim.lsp.config("tsc", native)
  vim.lsp.config("vtsls", legacy)
  vim.lsp.enable({ "tsc", "vtsls" })
  t:defer(function()
    for _, client in ipairs(vim.lsp.get_clients({ _uninitialized = true })) do
      client:stop(true)
    end
    vim.lsp.enable({ "tsc", "vtsls" }, false)
    flush_scheduled()
  end)
  flush_scheduled()

  local bufnr = vim.api.nvim_create_buf(false, false)
  t:defer(function()
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)
  vim.api.nvim_buf_set_name(bufnr, root .. "/main.ts")
  return root, bufnr
end

---@return string[]
local function capture_starts()
  local starts = {} ---@type string[]
  t:patch_table(vim.lsp.rpc, "start", function()
    return {}
  end)
  t:patch_table(vim.lsp, "start", function(config)
    starts[#starts + 1] = config.name
    if type(config.cmd) == "function" then
      config.cmd({}, config)
    end
    return nil
  end)
  return starts
end

t:test("one failed read selects vtsls once and the next activation can select tsc", function()
  local starts = capture_starts()
  local _, bufnr = setup()
  local reads = 0
  local read_json = stl.fs.read_json
  t:patch_table(stl.fs, "read_json", function(opts)
    reads = reads + 1
    return reads > 1 and read_json(opts) or nil
  end)

  vim.api.nvim_set_option_value("filetype", "typescript", { buf = bufnr })
  flush_scheduled()
  t.assert_eq(1, #starts, "one startup after failed read")
  t.assert_eq("vtsls", starts[1], "consistent fallback")
  t.assert_eq(1, reads, "one resolution in the first activation")

  vim.api.nvim_exec_autocmds("FileType", { buffer = bufnr })
  flush_scheduled()
  t.assert_eq(2, #starts, "one additional startup after recovery")
  t.assert_eq("tsc", starts[2], "native selection after recovery")
  t.assert_eq(2, reads, "one retry in the second activation")
end)

t:test("native selection and startup do not repeat the metadata stat", function()
  local starts = capture_starts()
  local root, bufnr = setup()
  local stats = 0
  local fs_stat = vim.uv.fs_stat
  t:patch_table(vim.uv, "fs_stat", function(path, ...)
    if path == root .. "/node_modules/typescript/package.json" then
      stats = stats + 1
      if stats == 2 then
        return nil, "EIO"
      end
    end
    return fs_stat(path, ...)
  end)

  vim.api.nvim_set_option_value("filetype", "typescript", { buf = bufnr })
  flush_scheduled()
  t.assert_eq(1, #starts, "one native startup")
  t.assert_eq("tsc", starts[1], "native client")
  t.assert_eq(1, stats, "no second stat in root callbacks or cmd")
end)

for _, expected in ipairs({ "tsc", "vtsls" }) do
  for _, first in ipairs({ "tsc", "vtsls" }) do
    t:test("queued startups keep " .. expected .. " when " .. first .. " initializes first", function()
      local initialize = {} ---@type table<string, fun()>
      local closed = {} ---@type table<string, boolean>
      t:patch_table(vim.lsp.rpc, "start", function(cmd, dispatchers)
        local name = cmd[2] == "--lsp" and "tsc" or "vtsls"
        local stopped = false
        return {
          request = function(method, _, callback)
            if method == "initialize" then
              initialize[name] = function()
                callback(nil, {
                  capabilities = {
                    textDocumentSync = { openClose = true, change = 1 },
                    semanticTokensProvider = {
                      legend = { tokenTypes = { "variable" }, tokenModifiers = {} },
                      full = true,
                    },
                  },
                })
              end
            else
              callback(nil, method == "textDocument/semanticTokens/full" and { data = {} } or nil)
            end
            return true, 1
          end,
          notify = function(method)
            if method == "textDocument/didClose" then
              closed[name] = true
            end
            return true
          end,
          is_closing = function()
            return stopped
          end,
          terminate = function()
            stopped = true
            dispatchers.on_exit(0, 0)
          end,
        }
      end)
      local root, bufnr = setup()
      vim.lsp.semantic_tokens.enable(true, { bufnr = bufnr })
      local reads = 0
      local read_json = stl.fs.read_json
      t:patch_table(stl.fs, "read_json", function(opts)
        reads = reads + 1
        if expected == "tsc" and reads == 1 then
          return nil
        end
        return read_json(opts)
      end)
      vim.api.nvim_set_option_value("filetype", "typescript", { buf = bufnr })
      if expected == "vtsls" then
        local filepath = root .. "/node_modules/typescript/package.json"
        local stat = assert(vim.uv.fs_stat(filepath))
        vim.fn.writefile({ '{"name":"typescript","version":"6.0.3"}' }, filepath)
        assert(vim.uv.fs_utime(filepath, stat.atime.sec, stat.mtime.sec + 1))
      end
      -- Match batched enable(): reactivate before either scheduled startup has run.
      vim.lsp.enable("vtsls")
      flush_scheduled()
      t.assert_eq(2, #vim.lsp.get_clients({ bufnr = bufnr, _uninitialized = true }), "both startups were queued")
      local reads_before_attach = reads
      initialize[first]()
      flush_scheduled()
      initialize[first == "tsc" and "vtsls" or "tsc"]()
      flush_scheduled()

      local clients = vim.lsp.get_clients({ bufnr = bufnr, _uninitialized = true })
      t.assert_eq(1, #clients, "only one client remains attached")
      t.assert_eq(expected, clients[1].name, "latest activation wins")
      t.assert_true(clients[1].initialized, "selected client is initialized")
      t.assert_true(closed[expected == "tsc" and "vtsls" or "tsc"], "stale client received didClose")
      t.assert_eq(reads_before_attach, reads, "attach does not reread metadata")
      local highlighter = vim.lsp._capability.all.semantic_tokens.active[bufnr]
      t.assert_eq(1, vim.tbl_count(highlighter.client_state), "only selected client retains semantic token state")
      t.assert_true(highlighter.client_state[clients[1].id] ~= nil, "selected highlighter remains active")
    end)
  end
end

t:run()
