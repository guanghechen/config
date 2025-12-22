---@class dot.module.git.repo: dot.module.git.Repo
---@field public new                   fun(toplevel: string, callback: fun(repo: dot.module.git.Repo|nil))
local M = {}
M.__index = M

---@param toplevel                   string
---@param callback                   fun(repo: dot.module.git.Repo|nil)
function M.new(toplevel, callback)
  dot.git.cmd.get_toplevel_async(toplevel, function(gitdir, resolved_toplevel)
    if not gitdir or not resolved_toplevel then
      callback(nil)
      return
    end

    dot.git.cmd.get_abbrev_head_async(resolved_toplevel, function(abbrev_head, detached)
      local self = setmetatable({}, M)
      self.abbrev_head = abbrev_head
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
  dot.git.cmd.add_intent_to_add_async(self.toplevel, relpath, callback)
end

---@param patch                      string
---@param reverse                    boolean|nil
---@param callback                   fun(ok: boolean, err: string|nil)
function M:apply_patch(patch, reverse, callback)
  dot.git.cmd.apply_patch_async(self.toplevel, patch, reverse, callback)
end

---@param file                       string
---@param callback                   fun(info: dot.module.git.FileInfo|nil)
function M:get_file_info(file, callback)
  local relpath = dot.path.relative(self.toplevel, file)
  dot.git.cmd.get_file_info_async(self.toplevel, relpath, callback)
end

---@param file                       string
---@return string
function M:get_relpath(file)
  return dot.path.relative(self.toplevel, file)
end

---@param object                     string
---@param callback                   fun(lines: string[]|nil)
function M:get_show_text(object, callback)
  dot.git.cmd.get_show_text_async(self.toplevel, object, callback)
end

---@param file                       string
---@param lines                      string[]
---@param callback                   fun(hash: string|nil)
function M:hash_object(file, lines, callback)
  local relpath = dot.path.relative(self.toplevel, file)
  dot.git.cmd.hash_object_async(self.toplevel, relpath, lines, callback)
end

---@param callback                   fun()|nil
function M:refresh_head(callback)
  dot.git.cmd.get_abbrev_head_async(self.toplevel, function(abbrev_head, detached)
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
  dot.git.cmd.stage_file_async(self.toplevel, relpath, callback)
end

---@param file                       string
---@param callback                   fun(ok: boolean)
function M:unstage_file(file, callback)
  local relpath = dot.path.relative(self.toplevel, file)
  dot.git.cmd.unstage_file_async(self.toplevel, relpath, callback)
end

---@param mode_bits                  string
---@param object_name                string
---@param file                       string
---@param callback                   fun(ok: boolean)
function M:update_index(mode_bits, object_name, file, callback)
  local relpath = dot.path.relative(self.toplevel, file)
  dot.git.cmd.update_index_async(self.toplevel, mode_bits, object_name, relpath, callback)
end

function M.setup() end

return M
