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
      from = "eve.fn.rename",
      subject = "source_not_exist",
      message = string.format("Source path does not exist: %s", from),
    })
    return false
  end

  -- Pre-flight validation for destination directory
  local dest_dir = std.path.dirname(to)
  if not std.path.is_exist(dest_dir) then
    std.reporter.error({
      from = "eve.fn.rename",
      subject = "dest_dir_not_exist",
      message = string.format("Destination directory does not exist: %s", dest_dir),
    })
    return false
  end

  local changes = { files = {} } ---@type { files: { oldUri: string, newUri: string }[] }

  if isdir then
    local result = oxi.fs.collect_files(from, true)
    if result and result.files then
      for _, relative_filepath in ipairs(result.files) do
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
    if client:supports_method("workspace/willRenameFiles") then
      -- Ensure the client is attached to buffers for relevant file types
      local buffers = vim.lsp.get_buffers_by_client_id(client.id)
      local client_active = false

      for _, bufnr in ipairs(buffers) do
        local buf_name = vim.api.nvim_buf_get_name(bufnr)
        if buf_name ~= "" and (buf_name == from or buf_name:find(std.path.dirname(from), 1, true)) then
          client_active = true
          break
        end
      end

      if client_active then
        local resp = client:request_sync("workspace/willRenameFiles", changes, 3000, 0)
        if resp and resp.result ~= nil then
          vim.lsp.util.apply_workspace_edit(resp.result, client.offset_encoding)
        end
      end
    end
  end

  -- Perform the rename using robust Rust implementation
  local move_success = oxi.fs.move({
    old_path = from,
    new_path = to,
    force = force,
  })

  if not move_success then
    local entity_type = isdir and "directory" or "file"
    std.reporter.error({
      from = "eve.fn.rename",
      subject = "rename_failed",
      message = string.format("Failed to rename %s from %s to %s", entity_type, from, to),
    })
    return false
  end

  -- LSP didRenameFiles notification
  for _, client in ipairs(clients) do
    if client:supports_method("workspace/didRenameFiles") then
      client:notify("workspace/didRenameFiles", changes)
    end
  end

  -- Replace old buffers with new buffers after rename
  eve.lsp.replace_renamed_buffers(changes.files)
  return true
end

return rename
