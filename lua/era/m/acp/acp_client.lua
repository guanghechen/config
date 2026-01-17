---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.acp.acp_client" ---@type string

---@alias era.m.acp.acp_client.ConnectionState
---| "disconnected"
---| "connecting"
---| "connected"
---| "initializing"
---| "ready"
---| "error"

---@alias era.m.acp.acp_client.StopReason
---| "end_turn"
---| "max_tokens"
---| "max_turn_requests"
---| "refusal"
---| "cancelled"

---@alias era.m.acp.acp_client.ToolKind
---| "read"
---| "edit"
---| "delete"
---| "move"
---| "search"
---| "execute"
---| "think"
---| "fetch"
---| "other"

---@alias era.m.acp.acp_client.ToolCallStatus
---| "pending"
---| "in_progress"
---| "completed"
---| "failed"

----------------------------------------------------------------------------------------------------

---@class era.m.acp.acp_client.ClientCapabilities
---@field public fs                        era.m.acp.acp_client.FileSystemCapability

---@class era.m.acp.acp_client.FileSystemCapability
---@field public readTextFile              boolean
---@field public writeTextFile             boolean

---@class era.m.acp.acp_client.AgentCapabilities
---@field public loadSession               ?boolean
---@field public promptCapabilities        ?era.m.acp.acp_client.PromptCapabilities

---@class era.m.acp.acp_client.PromptCapabilities
---@field public image                     boolean
---@field public audio                     boolean
---@field public embeddedContext           boolean

---@class era.m.acp.acp_client.AuthMethod
---@field public id                        string
---@field public name                      string
---@field public description               ?string

---@class era.m.acp.acp_client.McpServer
---@field public name                      string
---@field public command                   string
---@field public args                      string[]
---@field public env                       era.m.acp.acp_client.EnvVariable[]

---@class era.m.acp.acp_client.EnvVariable
---@field public name                      string
---@field public value                     string

---@class era.m.acp.acp_client.BaseContent
---@field public type                      "text"|"image"|"audio"|"resource_link"|"resource"
---@field public annotations               ?era.m.acp.acp_client.Annotations

---@class era.m.acp.acp_client.TextContent : era.m.acp.acp_client.BaseContent
---@field public type                      "text"
---@field public text                      string

---@class era.m.acp.acp_client.ImageContent : era.m.acp.acp_client.BaseContent
---@field public type                      "image"
---@field public data                      string
---@field public mimeType                  string
---@field public uri                       ?string

---@class era.m.acp.acp_client.AudioContent : era.m.acp.acp_client.BaseContent
---@field public type                      "audio"
---@field public data                      string
---@field public mimeType                  string

---@class era.m.acp.acp_client.ResourceLinkContent : era.m.acp.acp_client.BaseContent
---@field public type                      "resource_link"
---@field public uri                       string
---@field public name                      string
---@field public description               ?string
---@field public mimeType                  ?string
---@field public size                      ?number
---@field public title                     ?string

---@class era.m.acp.acp_client.ResourceContent : era.m.acp.acp_client.BaseContent
---@field public type                      "resource"
---@field public resource                  era.m.acp.acp_client.EmbeddedResource

---@class era.m.acp.acp_client.EmbeddedResource
---@field public uri                       string
---@field public text                      ?string
---@field public blob                      ?string
---@field public mimeType                  ?string

---@class era.m.acp.acp_client.Annotations
---@field public audience                  ?any[]
---@field public lastModified              ?string
---@field public priority                  ?number

---@alias era.m.acp.acp_client.Content era.m.acp.acp_client.TextContent|era.m.acp.acp_client.ImageContent|era.m.acp.acp_client.AudioContent|era.m.acp.acp_client.ResourceLinkContent|era.m.acp.acp_client.ResourceContent

---@class era.m.acp.acp_client.ToolCall
---@field public toolCallId                string
---@field public title                     string
---@field public kind                      era.m.acp.acp_client.ToolKind
---@field public status                    era.m.acp.acp_client.ToolCallStatus
---@field public content                   era.m.acp.acp_client.ToolCallContent[]
---@field public locations                 era.m.acp.acp_client.ToolCallLocation[]
---@field public rawInput                  table
---@field public rawOutput                 table

