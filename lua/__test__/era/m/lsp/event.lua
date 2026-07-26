---@diagnostic disable: undefined-global
--- Test for era.m.lsp.event module
--- Run with: nvim -l lua/__test__/era/m/lsp/event.lua

local bootstrap = require("__test__.bootstrap")
local harness = require("__test__.harness")

local t = harness.new("era.m.lsp.event")

bootstrap.with_stl(t, {
  nvim = {
    fn = {
      augroup = function(name)
        return vim.api.nvim_create_augroup(name, { clear = true })
      end,
      bindkeys = require("stl.nvim.fn").bindkeys,
    },
  },
})

local blink_loads = 0 ---@type integer
t:patch_table(package.preload, "blink.cmp", function()
  blink_loads = blink_loads + 1
  return {
    get_lsp_capabilities = function()
      return {}
    end,
  }
end)
t:patch_table(package.loaded, "blink.cmp", nil)

local Event = require("era.m.lsp.event")
local Methods = vim.lsp.protocol.Methods

---@type table<integer, vim.lsp.Client>
local clients = {}
local next_client_id = 100 ---@type integer

t:patch_table(vim.lsp, "get_clients", function(opts)
  opts = opts or {}
  local result = {} ---@type vim.lsp.Client[]
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

local function update_registrations(registrations, ctx, supported)
  local client = clients[ctx.client_id]
  for _, registration in ipairs(registrations) do
    client.methods[registration.method] = supported
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

---@param bufnr                         integer
---@param name                          string
---@param methods                       ?table<string, boolean>
---@return vim.lsp.Client
local function add_client(bufnr, name, methods)
  next_client_id = next_client_id + 1
  local client = {
    id = next_client_id,
    name = name,
    methods = methods or {},
    attached_buffers = { [bufnr] = true },
    server_capabilities = {},
  } ---@type any
  function client:supports_method(method)
    return self.methods[method] == true
  end
  clients[client.id] = client
  return client
end

---@param bufnr                         integer
---@return nil
local function delete_buffer(bufnr)
  for client_id, client in pairs(clients) do
    client.attached_buffers[bufnr] = nil
    if vim.tbl_isempty(client.attached_buffers) then
      clients[client_id] = nil
    end
  end
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
end

---@param bufnr                         integer
---@param mode                          string
---@param lhs                           string
---@return string|nil
local function map_desc(bufnr, mode, lhs)
  for _, keymap in ipairs(vim.api.nvim_buf_get_keymap(bufnr, mode)) do
    if keymap.lhs == lhs then
      return keymap.desc
    end
  end
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

t:test("capabilities: include completion deltas without loading blink", function()
  local capabilities = Event.get_capabilities()
  Event.before_init({ capabilities = capabilities }, {})

  local completion = capabilities.textDocument.completion
  local completion_item = completion.completionItem
  t.assert_true(vim.list_contains(completion_item.resolveSupport.properties, "detail"), "resolve detail")
  t.assert_true(vim.list_contains(completion_item.resolveSupport.properties, "data"), "resolve data")
  t.assert_eq(1, completion_item.insertTextModeSupport.valueSet[1], "insert text mode support")
  t.assert_true(vim.list_contains(completion.completionList.itemDefaults, "commitCharacters"), "item defaults")
  t.assert_eq(1, completion.insertTextMode, "insert text mode")
  t.assert_true(completion_item.snippetSupport, "snippet support")
  t.assert_eq(0, blink_loads, "blink load count")
end)

t:test("keymaps: reconcile dynamic capability changes with bounded writes", function()
  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  local client = add_client(bufnr, "tailwindcss")
  local keymap_sets = 0 ---@type integer
  local keymap_dels = 0 ---@type integer
  local keymap_set = vim.keymap.set
  local keymap_del = vim.keymap.del
  t:patch_table(vim.keymap, "set", function(modes, ...)
    keymap_sets = keymap_sets + (type(modes) == "table" and #modes or 1)
    return keymap_set(modes, ...)
  end)
  t:patch_table(vim.keymap, "del", function(...)
    keymap_dels = keymap_dels + 1
    return keymap_del(...)
  end)

  keymap_sets = 0
  Event.on_attach(client, bufnr)

  t.assert_eq(3, keymap_sets, "initial generic mappings")
  t.assert_eq(0, count_desc(bufnr, "lsp: code action"), "code action before registration")
  t.assert_eq(0, count_desc(bufnr, "lsp: source action"), "source action before registration")

  keymap_sets = 0
  keymap_dels = 0
  local result = vim.lsp.handlers[Methods.client_registerCapability](nil, {
    registrations = { { id = "code-action", method = "textDocument/codeAction" } },
  }, { client_id = client.id })

  t.assert_eq(vim.NIL, result, "register handler result")
  t.assert_eq(10, keymap_sets, "registered mapping writes")
  t.assert_eq(3, keymap_dels, "registered mapping deletes")
  t.assert_eq(6, count_desc(bufnr, "lsp: code action"), "code action after registration")
  t.assert_eq(1, count_desc(bufnr, "lsp: source action"), "source action after registration")

  keymap_sets = 0
  keymap_dels = 0
  vim.lsp.handlers[Methods.client_registerCapability](nil, {
    registrations = { { id = "watcher", method = "workspace/didChangeWatchedFiles" } },
  }, { client_id = client.id })

  t.assert_eq(0, keymap_sets, "irrelevant registration writes")
  t.assert_eq(0, keymap_dels, "irrelevant registration deletes")

  keymap_sets = 0
  keymap_dels = 0
  vim.lsp.handlers[Methods.client_unregisterCapability](nil, {
    unregisterations = { { id = "code-action", method = "textDocument/codeAction" } },
  }, { client_id = client.id })

  t.assert_eq(3, keymap_sets, "unregistered mapping writes")
  t.assert_eq(10, keymap_dels, "unregistered mapping deletes")
  t.assert_eq(0, count_desc(bufnr, "lsp: code action"), "code action after unregistration")
  t.assert_eq(0, count_desc(bufnr, "lsp: source action"), "source action after unregistration")

  delete_buffer(bufnr)
end)

t:test("keymaps: client-specific mappings win and detach restores fallback", function()
  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  local vtsls = add_client(bufnr, "vtsls")
  local tailwind = add_client(bufnr, "tailwindcss")

  Event.on_attach(vtsls, bufnr)
  Event.bindkeys(vtsls, bufnr, {
    {
      modes = { "n" },
      key = "gD",
      callback = function() end,
      desc = "lsp: go to source definition",
    },
    {
      modes = { "n" },
      key = "gR",
      callback = function() end,
      desc = "lsp: find all file references",
    },
  })
  Event.on_attach(tailwind, bufnr)

  t.assert_eq("lsp: go to source definition", map_desc(bufnr, "n", "gD"), "specific mapping priority")
  t.assert_eq("lsp: find all file references", map_desc(bufnr, "n", "gR"), "specific mapping")

  Event.on_detach(vtsls, bufnr)
  vtsls.attached_buffers[bufnr] = nil

  t.assert_eq("lsp: goto declaration", map_desc(bufnr, "n", "gD"), "generic fallback")
  t.assert_nil(map_desc(bufnr, "n", "gR"), "detached specific mapping")

  Event.on_detach(tailwind, bufnr)
  tailwind.attached_buffers[bufnr] = nil

  t.assert_nil(map_desc(bufnr, "n", "K"), "last detach hover")
  t.assert_nil(map_desc(bufnr, "n", "gD"), "last detach declaration")
  t.assert_nil(map_desc(bufnr, "n", "gK"), "last detach signature help")

  delete_buffer(bufnr)
end)

if vim.env.NVIM_LSP_EVENT_BENCHMARK == "1" then
  t:test("benchmark: dynamic capability reconciliation", function()
    local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
    local client = add_client(bufnr, "tailwindcss")
    Event.on_attach(client, bufnr)

    local function register(method)
      vim.lsp.handlers[Methods.client_registerCapability](nil, {
        registrations = { { id = method, method = method } },
      }, { client_id = client.id })
    end

    local function unregister(method)
      vim.lsp.handlers[Methods.client_unregisterCapability](nil, {
        unregisterations = { { id = method, method = method } },
      }, { client_id = client.id })
    end

    local function measure(callback)
      local samples = {} ---@type number[]
      for _ = 1, 20 do
        local started = vim.uv.hrtime()
        for _ = 1, 100 do
          callback()
        end
        samples[#samples + 1] = (vim.uv.hrtime() - started) / 200 / 1000
      end
      table.sort(samples)
      return samples[10], samples[19]
    end

    for _ = 1, 100 do
      register("textDocument/codeAction")
      unregister("textDocument/codeAction")
      register("workspace/didChangeWatchedFiles")
      unregister("workspace/didChangeWatchedFiles")
    end
    collectgarbage("collect")
    local memory_before = collectgarbage("count") ---@type number
    local relevant_median, relevant_p95 = measure(function()
      register("textDocument/codeAction")
      unregister("textDocument/codeAction")
    end)
    local irrelevant_median, irrelevant_p95 = measure(function()
      register("workspace/didChangeWatchedFiles")
      unregister("workspace/didChangeWatchedFiles")
    end)
    collectgarbage("collect")
    local memory_delta = collectgarbage("count") - memory_before ---@type number

    print(
      string.format(
        "BENCH lsp.keymaps relevant median=%.2fus p95=%.2fus irrelevant median=%.2fus p95=%.2fus gc_delta=%.2fKiB",
        relevant_median,
        relevant_p95,
        irrelevant_median,
        irrelevant_p95,
        memory_delta
      )
    )

    t.assert_eq(0, count_desc(bufnr, "lsp: code action"), "benchmark final capability state")
    delete_buffer(bufnr)
  end)
end

t:run()
