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

---@return boolean
function M.needs_preparation()
  for _, client in ipairs(vim.lsp.get_clients()) do
    if client:supports_method("workspace/willRenameFiles") then
      return true
    end
  end
  return false
end

---@param job                           yoz.ux.filetree.Job
---@param confirmation                  table
---@return stl.c.Future
function M.prepare(job, confirmation)
  return async.run_future(function()
    if not confirmation.source or not confirmation.target then
      return true
    end
    local source, target = filepath(confirmation.source), filepath(confirmation.target)
    if not source or not target then
      return true
    end
    local changes = {
      files = {
        {
          oldUri = vim.uri_from_fname(source),
          newUri = vim.uri_from_fname(target),
        },
      },
    }
    for _, client in ipairs(vim.lsp.get_clients()) do
      local status = job:status()
      if status.cancelling or not status.confirmation or status.confirmation.token ~= confirmation.token then
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
        status = job:status()
        if status.cancelling or not status.confirmation or status.confirmation.token ~= confirmation.token then
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
    return true
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
  local names = {}
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_get_option_value("buftype", { buf = bufnr }) == "" then
      local raw = vim.api.nvim_buf_get_name(bufnr)
      if raw ~= "" then
        local name = filepath(raw)
        if name then
          names[name] = bufnr
        end
      end
    end
  end
  for name, bufnr in pairs(names) do
    local from, to = source, target
    if name == physical or name:sub(1, #physical + 1) == physical .. "/" then
      from, to = physical, destination
    end
    if name == from or name:sub(1, #from + 1) == from .. "/" then
      local renamed = to .. name:sub(#from + 1)
      local ok, error = false, "target name belongs to another buffer"
      if not names[renamed] or names[renamed] == bufnr then
        ok, error = pcall(era.m.lsp.event.rename_buf, vim.api.nvim_buf_get_name(bufnr), renamed)
      end
      if not ok then
        vim.b[bufnr].filetree_move_target = renamed
        session.report("File moved; buffer path needs resolution: " .. renamed .. " (" .. tostring(error) .. ")")
      else
        vim.b[bufnr].filetree_move_target = nil
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

return M
