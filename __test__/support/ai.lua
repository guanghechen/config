---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.support.ai" ---@type string

-- `era.m.ai.term` over doubles of the globals it reads. An agent job runs no process: it is a terminal channel opened
-- in the buffer current when the job starts.

local bootstrap = require("__test__.support.bootstrap")

---@class __test__.support.ai.ICalls
---@field public starts                 integer Jobs started.
---@field public stops                  integer Jobs stopped; a stop calls the exit handler of its job at once.
---@field public detached               string[] The uuids of the sessions detached from the AI state, in order.
---@field public exits                  table<integer, function> The exit handler of each job.
---@field public bufnrs                 integer[] The buffer of each job started, in order.
---@field public reports                table<"debug"|"info"|"warn"|"error", table[]>
---@field public schedule               __test__.support.bootstrap.ISchedule
---@field public fail                   ?boolean Makes job starts fail while set.

local M = {}

---Loads a fresh `era.m.ai.term` whose jobs `calls` records, with the reports and the scheduled callbacks. When the case
---ends the terminal is hidden and the buffers of its jobs are deleted.
---@param t                             __test__.support.Harness
---@return era.m.ai.term
---@return __test__.support.ai.ICalls calls
function M.term(t)
  local calls = { starts = 0, stops = 0, detached = {}, exits = {}, bufnrs = {} }
  t:patch_global("stl", {
    filetype = { AI_TERMINAL = "ai-terminal" },
    nvim = {
      fn = { bindkeys = function() end },
      win = require("stl.nvim.win"),
      buf = {
        close = function(bufnr)
          if vim.api.nvim_buf_is_valid(bufnr) then
            vim.api.nvim_buf_delete(bufnr, { force = true })
          end
        end,
      },
    },
  })
  calls.reports = bootstrap.with_reporter(t)
  t:patch_global("era", {
    m = {
      ai = {
        state = {
          detach_by_term_uuid = function(uuid)
            calls.detached[#calls.detached + 1] = uuid
          end,
        },
      },
    },
  })
  calls.schedule = bootstrap.with_schedule(t)
  t:patch_table(vim.fn, "jobstart", function(_, opts)
    calls.starts = calls.starts + 1
    local bufnr = vim.api.nvim_get_current_buf()
    calls.bufnrs[#calls.bufnrs + 1] = bufnr
    if calls.fail then
      return 0
    end
    local channel = vim.api.nvim_open_term(bufnr, {})
    calls.exits[channel] = opts.on_exit
    return channel
  end)
  t:patch_table(vim.fn, "jobstop", function(jobid)
    calls.stops = calls.stops + 1
    -- Exercise reentrant exit notification during explicit cleanup.
    calls.exits[jobid](jobid, 0)
    return 1
  end)

  local term = assert(loadfile("lua/era/m/ai/term.lua"))()
  t:defer(function()
    term.hide()
    for _, bufnr in ipairs(calls.bufnrs) do
      if vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_delete(bufnr, { force = true })
      end
    end
  end)
  return term, calls
end

---Opens the session `uuid` of the `claude` agent, which runs `mock-agent` in the working directory.
---@param term                          era.m.ai.term
---@param uuid                          string
---@return era.m.ai.term.IMeta
function M.open(term, uuid)
  return term.open({ uuid = uuid, agent = "claude", cmd = { "mock-agent" }, cwd = vim.fn.getcwd() })
end

return M
