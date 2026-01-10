---@class era.m.acp.diff.IShowOpts
---@field public old_text                 string
---@field public new_text                 string
---@field public filepath                 ?string
---@field public title                    ?string

---@class era.m.acp.Diff
---@field protected _bufnr                integer|nil
---@field protected _winnr                integer|nil
---@field protected _ns                   integer
---@field protected _mode                 "unified"|"side_by_side"
---@field protected _hunks                era.m.acp.IDiffHunk[]
---@field protected _opts                 era.m.acp.diff.IShowOpts|nil
local M = {}
M.__index = M

---@return era.m.acp.Diff
function M.new()
  local self = setmetatable({}, M)
  self._bufnr = nil
  self._winnr = nil
  self._ns = vim.api.nvim_create_namespace("acp_diff")
  self._mode = "unified"
  self._hunks = {}
  self._opts = nil
  return self
end

---@param opts                          era.m.acp.diff.IShowOpts
---@return nil
function M:show(opts)
  self._opts = opts
  self._hunks = self:__compute_hunks__(opts.old_text, opts.new_text)

  self:__create_window__()
  self:__render__()
  self:__setup_keymaps__()
end

---@return nil
function M:close()
  if self._winnr and vim.api.nvim_win_is_valid(self._winnr) then
    vim.api.nvim_win_close(self._winnr, true)
  end
  self._winnr = nil
  if self._bufnr and vim.api.nvim_buf_is_valid(self._bufnr) then
    vim.api.nvim_buf_delete(self._bufnr, { force = true })
  end
  self._bufnr = nil
end

---@return nil
function M:toggle_mode()
  if self._mode == "unified" then
    self._mode = "side_by_side"
  else
    self._mode = "unified"
  end
  self:__render__()
end

----------------------------------------------------------------------------------------------------

---@protected
---@return nil
function M:__create_window__()
  if self._bufnr and vim.api.nvim_buf_is_valid(self._bufnr) then
    vim.api.nvim_buf_delete(self._bufnr, { force = true })
  end

  self._bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("filetype", "diff", { buf = self._bufnr })
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = self._bufnr })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = self._bufnr })
  vim.api.nvim_set_option_value("swapfile", false, { buf = self._bufnr })
  vim.api.nvim_set_option_value("modifiable", false, { buf = self._bufnr })

  local width = math.floor(vim.o.columns * 0.9)
  local height = math.floor(vim.o.lines * 0.9)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  self._winnr = vim.api.nvim_open_win(self._bufnr, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = self._opts and (self._opts.title or self._opts.filepath or "Diff") or "Diff",
    title_pos = "center",
  })

  vim.api.nvim_set_option_value("wrap", false, { win = self._winnr, scope = "local" })
  vim.api.nvim_set_option_value("number", true, { win = self._winnr, scope = "local" })
  vim.api.nvim_set_option_value("relativenumber", false, { win = self._winnr, scope = "local" })
  vim.api.nvim_set_option_value("cursorline", true, { win = self._winnr, scope = "local" })
  vim.api.nvim_set_option_value("winhighlight", "Normal:f_acp_normal", { win = self._winnr, scope = "local" })
end

---@protected
---@return nil
function M:__render__()
  if not self._bufnr or not vim.api.nvim_buf_is_valid(self._bufnr) then
    return
  end

  if self._mode == "unified" then
    self:__render_unified__()
  else
    self:__render_side_by_side__()
  end
end

