---@class era.m.git.repo: era.m.git.Repo
---@field public create                fun(toplevel: string, token: stl.c.CancellationToken|nil): stl.c.Future Resolves with ?era.m.git.Repo
local M = {}
M.__index = M

---@param gitdir                      string
---@return string|nil
local function resolve_commondir(gitdir)
  local commondir_file = gitdir .. "/commondir" ---@type string
  if vim.uv.fs_stat(commondir_file) == nil then
    return nil
  end

  local lines = vim.fn.readfile(commondir_file, "", 1) ---@type string[]
  if #lines == 0 or lines[1] == "" then
    return nil
  end

  local commondir = dot.path.normalize(gitdir .. "/" .. lines[1]) ---@type string
  local stat = vim.uv.fs_stat(commondir) ---@type uv.fs_stat.result|nil
  if stat and stat.type == "directory" then
    return commondir
  end

  return nil
end

---@param toplevel                   string
---@param token                      ?stl.c.CancellationToken
---@return stl.c.Future              Resolves with ?era.m.git.Repo
function M.create(toplevel, token)
  return stl.c.Future.new(function(resolve)
    if token and token:is_cancelled() then
      resolve(nil)
      return
    end

    stl.async.run(function()
      local result = stl.git.info.get_toplevel(toplevel, token):await()
      if not result or not result.gitdir or not result.toplevel then
        resolve(nil)
        return
      end

      local abbrev_result = stl.git.info.get_abbrev_head(result.toplevel, token):await()

      local self = setmetatable({}, M)
      self.abbrev_head = abbrev_result and abbrev_result.abbrev_head
      self.commondir = resolve_commondir(result.gitdir)
      self.detached = abbrev_result and abbrev_result.detached
      self.gitdir = result.gitdir
      self.toplevel = result.toplevel

      resolve(self)
    end)
  end)
end

---@param file                       string
---@param token                      ?stl.c.CancellationToken
---@return stl.c.Future              Resolves with boolean
function M:add_intent_to_add(file, token)
  local relpath = dot.path.relative(self.toplevel, file)
  return stl.git.act.add_intent_to_add(self.toplevel, relpath, token)
end

---@param patch                      string
---@param reverse                    boolean|nil
---@param token                      ?stl.c.CancellationToken
---@return stl.c.Future              Resolves with {ok: boolean, err: string|nil}
function M:apply_patch(patch, reverse, token)
  return stl.git.act.apply_patch(self.toplevel, patch, reverse, token)
end

---@param file                       string
---@param token                      ?stl.c.CancellationToken
---@return stl.c.Future              Resolves with era.m.git.FileInfo|nil
function M:get_file_info(file, token)
  local relpath = dot.path.relative(self.toplevel, file)
  return stl.git.info.get_file_info(self.toplevel, relpath, token)
end

---@param file                       string
---@return string
function M:get_relpath(file)
  return dot.path.relative(self.toplevel, file)
end

---@param object                     string
---@param token                      ?stl.c.CancellationToken
---@return stl.c.Future              Resolves with string[]|nil
function M:get_show_text(object, token)
  return stl.git.info.get_show_text(self.toplevel, object, token)
end

---@param file                       string
---@param lines                      string[]
---@param token                      ?stl.c.CancellationToken
---@return stl.c.Future              Resolves with string|nil (hash)
function M:hash_object(file, lines, token)
  local relpath = dot.path.relative(self.toplevel, file)
  return stl.git.act.hash_object(self.toplevel, relpath, lines, token)
end

---@param token                      ?stl.c.CancellationToken
---@return stl.c.Future              Resolves with nil
function M:refresh_head(token)
  return stl.c.Future.new(function(resolve)
    if token and token:is_cancelled() then
      resolve(nil)
      return
    end

    stl.async.run(function()
      local result = stl.git.info.get_abbrev_head(self.toplevel, token):await()
      if result then
        self.abbrev_head = result.abbrev_head
        self.detached = result.detached
      end
      resolve(nil)
    end)
  end)
end

---@param file                       string
---@param token                      ?stl.c.CancellationToken
---@return stl.c.Future              Resolves with boolean
function M:reset_file(file, token)
  local relpath = dot.path.relative(self.toplevel, file)
  return stl.git.act.reset_file(self.toplevel, relpath, token)
end

---@param file                       string
---@param token                      ?stl.c.CancellationToken
---@return stl.c.Future              Resolves with boolean
function M:stage_file(file, token)
  local relpath = dot.path.relative(self.toplevel, file)
  return stl.git.act.stage_file(self.toplevel, relpath, token)
end

---@param file                       string
---@param token                      ?stl.c.CancellationToken
---@return stl.c.Future              Resolves with boolean
function M:unstage_file(file, token)
  local relpath = dot.path.relative(self.toplevel, file)
  return stl.git.act.unstage_file(self.toplevel, relpath, token)
end

---@param mode_bits                  string
---@param object_name                string
---@param file                       string
---@param token                      ?stl.c.CancellationToken
---@return stl.c.Future              Resolves with boolean
function M:update_index(mode_bits, object_name, file, token)
  local relpath = dot.path.relative(self.toplevel, file)
  return stl.git.act.update_index(self.toplevel, mode_bits, object_name, relpath, token)
end

return M
