---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.acp.provider.gemini" ---@type string

local S = era.m.acp

---@class era.m.acp.provider.Gemini : era.m.acp.IProvider
---@field public name                   era.m.acp.ProviderName
---@field public config                 era.m.acp.IProviderConfig
---@field protected _client             ?era.m.acp.acp_client.ACPClient
---@field protected _session_id         ?string
---@field protected _current_tool_calls table<string, era.m.acp.acp_client.ToolCall>
---@field protected _current_opts       ?era.m.acp.IRequestOpts
local M = {}
M.__index = M

---@param config                        era.m.acp.IProviderConfig
---@return era.m.acp.provider.Gemini
function M.new(config)
  local self = setmetatable({}, M)
  self.name = config.name
  self.config = config
  self._client = nil
  self._session_id = nil
  self._current_tool_calls = {}
  self._current_opts = nil
  return self
end

---@param opts                          era.m.acp.IRequestOpts
---@return fun(): nil                   cancel
function M:send(opts)
  self._current_opts = opts
  local cwd = opts.cwd or vim.uv.cwd() or "."
  local cancelled = false

  local user_content = nil
  for i = #opts.messages, 1, -1 do
    local msg = opts.messages[i]
    if msg.role == "user" then
      user_content = msg.content
      break
    end
  end

  if not user_content then
    vim.schedule(function()
      opts.on_error("No user message to send")
    end)
    return stl.fn.noop
  end

  local function do_send()
    if cancelled then
      return
    end

    local prompt = { self._client:create_text_content(user_content) }

    self._client:send_prompt(self._session_id, prompt):finally(function(ok, result)
      if cancelled then
        return
      end

      if not ok or result.err then
        vim.schedule(function()
          opts.on_error((result.err and result.err.message) or "ACP prompt failed")
        end)
        return
      end

      vim.schedule(function()
        opts.on_done()
      end)
    end)
  end

  if self._client and self._client:is_ready() and self._session_id then
    do_send()
  else
    self:__ensure_client__(cwd, opts, function(success)
      if success and not cancelled then
        do_send()
      end
    end)
  end

  local unsub = opts.abort:subscribe(stl.c.Subscriber.new({
    on_next = function(val)
      if val then
        cancelled = true
        if self._client and self._session_id then
          self._client:cancel_session(self._session_id)
        end
      end
    end,
  }), true)

  return function()
    cancelled = true
    unsub:unsubscribe()
    if self._client and self._session_id then
      self._client:cancel_session(self._session_id)
    end
  end
end

---@return nil
function M:dispose()
  if self._client then
    self._client:stop()
    self._client = nil
  end
  self._session_id = nil
  self._current_tool_calls = {}
  self._current_opts = nil
end

----------------------------------------------------------------------------------------------------

---@protected
---@param cwd                           string
---@param opts                          era.m.acp.IRequestOpts
---@param callback                      fun(success: boolean): nil
---@return nil
function M:__ensure_client__(cwd, opts, callback)
  if self._client and self._client:is_ready() then
    if self._session_id then
      callback(true)
      return
    end

    -- Try to load existing session if available
    local session = opts.session
    if session and session.last_session_id then
      self._client:load_session(session.last_session_id, cwd, nil):finally(function(ok, result)
        if ok and not result.err and result.session_id then
          self._session_id = result.session_id
          callback(true)
          return
        end
        -- If load failed, fall back to creating new session
        self._client:create_session(cwd, nil):finally(function(create_ok, create_result)
          if not create_ok or create_result.err or not create_result.session_id then
            vim.schedule(function()
              opts.on_error("Failed to create ACP session: " .. ((create_result.err and create_result.err.message) or "unknown"))
            end)
            callback(false)
            return
          end
          self._session_id = create_result.session_id
          session.last_session_id = create_result.session_id
          callback(true)
        end)
      end)
      return
    end

    -- No existing session to load, create new one
    self._client:create_session(cwd, nil):finally(function(ok, result)
      if not ok or result.err or not result.session_id then
        vim.schedule(function()
          opts.on_error("Failed to create ACP session: " .. ((result.err and result.err.message) or "unknown"))
        end)
        callback(false)
        return
      end
      self._session_id = result.session_id
      if session then
        session.last_session_id = result.session_id
      end
      callback(true)
    end)
    return
  end

  local client_config = {
    command = "gemini",
    args = { "--experimental-acp" },
    -- Don't specify env - inherit all environment variables from parent process
    handlers = {
      on_session_update = function(update)
        self:__handle_session_update__(update)
      end,
      on_request_permission = function(tool_call, options, respond_callback)
        self:__handle_request_permission__(tool_call, options, respond_callback)
      end,
      on_read_file = function(path, line, limit, success_callback, error_callback)
        self:__handle_read_file__(path, line, limit, success_callback, error_callback)
      end,
      on_write_file = function(path, content, done_callback)
        self:__handle_write_file__(path, content, done_callback)
      end,
    },
    on_state_change = function(new_state, old_state)
      if new_state == "error" then
        vim.schedule(function()
          stl.reporter.error({
            group = "acp",
            from = __module_name__,
            subject = "state_change",
            message = "ACP client error",
            details = { old_state = old_state, new_state = new_state },
          })
        end)
      end
    end,
  }

  self._client = S.acp_client.new(client_config)
  self._current_tool_calls = {}

  self._client:connect():finally(function(ok, result)
    if not ok or result.err then
      vim.schedule(function()
        opts.on_error("Failed to connect ACP client: " .. ((result.err and result.err.message) or "unknown"))
      end)
      callback(false)
      return
    end

    -- Try to load existing session if available
    local session = opts.session
    if session and session.last_session_id then
      self._client:load_session(session.last_session_id, cwd, nil):finally(function(load_ok, load_result)
        if load_ok and not load_result.err and load_result.session_id then
          self._session_id = load_result.session_id
          callback(true)
          return
        end
        -- If load failed, fall back to creating new session
        self._client:create_session(cwd, nil):finally(function(create_ok, create_result)
          if not create_ok or create_result.err or not create_result.session_id then
            vim.schedule(function()
              opts.on_error("Failed to create ACP session: " .. ((create_result.err and create_result.err.message) or "unknown"))
            end)
            callback(false)
            return
          end
          self._session_id = create_result.session_id
          session.last_session_id = create_result.session_id
          callback(true)
        end)
      end)
      return
    end

    -- No existing session to load, create new one
    self._client:create_session(cwd, nil):finally(function(create_ok, create_result)
      if not create_ok or create_result.err or not create_result.session_id then
        vim.schedule(function()
          opts.on_error("Failed to create ACP session: " .. ((create_result.err and create_result.err.message) or "unknown"))
        end)
        callback(false)
        return
      end
      self._session_id = create_result.session_id
      if session then
        session.last_session_id = create_result.session_id
      end
      callback(true)
    end)
  end)
