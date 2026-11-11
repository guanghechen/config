---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.support.lsp" ---@type string

-- Language servers that run in the test process, and a recorder of the server processes LSP configs would spawn.

---@alias __test__.support.lsp.IRespond fun(err: lsp.ResponseError|nil, result: any): nil

---@class __test__.support.lsp.IServerOptions
---@field capabilities                  ?lsp.ServerCapabilities The answer to `initialize`.
---@field on_request                    ?fun(method: string, params: table, respond: __test__.support.lsp.IRespond, dispatchers: vim.lsp.rpc.Dispatchers): nil
---@field on_notify                     ?fun(method: string, params: table, dispatchers: vim.lsp.rpc.Dispatchers): nil

---@class __test__.support.lsp.IStart
---@field args                          string[]
---@field dispatchers                   vim.lsp.rpc.Dispatchers
---@field cwd                           ?string

local M = {}

---A `cmd` for `vim.lsp.start` or `vim.lsp.config` that serves in this process. `initialize` gets `capabilities` when
---they are given; every other request, and `initialize` without them, goes to `on_request`, which answers it. Without
---`on_request` those requests get a `nil` result. Notifications go to `on_notify`.
---@param options                       __test__.support.lsp.IServerOptions
---@return fun(dispatchers: vim.lsp.rpc.Dispatchers): vim.lsp.rpc.PublicClient
function M.server(options)
  return function(dispatchers)
    local stopped = false ---@type boolean
    local message_id = 0 ---@type integer
    return {
      request = function(method, params, respond)
        -- Unique ids let the client track and cancel each request.
        message_id = message_id + 1
        if method == "initialize" and options.capabilities ~= nil then
          respond(nil, { capabilities = options.capabilities })
        elseif options.on_request ~= nil then
          options.on_request(method, params, respond, dispatchers)
        else
          respond(nil, nil)
        end
        return true, message_id
      end,
      notify = function(method, params)
        if options.on_notify ~= nil then
          options.on_notify(method, params, dispatchers)
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
  end
end

---Starts a client on `bufnr` from `config`, such as one whose `cmd` is `M.server`, stopped when the case ends.
---@param t                             __test__.support.Harness
---@param bufnr                         integer
---@param config                        vim.lsp.ClientConfig
---@return integer
function M.start(t, bufnr, config)
  local client_id = assert(vim.lsp.start(config, { bufnr = bufnr }), "client started")
  t:defer(function()
    local client = vim.lsp.get_client_by_id(client_id)
    if client ~= nil then
      client:stop(true)
    end
  end)
  return client_id
end

---Records each `vim.lsp.rpc.start` until the case ends instead of spawning a server process; each start returns
---`client`, or an empty client.
---@param t                             __test__.support.Harness
---@param client                        ?table
---@return __test__.support.lsp.IStart[]
function M.record_starts(t, client)
  local starts = {} ---@type __test__.support.lsp.IStart[]
  t:patch_table(vim.lsp.rpc, "start", function(args, dispatchers, options)
    starts[#starts + 1] = { args = args, dispatchers = dispatchers, cwd = options and options.cwd }
    return client or {}
  end)
  return starts
end

return M
