---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.acp.provider.claude" ---@type string

---@class era.m.acp.provider.Claude : era.m.acp.IProvider
---@field public name                   era.m.acp.ProviderName
---@field public config                 era.m.acp.IProviderConfig
---@field protected _current_opts       ?era.m.acp.IRequestOpts
---@field protected _process            ?uv.uv_process_t
---@field protected _stdin              ?uv.uv_pipe_t
---@field protected _stdout             ?uv.uv_pipe_t
---@field protected _stderr             ?uv.uv_pipe_t
local M = {}
M.__index = M

---@param config                        era.m.acp.IProviderConfig
---@return era.m.acp.provider.Claude
function M.new(config)
  local self = setmetatable({}, M)
  self.name = config.name
  self.config = config
  self._current_opts = nil
  self._process = nil
  self._stdin = nil
  self._stdout = nil
  self._stderr = nil
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

  -- Kill any existing process
  self:__kill_process__()

  local stdin = vim.uv.new_pipe(false)
  local stdout = vim.uv.new_pipe(false)
  local stderr = vim.uv.new_pipe(false)

  if not stdin or not stdout or not stderr then
    vim.schedule(function()
      opts.on_error("Failed to create pipes")
    end)
    return stl.fn.noop
  end

  local claude_path = vim.fn.exepath("claude")
  if not claude_path or claude_path == "" then
    vim.schedule(function()
      opts.on_error("claude executable not found in PATH")
    end)
    return stl.fn.noop
  end

  local args = {
    "--print",
    "--output-format", "stream-json",
    "--verbose",
    "--include-partial-messages",
    "--dangerously-skip-permissions",
    user_content,
  }

  -- Don't specify env - inherit all environment variables from parent process
  -- Claude CLI uses OAuth authentication stored in ~/.claude.json

  local handle, _ = vim.uv.spawn(claude_path,
    { ---@diagnostic disable-line: missing-fields
      args = args,
      cwd = cwd,
      stdio = { stdin, stdout, stderr },
    }, function(code, _)
    vim.schedule(function()
      if not cancelled then
        if code == 0 then
          opts.on_done()
        else
          opts.on_error("Claude process exited with code " .. tostring(code))
        end
      end
    end)

    if self._process then
      self._process:close()
      self._process = nil
    end
  end)

  if not handle then
    vim.schedule(function()
      opts.on_error("Failed to spawn claude process")
    end)
    return stl.fn.noop
  end

  self._process = handle
  self._stdin = stdin
  self._stdout = stdout
  self._stderr = stderr

  -- Close stdin immediately since we pass prompt via args
  stdin:close()
  self._stdin = nil

  local buffer = ""
  stdout:read_start(function(err, data)
    if err then
      vim.schedule(function()
        if not cancelled then
          opts.on_error("stdout error: " .. tostring(err))
        end
      end)
      return
    end

    if data then
      buffer = buffer .. data

      local lines = vim.split(buffer, "\n", { plain = true })
      buffer = lines[#lines]

      for i = 1, #lines - 1 do
        local line = vim.trim(lines[i])
        if line ~= "" then
          self:__handle_stream_line__(line)
        end
      end
    end
  end)

  stderr:read_start(function(_, data)
    if data and not cancelled then
      vim.schedule(function()
        stl.reporter.warn({
          group = "acp",
          from = __module_name__,
          subject = "stderr",
          message = "claude stderr",
          details = { data = data },
        })
      end)
    end
  end)

  local unsub = opts.abort:subscribe(stl.c.Subscriber.new({
    on_next = function(val)
      if val then
        cancelled = true
        self:__kill_process__()
      end
    end,
  }), true)

  return function()
    cancelled = true
    unsub:unsubscribe()
    self:__kill_process__()
  end
end

---@return nil
function M:dispose()
  self:__kill_process__()
  self._current_opts = nil
end

----------------------------------------------------------------------------------------------------

---@protected
---@return nil
function M:__kill_process__()
  if self._stdin then
    pcall(function() self._stdin:close() end)
    self._stdin = nil
  end
  if self._stdout then
    pcall(function() self._stdout:close() end)
    self._stdout = nil
  end
  if self._stderr then
    pcall(function() self._stderr:close() end)
    self._stderr = nil
  end
  if self._process and not self._process:is_closing() then
    pcall(function() self._process:kill(15) end)
    pcall(function() self._process:close() end)
    self._process = nil
  end
end

---@protected
---@param line                          string
---@return nil
function M:__handle_stream_line__(line)
  local opts = self._current_opts
  if not opts then
    return
  end

  local ok, msg = pcall(vim.json.decode, line)
  if not ok then
    return
  end

  -- Claude Code stream-json format (with --include-partial-messages):
  -- {"type":"system","subtype":"init",...}
  -- {"type":"stream_event","event":{"type":"content_block_start",...}}
  -- {"type":"stream_event","event":{"type":"content_block_delta","delta":{"type":"text_delta","text":"..."}}}
  -- {"type":"stream_event","event":{"type":"content_block_stop",...}}
  -- {"type":"assistant","message":{...}}
  -- {"type":"result","subtype":"success",...}

  vim.schedule(function()
    -- Handle stream_event wrapper
    if msg.type == "stream_event" and msg.event then
      local event = msg.event
      if event.type == "content_block_delta" then
        local delta = event.delta
        if delta and delta.type == "text_delta" and delta.text then
          opts.on_chunk({
            type = "text",
            content = delta.text,
          })
        elseif delta and delta.type == "thinking_delta" and delta.thinking then
          opts.on_chunk({
            type = "thinking",
            content = delta.thinking,
          })
        elseif delta and delta.type == "input_json_delta" and delta.partial_json then
          opts.on_chunk({
            type = "tool_use_delta",
            tool_call_id = tostring(event.index or 0),
            tool_arguments_delta = delta.partial_json,
          })
        end
      elseif event.type == "content_block_start" then
        local block = event.content_block
        if block and block.type == "tool_use" then
          opts.on_chunk({
            type = "tool_use_start",
            tool_call_id = block.id or tostring(event.index),
            tool_name = block.name or "unknown",
          })
        elseif block and block.type == "thinking" then
          opts.on_chunk({
            type = "thinking_start",
          })
        end
      elseif event.type == "content_block_stop" then
        -- Content block finished
      end
    elseif msg.type == "result" then
      if msg.subtype == "error" then
        opts.on_error(msg.error or "Unknown error")
      end
    end
  end)
end

return M
