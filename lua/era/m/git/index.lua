---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.git.index" ---@type string

---@class era.m.git.index.ITask
---@field public reject                  fun(err: string): nil
---@field public resolve                 fun(result: any): nil
---@field public run                     fun(resolve: fun(result: any): nil, reject: fun(err: string): nil): nil

---@class era.m.git.index.IQueue
---@field public pending                 era.m.git.index.ITask[]
---@field public running                 boolean

---@class era.m.git.index
local M = {}

--- Git has one mutable index per worktree. Every in-process index mutation for
--- the same repository toplevel must run through this FIFO.
---@type table<string, era.m.git.index.IQueue>
local queues = {}

---@param toplevel                      string
---@param task                          fun(resolve: fun(result: any): nil, reject: fun(err: string): nil): nil
---@return stl.c.Future
function M.run(toplevel, task)
  return stl.c.Future.new(function(resolve, reject)
    local queue = queues[toplevel]
    if not queue then
      queue = { pending = {}, running = false }
      queues[toplevel] = queue
    end

    queue.pending[#queue.pending + 1] = { reject = reject, resolve = resolve, run = task }
    if queue.running then
      return
    end

    ---@return nil
    local function run_next()
      local next_task = table.remove(queue.pending, 1) ---@type era.m.git.index.ITask|nil
      if not next_task then
        queue.running = false
        if queues[toplevel] == queue then
          queues[toplevel] = nil
        end
        return
      end

      queue.running = true
      local settled = false ---@type boolean

      ---@param resolved                  boolean
      ---@param result                    any
      ---@return nil
      local function finish(resolved, result)
        if settled then
          return
        end
        settled = true
        if resolved then
          next_task.resolve(result)
        else
          next_task.reject(tostring(result))
        end
        run_next()
      end

      local ok, err = xpcall(function()
        next_task.run(function(result)
          finish(true, result)
        end, function(result)
          finish(false, result)
        end)
      end, debug.traceback)
      if not ok then
        finish(false, err)
      end
    end

    run_next()
  end)
end

return M
