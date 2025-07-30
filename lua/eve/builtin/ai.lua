---@class eve.builtin.ai
local M = {}

---@class eve.builtin.ai.IEditInlineConfig
---@field prompt                          string
---@field location                        string
---@field content                         string
---@field tools                           string[]
---@field system_prompt                   string|nil

---@class eve.builtin.ai.IJobCallbacks
---@field on_start                        fun(): nil
---@field on_success                      fun(output: string): nil
---@field on_error                        fun(code: integer, error: string): nil
---@field on_timeout                      fun(): nil
---@field on_complete                     fun(): nil

---@param config                          eve.builtin.ai.IEditInlineConfig
---@param callbacks                       eve.builtin.ai.IJobCallbacks
---@param timeout                         integer
---@return vim.SystemObj|nil
function M.edit_inline(config, callbacks, timeout)
  local cmd = {
    "claude",
    "-p",
    string.format(
      "%s\n\nFile: %s\n\n\nSelected content:\n```\n%s\n```",
      config.prompt,
      config.location,
      config.content
    ),
    "--output-format",
    "text",
    "--allowedTools",
    table.concat(config.tools, ","),
  }

  if config.system_prompt then
    table.insert(cmd, "--append-system-prompt")
    table.insert(cmd, config.system_prompt)
  end

  local process = vim.system(cmd, { text = true }, function(result)
    vim.schedule(function()
      callbacks.on_complete()

      if result.code == 0 then
        local output = result.stdout or ""
        callbacks.on_success(output)
      else
        local error_msg = result.stderr or "Unknown error"
        callbacks.on_error(result.code, error_msg)
      end
    end)
  end)

  if not process then
    return nil
  end

  callbacks.on_start()

  -- Add timeout handling
  if timeout > 0 then
    vim.defer_fn(function()
      if process then
        process:kill(9)
        vim.schedule(function()
          callbacks.on_timeout()
        end)
      end
    end, timeout * 1000)
  end

  return process
end

return M
