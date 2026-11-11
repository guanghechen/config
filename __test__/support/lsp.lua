---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.support.lsp" ---@type string

-- Language servers that run in the test process, a recorder of the server processes LSP configs would spawn, and the
-- projects those configs read.

local fs = require("__test__.support.fs")

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

---A project, removed when the case ends, of `files`: each a path under its root and the one line it holds. Returns the
---root and a buffer named `src/main.ts` under it.
---@param t                             __test__.support.Harness
---@param files                         table<string, string>
---@return string
---@return integer
function M.project(t, files)
  local root = t:tempdir()
  vim.fn.mkdir(root .. "/src", "p")
  for name, content in pairs(files) do
    fs.write(root .. "/" .. name, { content })
  end
  return root, t:buffer(nil, { name = root .. "/src/main.ts", scratch = false })
end

---The root directory `config.root_dir` gives `bufnr`, or nil when it gives none.
---@param config                        vim.lsp.Config
---@param bufnr                         integer
---@return string|nil
function M.root_dir(config, bufnr)
  local root = nil ---@type string|nil
  config.root_dir(bufnr, function(dir)
    root = dir
  end)
  return root
end

---Installs TypeScript `version` in `root`: its package metadata, the `lib/tsserver.js` of a version before 7, and an
---executable `node_modules/.bin/tsc` (`tsc.cmd` when `stl.env.IS_WIN`). Returns the path of that executable.
---@param root                          string
---@param version                       string
---@return string binpath
function M.install_typescript(root, version)
  vim.fn.mkdir(root .. "/node_modules/typescript/lib", "p")
  fs.write(
    root .. "/node_modules/typescript/package.json",
    { vim.json.encode({ name = "typescript", version = version }) }
  )
  if tonumber(version:match("^(%d+)")) < 7 then
    fs.write(root .. "/node_modules/typescript/lib/tsserver.js", {})
  end
  local binpath = root .. "/node_modules/.bin/" .. (stl.env.IS_WIN and "tsc.cmd" or "tsc")
  fs.write(binpath, { "#!/bin/sh", "exit 0" })
  assert(vim.uv.fs_chmod(binpath, 493))
  return binpath
end

return M
