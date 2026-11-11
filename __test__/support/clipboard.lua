---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.support.clipboard" ---@type string

-- The clipboard backends reach the system clipboard through the processes `vim.system` starts.

local M = {}

---Answers each `vim.system` call until the case ends with a process that has exited with 0 after printing `output`, and
---records each command and its options in order.
---@param t                             __test__.support.Harness
---@param output                        string
---@return string[][] commands
---@return vim.SystemOpts[] options
function M.capture_commands(t, output)
  local commands = {} ---@type string[][]
  local options = {} ---@type vim.SystemOpts[]
  t:patch_table(vim, "system", function(cmd, opts)
    commands[#commands + 1] = cmd
    options[#options + 1] = opts
    return {
      wait = function()
        return { code = 0, signal = 0, stdout = output, stderr = "" }
      end,
    }
  end)
  return commands, options
end

return M