---@class era.m.acp.acp_client.BaseToolCallContent
---@field public type                      "content"|"diff"

---@class era.m.acp.acp_client.ToolCallRegularContent : era.m.acp.acp_client.BaseToolCallContent
---@field public type                      "content"
---@field public content                   era.m.acp.acp_client.Content

---@class era.m.acp.acp_client.ToolCallDiffContent : era.m.acp.acp_client.BaseToolCallContent
---@field public type                      "diff"
---@field public path                      string
---@field public oldText                   ?string
---@field public newText                   string

---@alias era.m.acp.acp_client.ToolCallContent era.m.acp.acp_client.ToolCallRegularContent|era.m.acp.acp_client.ToolCallDiffContent

---@class era.m.acp.acp_client.ToolCallLocation
---@field public path                      string
---@field public line                      ?number

---@class era.m.acp.acp_client.BaseSessionUpdate
---@field public sessionUpdate             "user_message_chunk"|"agent_message_chunk"|"agent_thought_chunk"|"tool_call"|"tool_call_update"|"plan"|"available_commands_update"

---@class era.m.acp.acp_client.UserMessageChunk : era.m.acp.acp_client.BaseSessionUpdate
---@field public sessionUpdate             "user_message_chunk"
---@field public content                   era.m.acp.acp_client.Content

---@class era.m.acp.acp_client.AgentMessageChunk : era.m.acp.acp_client.BaseSessionUpdate
---@field public sessionUpdate             "agent_message_chunk"
---@field public content                   era.m.acp.acp_client.Content

---@class era.m.acp.acp_client.AgentThoughtChunk : era.m.acp.acp_client.BaseSessionUpdate
---@field public sessionUpdate             "agent_thought_chunk"
---@field public content                   era.m.acp.acp_client.Content

---@class era.m.acp.acp_client.ToolCallUpdate : era.m.acp.acp_client.BaseSessionUpdate
---@field public sessionUpdate             "tool_call"|"tool_call_update"
---@field public toolCallId                string
---@field public title                     ?string
---@field public kind                      ?era.m.acp.acp_client.ToolKind
---@field public status                    ?era.m.acp.acp_client.ToolCallStatus
---@field public content                   ?era.m.acp.acp_client.ToolCallContent[]
---@field public locations                 ?era.m.acp.acp_client.ToolCallLocation[]
---@field public rawInput                  ?table
---@field public rawOutput                 ?table

---@class era.m.acp.acp_client.PlanEntry
---@field public content                   ?string
---@field public priority                  ?era.m.acp.PlanPriority
---@field public status                    ?era.m.acp.PlanStatus

---@class era.m.acp.acp_client.Plan
---@field public entries                   ?era.m.acp.acp_client.PlanEntry[]

---@class era.m.acp.acp_client.PlanUpdate : era.m.acp.acp_client.BaseSessionUpdate
---@field public sessionUpdate             "plan"
---@field public plan                      era.m.acp.acp_client.Plan

---@alias era.m.acp.acp_client.SessionUpdate era.m.acp.acp_client.UserMessageChunk|era.m.acp.acp_client.AgentMessageChunk|era.m.acp.acp_client.AgentThoughtChunk|era.m.acp.acp_client.ToolCallUpdate|era.m.acp.acp_client.PlanUpdate

---@class era.m.acp.acp_client.PermissionOption
---@field public optionId                  string
---@field public name                      string
---@field public kind                      "allow_once"|"allow_always"|"reject_once"|"reject_always"

---@class era.m.acp.acp_client.RequestPermissionOutcome
---@field public outcome                   "cancelled"|"selected"
---@field public optionId                  ?string

---@class era.m.acp.acp_client.Error
---@field public code                      number
---@field public message                   string
---@field public data                      ?any

---@class era.m.acp.acp_client.Handlers
---@field public on_session_update         ?fun(update: era.m.acp.acp_client.SessionUpdate): nil
---@field public on_request_permission     ?fun(tool_call: table, options: table[], callback: fun(option_id: string|nil): nil): nil
---@field public on_read_file              ?fun(path: string, line: integer|nil, limit: integer|nil, callback: fun(content: string), error_callback: fun(message: string, code: integer|nil)): nil
---@field public on_write_file             ?fun(path: string, content: string, callback: fun(error: string|nil)): nil
---@field public on_error                  ?fun(error: table): nil

