---@class stl.git.IGitInfo
---@field public branch                 ?string
---@field public commit                 ?string

---@class stl.git.IRepoInfo
---@field public abbrev_head            string
---@field public detached               boolean
---@field public gitdir                 string
---@field public toplevel               string

---@class stl.git.IBlobResult
---@field public bytes                  ?string
---@field public err                    ?string
---@field public missing                boolean
---@field public ok                     boolean

---@class stl.git.IObjectNameResult
---@field public err                    ?string
---@field public missing                boolean
---@field public object_name            ?string
---@field public ok                     boolean

---@class stl.git.IFileInfoResult
---@field public err                    ?string
---@field public info                   ?stl.git.IFileInfo
---@field public missing                boolean
---@field public ok                     boolean

---@class stl.git.IFileModeResult
---@field public err                    ?string
---@field public missing                boolean
---@field public mode_bits              ?string
---@field public ok                     boolean

---@class stl.git.info
local M = {}

----------------------------------------------------------------------------------------------------
-- Private (file reading helpers)
----------------------------------------------------------------------------------------------------

---@param path                          string
---@return string|nil
local function read_all(path)
  local f = io.open(path, "r")
  if not f then
    return nil
  end
  local content = f:read("*a") ---@type string
  f:close()
  return content
end

---@param path                          string
---@return string|nil
local function read_first_line(path)
  local f = io.open(path, "r")
  if not f then
    return nil
  end
  local line = f:read("*l") ---@type string|nil
  f:close()
  return line
end

----------------------------------------------------------------------------------------------------
-- Public (sync methods - file reading)
----------------------------------------------------------------------------------------------------

---Read HEAD reference
---@param repo                          string
---@return string|nil
function M.head(repo)
  return read_first_line(repo .. "/.git/HEAD")
end

---Read git ref (heads, remotes, tags)
---@param repo                          string
---@param ...                           string
---@return string|nil
function M.ref(repo, ...)
  local ref = table.concat({ ... }, "/") ---@type string
  return read_first_line(repo .. "/.git/refs/" .. ref) or M.packed_ref(repo, ref)
end

---Read from packed-refs file
---@param repo                          string
---@param ref                           string
---@return string|nil
function M.packed_ref(repo, ref)
  local content = read_all(repo .. "/.git/packed-refs")
  if not content then
    return nil
  end

  for line in content:gmatch("[^\n]+") do
    local commit, name = line:match("^(%x+) refs/(.*)$")
    if name == ref then
      return commit
    end
  end
  return nil
end

---Get current git info (branch and commit)
---@param repo                          string
---@return stl.git.IGitInfo|nil
function M.info(repo)
  local line = M.head(repo)
  if not line then
    return nil
  end

  local ref, branch = line:match("ref: refs/(heads/(.*))")
  if ref then
    return {
      branch = branch,
      commit = M.ref(repo, ref),
    }
  else
    return { commit = line }
  end
end

---Get commit for specific branch
---@param repo                          string
---@param branch                        string
---@param origin                        ?boolean
---@return string|nil
function M.get_commit(repo, branch, origin)
  if origin then
    return M.ref(repo, "remotes/origin", branch) or M.ref(repo, "heads", branch)
  else
    return M.ref(repo, "heads", branch)
  end
end

---Get current branch name
---@param repo                          string
---@return string|nil
function M.get_branch(repo)
  local line = M.head(repo)
  if line then
    return line:match("ref: refs/heads/(.*)")
  end
  return nil
end

---Get origin URL from git config
---@param repo                          string
---@return string|nil
function M.get_origin(repo)
  local content = read_all(repo .. "/.git/config")
  if not content then
    return nil
  end

  local in_origin = false ---@type boolean
  for line in content:gmatch("[^\n]+") do
    if line:match('^%s*%[remote "origin"%]') then
      in_origin = true
    elseif line:match("^%s*%[") then
      in_origin = false
    elseif in_origin then
      local url = line:match("^%s*url%s*=%s*(.+)%s*$")
      if url then
        return url
      end
    end
  end
  return nil
end

