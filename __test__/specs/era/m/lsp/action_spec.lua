--- Run with: nvim -l __test__/run.lua __test__/specs/era/m/lsp/action_spec.lua
---@diagnostic disable: undefined-global

local harness = require("__test__.support.harness")
require("ark.bootstrap").setup()

local t = harness.new("era.m.lsp.action")

---@param lines                         string[]
---@return integer
local function new_buffer(lines)
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local previous_bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local bufnr = vim.api.nvim_create_buf(true, false) ---@type integer
  vim.api.nvim_buf_set_name(bufnr, vim.fn.tempname() .. ".lua")
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_win_set_buf(winnr, bufnr)
  t:defer(function()
    if vim.api.nvim_buf_is_valid(previous_bufnr) then
      vim.api.nvim_win_set_buf(winnr, previous_bufnr)
    end
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  return bufnr
end

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
  local client_id = vim.lsp.start({
    name = name,
    cmd = function(dispatchers)
      local stopped = false
      local message_id = 0
      return {
        request = function(method, params, callback)
          message_id = message_id + 1
          if method == "initialize" then
            callback(nil, { capabilities = { textDocumentSync = 1, codeActionProvider = true } })
          elseif method == "textDocument/codeAction" then
            received[#received + 1] = params
            callback(nil, {})
          elseif method == "textDocument/diagnostic" then
            callback(nil, { kind = "full", items = { diagnostic(name .. " " .. tostring(params.identifier)) } })
          else
            callback(nil, nil)
          end
          return true, message_id
        end,
        notify = function(method, params)
          if hooks[method] ~= nil then
            hooks[method](dispatchers, params)
          end
          return true
        end,
        is_closing = function()
          return stopped
        end,
        terminate = function()
          stopped = true
        end,
      }
    end,
  }, { bufnr = bufnr })
  t:defer(function()
    local client = client_id and vim.lsp.get_client_by_id(client_id)
    if client ~= nil then
      client:stop(true)
    end
  end)
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
  local bufnr = new_buffer({ "local value = 1" })
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
  end, 3000, "pushed and pulled diagnostics")
  t:patch_table(stl.reporter, "info", function() end)

  require("era.m.lsp.action").code_action()
  t.wait_until(function()
    return #pushed > 0 and #pulled > 0
  end, 3000, "code action requests")

  t.assert_eq("push", context_messages(pushed), "push client diagnostics")
  t.assert_eq("pull lint,pull types", context_messages(pulled), "pull client diagnostics")
end)

t:run()
