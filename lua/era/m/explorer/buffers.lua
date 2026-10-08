---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.explorer.buffers" ---@type string

local async = require("stl.async")
local Future = require("stl.c.future")
local paths = require("ux.filetree.path")
local DIAGNOSTIC_BYTES = 4096
local M = {}

---@param path                          ?string
---@return string|nil
local function filepath(path)
  if not path then
    return nil
  end
  if stl.env.IS_WIN then
    path = path:gsub("^//%?/UNC/", "//"):gsub("^//%?/([A-Za-z]:/)", "%1")
    if path:sub(1, 4) == "//?/" then
      return nil
    end
  end
  -- This editor boundary needs Neovim's UNC handling and byte-preserving Unix paths.
  local ok, value = pcall(vim.fs.normalize, path, { expand_env = false, win = stl.env.IS_WIN })
  return ok and value or nil
end

---@return fun(base: string, path: string): string|nil
local function path_matcher()
  -- Each synchronous matching pass gets its own cache; never retain resolutions across LSP replies or IO.
  local entries = {}
  ---@param path                        string
  ---@return string
  local function entry_path(path)
    if not entries[path] then
      local resolved, reason = yoz.fs.entry_path(paths.to_os(path))
      if not resolved then
        error("Cannot resolve buffer path " .. path .. ": " .. tostring(reason), 0)
      end
      entries[path] = paths.from_os(resolved)
    end
    return entries[path]
  end
  return function(base, path)
    local suffix, reason = yoz.fs.path_suffix(paths.to_os(entry_path(base)), paths.to_os(entry_path(path)))
    if reason then
      error("Cannot compare buffer path " .. path .. " with " .. base .. ": " .. reason, 0)
    end
    return suffix and paths.from_os(suffix) or nil
  end
end

---@return table<string, integer>
local function buffer_names()
  local names = {}
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_get_option_value("buftype", { buf = bufnr }) == "" then
      local raw = paths.from_os(vim.api.nvim_buf_get_name(bufnr))
      local name = raw ~= "" and filepath(raw) or nil
      if name then
        names[name] = bufnr
      end
    end
  end
  return names
end

---@param bufnr                         integer
---@return boolean
local function can_discard(bufnr)
  return not vim.api.nvim_buf_is_valid(bufnr)
    or not (
      vim.api.nvim_buf_is_loaded(bufnr)
      or vim.api.nvim_get_option_value("buflisted", { buf = bufnr })
      or vim.api.nvim_get_option_value("modified", { buf = bufnr })
    )
end

---@param bufnr                         integer
---@return boolean
local function discard_placeholder(bufnr)
  if not can_discard(bufnr) then
    return false
  end
  -- :file/nvim_buf_set_name retains the previous filename in an empty, unlisted buffer.
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = false })
  end
  return true
end