---Compare two git info objects (by first 7 chars of commit)
---@param a                             stl.git.IGitInfo
---@param b                             stl.git.IGitInfo
---@return boolean
function M.eq(a, b)
  local ra = a.commit and a.commit:sub(1, 7) ---@type string|nil
  local rb = b.commit and b.commit:sub(1, 7) ---@type string|nil
  return ra == rb
end

----------------------------------------------------------------------------------------------------
-- Private (async process helpers)
----------------------------------------------------------------------------------------------------

---@param cwd                           string
---@param token                         ?stl.c.CancellationToken
---@param callback                      fun(abbrev_head: string): nil
---@return vim.SystemObj
local function start_short_head(cwd, token, callback)
  return vim.system({ "git", "-C", cwd, "rev-parse", "--short", "HEAD" }, { text = true }, function(obj)
    vim.schedule(function()
      if token and token:is_cancelled() then
        return
      end
      callback(obj.code == 0 and vim.trim(obj.stdout or "") or "")
    end)
  end)
end

----------------------------------------------------------------------------------------------------
-- Public (async methods - Future version)
----------------------------------------------------------------------------------------------------

---@param message                       string
---@param obj                           vim.SystemCompleted
---@return string
local function git_error(message, obj)
  local stderr = vim.trim(obj.stderr or "") ---@type string
  if stderr ~= "" then
    return message .. ": " .. stderr
  end
  return string.format("%s (exit %s)", message, tostring(obj.code))
end

---@param cwd                           string
---@param object                        string
---@param token                         ?stl.c.CancellationToken
---@return stl.c.Future                 Resolves with stl.git.IObjectNameResult
function M.get_object_name(cwd, object, token)
  return stl.c.Future.new(function(resolve)
    local finished = false ---@type boolean
    local proc = nil ---@type vim.SystemObj|nil
    local cancel_sub = nil ---@type stl.c.IUnsubscribable|nil

    ---@param result                    stl.git.IObjectNameResult
    local function finish(result)
      if finished then
        return
      end
      finished = true
      if cancel_sub then
        cancel_sub:unsubscribe()
      end
      resolve(result)
    end

    local function cancelled()
      return token ~= nil and token:is_cancelled()
    end

    if cancelled() then
      finish({ ok = false, missing = false, err = "Operation cancelled" })
      return
    end

    proc = vim.system({ "git", "-C", cwd, "rev-parse", "--verify", "--quiet", object }, { text = true }, function(obj)
      vim.schedule(function()
        if finished then
          return
        end
        if obj.code == 1 then
          finish({ ok = false, missing = true, err = "Git object does not exist: " .. object })
          return
        end
        if obj.code ~= 0 then
          finish({
            ok = false,
            missing = false,
            err = git_error("Failed to resolve Git object " .. object, obj),
          })
          return
        end

        local object_name = vim.trim(obj.stdout or "") ---@type string
        if object_name == "" then
          finish({ ok = false, missing = false, err = "Git returned an empty object name: " .. object })
          return
        end
        finish({ ok = true, missing = false, object_name = object_name })
      end)
    end)

    if token then
      cancel_sub = token:on_cancel(function()
        if proc then
          proc:kill(9)
        end
        finish({ ok = false, missing = false, err = "Operation cancelled" })
      end)
    end
  end)
end