---@protected
---@return nil
function M:__render_unified__()
  local bufnr = self._bufnr
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local lines = {} ---@type string[]
  local highlights = {} ---@type { line: integer, col_start: integer, col_end: integer, hl: string }[]

  -- Header
  if self._opts then
    local add_count = 0
    local del_count = 0
    for _, hunk in ipairs(self._hunks) do
      add_count = add_count + #hunk.added
      del_count = del_count + #hunk.deleted
    end

    local stat = string.format("+%d -%d", add_count, del_count)
    lines[#lines + 1] = stat
    highlights[#highlights + 1] = { line = 0, col_start = 0, col_end = #stat, hl = "f_acp_diff_header" }
    lines[#lines + 1] = ""
  end

  -- Hunks
  for _, hunk in ipairs(self._hunks) do
    local hunk_header = string.format("@@ -%d,%d +%d,%d @@", hunk.old_start, hunk.old_count, hunk.new_start, hunk.new_count)
    lines[#lines + 1] = hunk_header
    local hunk_line = #lines - 1
    highlights[#highlights + 1] = { line = hunk_line, col_start = 0, col_end = #hunk_header, hl = "f_acp_diff_hunk" }

    -- Common lines before changes
    for i = 1, math.min(#hunk.common, 3) do
      lines[#lines + 1] = " " .. hunk.common[i]
    end

    -- Deleted lines
    for _, line in ipairs(hunk.deleted) do
      local text = "-" .. line
      lines[#lines + 1] = text
      local line_idx = #lines - 1
      highlights[#highlights + 1] = { line = line_idx, col_start = 0, col_end = #text, hl = "f_acp_diff_delete" }
    end

    -- Added lines
    for _, line in ipairs(hunk.added) do
      local text = "+" .. line
      lines[#lines + 1] = text
      local line_idx = #lines - 1
      highlights[#highlights + 1] = { line = line_idx, col_start = 0, col_end = #text, hl = "f_acp_diff_add" }
    end

    -- Common lines after changes
    local remaining = math.max(0, #hunk.common - 3)
    for i = remaining + 1, #hunk.common do
      lines[#lines + 1] = " " .. hunk.common[i]
    end

    lines[#lines + 1] = ""
  end

  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })

  -- Apply highlights
  vim.api.nvim_buf_clear_namespace(bufnr, self._ns, 0, -1)
  for _, hl in ipairs(highlights) do
    vim.hl.range(bufnr, self._ns, hl.hl, { hl.line, hl.col_start }, { hl.line, hl.col_end })
  end
end

---@protected
---@return nil
function M:__render_side_by_side__()
  local bufnr = self._bufnr
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local lines = {} ---@type string[]
  local highlights = {} ---@type { line: integer, col_start: integer, col_end: integer, hl: string }[]

  -- Header
  if self._opts then
    local add_count = 0
    local del_count = 0
    for _, hunk in ipairs(self._hunks) do
      add_count = add_count + #hunk.added
      del_count = del_count + #hunk.deleted
    end

    local stat = string.format("+%d -%d (Side by Side)", add_count, del_count)
    lines[#lines + 1] = stat
    highlights[#highlights + 1] = { line = 0, col_start = 0, col_end = #stat, hl = "f_acp_diff_header" }

    local sep = string.rep("─", 80)
    lines[#lines + 1] = sep
    highlights[#highlights + 1] = { line = 1, col_start = 0, col_end = #sep, hl = "f_acp_diff_header" }

    local col_header = string.format("%-38s │ %-38s", "OLD", "NEW")
    lines[#lines + 1] = col_header
    highlights[#highlights + 1] = { line = 2, col_start = 0, col_end = #col_header, hl = "f_acp_diff_header" }

    lines[#lines + 1] = sep
    highlights[#highlights + 1] = { line = 3, col_start = 0, col_end = #sep, hl = "f_acp_diff_header" }
  end

  -- Hunks
  for _, hunk in ipairs(self._hunks) do
    local max_lines = math.max(#hunk.deleted, #hunk.added)
    for i = 1, max_lines do
      local left = hunk.deleted[i] or ""
      local right = hunk.added[i] or ""

      left = left:sub(1, 38)
      right = right:sub(1, 38)

      local line_text = string.format("%-38s │ %-38s", left, right)
      lines[#lines + 1] = line_text
      local line_idx = #lines - 1

      if hunk.deleted[i] then
        highlights[#highlights + 1] = { line = line_idx, col_start = 0, col_end = 38, hl = "f_acp_diff_delete" }
      end
      if hunk.added[i] then
        highlights[#highlights + 1] = { line = line_idx, col_start = 41, col_end = 80, hl = "f_acp_diff_add" }
      end
    end

    lines[#lines + 1] = ""
  end

  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })

  -- Apply highlights
  vim.api.nvim_buf_clear_namespace(bufnr, self._ns, 0, -1)
  for _, hl in ipairs(highlights) do
    vim.hl.range(bufnr, self._ns, hl.hl, { hl.line, hl.col_start }, { hl.line, hl.col_end })
  end
end

---@protected
---@return nil
function M:__setup_keymaps__()
  if not self._bufnr or not vim.api.nvim_buf_is_valid(self._bufnr) then
    return
  end

  local bufnr = self._bufnr
  local opts = { buffer = bufnr, noremap = true, silent = true }

  vim.keymap.set("n", "q", function()
    self:close()
  end, vim.tbl_extend("force", opts, { desc = "diff: close" }))

  vim.keymap.set("n", "<Esc>", function()
    self:close()
  end, vim.tbl_extend("force", opts, { desc = "diff: close" }))

  vim.keymap.set("n", "m", function()
    self:toggle_mode()
  end, vim.tbl_extend("force", opts, { desc = "diff: toggle mode" }))

  vim.keymap.set("n", "]c", function()
    self:__jump_to_next_hunk__()
  end, vim.tbl_extend("force", opts, { desc = "diff: next hunk" }))

  vim.keymap.set("n", "[c", function()
    self:__jump_to_prev_hunk__()
  end, vim.tbl_extend("force", opts, { desc = "diff: previous hunk" }))
end

---@protected
---@return nil
function M:__jump_to_next_hunk__()
  if not self._bufnr or not vim.api.nvim_buf_is_valid(self._bufnr) or not self._winnr or not vim.api.nvim_win_is_valid(self._winnr) then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(self._winnr)
  local current_line = cursor[1]
  local lines = vim.api.nvim_buf_get_lines(self._bufnr, 0, -1, false)

  for i = current_line + 1, #lines do
    if lines[i]:match("^@@") then
      vim.api.nvim_win_set_cursor(self._winnr, { i, 0 })
      return
    end
  end
end

---@protected
---@return nil
function M:__jump_to_prev_hunk__()
  if not self._bufnr or not vim.api.nvim_buf_is_valid(self._bufnr) or not self._winnr or not vim.api.nvim_win_is_valid(self._winnr) then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(self._winnr)
  local current_line = cursor[1]
  local lines = vim.api.nvim_buf_get_lines(self._bufnr, 0, -1, false)

  for i = current_line - 1, 1, -1 do
    if lines[i]:match("^@@") then
      vim.api.nvim_win_set_cursor(self._winnr, { i, 0 })
      return
    end
  end
end

---@protected
---@param old_text                      string
---@param new_text                      string
---@return era.m.acp.IDiffHunk[]
function M:__compute_hunks__(old_text, new_text)
  local old_lines = vim.split(old_text, "\n", { plain = true })
  local new_lines = vim.split(new_text, "\n", { plain = true })

  local hunks = {} ---@type era.m.acp.IDiffHunk[]
  local i = 1
  local j = 1

  while i <= #old_lines or j <= #new_lines do
    local old_start = i
    local new_start = j
    local deleted = {} ---@type string[]
    local added = {} ---@type string[]
    local common = {} ---@type string[]

    -- Collect common lines
    while i <= #old_lines and j <= #new_lines and old_lines[i] == new_lines[j] do
      common[#common + 1] = old_lines[i]
      i = i + 1
      j = j + 1
    end

    -- Collect deleted lines
    while i <= #old_lines and (j > #new_lines or old_lines[i] ~= new_lines[j]) do
      -- Check if this line exists anywhere in the near future of new_lines
      local found = false
      for k = j, math.min(j + 10, #new_lines) do
        if old_lines[i] == new_lines[k] then
          found = true
          break
        end
      end
      if found then
        break
      end
      deleted[#deleted + 1] = old_lines[i]
      i = i + 1
    end

    -- Collect added lines
    while j <= #new_lines and (i > #old_lines or old_lines[i] ~= new_lines[j]) do
      -- Check if this line exists anywhere in the near future of old_lines
      local found = false
      for k = i, math.min(i + 10, #old_lines) do
        if new_lines[j] == old_lines[k] then
          found = true
          break
        end
      end
      if found then
        break
      end
      added[#added + 1] = new_lines[j]
      j = j + 1
    end

    -- Create hunk if there are changes
    if #deleted > 0 or #added > 0 then
      ---@type era.m.acp.IDiffHunk
      hunks[#hunks + 1] = {
        old_start = old_start,
        old_count = #deleted,
        new_start = new_start,
        new_count = #added,
        deleted = deleted,
        added = added,
        common = common,
      }
    end
  end

  return hunks
end

return M
