local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")
local lsp = require("__test__.support.lsp")
require("ark.bootstrap").setup()

local t = harness.new()

---@param message                       string
---@return lsp.Diagnostic
local function diagnostic(message)
  return { range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 5 } }, message = message }
end

-- An in-process server answering pull diagnostics per identifier and recording code action requests.
---@param bufnr                         integer
---@param name                          string
---@param hooks                         table<string, fun(dispatchers: vim.lsp.rpc.Dispatchers, params: table)>
---@return lsp.CodeActionParams[]
local function start_server(bufnr, name, hooks)
  local received = {} ---@type lsp.CodeActionParams[]
  lsp.start(t, bufnr, {
    name = name,
    cmd = lsp.server({
      capabilities = { textDocumentSync = 1, codeActionProvider = true },
      on_request = function(method, params, respond)
        if method == "textDocument/codeAction" then
          received[#received + 1] = params
          respond(nil, {})
        elseif method == "textDocument/diagnostic" then
          respond(nil, { kind = "full", items = { diagnostic(name .. " " .. tostring(params.identifier)) } })
        else
          respond(nil, nil)
        end
      end,
      on_notify = function(method, params, dispatchers)
        if hooks[method] ~= nil then
          hooks[method](dispatchers, params)
        end
      end,
    }),
  })
  return received
end

---@param received                      lsp.CodeActionParams[]
---@return string
local function context_messages(received)
  local messages = vim.tbl_map(function(item)
    return item.message
  end, received[1].context.diagnostics)
  table.sort(messages)
  return table.concat(messages, ",")
end

t:test("code actions send each client its own push and pull diagnostics", function()
  local bufnr = t:buffer({ "local value = 1" }, { name = vim.fn.tempname() .. ".lua", listed = true, current = true })
  local uri = vim.uri_from_bufnr(bufnr) ---@type string
  local pushed = start_server(bufnr, "push", {
    ["textDocument/didOpen"] = function(dispatchers)
      dispatchers.notification("textDocument/publishDiagnostics", { uri = uri, diagnostics = { diagnostic("push") } })
    end,
  })
  -- Pull providers registered at runtime each keep their diagnostics in a namespace of their own.
  local pulled = start_server(bufnr, "pull", {
    ["initialized"] = function(dispatchers)
      local registrations = {} ---@type lsp.Registration[]
      for _, identifier in ipairs({ "lint", "types" }) do
        registrations[#registrations + 1] = {
          id = identifier,
          method = "textDocument/diagnostic",
          registerOptions = { identifier = identifier, interFileDependencies = false, workspaceDiagnostics = false },
        }
      end
      dispatchers.server_request("client/registerCapability", { registrations = registrations })
    end,
  })
  t.wait_until(function()
    return #vim.diagnostic.get(bufnr) == 3
  end, 5000, "pushed and pulled diagnostics")
  bootstrap.with_reporter(t)

  require("era.m.lsp.action").code_action()
  t.wait_until(function()
    return #pushed > 0 and #pulled > 0
  end, 5000, "code action requests")

  t.assert_eq("push", context_messages(pushed), "push client diagnostics")
  t.assert_eq("pull lint,pull types", context_messages(pulled), "pull client diagnostics")
end)

t:run()