---@param cwd                           string
---@param object                        string
---@param token                         ?stl.c.CancellationToken
---@return stl.c.Future                 Resolves with stl.git.IBlobResult
function M.get_show_blob(cwd, object, token)
  return stl.c.Future.new(function(resolve)
    local finished = false ---@type boolean
    local proc = nil ---@type vim.SystemObj|nil
    local cancel_sub = nil ---@type stl.c.IUnsubscribable|nil

    ---@param result                    stl.git.IBlobResult
    local function finish(result)
      if finished then
        return
      end
      finished = true
      if cancel_sub then
        cancel_sub:unsubscribe()
      end
      resolve(result)
    end

    local function cancelled()
      return token ~= nil and token:is_cancelled()
    end

    if cancelled() then
      finish({ ok = false, missing = false, err = "Operation cancelled" })
      return
    end

    proc = vim.system({ "git", "-C", cwd, "cat-file", "-p", object }, { text = false }, function(obj)
      vim.schedule(function()
        if finished then
          return
        end
        if obj.code == 0 then
          finish({ ok = true, missing = false, bytes = obj.stdout or "" })
          return
        end

        local read_err = git_error("Failed to read Git object " .. object, obj) ---@type string
        local index_stage, staged_path = object:match("^:(%d):(.*)$")
        local index_path = object:match("^:(.*)$") ---@type string|nil
        if staged_path then
          index_path = staged_path
        end

        if index_path then
          local inspect_args = index_stage and { "--literal-pathspecs", "ls-files", "--stage", "-z", "--", index_path }
            or { "--literal-pathspecs", "ls-files", "--error-unmatch", "--", index_path }
          proc = vim.system(vim.list_extend({ "git", "-C", cwd }, inspect_args), { text = false }, function(index_obj)
            vim.schedule(function()
              if finished then
                return
              end
              if index_obj.code == 1 then
                finish({ ok = false, missing = true, err = "Git index path does not exist: " .. index_path })
              elseif index_obj.code == 0 then
                if index_stage then
                  local found = false ---@type boolean
                  for record in (index_obj.stdout or ""):gmatch("([^%z]+)%z") do
                    if record:match("^%d+%s+%x+%s+" .. index_stage .. "\t") then
                      found = true
                      break
                    end
                  end
                  if not found then
                    finish({
                      ok = false,
                      missing = true,
                      err = string.format("Git index stage %s path does not exist: %s", index_stage, index_path),
                    })
                    return
                  end
                end
                finish({ ok = false, missing = false, err = read_err })
              else
                finish({
                  ok = false,
                  missing = false,
                  err = git_error("Failed to inspect Git index path " .. index_path, index_obj),
                })
              end
            end)
          end)
          return
        end

        local revision, relpath = object:match("^([^:]+):(.*)$")
        if revision then
          proc = vim.system(
            { "git", "-C", cwd, "--literal-pathspecs", "ls-tree", revision, "--", relpath },
            { text = false },
            function(tree_obj)
              vim.schedule(function()
                if finished then
                  return
                end
                if tree_obj.code ~= 0 then
                  local tree_err = git_error("Failed to inspect Git tree " .. revision, tree_obj) ---@type string
                  proc = vim.system(
                    { "git", "-C", cwd, "rev-parse", "--verify", "--quiet", revision },
                    { text = false },
                    function(revision_obj)
                      vim.schedule(function()
                        if finished then
                          return
                        end
                        if revision_obj.code == 1 then
                          finish({
                            ok = false,
                            missing = true,
                            err = "Git revision does not exist: " .. revision,
                          })
                        elseif revision_obj.code == 0 then
                          finish({ ok = false, missing = false, err = tree_err })
                        else
                          finish({
                            ok = false,
                            missing = false,
                            err = git_error("Failed to inspect Git revision " .. revision, revision_obj),
                          })
                        end
                      end)
                    end
                  )
                elseif tree_obj.stdout == nil or tree_obj.stdout == "" then
                  finish({ ok = false, missing = true, err = "Git tree path does not exist: " .. object })
                else
                  finish({ ok = false, missing = false, err = read_err })
                end
              end)
            end
          )
          return
        end

        finish({ ok = false, missing = false, err = read_err })
      end)
    end)

    if token then
      cancel_sub = token:on_cancel(function()
        if proc then
          proc:kill(9)
        end
        finish({ ok = false, missing = false, err = "Operation cancelled" })
      end)
    end
  end)
end

