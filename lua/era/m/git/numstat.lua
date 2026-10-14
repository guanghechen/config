---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.git.numstat" ---@type string

local M = {}

---Parse Git's NUL protocol without interpreting tabs or newlines inside paths.
---@param lines                         string[]
---@return table<string, yoz.git.Numstat>
function M.parse(lines)
  local output, stats = table.concat(lines, "\n"), {}
  if not output:find("\0", 1, true) then
    for _, line in ipairs(lines) do
      local added, deleted, previous, path = line:match("^(%d+)\t(%d+)\t([^\t]+)\t(.+)$")
      if not previous then
        added, deleted, path = line:match("^(%d+)\t(%d+)\t(.+)$")
      end
      if added and deleted and path then
        stats[path] = { insertions = tonumber(added), deletions = tonumber(deleted) }
      end
    end
    return stats
  end
  local records, index = vim.split(output, "\0", { plain = true }), 1
  while index <= #records do
    local added, deleted, path = records[index]:match("^([%d-]+)\t([%d-]+)\t(.*)$")
    index = index + 1
    if path == "" then
      path, index = records[index + 1], index + 2
    end
    added, deleted = tonumber(added), tonumber(deleted)
    if added and deleted and path and path ~= "" then
      stats[path] = { insertions = added, deletions = deleted }
    end
  end
  return stats
end

---@param directory                     string
---@return nil
local function cleanup(directory)
  if vim.fn.delete(directory, "rf") == 0 or not vim.uv.fs_stat(directory) then
    return
  end
  vim.defer_fn(function()
    if vim.fn.delete(directory, "rf") ~= 0 and vim.uv.fs_stat(directory) then
      stl.reporter.warn({ from = __module_name__, message = "Unable to remove temporary Git index: " .. directory })
    end
  end, 100)
end

---@param args                          string[]
---@param opts                          stl.git.exec.IExecOpts
---@param token                         ?stl.c.CancellationToken
---@return stl.git.exec.IResult
local function execute(args, opts, token)
  return stl.async.await_all({ stl.git.exec.exec(args, opts, token) })[1]
end

---An alternate intent-to-add index lets Git count all untracked files in one diff.
---Auxiliary failures leave counts unknown; cancellation still rejects the caller's generation.
---@async
---@param cwd                           string
---@param paths                         string[] Repository-relative, literal paths.
---@param token                         ?stl.c.CancellationToken
---@return stl.git.exec.IResult|nil
function M.collect_untracked(cwd, paths, token)
  if #paths == 0 then
    return nil
  end
  if token then
    token:throw_if_cancelled()
  end
  local directory = vim.fn.tempname()
  if vim.fn.mkdir(directory, "p") ~= 1 then
    return nil
  end
  local env = { GIT_INDEX_FILE = directory .. "/index" }
  local ok, result = pcall(function()
    local added = execute({
      "--literal-pathspecs",
      "add",
      "-N",
      "--pathspec-from-file=-",
      "--pathspec-file-nul",
    }, { cwd = cwd, raw = true, env = env, stdin = table.concat(paths, "\0") .. "\0" }, token)
    if token then
      token:throw_if_cancelled()
    end
    if added.code ~= 0 then
      return nil
    end
    local diff = execute({ "diff", "--numstat", "-z", "--" }, { cwd = cwd, raw = true, env = env }, token)
    if token then
      token:throw_if_cancelled()
    end
    return diff.code == 0 and diff or nil
  end)
  cleanup(directory)
  if not ok then
    if token then
      token:throw_if_cancelled()
    end
    error(result, 0)
  end
  return result
end

return M
