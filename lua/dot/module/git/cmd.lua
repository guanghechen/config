local __module_name__ = "dot.module.git.cmd"

---@class dot.module.git.cmd
local M = {}

---@param args                       string[]
---@param opts                       { cwd: string|nil }|nil
---@param callback                   fun(lines: string[], code: integer)
function M.run_async(args, opts, callback)
  local cmd = { "git" }
  if opts and opts.cwd then
    cmd[#cmd + 1] = "-C"
    cmd[#cmd + 1] = opts.cwd
  end
  for _, arg in ipairs(args) do
    cmd[#cmd + 1] = arg
  end

  vim.system(cmd, { text = true }, function(obj)
    vim.schedule(function()
      local lines = {}
      if obj.code == 0 and obj.stdout then
        lines = vim.split(obj.stdout, "\n", { plain = true })
        if lines[#lines] == "" then
          lines[#lines] = nil
        end
      end
      callback(lines, obj.code)
    end)
  end)
end

---For user-triggered actions where blocking is acceptable (e.g., browse.lua)
---@param args                       string[]
---@param opts                       { cwd: string|nil }|nil
---@return string[]
---@return integer
function M.run_sync(args, opts)
  local cmd = { "git" }
  if opts and opts.cwd then
    cmd[#cmd + 1] = "-C"
    cmd[#cmd + 1] = opts.cwd
  end
  for _, arg in ipairs(args) do
    cmd[#cmd + 1] = arg
  end

  local obj = vim.system(cmd, { text = true }):wait()
  local lines = {}
  if obj.code == 0 and obj.stdout then
    lines = vim.split(obj.stdout, "\n", { plain = true })
    if lines[#lines] == "" then
      lines[#lines] = nil
    end
  end
  return lines, obj.code
end

---@param cwd                        string
---@param relpath                    string
---@param callback                   fun(ok: boolean)
function M.add_intent_to_add_async(cwd, relpath, callback)
  vim.system(
    { "git", "-C", cwd, "add", "--intent-to-add", "--", relpath },
    {},
    function(obj)
      vim.schedule(function()
        callback(obj.code == 0)
      end)
    end
  )
end

---@param cwd                        string
---@param patch                      string
---@param reverse                    boolean|nil
---@param callback                   fun(ok: boolean, err: string|nil)
function M.apply_patch_async(cwd, patch, reverse, callback)
  local args = { "git", "-C", cwd, "apply", "--cached", "--unidiff-zero", "-" }
  if reverse then
    table.insert(args, 5, "--reverse")
  end
  vim.system(args, { stdin = patch }, function(obj)
    vim.schedule(function()
      if obj.code ~= 0 then
        local err_msg = obj.stderr or ""
        ark.reporter.error({
          from = __module_name__,
          subject = "apply_patch",
          message = "Failed to apply patch.",
          details = { error = err_msg },
        })
        callback(false, err_msg)
      else
        callback(true, nil)
      end
    end)
  end)
end

---@param cwd                        string
---@param callback                   fun(abbrev_head: string, detached: boolean)
function M.get_abbrev_head_async(cwd, callback)
  vim.system(
    { "git", "-C", cwd, "rev-parse", "--abbrev-ref", "HEAD" },
    { text = true },
    function(obj)
      vim.schedule(function()
        if obj.code ~= 0 then
          callback("", false)
          return
        end
        local head = vim.trim(obj.stdout or "")
        if head == "HEAD" then
          vim.system(
            { "git", "-C", cwd, "rev-parse", "--short", "HEAD" },
            { text = true },
            function(obj2)
              vim.schedule(function()
                if obj2.code == 0 then
                  callback(vim.trim(obj2.stdout or ""), true)
                else
                  callback("", true)
                end
              end)
            end
          )
        else
          callback(head, false)
        end
      end)
    end
  )
end

---@param cwd                        string
---@param relpath                    string
---@param callback                   fun(info: dot.module.git.FileInfo|nil)
function M.get_file_info_async(cwd, relpath, callback)
  ---@type dot.module.git.FileInfo
  local info = {
    has_conflicts = false,
    mode_bits = nil,
    object_name = nil,
    relpath = relpath,
  }

  vim.system(
    { "git", "-C", cwd, "ls-files", "--stage", "-u", "--", relpath },
    { text = true },
    function(obj)
      vim.schedule(function()
        if obj.code == 0 then
          for line in (obj.stdout or ""):gmatch("[^\n]+") do
            if line:match("^%d+%s+%x+%s+[123]%s+") then
              info.has_conflicts = true
              break
            end
          end
        end

        vim.system(
          { "git", "-C", cwd, "ls-files", "--stage", "--", relpath },
          { text = true },
          function(obj2)
            vim.schedule(function()
              if obj2.code == 0 then
                local line = (obj2.stdout or ""):match("[^\n]+")
                if line then
                  local mode, object = line:match("^(%d+)%s+(%x+)%s+")
                  if mode and object then
                    info.mode_bits = mode
                    info.object_name = object
                  end
                end
              end

              if not info.object_name and not info.has_conflicts then
                callback(nil)
              else
                callback(info)
              end
            end)
          end
        )
      end)
    end
  )
end

---@param cwd                        string
---@param object                     string
---@param callback                   fun(lines: string[]|nil)
function M.get_show_text_async(cwd, object, callback)
  vim.system(
    { "git", "-C", cwd, "cat-file", "-p", object },
    { text = true },
    function(obj)
      vim.schedule(function()
        if obj.code == 0 then
          local lines = vim.split(obj.stdout or "", "\n", { plain = true })
          if lines[#lines] == "" then
            lines[#lines] = nil
          end
          callback(lines)
        else
          vim.system(
            { "git", "-C", cwd, "show", object },
            { text = true },
            function(obj2)
              vim.schedule(function()
                if obj2.code == 0 then
                  local lines = vim.split(obj2.stdout or "", "\n", { plain = true })
                  if lines[#lines] == "" then
                    lines[#lines] = nil
                  end
                  callback(lines)
                else
                  callback(nil)
                end
              end)
            end
          )
        end
      end)
    end
  )
end

---@param cwd                        string
---@param callback                   fun(gitdir: string|nil, toplevel: string|nil)
function M.get_toplevel_async(cwd, callback)
  vim.system(
    { "git", "-C", cwd, "rev-parse", "--show-toplevel", "--absolute-git-dir" },
    { text = true },
    function(obj)
      vim.schedule(function()
        if obj.code ~= 0 then
          callback(nil, nil)
          return
        end
        local lines = vim.split(obj.stdout or "", "\n", { plain = true })
        if #lines < 2 then
          callback(nil, nil)
          return
        end
        local toplevel = dot.path.normalize(lines[1])
        local gitdir = dot.path.normalize(lines[2])
        callback(gitdir, toplevel)
      end)
    end
  )
end

---@param cwd                        string
---@param file                       string
---@param lines                      string[]
---@param callback                   fun(hash: string|nil)
function M.hash_object_async(cwd, file, lines, callback)
  local stdin = table.concat(lines, "\n")
  if #lines > 0 then
    stdin = stdin .. "\n"
  end
  vim.system(
    { "git", "-C", cwd, "hash-object", "-w", "--path", file, "--stdin" },
    { stdin = stdin, text = true },
    function(obj)
      vim.schedule(function()
        if obj.code ~= 0 then
          callback(nil)
        else
          local hash = vim.trim(obj.stdout or "")
          callback(hash ~= "" and hash or nil)
        end
      end)
    end
  )
end

---@param cwd                        string
---@param relpath                    string
---@param callback                   fun(ok: boolean)
function M.stage_file_async(cwd, relpath, callback)
  vim.system(
    { "git", "-C", cwd, "add", "--", relpath },
    {},
    function(obj)
      vim.schedule(function()
        callback(obj.code == 0)
      end)
    end
  )
end

---@param cwd                        string
---@param relpath                    string
---@param callback                   fun(ok: boolean)
function M.unstage_file_async(cwd, relpath, callback)
  vim.system(
    { "git", "-C", cwd, "reset", "HEAD", "--", relpath },
    {},
    function(obj)
      vim.schedule(function()
        callback(obj.code == 0)
      end)
    end
  )
end

---@param cwd                        string
---@param mode_bits                  string
---@param object_name                string
---@param relpath                    string
---@param callback                   fun(ok: boolean)
function M.update_index_async(cwd, mode_bits, object_name, relpath, callback)
  vim.system(
    { "git", "-C", cwd, "update-index", "--cacheinfo", string.format("%s,%s,%s", mode_bits, object_name, relpath) },
    {},
    function(obj)
      vim.schedule(function()
        callback(obj.code == 0)
      end)
    end
  )
end

function M.setup() end

return M