---@param cwd                           string
---@param token                         ?stl.c.CancellationToken
---@return stl.c.Future                 Resolves with { abbrev_head: string, detached: boolean }
function M.get_abbrev_head(cwd, token)
  return stl.c.Future.new(function(resolve)
    if token and token:is_cancelled() then
      resolve({ abbrev_head = "", detached = false })
      return
    end

    local proc ---@type vim.SystemObj|nil
    proc = vim.system({ "git", "-C", cwd, "rev-parse", "--abbrev-ref", "HEAD" }, { text = true }, function(obj)
      vim.schedule(function()
        if token and token:is_cancelled() then
          return
        end

        if obj.code ~= 0 then
          resolve({ abbrev_head = "", detached = false })
          return
        end

        local head = vim.trim(obj.stdout or "")
        if head == "HEAD" then
          proc = start_short_head(cwd, token, function(abbrev_head)
            resolve({ abbrev_head = abbrev_head, detached = true })
          end)
        else
          resolve({ abbrev_head = head, detached = false })
        end
      end)
    end)

    if token then
      token:on_cancel(function()
        if proc then
          proc:kill(9)
        end
      end)
    end
  end)
end

---@param cwd                           string
---@param relpath                       string
---@param token                         ?stl.c.CancellationToken
---@return stl.c.Future                 Resolves with stl.git.IFileInfoResult
function M.get_file_info(cwd, relpath, token)
  return stl.c.Future.new(function(resolve)
    local finished = false ---@type boolean
    local proc = nil ---@type vim.SystemObj|nil
    local cancel_sub = nil ---@type stl.c.IUnsubscribable|nil

    ---@param result                    stl.git.IFileInfoResult
    local function finish(result)
      if finished then
        return
      end
      finished = true
      if cancel_sub then
        cancel_sub:unsubscribe()
      end
      resolve(result)
    end

    if token and token:is_cancelled() then
      finish({ ok = false, missing = false, err = "Operation cancelled" })
      return
    end

    proc = vim.system(
      { "git", "-C", cwd, "--literal-pathspecs", "ls-files", "--stage", "--", relpath },
      { text = true },
      function(obj)
        vim.schedule(function()
          if finished then
            return
          end
          if obj.code ~= 0 then
            finish({
              ok = false,
              missing = false,
              err = git_error("Failed to inspect Git index path " .. relpath, obj),
            })
            return
          end

          ---@type stl.git.IFileInfo
          local info = {
            has_conflicts = false,
            mode_bits = nil,
            object_name = nil,
            relpath = relpath,
          }

          local lines = vim.split(obj.stdout or "", "\n", { plain = true })
          for _, line in ipairs(lines) do
            local mode, object, stage = line:match("^(%d+)%s+(%x+)%s+(%d)%s+")
            if mode and object and stage then
              if stage == "0" then
                info.mode_bits = mode
                info.object_name = object
              else
                info.has_conflicts = true
              end
            end
          end

          if not info.object_name and not info.has_conflicts then
            finish({ ok = false, missing = true })
          else
            finish({ ok = true, missing = false, info = info })
          end
        end)
      end
    )

    if token then
      cancel_sub = token:on_cancel(function()
        if proc then
          proc:kill(9)
        end
        finish({ ok = false, missing = false, err = "Operation cancelled" })
      end)
    end
  end)
end

---@param cwd                           string
---@param relpath                       string
---@param token                         ?stl.c.CancellationToken
---@return stl.c.Future                 Resolves with stl.git.IFileModeResult
function M.get_head_file_mode(cwd, relpath, token)
  return stl.c.Future.new(function(resolve)
    local finished = false ---@type boolean
    local proc = nil ---@type vim.SystemObj|nil
    local cancel_sub = nil ---@type stl.c.IUnsubscribable|nil

    ---@param result                    stl.git.IFileModeResult
    local function finish(result)
      if finished then
        return
      end
      finished = true
      if cancel_sub then
        cancel_sub:unsubscribe()
      end
      resolve(result)
    end

    if token and token:is_cancelled() then
      finish({ ok = false, missing = false, err = "Operation cancelled" })
      return
    end

    proc = vim.system(
      { "git", "-C", cwd, "--literal-pathspecs", "ls-tree", "HEAD", "--", relpath },
      { text = true },
      function(obj)
        vim.schedule(function()
          if finished then
            return
          end
          if obj.code ~= 0 then
            local tree_err = git_error("Failed to inspect HEAD path " .. relpath, obj) ---@type string
            proc = vim.system(
              { "git", "-C", cwd, "rev-parse", "--verify", "--quiet", "HEAD" },
              { text = false },
              function(head_obj)
                vim.schedule(function()
                  if finished then
                    return
                  end
                  if head_obj.code == 1 then
                    finish({ ok = false, missing = true })
                  elseif head_obj.code == 0 then
                    finish({ ok = false, missing = false, err = tree_err })
                  else
                    finish({
                      ok = false,
                      missing = false,
                      err = git_error("Failed to inspect HEAD", head_obj),
                    })
                  end
                end)
              end
            )
            return
          end
          local mode_bits = (obj.stdout or ""):match("^(%d+)") ---@type string|nil
          if mode_bits then
            finish({ ok = true, missing = false, mode_bits = mode_bits })
          else
            finish({ ok = false, missing = true })
          end
        end)
      end
    )

    if token then
      cancel_sub = token:on_cancel(function()
        if proc then
          proc:kill(9)
        end
        finish({ ok = false, missing = false, err = "Operation cancelled" })
      end)
    end
  end)