---@param source                        string
---@param target                        string
---@return nil
local function check_targets(source, target)
  local path_suffix = path_matcher()
  local names = buffer_names()
  local conflicts = {}
  -- Move replaces the target namespace; its buffers matter even when the source was never opened.
  for name, bufnr in pairs(names) do
    local ok, conflict = pcall(function()
      -- Parent resolution may cross the very symlink being replaced. Check every original ancestor entry too.
      local ancestor = name
      local visited = {}
      while ancestor and conflicts[ancestor] == nil do
        visited[#visited + 1] = ancestor
        local suffix = path_suffix(target, ancestor)
        if suffix ~= nil then
          conflicts[ancestor] = path_suffix(source, ancestor) ~= suffix
          break
        end
        local parent = paths.dirname(ancestor)
        ancestor = parent ~= ancestor and parent or nil
      end
      local conflict = ancestor and conflicts[ancestor] or false
      -- Shared ancestors need only one comparison within this synchronous pass.
      for _, path in ipairs(visited) do
        conflicts[path] = conflict
      end
      return conflict
    end)
    -- Check ownership only for conflicting or unreadable names; preparation never deletes buffers.
    if (not ok or conflict) and not can_discard(bufnr) then
      if not ok then
        error(conflict, 0)
      end
      error("Move refused; target belongs to another buffer: " .. name, 0)
    end
  end
end

---@param job                           yoz.ux.filetree.Job
---@param confirmation                  table
---@return boolean
local function preparing(job, confirmation)
  local status = job:status()
  return not status.cancelling and status.confirmation ~= nil and status.confirmation.token == confirmation.token
end

---@param job                           yoz.ux.filetree.Job
---@param confirmation                  table
---@return stl.c.Future
function M.prepare(job, confirmation)
  return async.run_future(function()
    if not preparing(job, confirmation) then
      return false
    end
    if not confirmation.source or not confirmation.target then
      return true
    end
    local source, target = filepath(confirmation.source), filepath(confirmation.target)
    if not source or not target then
      return true
    end
    local changes
    for _, client in ipairs(vim.lsp.get_clients()) do
      if not preparing(job, confirmation) then
        return false
      end
      if client:supports_method("workspace/willRenameFiles") then
        if not changes then
          check_targets(source, target)
          changes = {
            files = {
              {
                oldUri = vim.uri_from_fname(source),
                newUri = vim.uri_from_fname(target),
              },
            },
          }
        end
        local response = Future.new(function(resolve)
          local finished, timer = false, nil
          local accepted, id = client:request("workspace/willRenameFiles", changes, function(error, result)
            if finished then
              return
            end
            finished = true
            if timer then
              timer:stop()
              timer:close()
            end
            resolve({ error = error, result = result })
          end, 0)
          if not accepted then
            finished = true
            resolve(nil)
          elseif not finished then
            timer = vim.defer_fn(function()
              finished = true
              client:cancel_request(id)
              resolve(nil)
            end, 1000)
          end
        end):await()
        if not preparing(job, confirmation) then
          return false
        end
        if response and response.error then
          error(response.error.message or "LSP rename preparation failed", 0)
        end
        if response and response.result then
          vim.lsp.util.apply_workspace_edit(response.result, client.offset_encoding)
        end
      end
    end
    -- Workspace edits and asynchronous replies may introduce a destination buffer.
    if not preparing(job, confirmation) then
      return false
    end
    check_targets(source, target)
    return preparing(job, confirmation)
  end)
end

---@param item                          ux.filetree.IItemResult
---@param report                        fun(message: string): nil
---@return nil
local function sync_editor(item, report)
  local source, target = filepath(item.source), filepath(item.target)
  local physical, destination =
    filepath(item.source_physical or item.source), filepath(item.target_physical or item.target)
  if not source or not target or not physical or not destination then
    report("File moved; its path cannot be represented by Neovim")
    return
  end
  local path_suffix = path_matcher()
  local names = buffer_names()
  local targets = {}
  -- Most directory moves have no target buffers. Avoid comparing every source with every buffer.
  for name, bufnr in pairs(names) do
    local ok, suffix = pcall(path_suffix, destination, name)
    if ok and suffix == nil and destination ~= target then
      ok, suffix = pcall(path_suffix, target, name)
    end
    -- A file moved to B can leave an empty B/child placeholder whose parent is no longer a directory.
    if (not ok and not can_discard(bufnr)) or (ok and suffix ~= nil) then
      targets[name] = bufnr
    end
  end
  for name, bufnr in pairs(names) do
    local renamed
    local ok, reason = pcall(function()
      if not vim.api.nvim_buf_is_valid(bufnr) then
        return
      end
      local suffix, to = path_suffix(physical, name), destination
      if suffix == nil and physical ~= source then
        suffix, to = path_suffix(source, name), target
      end
      if suffix == nil then
        return
      end
      renamed = suffix == "" and to or to .. "/" .. suffix
      for other, current in pairs(targets) do
        if
          current ~= bufnr
          and vim.api.nvim_buf_is_valid(current)
          and path_suffix(renamed, other) == ""
          and not discard_placeholder(current)
        then
          error("target name belongs to another buffer: " .. other, 0)
        end
      end
      era.m.lsp.event.rename_buf(paths.from_os(vim.api.nvim_buf_get_name(bufnr)), renamed)
    end)
    if not ok and (renamed or not can_discard(bufnr)) then
      -- If source matching failed, retain the destination namespace for manual resolution.
      vim.b[bufnr].filetree_move_target = renamed or destination
      vim.b[bufnr].filetree_move_source = name
      report(
        "File moved; buffer path needs resolution: " .. (renamed or destination) .. " (" .. tostring(reason) .. ")"
      )
    elseif renamed then
      vim.b[bufnr].filetree_move_target = nil
      vim.b[bufnr].filetree_move_source = nil
    end
  end
  local changes = { files = { { oldUri = vim.uri_from_fname(physical), newUri = vim.uri_from_fname(destination) } } }
  for _, client in ipairs(vim.lsp.get_clients()) do
    if client:supports_method("workspace/didRenameFiles") then
      if client:notify("workspace/didRenameFiles", changes) == false then
        report("File moved; LSP rename notification was rejected by " .. client.name)
      end
    end
  end
end

---@param session                       era.m.explorer.Session
---@param item                          ux.filetree.IItemResult
---@return era.m.explorer.IEditorSyncError|nil
function M.sync(session, item)
  if item.status ~= "success" or session.operation ~= "move" then
    return nil
  end
  local issue ---@type era.m.explorer.IEditorSyncError|nil
  ---@param message                     any
  ---@return nil
  local function report(message)
    message = tostring(type(message) == "table" and message.message or message)
    -- A directory may affect many buffers; retain one diagnostic and count reported failures.
    if not issue then
      local diagnostic = message
      if #diagnostic > DIAGNOSTIC_BYTES then
        local last = DIAGNOSTIC_BYTES - 3
        -- Keep the bounded result tail from retaining arbitrary plugin errors or a partial UTF-8 character.
        while last > 0 and diagnostic:byte(last + 1) >= 0x80 and diagnostic:byte(last + 1) < 0xC0 do
          last = last - 1
        end
        diagnostic = diagnostic:sub(1, last) .. "..."
      end
      issue = { message = diagnostic, failures = 0 }
    end
    issue.failures = issue.failures + 1
    session.report(message)
  end
  local ok, reason = pcall(sync_editor, item, report)
  if not ok then
    report(reason)
  end
  return issue
end

vim.api.nvim_create_autocmd({ "BufWritePre", "FileWritePre" }, {
  group = vim.api.nvim_create_augroup("ExplorerMoveBuffers", { clear = true }),
  callback = function(event)
    local target = vim.b[event.buf].filetree_move_target
    if not target then
      return
    end
    local path_suffix = path_matcher()
    local name = filepath(paths.from_os(vim.api.nvim_buf_get_name(event.buf)))
    local written = filepath(paths.from_os(event.match))
    local source = vim.b[event.buf].filetree_move_source or name
    if not source or not written then
      error("File moved to " .. target .. "; resolve this buffer's filename before saving", 0)
    end
    ---@param path                      string
    ---@return boolean
    local function at_source(path)
      local ok, suffix = pcall(path_suffix, source, path)
      if not ok then
        local _, _, code = vim.uv.fs_lstat(paths.to_os(source))
        -- A resolvable destination cannot share the old parent now occupied by a file.
        if code ~= "ENOTDIR" or not yoz.fs.entry_path(paths.to_os(path)) then
          error(suffix, 0)
        end
        return false
      end
      return suffix == ""
    end
    -- Another spelling of the old filename is not an explicit recovery path.
    if name and name ~= source and not at_source(name) then
      vim.b[event.buf].filetree_move_target = nil
      vim.b[event.buf].filetree_move_source = nil
    elseif at_source(written) then
      error("File moved to " .. target .. "; resolve this buffer's filename before saving", 0)
    end
  end,
})

return M
