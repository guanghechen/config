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
  local names = buffer_names()
  -- Move replaces the target namespace; its buffers matter even when the source was never opened.
  for name, bufnr in pairs(names) do
    if name == target or name:sub(1, #target + 1) == target .. "/" then
      local original = source .. name:sub(#target + 1)
      if names[original] ~= bufnr and not discard_placeholder(bufnr) then
        error("Move refused; target belongs to another buffer: " .. name, 0)
      end
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
  local names = buffer_names()
  for name, bufnr in pairs(names) do
    local from, to = source, target
    if name == physical or name:sub(1, #physical + 1) == physical .. "/" then
      from, to = physical, destination
    end
    if name == from or name:sub(1, #from + 1) == from .. "/" then
      local renamed = to .. name:sub(#from + 1)
      local ok, error = pcall(function()
        if names[renamed] and names[renamed] ~= bufnr and not discard_placeholder(names[renamed]) then
          error("target name belongs to another buffer", 0)
        end
        era.m.lsp.event.rename_buf(vim.api.nvim_buf_get_name(bufnr), renamed)
      end)
      if not ok then
        vim.b[bufnr].filetree_move_target = renamed
        vim.b[bufnr].filetree_move_source = name
        session.report("File moved; buffer path needs resolution: " .. renamed .. " (" .. tostring(error) .. ")")
      else
        vim.b[bufnr].filetree_move_target = nil
        vim.b[bufnr].filetree_move_source = nil
      end
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
    local name = filepath(vim.api.nvim_buf_get_name(event.buf))
    local source = vim.b[event.buf].filetree_move_source
    if name == target or source and name and name ~= source then
      vim.b[event.buf].filetree_move_target = nil
      vim.b[event.buf].filetree_move_source = nil
    elseif filepath(event.match) == (source or name) then
      error("File moved to " .. target .. "; resolve this buffer's filename before saving", 0)
    end
  end,
})

return M
