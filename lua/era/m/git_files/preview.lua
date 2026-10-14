---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.git_files.preview" ---@type string

local Surface = require("era.view.picker.preview")
local Diff = require("era.m.git_files.diff")
local namespace = vim.api.nvim_create_namespace("era.git_files.diff")

---@class era.m.git_files.Preview
---@field surface                       era.view.PickerPreview
---@field _root                         ?string
---@field _entry                        ?era.view.git_files.IMetadata
---@field _token                        ?stl.c.CancellationToken
---@field _epoch                        integer
---@field _requested                    ?integer
---@field _rows                         era.m.git_files.diff.IRow[]
---@field _gutter                       string[]
---@field _gutter_width                 integer
---@field _statuscolumn                 string
---@field _unregister                   fun(): nil
---@field _syntax_bufnr                 ?integer
---@field _filetype                     ?string
---@field _disposed                     boolean
---@field _title                        string
local M = {}
M.__index = M

---@param keymaps                       stl.t.IKeymap[]
---@return era.m.git_files.Preview
function M.new(keymaps)
  local self = setmetatable({
    _epoch = 0,
    _rows = { { kind = "info", text = "Select a file to preview its diff." } },
    _gutter = {},
    _gutter_width = 0,
    _title = "Diff preview",
    _disposed = false,
  }, M)
  local callback, unregister = dot.G.register_anonymous_fn(function()
    return vim.v.virtnum == 0 and self._gutter[vim.v.lnum] or ""
  end)
  self._statuscolumn, self._unregister = "%!v:lua." .. callback .. "()", unregister
  self.surface = Surface.new({
    name = "Git Files",
    diagnostic_scope = "diff preview",
    relative_number = false,
    keymaps = keymaps,
    draw = function(bufnr)
      self:_start()
      return self:_draw(bufnr)
    end,
    on_drawed = function()
      local winnr = self.surface:get_winnr()
      if winnr and vim.api.nvim_win_is_valid(winnr) then
        vim.api.nvim_set_option_value("signcolumn", "no", { win = winnr })
        vim.api.nvim_set_option_value("foldcolumn", "0", { win = winnr })
        vim.api.nvim_set_option_value("numberwidth", math.min(20, math.max(1, self._gutter_width)), { win = winnr })
        vim.api.nvim_set_option_value(
          "statuscolumn",
          self._gutter_width > 0 and self._statuscolumn or "",
          { win = winnr }
        )
      end
    end,
  })
  return self
end

