---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.explorer.buffers" ---@type string

local async = require("stl.async")
local Future = require("stl.c.future")
local M = {}

---@param path                          string
---@return string|nil
local function filepath(path)
  if stl.env.IS_WIN then
    path = path:gsub("\\", "/"):gsub("^//%?/UNC/", "//"):gsub("^//%?/([A-Za-z]:/)", "%1")
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
      local resolved, reason = yoz.fs.entry_path(path)
      if not resolved then
        error("Cannot resolve buffer path " .. path .. ": " .. tostring(reason), 0)
      end
      entries[path] = resolved
    end
    return entries[path]
  end
  return function(base, path)
    local suffix, reason = yoz.fs.path_suffix(entry_path(base), entry_path(path))
    if reason then
      error("Cannot compare buffer path " .. path .. " with " .. base .. ": " .. reason, 0)
    end
    return suffix
  end
end

---@return table<string, integer>
local function buffer_names()
  local names = {}
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_get_option_value("buftype", { buf = bufnr }) == "" then
      local raw = vim.api.nvim_buf_get_name(bufnr)
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
local function discard_placeholder(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return true
  end
  if
    vim.api.nvim_buf_is_loaded(bufnr)
    or vim.api.nvim_get_option_value("buflisted", { buf = bufnr })
    or vim.api.nvim_get_option_value("modified", { buf = bufnr })
  then
    return false
  end
  -- :file/nvim_buf_set_name retains the previous filename in an empty, unlisted buffer.
  vim.api.nvim_buf_delete(bufnr, { force = false })
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
      -- Neovim's dirname can strip the share from a UNC root, which is not a valid absolute parent.
      if stl.env.IS_WIN and ancestor:match("^//[^/]+/[^/]+/?$") then
        break
      end
      local parent = vim.fs.dirname(ancestor)
      ancestor = parent ~= ancestor and parent or nil
    end
    local conflict = ancestor and conflicts[ancestor] or false
    -- Shared ancestors need only one comparison within this synchronous pass.
    for _, path in ipairs(visited) do
      conflicts[path] = conflict
    end
    if conflict and not discard_placeholder(bufnr) then
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
    check_targets(source, target)
    local changes = {
      files = {
        {
          oldUri = vim.uri_from_fname(source),
          newUri = vim.uri_from_fname(target),
        },
      },
    }
    for _, client in ipairs(vim.lsp.get_clients()) do
      if not preparing(job, confirmation) then
        return false
      end
      if client:supports_method("workspace/willRenameFiles") then
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

---@param session                       era.m.explorer.Session
---@param item                          ux.filetree.IItemResult
---@return nil
function M.sync(session, item)
  if item.status ~= "success" or session.operation ~= "move" or not item.target or not item.source then
    return
  end
  local source, target = filepath(item.source), filepath(item.target)
  local physical, destination =
    filepath(item.source_physical or item.source), filepath(item.target_physical or item.target)
  if not source or not target or not physical or not destination then
    session.report("File moved; its path cannot be represented by Neovim")
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
    if not ok or suffix ~= nil then
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
      era.m.lsp.event.rename_buf(vim.api.nvim_buf_get_name(bufnr), renamed)
    end)
    if not ok then
      -- If source matching failed, retain the destination namespace for manual resolution.
      vim.b[bufnr].filetree_move_target = renamed or destination
      vim.b[bufnr].filetree_move_source = name
      session.report(
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
      client:notify("workspace/didRenameFiles", changes)
    end
  end
end

vim.api.nvim_create_autocmd({ "BufWritePre", "FileWritePre" }, {
  group = vim.api.nvim_create_augroup("ExplorerMoveBuffers", { clear = true }),
  callback = function(event)
    local target = vim.b[event.buf].filetree_move_target
    if not target then
      return
    end
    local path_suffix = path_matcher()
    local name = filepath(vim.api.nvim_buf_get_name(event.buf))
    local written = filepath(event.match)
    local source = vim.b[event.buf].filetree_move_source or name
    if not source or not written then
      error("File moved to " .. target .. "; resolve this buffer's filename before saving", 0)
    end
    ---@param path                      string
    ---@return boolean
    local function at_source(path)
      local ok, suffix = pcall(path_suffix, source, path)
      if not ok then
        local _, _, code = vim.uv.fs_lstat(source)
        -- A resolvable destination cannot share the old parent now occupied by a file.
        if code ~= "ENOTDIR" or not yoz.fs.entry_path(path) then
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