---@class era.m.acp.acp_client.Config
---@field public command                   string
---@field public args                      ?string[]
---@field public env                       ?table<string, string>
---@field public timeout                   ?number
---@field public handlers                  ?era.m.acp.acp_client.Handlers
---@field public on_state_change           ?fun(new_state: era.m.acp.acp_client.ConnectionState, old_state: era.m.acp.acp_client.ConnectionState): nil

---@class era.m.acp.acp_client.Transport
---@field public send                      fun(self: era.m.acp.acp_client.Transport, data: string): boolean
---@field public start                     fun(self: era.m.acp.acp_client.Transport, on_message: fun(message: table): nil): nil
---@field public stop                      fun(self: era.m.acp.acp_client.Transport): nil
---@field public stdin                     ?uv.uv_pipe_t
---@field public stdout                    ?uv.uv_pipe_t
---@field public process                   ?uv.uv_process_t

----------------------------------------------------------------------------------------------------

---@class era.m.acp.acp_client.ACPClient
---@field public protocol_version          number
---@field public capabilities              era.m.acp.acp_client.ClientCapabilities
---@field public agent_capabilities        ?era.m.acp.acp_client.AgentCapabilities
---@field public config                    era.m.acp.acp_client.Config
---@field public state                     era.m.acp.acp_client.ConnectionState
---@field protected id_counter             integer
---@field protected callbacks              table<number, fun(result: table|nil, err: era.m.acp.acp_client.Error|nil): nil>
---@field protected transport              era.m.acp.acp_client.Transport
---@field protected reconnect_count        integer
---@field protected auth_methods           ?table
local M = {}
M.__index = M

M.ERROR_CODES = {
  -- JSON-RPC 2.0
  PARSE_ERROR = -32700,
  INVALID_REQUEST = -32600,
  METHOD_NOT_FOUND = -32601,
  INVALID_PARAMS = -32602,
  INTERNAL_ERROR = -32603,
  -- ACP
  AUTH_REQUIRED = -32000,
  RESOURCE_NOT_FOUND = -32002,
  PROTOCOL_ERROR = -32001,
  TIMEOUT_ERROR = -32003,
}

---@param config                           era.m.acp.acp_client.Config
---@return era.m.acp.acp_client.ACPClient
function M.new(config)
  local client = setmetatable({
    id_counter = 0,
    protocol_version = 1,
    capabilities = {
      fs = {
        readTextFile = true,
        writeTextFile = true,
      },
    },
    config = config or {},
    state = "disconnected",
    reconnect_count = 0,
    callbacks = {},
  }, M)

  client.transport = client:__create_stdio_transport__()
  return client
end

---@return stl.c.Future                    Resolves with { err: era.m.acp.acp_client.Error|nil }
function M:connect()
  return stl.c.Future.new(function(resolve)
    if self.state ~= "disconnected" then
      resolve({ err = nil })
      return
    end

    self.transport:start(vim.schedule_wrap(function(message)
      self:__handle_message__(message)
    end))

    self:__initialize__(function(err)
      resolve({ err = err })
    end)
  end)
end

---@return nil
function M:stop()
  self.transport:stop()
  self.reconnect_count = 0
end

---@param cwd                              string
---@param mcp_servers                      ?table[]
---@return stl.c.Future                    Resolves with { session_id: string|nil, err: era.m.acp.acp_client.Error|nil }
function M:create_session(cwd, mcp_servers)
  return stl.c.Future.new(function(resolve)
    self:__send_request__("session/new", {
      cwd = cwd,
      mcpServers = mcp_servers or {},
    }, function(result, err)
      if err then
        vim.schedule(function()
          stl.reporter.error({
            group = "acp",
            from = __module_name__,
            subject = "create_session",
            message = "Failed to create session",
            details = { error = err.message },
          })
        end)
        resolve({ session_id = nil, err = err })
        return
      end
      if not result then
        local error = self:__create_error__(M.ERROR_CODES.PROTOCOL_ERROR, "Missing result")
        resolve({ session_id = nil, err = error })
        return
      end
      resolve({ session_id = result.sessionId, err = nil })
    end)
  end)
