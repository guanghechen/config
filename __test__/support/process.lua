---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.support.process" ---@type string

-- Child Neovim processes run from the checkout root; their files belong in the case's temporary directory.

local source = assert(vim.uv.fs_realpath(debug.getinfo(1, "S").source:sub(2))) ---@type string
local ROOT = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(source))) ---@type string

---@class __test__.support.process.IPtyOptions
---@field width                         integer
---@field height                        integer
---@field env                           ?table<string, string>

---@class __test__.support.process.Pty
---@field output                        string[]
---@field exit_code                     ?integer

local M = {}

---Runs a Lua script of this checkout in a fresh headless Neovim and returns the completed process.
---@param t                             __test__.support.Harness
---@param script                        string
---@param args                          ?string[]
---@param env                           ?table<string, string>
---@return vim.SystemCompleted
function M.script(t, script, args, env)
  local command = { vim.v.progpath, "--headless", "-u", "NONE", "-i", "NONE", "-n", "-l", ROOT .. "/" .. script }
  local process = vim.system(vim.list_extend(command, args or {}), { cwd = ROOT, text = true, env = env })
  t:defer(function()
    if not process:is_closing() then
      process:kill(15)
      process:wait(1000)
    end
  end)
  return process:wait(10000)
end

---Starts Neovim on a pseudo-terminal, stopped when the case ends if it is still running.
---@param t                             __test__.support.Harness
---@param args                          string[]
---@param options                       __test__.support.process.IPtyOptions
---@return __test__.support.process.Pty
function M.pty(t, args, options)
  local run = { output = {} } ---@type __test__.support.process.Pty
  local job = vim.fn.jobstart(vim.list_extend({ vim.v.progpath }, args), {
    cwd = ROOT,
    pty = true,
    width = options.width,
    height = options.height,
    env = vim.tbl_extend("force", { TERM = "xterm-256color" }, options.env or {}),
    on_stdout = function(_, data)
      run.output[#run.output + 1] = table.concat(data, "\n")
    end,
    on_exit = function(_, code)
      run.exit_code = code
    end,
  })
  t.assert_true(job > 0, "Neovim started on a pseudo-terminal")
  t:defer(function()
    if run.exit_code == nil then
      vim.fn.jobstop(job)
      vim.fn.jobwait({ job }, 1000)
    end
  end)
  return run
end

---Waits for every run to exit and requires each to exit cleanly, showing its terminal output otherwise.
---@param t                             __test__.support.Harness
---@param runs                          __test__.support.process.Pty[]
---@param timeout_ms                    integer
---@return nil
function M.assert_exited(t, runs, timeout_ms)
  local exited = vim.wait(timeout_ms, function()
    for _, run in ipairs(runs) do
      if run.exit_code == nil then
        return false
      end
    end
    return true
  end)
  for _, run in ipairs(runs) do
    local output = table.concat(run.output)
    t.assert_true(exited, "Neovim did not exit:\n" .. output)
    t.assert_eq(0, run.exit_code, output)
  end
end

return M
