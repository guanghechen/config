---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.filetree.jobs" ---@type string

local Future = require("stl.c.future")
local Filetree = require("ux.filetree")
local paths = require("ux.filetree.path")
local buffers = require("era.m.explorer.buffers")
local active = {}
local M = {}

---@param value                         any
---@return any
local function checked(value)
  if type(value) == "table" and value.kind == "Rejected" then
    error(type(value.error) == "table" and value.error.message or tostring(value.error), 0)
  end
  return value
end

---@param error                         any
---@return nil
local function report(error)
  stl.reporter.error({ from = __module_name__, message = tostring(error) })
end

---@param path                          string
---@return stl.c.Future
function M.capture(path)
  return Filetree.open(paths.dirname(path)):map(checked):then_(function(data)
    return data:resolve(path):map(checked):map(function(resource)
      return { data = data, resource = resource }
    end)
  end)
end

---@param data                          ux.filetree.Data
---@param plan                          ux.filetree.IOperationPlan|ux.filetree.ICreatePlan
---@param overwrite                     ?fun(confirmation: table): stl.c.Future
---@return stl.c.Future
function M.run(data, plan, overwrite)
  local future, resolve = Future.new_with_resolver()
  -- Only IOperationPlan carries kind.
  local job = plan.kind and data:start_operation(plan --[[@as ux.filetree.IOperationPlan]])
    or data:start_create(plan --[[@as ux.filetree.ICreatePlan]])
  local work = { job = job, data = data, results = {}, operation = plan.kind or "create", report = report }
  active[job] = work
  ---@param status                      ux.filetree.IJobStatus
  ---@return nil
  local function update(status)
    if not active[job] then
      return
    end
    local confirmation = status.confirmation
    if confirmation and work.confirmation ~= confirmation.token then
      work.confirmation = confirmation.token
      local decision = confirmation.kind == "prepare_move" and buffers.prepare(job, confirmation)
        or overwrite and overwrite(confirmation)
        or Future.resolve(false)
      decision:finally(function(ok, proceed)
        if not ok then
          report(proceed)
        end
        local current = job:status().confirmation
        if current and current.token == confirmation.token then
          local confirmed, error = pcall(job.confirm, job, confirmation.token, ok and proceed == true)
          if not confirmed then
            report(error)
          end
        end
      end)
    end
    local last = math.min(status.results, #work.results + 128)
    if last > #work.results then
      for _, item in ipairs(job:results(#work.results + 1, last)) do
        ---@cast item era.m.explorer.IItemResult
        item.editor_error = buffers.sync(work, item)
        work.results[#work.results + 1] = item
      end
    end
    if #work.results < status.results then
      vim.schedule(function()
        update(job:status())
      end)
      return
    end
    if status.terminal then
      active[job] = nil
      local success = not status.cancelled and not status.error and #work.results > 0
      local failure = status.error and status.error.message
      for _, item in ipairs(work.results) do
        success = success and item.status == "success"
        if item.status == "failed" and not failure then
          failure = item.error and item.error.message or "File operation failed"
        end
      end
      if #work.results > 0 then
        require("era.m.git.state").refresh()
      end
      resolve({ status = status, items = work.results, success = success, error = failure })
    end
  end
  work.update = update
  data:_track_job(job, update)
  return future
end

---@param data                          ux.filetree.Data
---@param target                        yoz.ux.filetree.Resource
---@param path                          string Relative to target; another filesystem root stays absolute.
---@param directory                     boolean
---@return stl.c.Future
function M.create(data, target, path, directory)
  -- Parent components use the captured lineage, never a fresh binding of the same pathname.
  while path == ".." or path:sub(1, 3) == "../" do
    local source = target:source()
    local parent = source:node(target:node()).parent
    if not parent then
      return Future.reject("Creation path is outside the captured filesystem root")
    end
    target = data:inspect(source, parent)
    path = path == ".." and "." or path:sub(4)
  end
  if not yoz.canonical_path.is_absolute(path) then
    return M.run(data, { target = target, path = path, directory = directory })
  end
  -- A different volume is an explicit new target, resolved after the user supplies it.
  local names = { paths.basename(path) }
  ---@param parent                      string
  ---@return stl.c.Future
  local function resolve(parent)
    return data:resolve(parent):then_(function(value)
      if type(value) == "userdata" then
        local parts = {}
        for index = #names, 1, -1 do
          parts[#parts + 1] = names[index]
        end
        return M.run(data, { target = value, path = table.concat(parts, "/"), directory = directory })
      end
      local ancestor = paths.dirname(parent)
      if value.error.code ~= "NotFound" or ancestor == parent then
        return checked(value)
      end
      names[#names + 1] = paths.basename(parent)
      return resolve(ancestor)
    end)
  end
  return resolve(paths.dirname(path))
end

---@param data                          ux.filetree.Data
---@param source                        yoz.ux.filetree.Resource
---@param path                          string
---@param overwrite                     ?fun(confirmation: table): stl.c.Future
---@return stl.c.Future
function M.move(data, source, path, overwrite)
  local parent = paths.dirname(path)
  local missing = {}
  ---@param directory                   string
  ---@return stl.c.Future
  local function target(directory)
    return data:resolve(directory):then_(function(value)
      if type(value) == "userdata" then
        if #missing == 0 then
          return value
        end
        return data:check_transfer_target(source, value):map(checked):then_(function()
          local names = {}
          for index = #missing, 1, -1 do
            names[#names + 1] = missing[index]
          end
          return M.run(data, { target = value, path = table.concat(names, "/"), directory = true })
            :then_(function(result)
              if not result.success then
                error(result.error or "Target directory creation failed", 0)
              end
              return data:resolve(parent):map(checked)
            end)
        end)
      end
      local ancestor = paths.dirname(directory)
      if value.error.code ~= "NotFound" or ancestor == directory then
        return checked(value)
      end
      missing[#missing + 1] = paths.basename(directory)
      return target(ancestor)
    end)
  end
  return target(parent):then_(function(destination)
    return M.run(data, {
      kind = "move",
      source = source:source(),
      nodes = { source:node() },
      target = destination,
      name = paths.basename(path),
      prepare_move = true,
    }, overwrite)
  end)
end

---@return boolean
function M.pending()
  return next(active) ~= nil
end

---@return nil
function M.cancel_all()
  for job in pairs(active) do
    job:cancel()
  end
end

---@return nil
function M.poll()
  for job, work in pairs(active) do
    work.update(job:status())
  end
end

require("era.m.explorer.exit").setup(M)

return M