end

---@param session_id                       string
---@param cwd                              string
---@param mcp_servers                      ?table[]
---@return stl.c.Future                    Resolves with { session_id: string|nil, err: era.m.acp.acp_client.Error|nil }
function M:load_session(session_id, cwd, mcp_servers)
  return stl.c.Future.new(function(resolve)
    if not self.agent_capabilities or not self.agent_capabilities.loadSession then
      local error = self:__create_error__(M.ERROR_CODES.METHOD_NOT_FOUND, "Agent does not support session loading")
      resolve({ session_id = nil, err = error })
      return
    end

    self:__send_request__("session/load", {
      sessionId = session_id,
      cwd = cwd,
      mcpServers = mcp_servers or {},
    }, function(result, err)
      if err then
        vim.schedule(function()
          stl.reporter.error({
            group = "acp",
            from = __module_name__,
            subject = "load_session",
            message = "Failed to load session",
            details = { error = err.message },
          })
        end)
        resolve({ session_id = nil, err = err })
        return
      end
      if not result then
        local error = self:__create_error__(M.ERROR_CODES.PROTOCOL_ERROR, "Missing result")
        resolve({ session_id = nil, err = error })
        return
      end
      resolve({ session_id = result.sessionId, err = nil })
    end)
  end)
end

---@param session_id                       string
---@param prompt                           table[]
---@return stl.c.Future                    Resolves with { result: table|nil, err: era.m.acp.acp_client.Error|nil }
function M:send_prompt(session_id, prompt)
  return stl.c.Future.new(function(resolve)
    local params = {
      sessionId = session_id,
      prompt = prompt,
    }
    self:__send_request__("session/prompt", params, function(result, err)
      resolve({ result = result, err = err })
    end)
  end)
end

---@param session_id                       string
---@return nil
function M:cancel_session(session_id)
  self:__send_notification__("session/cancel", {
    sessionId = session_id,
  })
end

---@param text                             string
---@param annotations                      ?table
---@return table
function M:create_text_content(text, annotations)
  return {
    type = "text",
    text = text,
    annotations = annotations,
  }
end

---@return boolean
function M:is_ready()
  return self.state == "ready"
end

---@return boolean
function M:is_connected()
  return self.state ~= "disconnected" and self.state ~= "error"
end

---@return era.m.acp.acp_client.ConnectionState
function M:get_state()
  return self.state
end

----------------------------------------------------------------------------------------------------

---@param state                            era.m.acp.acp_client.ConnectionState
---@return nil
function M:__set_state__(state)
  local old_state = self.state
  self.state = state

  if self.config.on_state_change then
    self.config.on_state_change(state, old_state)
  end
end

---@param code                             number
---@param message                          string
---@param data                             ?any
---@return era.m.acp.acp_client.Error
function M:__create_error__(code, message, data)
  return {
    code = code,
    message = message,
    data = data,
  }
end