end

---@protected
---@param update                        era.m.acp.acp_client.SessionUpdate
---@return nil
function M:__handle_session_update__(update)
  local opts = self._current_opts
  if not opts then
    return
  end

  if update.sessionUpdate == "agent_message_chunk" then
    local content = update.content
    if content and content.type == "text" and content.text then
      opts.on_chunk({
        type = "text",
        content = content.text,
      })
    end
  elseif update.sessionUpdate == "agent_thought_chunk" then
    local content = update.content
    if content and content.type == "text" and content.text then
      opts.on_chunk({
        type = "thinking",
        content = content.text,
      })
    end
  elseif update.sessionUpdate == "tool_call" then
    local tool_call_id = update.toolCallId
    local title = update.title or "Unknown Tool"
    local kind = update.kind or "other"

    self._current_tool_calls[tool_call_id] = {
      toolCallId = tool_call_id,
      title = title,
      kind = kind,
      status = "pending",
      content = update.content or {},
      locations = update.locations or {},
      rawInput = update.rawInput or {},
      rawOutput = {},
    }

    opts.on_chunk({
      type = "tool_use_start",
      tool_call_id = tool_call_id,
      tool_name = title,
    })

    if update.rawInput then
      opts.on_chunk({
        type = "tool_use_delta",
        tool_call_id = tool_call_id,
        tool_arguments_delta = vim.json.encode(update.rawInput),
      })
    end
  elseif update.sessionUpdate == "tool_call_update" then
    local tool_call_id = update.toolCallId
    local existing = self._current_tool_calls[tool_call_id]

    if existing then
      if update.status then
        existing.status = update.status
      end
      if update.rawOutput then
        existing.rawOutput = update.rawOutput
      end

      if update.status == "completed" or update.status == "failed" then
        opts.on_chunk({
          type = "tool_use_end",
          tool_call_id = tool_call_id,
        })
      end
    end
  end
end

---@protected
---@param tool_call                     table
---@param options                       table[]
---@param respond_callback              fun(option_id: string|nil): nil
---@return nil
function M:__handle_request_permission__(tool_call, options, respond_callback)
  local opts = self._current_opts
  local session = opts and opts.session
  if session and session.auto_approve_all then
    for _, option in ipairs(options) do
      if option.kind == "allow_once" or option.kind == "allow_always" then
        respond_callback(option.optionId)
        return
      end
    end
  end

  S.confirm.show({
    tool_call = tool_call,
    options = options,
    callback = function(option_id)
      if option_id and session then
        for _, option in ipairs(options) do
          if option.optionId == option_id and option.kind == "allow_always" then
            session.auto_approve_all = true
            break
          end
        end
      end
      respond_callback(option_id)
    end,
  })
end

---@protected
---@param path                          string
---@param line                          ?integer
---@param limit                         ?integer
---@param success_callback              fun(content: string): nil
---@param error_callback                fun(message: string, code: integer|nil): nil
---@return nil
function M:__handle_read_file__(path, line, limit, success_callback, error_callback)
  local ok, content = pcall(function()
    local lines = vim.fn.readfile(path)
    if line and line > 0 then
      local start_line = line
      local end_line = limit and (line + limit - 1) or #lines
      lines = vim.list_slice(lines, start_line, end_line)
    end
    return table.concat(lines, "\n")
  end)

  if ok then
    success_callback(content)
  else
    error_callback("Failed to read file: " .. tostring(content), -32002)
  end
end

---@protected
---@param path                          string
---@param content                       string
---@param done_callback                 fun(error: string|nil): nil
---@return nil
function M:__handle_write_file__(path, content, done_callback)
  local ok, err = pcall(function()
    local lines = vim.split(content, "\n", { plain = true })
    vim.fn.writefile(lines, path)
  end)

  if ok then
    done_callback(nil)
  else
    done_callback("Failed to write file: " .. tostring(err))
  end
end

return M
