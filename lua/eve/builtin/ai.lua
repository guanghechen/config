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
---@field system_prompt                 string|nil

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
**You are asking to editing the selected content with the given file and range.** However, since I sometimes may not always accurately select the correct region or the selected range may lack contextual information, you still need to examine the content before and after the selection. But ultimately, you should still try to update only the content within the selection (unless you determine that the user-provided selection is incomplete, such as when a word is truncated).

## Code Principles

1. **Codebase Consistency**
   - Follow Existing Conventions: Analyze target codebase's coding style, naming conventions, and directory structure before implementation
   - Maintain Format Unity: Use consistent indentation, quote styles, line breaks, and spacing patterns
   - Adopt Existing Patterns: Reference existing components/modules implementation approaches to maintain architectural consistency
   - Respect Framework Choices: Use the same libraries, frameworks, and tools already established in the codebase

2. **Concise Design Philosophy**
   - Avoid Over-Engineering: Implement only current requirements without anticipating future needs
   - Minimal Viable Implementation: Choose the simplest effective solution that meets the specification
   - Reduce Abstraction Layers: Avoid premature abstraction unless there's clear reuse requirements
   - Direct Problem Solving: Focus on solving the immediate problem rather than building generic frameworks

3. **Flexibility & Maintainability**
   - Eliminate Hard-Coding: Extract configuration items, constants, and magic numbers into variables or config files
   - Parameterized Design: Control behavior through parameters rather than embedding logic in code
   - Sensible Defaults: Provide reasonable default values while preserving customization capabilities
   - Interface-Driven Development: Design clear interfaces between modules to reduce coupling

4. **Performance Considerations**
   - Cache-Conscious Approach: Prioritize algorithmic optimization over caching mechanisms to avoid management complexity
   - Efficient Data Structures: Select appropriate data structures based on usage patterns and access requirements
   - Computational Efficiency: Minimize redundant calculations through smart algorithm design, not caching
   - Resource Awareness: Consider memory and CPU usage implications of implementation choices

5. **Single Responsibility & Modularity**
   - Clear File Purpose: Each file should focus on a single, well-defined functional domain
   - Logical Module Separation: Group related functionality together while keeping unrelated concerns separate
   - Interface Clarity: Define explicit interfaces between modules to ensure loose coupling
   - Cohesive Functionality: Ensure high cohesion within modules and low coupling between modules

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
    string.format("--allowedTools=%s", table.concat(config.tools, ",")),
    "--print",
    vim.trim(query),
  }

  if config.system_prompt then
    table.insert(cmd, "--append-system-prompt")
    table.insert(cmd, config.system_prompt)
  end

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
