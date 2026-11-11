local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")
local lsp = require("__test__.support.lsp")
local t = harness.new()

require("ark.bootstrap").setup()
local reports = bootstrap.with_reporter(t)

---@class era.m.lsp.symbols.test.IServer
---@field client_id                     integer
---@field pending                       fun(err: any, result: any)[]
---@field cancelled                     integer
---@field hold                          boolean
---@field symbols                       table[]

---@param lines                         string[]
---@return integer bufnr
---@return integer winnr
local function new_buffer(lines)
  local name = vim.fs.joinpath(t:tempdir(), "symbols.lua")
  local bufnr = t:buffer(lines, { name = name, listed = true, current = true })
  return bufnr, vim.api.nvim_get_current_win()
end

---@param bufnr                         integer
---@param symbols                       table[]
---@return era.m.lsp.symbols.test.IServer
local function start_server(bufnr, symbols)
  local server = { pending = {}, cancelled = 0, hold = false, symbols = symbols } ---@type era.m.lsp.symbols.test.IServer
  server.client_id = lsp.start(t, bufnr, {
    name = "symbols-test",
    cmd = lsp.server({
      capabilities = { textDocumentSync = 1, documentSymbolProvider = true },
      on_request = function(method, _, respond)
        if method ~= "textDocument/documentSymbol" then
          respond(nil, nil)
        elseif server.hold then
          server.pending[#server.pending + 1] = respond
        else
          vim.schedule(function()
            respond(nil, server.symbols)
          end)
        end
      end,
      on_notify = function(method)
        if method == "$/cancelRequest" then
          server.cancelled = server.cancelled + 1
        end
      end,
    }),
  })
  t.wait_until(function()
    return vim.lsp.buf_is_attached(bufnr, server.client_id)
  end, 5000, "client attached")
  vim.b[bufnr].support_documentSymbol = 1
  return server
end

---@param symbols                       dot.t.ILspSymbol[]|nil
---@return string|nil
local function describe(symbols)
  if symbols == nil then
    return nil
  end
  local out = {} ---@type string[]
  for _, symbol in ipairs(symbols) do
    out[#out + 1] = string.format("%s@%d:%d", symbol.name, symbol.row, symbol.col)
  end
  return table.concat(out, ">")
end

t:test("utf-16 symbol positions map to the byte columns of multibyte lines", function()
  local bufnr, winnr = new_buffer({ "中文 = function()", "end" })
  start_server(bufnr, {
    {
      name = "中文",
      kind = 12,
      range = { start = { line = 0, character = 0 }, ["end"] = { line = 1, character = 3 } },
      children = {
        {
          name = "body",
          kind = 12,
          range = { start = { line = 0, character = 5 }, ["end"] = { line = 0, character = 15 } },
        },
      },
    },
  })
  local Symbols = assert(loadfile("lua/era/m/lsp/symbols.lua"))()
  -- Byte 9 is "f"; utf-16 character 5 begins at the same "f".
  vim.api.nvim_win_set_cursor(winnr, { 1, 9 })

  local delivered = nil ---@type string|nil
  Symbols.request(winnr, function(_, symbols)
    delivered = describe(symbols)
  end)
  t.wait_until(function()
    return delivered ~= nil
  end, 5000, "delivered")
  t.assert_eq("中文@1:1>body@1:10", delivered, "multibyte path")
  t.assert_eq("中文@1:1>body@1:10", describe(Symbols.path(winnr)), "confirmed path")
end)

t:test("a client stopped with a request in flight settles silently and the next request recovers", function()
  local bufnr, winnr = new_buffer({ "local value = 1" })
  local symbols = {
    {
      name = "value",
      kind = 13,
      range = { start = { line = 0, character = 6 }, ["end"] = { line = 0, character = 11 } },
    },
  }
  local server = start_server(bufnr, symbols)
  server.hold = true
  local Symbols = assert(loadfile("lua/era/m/lsp/symbols.lua"))()
  vim.api.nvim_win_set_cursor(winnr, { 1, 7 })
  Symbols.request(winnr, function() end)
  t.wait_until(function()
    return #server.pending == 1
  end, 5000, "request in flight")

  local errors = #reports.error
  assert(vim.lsp.get_client_by_id(server.client_id)):stop(true)
  t.wait_until(function()
    return vim.lsp.get_client_by_id(server.client_id) == nil
  end, 5000, "client stopped")

  start_server(bufnr, symbols)
  local delivered = nil ---@type string|nil
  Symbols.request(winnr, function(_, result)
    delivered = describe(result)
  end)
  t.wait_until(function()
    return delivered ~= nil
  end, 5000, "next request delivered")
  t.assert_eq("value@1:7", delivered, "recovered path")
  t.assert_eq(errors, #reports.error, "no error reported")
end)

t:test("wiping the buffer cancels its in-flight request", function()
  local bufnr, winnr = new_buffer({ "local value = 1" })
  local server = start_server(bufnr, {})
  server.hold = true
  local Symbols = assert(loadfile("lua/era/m/lsp/symbols.lua"))()
  Symbols.request(winnr, function() end)
  t.wait_until(function()
    return #server.pending == 1
  end, 5000, "request in flight")

  local other_bufnr = t:buffer(nil, { listed = true })
  vim.api.nvim_win_set_buf(winnr, other_bufnr)
  vim.api.nvim_buf_delete(bufnr, { force = true })
  t.wait_until(function()
    return server.cancelled == 1
  end, 5000, "cancel sent")
end)

t:run()
