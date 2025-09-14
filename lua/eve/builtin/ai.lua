---@class eve.builtin.ai
local M = {}

---@class eve.builtin.ai.ISelectedRange
---@field lnum_start                    integer
---@field lnum_end                      integer
---@field col_start                     integer
---@field col_end                       integer

---@class eve.builtin.ai.IEditInlineConfig
---@field prompt                        string
---@field filepath                      string
---@field range                         eve.builtin.ai.ISelectedRange
---@field content                       string
---@field tools                         string[]

---@class eve.builtin.ai.IJobCallbacks
---@field on_start                      fun(): nil
---@field on_stdout                     fun(err: string|nil, data: string|nil): nil
---@field on_stderr                     fun(err: string|nil, data: string|nil): nil
---@field on_success                    fun(output: string): nil
---@field on_error                      fun(code: integer, error: string): nil
---@field on_timeout                    fun(): nil
---@field on_complete                   fun(): nil

---@param config                        eve.builtin.ai.IEditInlineConfig
---@param callbacks                     eve.builtin.ai.IJobCallbacks
---@param timeout                       integer
---@return vim.SystemObj|nil
function M.edit_inline(config, callbacks, timeout)
  local filepath = config.filepath ---@type string
  local range = config.range ---@type eve.builtin.ai.ISelectedRange
  local content = config.content ---@type string
  local prompt = config.prompt ---@type string

  ---@type string
  local query = string.format(
    [[
## Task Details

%s

## Selected Content

Selected text spans from line %d, column %d to line %d, column %d in file %s. The selected content is as follows:

```text title="selected content"
%s
```
]],
    prompt,
    range.lnum_start,
    range.col_start,
    range.lnum_end,
    range.col_end,
    filepath,
    content
  )

  local cmd = {
    "claude",
    "--output-format=stream-json",
    "--verbose",
    "--allowedTools",
    table.concat(config.tools, ","),
    "--append-system-prompt",
    eve.prompt.code_inline,
    "--print",
    vim.trim(query),
  }

  local process = vim.system(cmd, {
    text = true,
    stdout = function(err, data)
      if callbacks.on_stdout then
        vim.schedule(function()
          callbacks.on_stdout(err, data)
        end)
      end
    end,
    stderr = function(err, data)
      if callbacks.on_stderr then
        vim.schedule(function()
          callbacks.on_stderr(err, data)
        end)
      end
    end,
  }, function(result)
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
