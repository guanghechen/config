-- Usage, from the repository root: nvim -l __test__/bench/lsp_event.lua
-- Measures how `era.m.lsp.event` reconciles buffer keymaps when a client registers and unregisters a capability at run
-- time: per handler call, for a method that has LSP keymaps (textDocument/codeAction) and for one that has none
-- (workspace/didChangeWatchedFiles). The client is a double that only tracks its methods, so the time is Event's own
-- work. Each of 20 samples times 100 register/unregister pairs after 100 warm-up pairs of each method; the Lua heap
-- retained across the samples is compared after a full GC on both sides.
---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.lsp_event" ---@type string

local root =
  vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(assert(vim.uv.fs_realpath(debug.getinfo(1, "S").source:sub(2))))))
vim.opt.runtimepath:prepend(root)
package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path
local bootstrap = require("__test__.support.bootstrap")
local Record = require("__test__.bench.lib.record")
local Stats = require("__test__.bench.lib.stats")
local t = require("__test__.support.harness").new()

local SAMPLES, PAIRS, WARMUP = 20, 100, 100
local KEYMAP_METHOD, OTHER_METHOD = "textDocument/codeAction", "workspace/didChangeWatchedFiles"
local Methods = vim.lsp.protocol.Methods

bootstrap.with_global(t, "stl", {
  fn = {
    observe = function()
      return { unsubscribe = function() end }
    end,
  },
  nvim = {
    fn = {
      augroup = function(name)
        return vim.api.nvim_create_augroup(name, { clear = true })
      end,
      bindkeys = require("stl.nvim.fn").bindkeys,
    },
  },
})
bootstrap.with_global(t, "dot", {
  context = {
    lsp = {
      code_lens = {
        snapshot = function()
          return true
        end,
      },
      inlay_hints = {
        snapshot = function()
          return true
        end,
      },
    },
  },
})

local Event = require("era.m.lsp.event")

-- Client doubles by id; registrations change their methods, as Neovim's own handlers do for a real client.
local clients = {} ---@type table<integer, table>
t:patch_table(vim.lsp, "get_clients", function(opts)
  opts = opts or {}
  local result = {} ---@type table[]
  for _, client in pairs(clients) do
    if
      (opts.id == nil or client.id == opts.id)
      and (opts.name == nil or client.name == opts.name)
      and (opts.bufnr == nil or client.attached_buffers[opts.bufnr] ~= nil)
      and (opts.method == nil or client:supports_method(opts.method, opts.bufnr))
    then
      result[#result + 1] = client
    end
  end
  table.sort(result, function(a, b)
    return a.id < b.id
  end)
  return result
end)
t:patch_table(vim.lsp, "get_client_by_id", function(client_id)
  return clients[client_id]
end)

---@param registrations                 { method: string }[]
---@param ctx                           { client_id: integer }
---@param supported                     boolean
---@return vim.NIL
local function update_registrations(registrations, ctx, supported)
  for _, registration in ipairs(registrations) do
    clients[ctx.client_id].methods[registration.method] = supported
  end
  return vim.NIL
end
t:patch_table(vim.lsp.handlers, Methods.client_registerCapability, function(_, params, ctx)
  return update_registrations(params.registrations or {}, ctx, true)
end)
t:patch_table(vim.lsp.handlers, Methods.client_unregisterCapability, function(_, params, ctx)
  return update_registrations(params.unregisterations or {}, ctx, false)
end)
Event.dressing()

---@param client                        table
---@param method                        string
---@return nil
local function register(client, method)
  vim.lsp.handlers[Methods.client_registerCapability](nil, {
    registrations = { { id = method, method = method } },
    ---@diagnostic disable-next-line: missing-fields
  }, { client_id = client.id })
end

---@param client                        table
---@param method                        string
---@return nil
local function unregister(client, method)
  vim.lsp.handlers[Methods.client_unregisterCapability](nil, {
    unregisterations = { { id = method, method = method } },
    ---@diagnostic disable-next-line: missing-fields
  }, { client_id = client.id })
end

---Milliseconds per handler call of each sample of `PAIRS` register/unregister pairs of `method`.
---@param client                        table
---@param method                        string
---@return number[]
local function measure(client, method)
  local samples = {} ---@type number[]
  for _ = 1, SAMPLES do
    local started = vim.uv.hrtime()
    for _ = 1, PAIRS do
      register(client, method)
      unregister(client, method)
    end
    samples[#samples + 1] = (vim.uv.hrtime() - started) / (2 * PAIRS) / 1e6
  end
  return samples
end

---@param bufnr                         integer
---@param desc                          string
---@return integer
local function count_desc(bufnr, desc)
  local count = 0 ---@type integer
  for _, mode in ipairs({ "n", "x", "i", "s" }) do
    for _, keymap in ipairs(vim.api.nvim_buf_get_keymap(bufnr, mode)) do
      if keymap.desc == desc then
        count = count + 1
      end
    end
  end
  return count
end

local results ---@type table

t:test("dynamic capability changes reconcile the LSP keymaps", function()
  local bufnr = t:buffer()
  local client = {
    id = 1,
    name = "tailwindcss",
    methods = {},
    attached_buffers = { [bufnr] = true },
    server_capabilities = {},
  }
  function client:supports_method(method)
    return self.methods[method] == true
  end
  clients[client.id] = client
  t:defer(function()
    clients[client.id] = nil
  end)
  Event.on_attach(client, bufnr)

  for _ = 1, WARMUP do
    register(client, KEYMAP_METHOD)
    unregister(client, KEYMAP_METHOD)
    register(client, OTHER_METHOD)
    unregister(client, OTHER_METHOD)
  end
  collectgarbage("collect")
  local heap = collectgarbage("count") ---@type number
  local keymap_method = measure(client, KEYMAP_METHOD)
  local other_method = measure(client, OTHER_METHOD)
  collectgarbage("collect")
  results = {
    keymap_method_ms = Stats.summary(keymap_method),
    other_method_ms = Stats.summary(other_method),
    retained_heap_bytes = (collectgarbage("count") - heap) * 1024,
  }
  t.assert_eq(0, count_desc(bufnr, "lsp: code action"), "code action keymaps after the last unregistration")
end)

local run = t:run({ exit = false, quiet = true })
assert(run.failed == 0, table.concat(run.failures, "\n"))
io.write(vim.json.encode(results), "\n")
local conditions = {
  samples = SAMPLES,
  pairs_per_sample = PAIRS,
  warmup_pairs = WARMUP,
  keymap_method = KEYMAP_METHOD,
  other_method = OTHER_METHOD,
  unit = "ms per handler call",
  gc = "natural during samples; full GC before and after",
}
io.write("results: ", Record.write("lsp_event", { conditions = conditions, results = results }), "\n")