---@param bufnr                         integer
---@return era.view.picker.preview.IDrawResult
function M:_draw(bufnr)
  local lines, maximum = {}, 0
  for _, row in ipairs(self._rows) do
    lines[#lines + 1] = row.text
    maximum = math.max(maximum, row.old_lnum or 0, row.new_lnum or 0)
  end
  local digits = math.max(2, #tostring(maximum))
  local gutter = "%%#%s# %" .. digits .. "s %" .. digits .. "s %%#%s#%s "
  self._gutter, self._gutter_width = {}, maximum > 0 and 2 * digits + 5 or 0
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
  for index, row in ipairs(self._rows) do
    local added, removed = row.kind == "add", row.kind == "delete"
    local hunk = row.kind == "hunk"
    local highlight = added and "m_gf_diff_add_nr"
      or removed and "m_gf_diff_del_nr"
      or hunk and "m_gf_diff_hunk"
      or "LineNr"
    local background = added and "DiffAddRight" or removed and "DiffDelRight" or hunk and "m_gf_diff_hunk"
    self._gutter[index] = string.format(
      gutter,
      highlight,
      row.old_lnum and tostring(row.old_lnum) or "",
      row.new_lnum and tostring(row.new_lnum) or "",
      background or "LineNr",
      added and "+" or removed and "-" or " "
    )
    if background then
      vim.api.nvim_buf_set_extmark(bufnr, namespace, index - 1, 0, {
        hl_group = background,
        end_row = index,
        end_col = 0,
        hl_eol = true,
        priority = hunk and 140 or 90,
      })
      for _, word in ipairs(row.words or {}) do
        local first, last = added and word.new_start or word.old_start, added and word.new_end or word.old_end
        if last > first then
          -- Word diff already supplies exact, zero-based byte ranges.
          vim.api.nvim_buf_set_extmark(bufnr, namespace, index - 1, first, {
            hl_group = added and "DiffWordRight" or "DiffWordLeft",
            end_row = index - 1,
            end_col = last,
            priority = 130,
          })
        end
      end
    elseif row.kind == "info" then
      vim.hl.range(bufnr, namespace, "Comment", { index - 1, 0 }, { index - 1, #row.text })
    end
    if row.missing_newline then
      vim.api.nvim_buf_set_extmark(bufnr, namespace, index - 1, 0, {
        virt_text = { { "  No newline at end of file", "Comment" } },
        virt_text_pos = "eol",
      })
    end
  end

  local filetype = maximum > 0 and self._entry and stl.filetype.detect(self._entry.path) or ""
  if self._syntax_bufnr ~= bufnr or self._filetype ~= filetype then
    vim.treesitter.stop(bufnr)
    vim.api.nvim_set_option_value("syntax", "", { buf = bufnr })
    if filetype ~= "" then
      local lang = vim.treesitter.language.get_lang(filetype) or filetype
      if not pcall(vim.treesitter.start, bufnr, lang) then
        vim.api.nvim_set_option_value("syntax", filetype, { buf = bufnr })
      end
    end
    self._syntax_bufnr, self._filetype = bufnr, filetype
  end
  return {
    title = self._title,
    cursorline = false,
    number = maximum > 0,
    wrap = false,
    whitespaces = false,
    lnum = 1,
    col = 0,
  }
end

---@param root                          ?string
---@param entry                         ?era.view.git_files.IMetadata
---@param force                         ?boolean
---@return nil
function M:update(root, entry, force)
  if self._disposed then
    return
  end
  if not force and self._root == root and self._entry == entry then
    return
  end
  if self._token then
    self._token:cancel()
    self._token = nil
  end
  self._root, self._entry, self._epoch = root, entry, self._epoch + 1
  if entry and entry.path then
    local side = entry.scope == "staged" and "Staged" or "Unstaged"
    self._title = side .. " · " .. vim.fn.strtrans(entry.path)
    self._rows = { { kind = "info", text = "Loading diff…" } }
  else
    self._title, self._rows = "Diff preview", { { kind = "info", text = "Select a file to preview its diff." } }
  end
  self.surface:mark_content_dirty()
end

---The surface debounces draw; Git only starts for a visible, settled cursor target.
---@return nil
function M:_start()
  local root, entry, epoch = self._root, self._entry, self._epoch
  if not root or not entry or not entry.path or self._requested == epoch or not self.surface:isvisible() then
    return
  end
  self._requested = epoch
  local token = stl.c.CancellationToken.new()
  self._token = token
  local command = {
    "git",
    "-C",
    yoz.canonical_path.to_os_path(root),
    "--no-optional-locks",
    "--literal-pathspecs",
    "diff",
    "--no-ext-diff",
    "--no-textconv",
    "--no-color",
    "--unified=3",
  }
  local untracked = entry.status == "?"
  if untracked then
    vim.list_extend(command, { "--no-index", "--", jit.os == "Windows" and "NUL" or "/dev/null", entry.path })
  else
    if entry.scope == "staged" then
      command[#command + 1] = "--cached"
    end
    vim.list_extend(command, { "--", entry.path })
    if entry.previous and entry.status:find("R", 1, true) then
      command[#command + 1] = entry.previous
    end
  end
  local output, truncated = "", false
  local limit = 256 * 1024
  local process = vim.system(command, {
    text = false,
    timeout = 10000,
    stdout = function(_, data)
      if data then
        local available = limit - #output
        truncated = truncated or #data > available
        output = output .. data:sub(1, available)
      end
    end,
  }, function(result)
    vim.schedule(function()
      if
        self._token ~= token
        or token:is_cancelled()
        or not self.surface:isvisible()
        or root ~= dot.path.workspace()
      then
        return
      end
      self._token = nil
      if result.code ~= 0 and not (untracked and result.code == 1) then
        self._rows =
          { { kind = "info", text = "Diff unavailable: " .. vim.fn.strtrans(result.stderr or "Git failed") } }
      else
        if truncated then
          output = output:match("^(.*)\n") or ""
        end
        local lines = vim.split(output, "\n", { plain = true })
        if lines[#lines] == "" then
          lines[#lines] = nil
        end
        if #lines > 4000 then
          lines = vim.list_slice(lines, 1, 4000)
          truncated = true
        end
        self._rows = Diff.parse(lines, truncated)
      end
      self.surface:mark_content_dirty()
    end)
  end)
  token:on_cancel(function()
    pcall(process.kill, process, 9)
  end)
end

---@return nil
function M:hide()
  self:update(nil, nil, true)
  self.surface:hide()
end

---@return nil
function M:dispose()
  if self._disposed then
    return
  end
  self._disposed = true
  if self._token then
    self._token:cancel()
    self._token = nil
  end
  self.surface:dispose()
  self._unregister()
end

return M
