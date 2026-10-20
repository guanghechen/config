local harness = require("__test__.support.harness")
local t = harness.new()

require("ark.bootstrap").setup()
local reports = {} ---@type table[]
t:patch_table(stl.reporter, "error", function(report)
  reports[#reports + 1] = report
end)

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
  local bufnr = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_name(bufnr, vim.fn.tempname() .. ".lua")
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  local winnr = vim.api.nvim_get_current_win()
  local previous_bufnr = vim.api.nvim_win_get_buf(winnr)
  vim.api.nvim_win_set_buf(winnr, bufnr)
  t:defer(function()
    if vim.api.nvim_buf_is_valid(previous_bufnr) then
      vim.api.nvim_win_set_buf(winnr, previous_bufnr)
    end
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  return bufnr, winnr
end

---@param bufnr                         integer
---@param symbols                       table[]
---@return era.m.lsp.symbols.test.IServer
local function start_server(bufnr, symbols)
  local server = { pending = {}, cancelled = 0, hold = false, symbols = symbols } ---@type era.m.lsp.symbols.test.IServer
  local client_id = vim.lsp.start({
    name = "symbols-test",
    cmd = function(dispatchers)
      local stopped = false
      local message_id = 0
      return {
        request = function(method, _, callback)
          -- Unique ids let the client track and cancel each request.
          message_id = message_id + 1
          if method == "initialize" then
            callback(nil, { capabilities = { textDocumentSync = 1, documentSymbolProvider = true } })
          elseif method == "textDocument/documentSymbol" then
            local function answer(err, result)
              callback(err, result)
            end
            if server.hold then
              server.pending[#server.pending + 1] = answer
            else
              vim.schedule(function()
                answer(nil, server.symbols)
              end)
            end
          else
            callback(nil, nil)
          end
          return true, message_id
        end,
        notify = function(method)
          if method == "$/cancelRequest" then
            server.cancelled = server.cancelled + 1
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
    end,
  }, { bufnr = bufnr })
  server.client_id = assert(client_id, "client started")
  t:defer(function()
    local client = vim.lsp.get_client_by_id(server.client_id)
    if client ~= nil then
      client:stop(true)
    end
  end)
  t.assert_true(
    vim.wait(1000, function()
      return vim.lsp.buf_is_attached(bufnr, server.client_id)
    end),
    "client attached"
  )
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
  t.assert_true(
    vim.wait(1000, function()
      return delivered ~= nil
    end),
    "delivered"
  )
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
  t.assert_true(
    vim.wait(1000, function()
      return #server.pending == 1
    end),
    "request in flight"
  )

  local errors = #reports
  assert(vim.lsp.get_client_by_id(server.client_id)):stop(true)
  t.assert_true(
    vim.wait(1000, function()
      return vim.lsp.get_client_by_id(server.client_id) == nil
    end),
    "client stopped"
  )

  start_server(bufnr, symbols)
  local delivered = nil ---@type string|nil
  Symbols.request(winnr, function(_, result)
    delivered = describe(result)
  end)
  t.assert_true(
    vim.wait(1000, function()
      return delivered ~= nil
    end),
    "next request delivered"
  )
  t.assert_eq("value@1:7", delivered, "recovered path")
  t.assert_eq(errors, #reports, "no error reported")
end)

t:test("wiping the buffer cancels its in-flight request", function()
  local bufnr, winnr = new_buffer({ "local value = 1" })
  local server = start_server(bufnr, {})
  server.hold = true
  local Symbols = assert(loadfile("lua/era/m/lsp/symbols.lua"))()
  Symbols.request(winnr, function() end)
  t.assert_true(
    vim.wait(1000, function()
      return #server.pending == 1
    end),
    "request in flight"
  )

  vim.api.nvim_win_set_buf(winnr, vim.api.nvim_create_buf(true, false))
  vim.api.nvim_buf_delete(bufnr, { force = true })
  t.assert_true(
    vim.wait(1000, function()
      return server.cancelled == 1
    end),
    "cancel sent"
  )
end)

t:run()
