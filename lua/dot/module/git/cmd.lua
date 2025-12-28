---@class dot.module.git.cmd
local M = {}

---@param args                       string[]
---@param opts                       { cwd: string|nil }|nil
---@param callback                   fun(lines: string[], code: integer): nil
---@return fun(): nil                cancel_fn
function M.run_async(args, opts, callback)
  local cmd = { "git" }
  if opts and opts.cwd then
    cmd[#cmd + 1] = "-C"
    cmd[#cmd + 1] = opts.cwd
  end
  for _, arg in ipairs(args) do
    cmd[#cmd + 1] = arg
  end

  local cancelled = false                  ---@type boolean
  local proc = vim.system(cmd, { text = true }, function(obj)
    if not cancelled then
      vim.schedule(function()
        if not cancelled then
          local lines = {}
          if obj.code == 0 and obj.stdout then
            lines = vim.split(obj.stdout, "\n", { plain = true })
            if lines[#lines] == "" then
              lines[#lines] = nil
            end
          end
          callback(lines, obj.code)
        end
      end)
    end
  end)

  return function()
    cancelled = true
    if proc then
      proc:kill(9)
    end
  end
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
---@param callback                   fun(ok: boolean): nil
---@return fun(): nil                cancel_fn
function M.add_intent_to_add_async(cwd, relpath, callback)
  return M.run_async({ "add", "--intent-to-add", "--", relpath }, { cwd = cwd }, function(_, code)
    callback(code == 0)
  end)
end

---@param cwd                        string
---@param patch                      string
---@param reverse                    boolean|nil
---@param callback                   fun(ok: boolean, err: string|nil): nil
---@return fun(): nil                cancel_fn
function M.apply_patch_async(cwd, patch, reverse, callback)
  local args = { "git", "-C", cwd, "apply", "--cached", "--unidiff-zero", "-" }
  if reverse then
    table.insert(args, 5, "--reverse")
  end

  local cancelled = false
  local proc = vim.system(args, { stdin = patch }, function(obj)
    if not cancelled then
      vim.schedule(function()
        if not cancelled then
          if obj.code ~= 0 then
            local err_msg = obj.stderr or ""
            ark.reporter.error({
              from = "dot.module.git.cmd",
              subject = "apply_patch",
              message = "Failed to apply patch.",
              details = { error = err_msg },
            })
            callback(false, err_msg)
          else
            callback(true, nil)
          end
        end
      end)
    end
  end)

  return function()
    cancelled = true
    if proc then
      proc:kill(9)
    end
  end
end

---@param cwd                        string
---@param callback                   fun(abbrev_head: string, detached: boolean): nil
---@return fun(): nil                cancel_fn
function M.get_abbrev_head_async(cwd, callback)
  local cancelled = false
  local proc = nil

  proc = vim.system(
    { "git", "-C", cwd, "rev-parse", "--abbrev-ref", "HEAD" },
    { text = true },
    function(obj)
      if not cancelled then
        vim.schedule(function()
          if cancelled then return end

          if obj.code ~= 0 then
            callback("", false)
            return
          end

          local head = vim.trim(obj.stdout or "")
          if head == "HEAD" then
            proc = vim.system(
              { "git", "-C", cwd, "rev-parse", "--short", "HEAD" },
              { text = true },
              function(obj2)
                if not cancelled then
                  vim.schedule(function()
                    if cancelled then return end
                    if obj2.code == 0 then
                      callback(vim.trim(obj2.stdout or ""), true)
                    else
                      callback("", true)
                    end
                  end)
                end
              end
            )
          else
            callback(head, false)
          end
        end)
      end
    end
  )

  return function()
    cancelled = true
    if proc then
      proc:kill(9)
    end
  end
end

---@param cwd                        string
---@param relpath                    string
---@param callback                   fun(info: dot.module.git.FileInfo|nil): nil
---@return fun(): nil                cancel_fn
function M.get_file_info_async(cwd, relpath, callback)
  return M.run_async({ "ls-files", "--stage", "--", relpath }, { cwd = cwd }, function(lines, code)
    ---@type dot.module.git.FileInfo
    local info = {
      has_conflicts = false,
      mode_bits = nil,
      object_name = nil,
      relpath = relpath,
    }

    if code == 0 then
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
    end

    if not info.object_name and not info.has_conflicts then
      callback(nil)
    else
      callback(info)
    end
  end)
end

---@param cwd                        string
---@param object                     string
---@param callback                   fun(lines: string[]|nil): nil
---@return fun(): nil                cancel_fn
function M.get_show_text_async(cwd, object, callback)
  local cancelled = false
  local proc = nil

  proc = vim.system(
    { "git", "-C", cwd, "cat-file", "-p", object },
    { text = true },
    function(obj)
      if not cancelled then
        vim.schedule(function()
          if cancelled then return end

          if obj.code == 0 then
            local lines = vim.split(obj.stdout or "", "\n", { plain = true })
            -- Keep trailing empty string to preserve no_nl_at_eof information
            callback(lines)
          else
            proc = vim.system(
              { "git", "-C", cwd, "show", object },
              { text = true },
              function(obj2)
                if not cancelled then
                  vim.schedule(function()
                    if cancelled then return end
                    if obj2.code == 0 then
                      local lines = vim.split(obj2.stdout or "", "\n", { plain = true })
                      callback(lines)
                    else
                      callback(nil)
                    end
                  end)
                end
              end
            )
          end
        end)
      end
    end
  )

  return function()
    cancelled = true
    if proc then
      proc:kill(9)
    end
  end
end

---@param cwd                        string
---@param callback                   fun(gitdir: string|nil, toplevel: string|nil): nil
---@return fun(): nil                cancel_fn
function M.get_toplevel_async(cwd, callback)
  return M.run_async({ "rev-parse", "--show-toplevel", "--absolute-git-dir" }, { cwd = cwd }, function(lines, code)
    if code ~= 0 or #lines < 2 then
      callback(nil, nil)
      return
    end
    local toplevel = dot.path.normalize(lines[1])
    local gitdir = dot.path.normalize(lines[2])
    callback(gitdir, toplevel)
  end)
end

---@param cwd                        string
---@param file                       string
---@param lines                      string[]
---@param callback                   fun(hash: string|nil): nil
---@return fun(): nil                cancel_fn
function M.hash_object_async(cwd, file, lines, callback)
  local stdin = table.concat(lines, "\n")
  if #lines > 0 then
    stdin = stdin .. "\n"
  end

  local cancelled = false
  local proc = vim.system(
    { "git", "-C", cwd, "hash-object", "-w", "--path", file, "--stdin" },
    { stdin = stdin, text = true },
    function(obj)
      if not cancelled then
        vim.schedule(function()
          if not cancelled then
            if obj.code ~= 0 then
              ark.reporter.warn({
                from = "dot.module.git.cmd",
                subject = "hash_object",
                message = "Failed to hash object",
                details = { file = file, code = obj.code, stderr = obj.stderr },
              })
              callback(nil)
            else
              local hash = vim.trim(obj.stdout or "")
              callback(hash ~= "" and hash or nil)
            end
          end
        end)
      end
    end
  )

  return function()
    cancelled = true
    if proc then
      proc:kill(9)
    end
  end
end

---@param cwd                        string
---@param relpath                    string
---@param callback                   fun(ok: boolean): nil
---@return fun(): nil                cancel_fn
function M.stage_file_async(cwd, relpath, callback)
  return M.run_async({ "add", "--", relpath }, { cwd = cwd }, function(_, code)
    if code ~= 0 then
      ark.reporter.warn({
        from = "dot.module.git.cmd",
        subject = "stage_file",
        message = "Failed to stage file",
        details = { relpath = relpath, code = code },
      })
    end
    callback(code == 0)
  end)
end

---@param cwd                        string
---@param relpath                    string
---@param callback                   fun(ok: boolean): nil
---@return fun(): nil                cancel_fn
function M.unstage_file_async(cwd, relpath, callback)
  return M.run_async({ "reset", "HEAD", "--", relpath }, { cwd = cwd }, function(_, code)
    if code ~= 0 then
      ark.reporter.warn({
        from = "dot.module.git.cmd",
        subject = "unstage_file",
        message = "Failed to unstage file",
        details = { relpath = relpath, code = code },
      })
    end
    callback(code == 0)
  end)
end

---@param cwd                        string
---@param mode_bits                  string
---@param object_name                string
---@param relpath                    string
---@param callback                   fun(ok: boolean): nil
---@return fun(): nil                cancel_fn
function M.update_index_async(cwd, mode_bits, object_name, relpath, callback)
  return M.run_async(
    { "update-index", "--cacheinfo", string.format("%s,%s,%s", mode_bits, object_name, relpath) },
    { cwd = cwd },
    function(_, code)
      if code ~= 0 then
        ark.reporter.warn({
          from = "dot.module.git.cmd",
          subject = "update_index",
          message = "Failed to update index",
          details = { relpath = relpath, code = code },
        })
      end
      callback(code == 0)
    end
  )
end

return M
