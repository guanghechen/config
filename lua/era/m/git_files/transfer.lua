---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.git_files.transfer" ---@type string

local index = require("era.m.git.index")

---Transfer exactly the displayed files. Rename sources belong to the same transfer;
---copy sources do not. stdin keeps pathspec metacharacters and control bytes literal.
---@param root                          string
---@param scope                         era.view.git_files.Scope Source pane.
---@param entries                       era.view.git_files.IMetadata[]
---@return stl.c.Future
local function transfer(root, scope, entries)
  local paths, seen = {}, {}
  for _, entry in ipairs(entries) do
    local candidates = { entry.path }
    if entry.status:find("R", 1, true) and entry.previous then
      candidates[#candidates + 1] = entry.previous
    end
    for _, path in ipairs(candidates) do
      if not seen[path] then
        seen[path], paths[#paths + 1] = true, path
      end
    end
  end
  if #paths == 0 then
    return stl.c.Future.resolve(false)
  end
  local input = table.concat(paths, "\0") .. "\0"
  return index.run(root, function(resolve, reject)
    stl.async
      .run_future(function()
        local args = { "--literal-pathspecs" }
        if scope == "unstaged" then
          args[#args + 1] = "add"
        else
          assert(scope == "staged", "invalid Git Files transfer scope")
          local head = stl.git.exec
            .exec({ "rev-parse", "--verify", "--quiet", "HEAD^{commit}" }, { cwd = root })
            :await()
          if head.code == 0 then
            vim.list_extend(args, { "reset", "HEAD" })
          elseif head.code == 1 then
            vim.list_extend(args, { "rm", "--cached", "-f" })
          else
            error(head.stderr)
          end
        end
        vim.list_extend(args, { "--pathspec-from-file=-", "--pathspec-file-nul" })
        local result = stl.git.exec.exec(args, { cwd = root, stdin = input }):await()
        if result.code ~= 0 then
          error(result.stderr)
        end
        return true
      end)
      :finally(function(ok, result)
        if ok then
          resolve(result)
        else
          reject(result)
        end
      end)
  end)
end

return transfer
