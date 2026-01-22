---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.acp.input" ---@type string

---@class era.m.acp.input.IInputOpts
---@field public session                era.m.acp.Session
---@field public on_submit              fun(content: string, attachments: era.m.acp.IContentBlock[]): nil

---@class era.m.acp.Input
---@field public session                era.m.acp.Session
---@field protected _bufnr              integer|nil
---@field protected _winnr              integer|nil
---@field protected _attachments        era.m.acp.IContentBlock[]
---@field protected _on_submit          fun(content: string, attachments: era.m.acp.IContentBlock[]): nil
local M = {}
M.__index = M

---@param opts                          era.m.acp.input.IInputOpts
---@return era.m.acp.Input
function M.new(opts)
  local self = setmetatable({}, M)
  self.session = opts.session
  self._on_submit = opts.on_submit
  self._bufnr = nil
  self._winnr = nil
  self._attachments = {}
  return self
end

---@return integer|nil
function M:bufnr()
  return self._bufnr
end

---@return integer|nil
function M:winnr()
  return self._winnr
end

---@param winnr                        integer
---@return nil
function M:set_winnr(winnr)
  if self._winnr and self._winnr ~= winnr and vim.api.nvim_win_is_valid(self._winnr) then
    vim.api.nvim_win_close(self._winnr, true)
  end
  self._winnr = winnr

  local bufnr = self._bufnr ---@type integer
  if vim.api.nvim_win_get_buf(winnr) ~= bufnr then
    return
  end

  vim.api.nvim_win_call(winnr, function()
    -- Trigger FileType autocmd only once per buffer
    if not vim.b[bufnr].acp_filetype_done then
      vim.b[bufnr].acp_filetype_done = true
      vim.api.nvim_exec_autocmds("FileType", { buffer = bufnr })
    end
  end)
end

---@return nil
function M:create_buf()
  if self._bufnr ~= nil then
    return
  end

  self._bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = self._bufnr })
  vim.api.nvim_set_option_value("bufhidden", "hide", { buf = self._bufnr })
  vim.api.nvim_set_option_value("swapfile", false, { buf = self._bufnr })
  vim.api.nvim_set_option_value("filetype", stl.filetype.ACP_CHATBOX, { buf = self._bufnr })
  vim.treesitter.start(self._bufnr, "markdown")

  self:__setup_keymaps__()
end

---@return nil
function M:dispose()
  if self._winnr ~= nil and vim.api.nvim_win_is_valid(self._winnr) then
    vim.api.nvim_win_close(self._winnr, true)
  end
  self._winnr = nil
  if self._bufnr ~= nil and vim.api.nvim_buf_is_valid(self._bufnr) then
    vim.api.nvim_buf_delete(self._bufnr, { force = true })
  end
  self._bufnr = nil
end

---@return nil
function M:focus()
  if self._winnr ~= nil and vim.api.nvim_win_is_valid(self._winnr) then
    vim.api.nvim_set_current_win(self._winnr)
    vim.cmd("startinsert")
  end
end

---@return nil
function M:clear()
  local bufnr = self._bufnr
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
  self._attachments = {}
end

---@param filepath                      string
---@return boolean success
---@return string? error_msg
function M:attach_image(filepath)
  local normalized = dot.path.normalize(filepath)

  -- Check if file exists
  local stat = vim.uv.fs_stat(normalized)
  if not stat then
    return false, "File not found: " .. normalized
  end

  -- Check file size (limit to 5MB)
  local max_size = 5 * 1024 * 1024
  if stat.size > max_size then
    return false, string.format("File too large: %d bytes (max %d)", stat.size, max_size)
  end

  -- Read file
  local fd = vim.uv.fs_open(normalized, "r", 438)
  if not fd then
    return false, "Failed to open file: " .. normalized
  end

  local data = vim.uv.fs_read(fd, stat.size, 0)
  vim.uv.fs_close(fd)

  if not data then
    return false, "Failed to read file: " .. normalized
  end

  -- Convert to base64
  local base64 = vim.base64.encode(data)

  -- Detect mime type from extension
  local ext = normalized:match("%.([^.]+)$")
  local mime_type = "image/" .. (ext or "png")
  if ext == "jpg" then
    mime_type = "image/jpeg"
  end

  ---@type era.m.acp.IImageContent
  local image_content = {
    type = "image",
    data = base64,
    mime_type = mime_type,
    uri = normalized,
  }

  self._attachments[#self._attachments + 1] = image_content

  stl.reporter.info({
    from = "era.m.acp.input",
    subject = "Attachment",
    message = string.format("Attached image: %s (%d bytes)", normalized, stat.size),
  })

  return true
end

---@return era.m.acp.IContentBlock[]
function M:get_content_blocks()
  return vim.deepcopy(self._attachments)
end

---@param content                       string
---@return nil
function M:submit(content)
  if self.session.generating:snapshot() then
    return
  end
  local trimmed = vim.trim(content)
  if trimmed == "" and #self._attachments == 0 then
    return
  end
  self._on_submit(trimmed, vim.deepcopy(self._attachments))
  self._attachments = {}
end

----------------------------------------------------------------------------------------------------

---@protected
---@return nil
function M:__setup_keymaps__()
  local bufnr = self._bufnr
  if bufnr == nil then
    return
  end

  local opts = { buffer = bufnr, noremap = true, silent = true }

  vim.keymap.set({ "n" }, "<CR>", function()
    self:__submit__()
  end, vim.tbl_extend("force", opts, { desc = "acp: submit" }))

  vim.keymap.set({ "i" }, "<C-CR>", function()
    self:__submit__()
  end, vim.tbl_extend("force", opts, { desc = "acp: submit" }))

  vim.keymap.set({ "i" }, "<M-CR>", function()
    self:__submit__()
  end, vim.tbl_extend("force", opts, { desc = "acp: submit" }))

  vim.keymap.set({ "n", "i" }, "<C-a>", function()
    self:__attach_image__()
  end, vim.tbl_extend("force", opts, { desc = "acp: attach image" }))

  vim.keymap.set({ "n", "i" }, "<C-c>", function()
    self.session:cancel()
  end, vim.tbl_extend("force", opts, { desc = "acp: cancel" }))
end

---@protected
---@return nil
function M:__attach_image__()
  vim.ui.input({ prompt = "Image path: ", completion = "file" }, function(input)
    if not input or input == "" then
      return
    end
    local success, err = self:attach_image(input)
    if not success then
      stl.reporter.error({
        from = "era.m.acp.input",
        subject = "Attachment",
        message = err or "Failed to attach image",
      })
    end
  end)
end

---@protected
---@return nil
function M:__submit__()
  local bufnr = self._bufnr
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  if self.session.generating:snapshot() then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local content = vim.trim(table.concat(lines, "\n"))

  if content == "" and #self._attachments == 0 then
    return
  end

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
  self._on_submit(content, vim.deepcopy(self._attachments))
  self._attachments = {}
end

return M