end

---@param cwd                           string
---@param object                        string
---@param token                         ?stl.c.CancellationToken
---@return stl.c.Future                 Resolves with ?string[]
function M.get_show_text(cwd, object, token)
  return stl.c.Future.new(function(resolve)
    if token and token:is_cancelled() then
      resolve(nil)
      return
    end

    local proc ---@type vim.SystemObj|nil
    proc = vim.system({ "git", "-C", cwd, "cat-file", "-p", object }, { text = true }, function(obj)
      vim.schedule(function()
        if token and token:is_cancelled() then
          return
        end

        if obj.code == 0 then
          local lines = vim.split(obj.stdout or "", "\n", { plain = true })
          -- Keep trailing empty string to preserve no_nl_at_eof information
          resolve(lines)
        else
          proc = vim.system({ "git", "-C", cwd, "show", object }, { text = true }, function(obj2)
            vim.schedule(function()
              if token and token:is_cancelled() then
                return
              end
              if obj2.code == 0 then
                local lines = vim.split(obj2.stdout or "", "\n", { plain = true })
                resolve(lines)
              else
                resolve(nil)
              end
            end)
          end)
        end
      end)
    end)

    if token then
      token:on_cancel(function()
        if proc then
          proc:kill(9)
        end
      end)
    end
  end)
end

---@param cwd                           string
---@param token                         ?stl.c.CancellationToken
---@return stl.c.Future                 Resolves with ?stl.git.IRepoInfo
function M.get_repo_info(cwd, token)
  return stl.c.Future.new(function(resolve)
    if token and token:is_cancelled() then
      resolve(nil)
      return
    end

    local proc ---@type vim.SystemObj|nil
    proc = vim.system(
      { "git", "-C", cwd, "rev-parse", "--show-toplevel", "--absolute-git-dir", "--abbrev-ref", "HEAD" },
      { text = true },
      function(obj)
        vim.schedule(function()
          if token and token:is_cancelled() then
            return
          end

          local lines = vim.split(obj.stdout or "", "\n", { plain = true })
          if not lines[1] or lines[1] == "" or not lines[2] or lines[2] == "" then
            resolve(nil)
            return
          end

          local toplevel = yoz.path.normalize(lines[1], true, stl.env.PATH_SEP)
          local gitdir = yoz.path.normalize(lines[2], true, stl.env.PATH_SEP)
          local head = lines[3] or ""
          local result = {
            abbrev_head = "",
            detached = false,
            gitdir = gitdir,
            toplevel = toplevel,
          } ---@type stl.git.IRepoInfo

          if obj.code ~= 0 then
            -- An unborn repository has valid paths but cannot resolve HEAD yet.
            resolve(head == "HEAD" and result or nil)
          elseif head == "HEAD" then
            proc = start_short_head(toplevel, token, function(abbrev_head)
              result.abbrev_head = abbrev_head
              result.detached = true
              resolve(result)
            end)
          elseif head ~= "" then
            result.abbrev_head = head
            resolve(result)
          else
            resolve(nil)
          end
        end)
      end
    )

    if token then
      token:on_cancel(function()
        if proc then
          proc:kill(9)
        end
        resolve(nil)
      end)
    end
  end)
end

return M
