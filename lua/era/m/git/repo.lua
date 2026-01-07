---@class era.m.git.repo: era.m.git.Repo
---@field public new                   fun(toplevel: string, callback: fun(repo: era.m.git.Repo|nil))
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
---@param callback                   fun(repo: era.m.git.Repo|nil)
function M.new(toplevel, callback)
  era.m.git.cmd.get_toplevel_async(toplevel, function(gitdir, resolved_toplevel)
    if not gitdir or not resolved_toplevel then
      callback(nil)
      return
    end

    era.m.git.cmd.get_abbrev_head_async(resolved_toplevel, function(abbrev_head, detached)
      local self = setmetatable({}, M)
      self.abbrev_head = abbrev_head
      self.commondir = resolve_commondir(gitdir)
      self.detached = detached
      self.gitdir = gitdir
      self.toplevel = resolved_toplevel

      callback(self)
    end)
  end)
end

---@param file                       string
---@param callback                   fun(ok: boolean)
function M:add_intent_to_add(file, callback)
  local relpath = dot.path.relative(self.toplevel, file)
  era.m.git.cmd.add_intent_to_add_async(self.toplevel, relpath, callback)
end

---@param patch                      string
---@param reverse                    boolean|nil
---@param callback                   fun(ok: boolean, err: string|nil)
function M:apply_patch(patch, reverse, callback)
  era.m.git.cmd.apply_patch_async(self.toplevel, patch, reverse, callback)
end

---@param file                       string
---@param callback                   fun(info: era.m.git.FileInfo|nil)
function M:get_file_info(file, callback)
  local relpath = dot.path.relative(self.toplevel, file)
  era.m.git.cmd.get_file_info_async(self.toplevel, relpath, callback)
end

---@param file                       string
---@return string
function M:get_relpath(file)
  return dot.path.relative(self.toplevel, file)
end

---@param object                     string
---@param callback                   fun(lines: string[]|nil)
function M:get_show_text(object, callback)
  era.m.git.cmd.get_show_text_async(self.toplevel, object, callback)
end

---@param file                       string
---@param lines                      string[]
---@param callback                   fun(hash: string|nil)
function M:hash_object(file, lines, callback)
  local relpath = dot.path.relative(self.toplevel, file)
  era.m.git.cmd.hash_object_async(self.toplevel, relpath, lines, callback)
end

---@param callback                   (fun(): nil)|nil
function M:refresh_head(callback)
  era.m.git.cmd.get_abbrev_head_async(self.toplevel, function(abbrev_head, detached)
    self.abbrev_head = abbrev_head
    self.detached = detached
    if callback then
      callback()
    end
  end)
end

---@param file                       string
---@param callback                   fun(ok: boolean)
function M:reset_file(file, callback)
  local relpath = dot.path.relative(self.toplevel, file)
  local args = { "git", "-C", self.toplevel, "checkout", "--", relpath }
  vim.system(args, {}, function(obj)
    vim.schedule(function()
      callback(obj.code == 0)
    end)
  end)
end

---@param file                       string
---@param callback                   fun(ok: boolean)
function M:stage_file(file, callback)
  local relpath = dot.path.relative(self.toplevel, file)
  era.m.git.cmd.stage_file_async(self.toplevel, relpath, callback)
end

---@param file                       string
---@param callback                   fun(ok: boolean)
function M:unstage_file(file, callback)
  local relpath = dot.path.relative(self.toplevel, file)
  era.m.git.cmd.unstage_file_async(self.toplevel, relpath, callback)
end

---@param mode_bits                  string
---@param object_name                string
---@param file                       string
---@param callback                   fun(ok: boolean)
function M:update_index(mode_bits, object_name, file, callback)
  local relpath = dot.path.relative(self.toplevel, file)
  era.m.git.cmd.update_index_async(self.toplevel, mode_bits, object_name, relpath, callback)
end

return M
