local __module_name__ = "eve.fn.rename" ---@type string

local Methods = vim.lsp.protocol.Methods

---@alias eve.fn.rename
---| function(params: eve.fn.rename.IParams): boolean

---@class eve.fn.rename.IParams
---@field from                          string
---@field to                            string
---@field isdir                         ?boolean
---@field force                         ?boolean

---@type eve.fn.rename
local function rename(params)
  local from = params.from ---@type string
  local to = params.to ---@type string
  local isdir = params.isdir or false ---@type boolean
  local force = params.force or false ---@type boolean

  -- Early validation
  if not std.path.is_exist(from) then
    std.reporter.error({
      from = __module_name__,
      subject = "source_not_exist",
      message = string.format("Source path does not exist: %s", from),
    })
    return false
  end

  -- Pre-flight validation for destination directory
  local dest_dir = std.path.dirname(to)
  if not std.path.is_exist(dest_dir) then
    std.reporter.error({
      from = __module_name__,
      subject = "dest_dir_not_exist",
      message = string.format("Destination directory does not exist: %s", dest_dir),
    })
    return false
  end

  local changes = { files = {} } ---@type { files: { oldUri: string, newUri: string }[] }

  if isdir then
    local collect_result, collect_err = rstd.fs.collect_files(from, true)
    if collect_err ~= nil then
      std.reporter.error({
        from = __module_name__,
        subject = "collect_files_failed",
        details = {
          error = collect_err.error,
          source = from,
        },
      })
      return false
    end

    if collect_result ~= nil and collect_result.files ~= nil then
      for _, relative_filepath in ipairs(collect_result.files) do
        local from_filepath = from .. std.env.PATH_SEP .. relative_filepath ---@type string
        local to_filepath = to .. std.env.PATH_SEP .. relative_filepath ---@type string

        changes.files[#changes.files + 1] = {
          oldUri = vim.uri_from_fname(from_filepath),
          newUri = vim.uri_from_fname(to_filepath),
        }
      end
    end
  else
    changes.files[1] = {
      oldUri = vim.uri_from_fname(from),
      newUri = vim.uri_from_fname(to),
    }
  end

  -- Preload files to ensure LSP is triggered
  eve.lsp.preload_rename_files(changes.files)

  local clients = vim.lsp.get_clients()
  for _, client in ipairs(clients) do
    if client:supports_method(Methods.workspace_willRenameFiles) then
      -- Ensure the client is attached to buffers for relevant file types
      local buffers = client.attached_buffers or {} ---@type table<integer, boolean>
      local client_active = false

      for bufnr in pairs(buffers) do
        local buf_name = vim.api.nvim_buf_get_name(bufnr)
        if buf_name ~= "" and (buf_name == from or buf_name:find(std.path.dirname(from), 1, true)) then
          client_active = true
          break
        end
      end

      if client_active then
        local resp = client:request_sync(Methods.workspace_willRenameFiles, changes, 3000, 0)
        if resp and resp.result ~= nil then
          vim.lsp.util.apply_workspace_edit(resp.result, client.offset_encoding)
        end
      end
    end
  end

  -- Perform the rename using robust Rust implementation
  local move_success, move_err = rstd.fs.move({
    old_path = from,
    new_path = to,
    force = force,
  })

  if not move_success then
    local entity_type = isdir and "directory" or "file"
    std.reporter.error({
      from = __module_name__,
      subject = "rename_failed",
      message = string.format("Failed to rename %s from %s to %s", entity_type, from, to),
      details = move_err and { error = move_err.error } or nil,
    })
    return false
  end

  -- LSP didRenameFiles notification
  for _, client in ipairs(clients) do
    if client:supports_method(Methods.workspace_didRenameFiles) then
      client:notify(Methods.workspace_didRenameFiles, changes)
    end
  end

  -- Replace old buffers with new buffers after rename
  eve.lsp.replace_renamed_buffers(changes.files)
  return true
end

return rename