---@return era.m.acp.acp_client.Transport
function M:__create_stdio_transport__()
  ---@type era.m.acp.acp_client.Transport
  local transport = {
    stdin = nil,
    stdout = nil,
    process = nil,
    send = function() return false end, ---@diagnostic disable-line: missing-return
    start = function() end,
    stop = function() end,
  }

  function transport.send(transport_self, data)
    if transport_self.stdin and not transport_self.stdin:is_closing() then
      transport_self.stdin:write(data .. "\n")
      return true
    end
    return false
  end

  function transport.start(transport_self, on_message)
    self:__set_state__("connecting")

    local stdin = vim.uv.new_pipe(false)
    local stdout = vim.uv.new_pipe(false)
    local stderr = vim.uv.new_pipe(false)

    if not stdin or not stdout or not stderr then
      self:__set_state__("error")
      error("Failed to create pipes for ACP agent")
    end

    local args = vim.deepcopy(self.config.args or {})
    local env = self.config.env

    -- If env is not specified, inherit all environment variables from parent process
    -- If env is specified, merge PATH with the provided env variables
    local final_env = nil ---@type string[]|nil
    if env then
      final_env = {}
      local path = vim.fn.getenv("PATH")
      if path then
        final_env[#final_env + 1] = "PATH=" .. path
      end
      for k, v in pairs(env) do
        final_env[#final_env + 1] = k .. "=" .. v
      end
    end

    local handle, _ = vim.uv.spawn(self.config.command,
      { ---@diagnostic disable-line: missing-fields
        args = args,
        env = final_env,
        stdio = { stdin, stdout, stderr },
      }, function(_, _)
      self:__set_state__("disconnected")

      if transport_self.process then
        transport_self.process:close()
        transport_self.process = nil
      end
    end)

    if not handle then
      self:__set_state__("error")
      error("Failed to spawn ACP agent process")
    end

    transport_self.process = handle
    transport_self.stdin = stdin
    transport_self.stdout = stdout

    self:__set_state__("connected")

    local buffer = ""
    stdout:read_start(function(err, data)
      if err then
        vim.schedule(function()
          stl.reporter.error({
            group = "acp",
            from = __module_name__,
            subject = "stdout",
            message = "ACP stdout error",
            details = { error = err },
          })
        end)
        self:__set_state__("error")
        return
      end

      if data then
        buffer = buffer .. data

        local lines = vim.split(buffer, "\n", { plain = true })
        buffer = lines[#lines]

        for i = 1, #lines - 1 do
          local line = vim.trim(lines[i])
          if line ~= "" then
            local ok, message = pcall(vim.json.decode, line)
            if ok then
              on_message(message)
            else
              vim.schedule(function()
                stl.reporter.warn({
                  group = "acp",
                  from = __module_name__,
                  subject = "parse_json",
                  message = "Failed to parse JSON-RPC message",
                  details = { line = line },
                })
              end)
            end
          end
        end
      end
    end)

    stderr:read_start(function() end)
  end

  function transport.stop(transport_self)
    if transport_self.process and not transport_self.process:is_closing() then
      local process = transport_self.process
      transport_self.process = nil

      if not process then
        return
      end

      pcall(function()
        process:kill(15)
      end)
      pcall(function()
        process:kill(9)
      end)
      process:close()
    end
    if transport_self.stdin then
      transport_self.stdin:close()
      transport_self.stdin = nil
    end
    if transport_self.stdout then
      transport_self.stdout:close()
      transport_self.stdout = nil
    end
    self:__set_state__("disconnected")
  end

  return transport
end

---@return number
function M:__next_id__()
  self.id_counter = self.id_counter + 1
  return self.id_counter
end

---@param method                           string
---@param params                           ?table
---@param callback                         fun(result: table|nil, err: era.m.acp.acp_client.Error|nil): nil
---@return nil
function M:__send_request__(method, params, callback)
  local id = self:__next_id__()
  local message = {
    jsonrpc = "2.0",
    id = id,
    method = method,
    params = params or {},
  }

  self.callbacks[id] = callback

  local data = vim.json.encode(message)
  self.transport:send(data)
end

---@param method                           string
---@param params                           ?table
---@return nil
function M:__send_notification__(method, params)
  local message = {
    jsonrpc = "2.0",
    method = method,
    params = params or {},
  }

  local data = vim.json.encode(message)
  self.transport:send(data)
end

---@param id                               number
---@param result                           table|string|vim.NIL|nil
---@return nil
function M:__send_result__(id, result)
  local message = {
    jsonrpc = "2.0",
    id = id,
    result = result,
  }

  local data = vim.json.encode(message)
  self.transport:send(data)
end

---@param id                               number
---@param message                          string
---@param code                             ?number
---@return nil
function M:__send_error__(id, message, code)
  code = code or M.ERROR_CODES.INTERNAL_ERROR
  local msg = {
    jsonrpc = "2.0",
    id = id,
    error = {
      code = code,
      message = message,
    },
  }

  local data = vim.json.encode(msg)
  self.transport:send(data)
end

---@param message                          table
---@return nil
function M:__handle_message__(message)
  if message.method and not message.result and not message.error then
    self:__handle_notification__(message.id, message.method, message.params)
  elseif message.id and (message.result or message.error) then
    local callback = self.callbacks[message.id]
    if callback then
      callback(message.result, message.error)
      self.callbacks[message.id] = nil
    end
  end
end

---@param message_id                       number
---@param method                           string
---@param params                           table
---@return nil
function M:__handle_notification__(message_id, method, params)
  if method == "session/update" then
    self:__handle_session_update__(params)
  elseif method == "session/request_permission" then
    self:__handle_request_permission__(message_id, params)
  elseif method == "fs/read_text_file" then
    self:__handle_read_text_file__(message_id, params)
  elseif method == "fs/write_text_file" then
    self:__handle_write_text_file__(message_id, params)
  end
end

---@param params                           table
---@return nil
function M:__handle_session_update__(params)
  local session_id = params.sessionId
  local update = params.update

  if not session_id or not update then
    return
  end

  if self.config.handlers and self.config.handlers.on_session_update then
    vim.schedule(function()
      self.config.handlers.on_session_update(update)
    end)
  end
end

---@param message_id                       number
---@param params                           table
---@return nil
function M:__handle_request_permission__(message_id, params)
  local session_id = params.sessionId
  local tool_call = params.toolCall
  local options = params.options

  if not session_id or not tool_call then
    return
  end

  if self.config.handlers and self.config.handlers.on_request_permission then
    vim.schedule(function()
      self.config.handlers.on_request_permission(tool_call, options, function(option_id)
        self:__send_result__(message_id, {
          outcome = {
            outcome = "selected",
            optionId = option_id,
          },
        })
      end)
    end)
  end
end

---@param message_id                       number
---@param params                           table
---@return nil
function M:__handle_read_text_file__(message_id, params)
  local session_id = params.sessionId
  local path = params.path

  if not session_id or not path then
    self:__send_error__(message_id, "Invalid fs/read_text_file params", M.ERROR_CODES.INVALID_PARAMS)
    return
  end

  if self.config.handlers and self.config.handlers.on_read_file then
    vim.schedule(function()
      self.config.handlers.on_read_file(
        path,
        params.line ~= vim.NIL and params.line or nil,
        params.limit ~= vim.NIL and params.limit or nil,
        function(content)
          self:__send_result__(message_id, { content = content })
        end,
        function(err, code)
          self:__send_error__(message_id, err or "Failed to read file", code)
        end
      )
    end)
  else
    self:__send_error__(message_id, "fs/read_text_file handler not configured", M.ERROR_CODES.METHOD_NOT_FOUND)
  end
end

---@param message_id                       number
---@param params                           table
---@return nil
function M:__handle_write_text_file__(message_id, params)
  local session_id = params.sessionId
  local path = params.path
  local content = params.content

  if not session_id or not path or not content then
    self:__send_error__(message_id, "Invalid fs/write_text_file params", M.ERROR_CODES.INVALID_PARAMS)
    return
  end

  if self.config.handlers and self.config.handlers.on_write_file then
    vim.schedule(function()
      self.config.handlers.on_write_file(path, content, function(error)
        self:__send_result__(message_id, error == nil and vim.NIL or error)
      end)
    end)
  else
    self:__send_error__(message_id, "fs/write_text_file handler not configured", M.ERROR_CODES.METHOD_NOT_FOUND)
  end
end

---@param callback                         fun(err: era.m.acp.acp_client.Error|nil): nil
---@return nil
function M:__initialize__(callback)
  callback = callback or function() end

  if self.state ~= "connected" then
    local error = self:__create_error__(M.ERROR_CODES.PROTOCOL_ERROR, "Cannot initialize: client not connected")
    callback(error)
    return
  end

  self:__set_state__("initializing")

  self:__send_request__("initialize", {
    protocolVersion = self.protocol_version,
    clientCapabilities = self.capabilities,
  }, function(result, err)
    if err or not result then
      self:__set_state__("error")
      vim.schedule(function()
        stl.reporter.error({
          group = "acp",
          from = __module_name__,
          subject = "initialize",
          message = "Failed to initialize",
          details = { error = err },
        })
      end)
      callback(err or self:__create_error__(M.ERROR_CODES.PROTOCOL_ERROR, "Failed to initialize: missing result"))
      return
    end

    self.protocol_version = result.protocolVersion
    self.agent_capabilities = result.agentCapabilities
    self.auth_methods = result.authMethods or {}

    self:__set_state__("ready")
    callback(nil)
  end)
end

return M
