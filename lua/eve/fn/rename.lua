---@alias eve.fn.rename
---| function(params: eve.fn.rename.IParams): nil

---@class eve.fn.rename.IParams
---@field from                          string
---@field to                            string
---@field isdir                         ?boolean

---@type eve.fn.rename
local function rename(params)
  local from = params.from ---@type string
  local to = params.to ---@type string
  local isdir = params.isdir or false ---@type boolean

  local changes = { files = {} } ---@type { files: { oldUri: string, newUri: string }[] }

  if isdir then
    local result = oxi.fs.collect_files(from, true)
    if result and result.files then
      for _, filepath in ipairs(result.files) do
        local relative_path = filepath:sub(#from + 2) -- +2 to skip the directory separator
        local new_filepath = to .. "/" .. relative_path
        changes.files[#changes.files + 1] = {
          oldUri = vim.uri_from_fname(filepath),
          newUri = vim.uri_from_fname(new_filepath),
        }
      end
    end
  else
    changes.files[1] = {
      oldUri = vim.uri_from_fname(from),
      newUri = vim.uri_from_fname(to),
    }
  end

  local clients = vim.lsp.get_clients()
  for _, client in ipairs(clients) do
    if client:supports_method("workspace/willRenameFiles") then
      local resp = client:request_sync("workspace/willRenameFiles", changes, 1000, 0)
      if resp and resp.result ~= nil then
        vim.lsp.util.apply_workspace_edit(resp.result, client.offset_encoding)
      end
    end
  end

  local ok, err = pcall(vim.uv.fs_rename, from, to)

  if not ok then
    local entity_type = isdir and "directory" or "file"
    std.reporter.error({
      from = "eve.fn.rename",
      subject = "rename_failed",
      message = string.format("Failed to rename %s: %s", entity_type, err or "unknown error"),
    })
    return
  end

  for _, client in ipairs(clients) do
    if client:supports_method("workspace/didRenameFiles") then
      client:notify("workspace/didRenameFiles", changes)
    end
  end
end

return rename
