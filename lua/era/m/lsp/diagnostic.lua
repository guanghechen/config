---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.lsp.diagnostic" ---@type string

local DEBOUNCE_MS = 50 ---@type integer

---@param bufnr                          integer
---@return era.m.lsp.diagnostic.IBufferDiagnostics
local function new_buffer(bufnr)
  return { bufnr = bufnr, error = 0, warn = 0, info = 0, hint = 0 }
end

---@param a                              era.m.lsp.diagnostic.IBufferDiagnostics
---@param b                              era.m.lsp.diagnostic.IBufferDiagnostics
---@return boolean
local function equals_buffer(a, b)
  return a.error == b.error and a.warn == b.warn and a.info == b.info and a.hint == b.hint
end

---@param bufnr                          integer
---@return boolean
local function is_file_buffer(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end
  local bufname = vim.api.nvim_buf_get_name(bufnr) ---@type string
  return bufname ~= "" and not vim.startswith(bufname, "term://")
end

---@type era.m.lsp.diagnostic.IBufferDiagnostics
local EMPTY_BUFFER = new_buffer(-1)

---@param data                           era.m.lsp.diagnostic.IBufferDiagnostics
---@param diagnostic                    vim.Diagnostic
---@return nil
local function add_diagnostic(data, diagnostic)
  local severity = diagnostic.severity ---@type vim.diagnostic.Severity
  if severity == vim.diagnostic.severity.ERROR then
    data.error = data.error + 1
  elseif severity == vim.diagnostic.severity.WARN then
    data.warn = data.warn + 1
  elseif severity == vim.diagnostic.severity.INFO then
    data.info = data.info + 1
  elseif severity == vim.diagnostic.severity.HINT then
    data.hint = data.hint + 1
  end
end

---@param bufnr                          integer
---@return era.m.lsp.diagnostic.IBufferDiagnostics|nil
local function collect_buffer(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return nil
  end

  local data = new_buffer(bufnr) ---@type era.m.lsp.diagnostic.IBufferDiagnostics
  if not is_file_buffer(bufnr) then
    return data
  end

  local diagnostics = vim.diagnostic.get(bufnr) ---@type vim.Diagnostic[]
  for _, diagnostic in ipairs(diagnostics) do
    add_diagnostic(data, diagnostic)
  end
  return data
end

---@class era.m.lsp.diagnostic.IStoreProps
---@field public debounce_ms            integer
---@field public on_change              fun(): nil Called once per refresh that changed any buffer's counts.

---Diagnostic counts per file buffer. Single-buffer refreshes are batched over `debounce_ms`.
---@class era.m.lsp.diagnostic.Store
---@field protected _buffers            table<integer, era.m.lsp.diagnostic.IBufferDiagnostics>
---@field protected _keys               table<integer, { name: string, key: string }> Normalized names of buffers with counts, computed again whenever a buffer's name changes.
---@field protected _on_change          fun(): nil
---@field protected _pending            table<integer, boolean>
---@field protected _refresh_pending    stl.timer.IDisposableCallable
local Store = {}
Store.__index = Store

---@param props                          era.m.lsp.diagnostic.IStoreProps
---@return era.m.lsp.diagnostic.Store
function Store.new(props)
  local self = setmetatable({}, Store)
  self._buffers = {}
  self._keys = {}
  self._on_change = props.on_change
  self._pending = {}
  self._refresh_pending = stl.timer.debounce(function()
    self:__refresh_pending__()
  end, props.debounce_ms)
  return self
end

-- The one writer of the per-buffer counts.
---@param bufnr                          integer
---@param next_data                      era.m.lsp.diagnostic.IBufferDiagnostics|nil
---@return boolean changed
function Store:__apply__(bufnr, next_data)
  local prev_counts = self._buffers[bufnr] or EMPTY_BUFFER ---@type era.m.lsp.diagnostic.IBufferDiagnostics
  self._buffers[bufnr] = next_data
  return not equals_buffer(prev_counts, next_data or EMPTY_BUFFER)
end

---@param bufnr                          integer
---@return string
function Store:__key__(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr) ---@type string
  local cached = self._keys[bufnr]
  if cached == nil or cached.name ~= name then
    cached = { name = name, key = stl.nvim.buf.normalize_bufpath(name) }
    self._keys[bufnr] = cached
  end
  return cached.key
end

---@return nil
function Store:__refresh_pending__()
  local bufnrs = self._pending ---@type table<integer, boolean>
  self._pending = {}

  local changed = false ---@type boolean
  for bufnr in pairs(bufnrs) do
    changed = self:__apply__(bufnr, collect_buffer(bufnr)) or changed
  end
  if changed then
    self._on_change()
  end
end

---Queues `bufnr` for the next batched refresh.
---@param bufnr                          integer
---@return nil
function Store:refresh(bufnr)
  self._pending[bufnr] = true
  self._refresh_pending()
end

---Counts every buffer again now.
---@return nil
function Store:refresh_all()
  local next_buffers = {} ---@type table<integer, era.m.lsp.diagnostic.IBufferDiagnostics>
  local diagnostics = vim.diagnostic.get() ---@type vim.Diagnostic[]
  for _, diagnostic in ipairs(diagnostics) do
    local bufnr = diagnostic.bufnr ---@type integer|nil
    if bufnr ~= nil and is_file_buffer(bufnr) then
      local data = next_buffers[bufnr] ---@type era.m.lsp.diagnostic.IBufferDiagnostics|nil
      if data == nil then
        data = new_buffer(bufnr)
        next_buffers[bufnr] = data
      end
      add_diagnostic(data, diagnostic)
    end
  end

  local bufnrs = {} ---@type table<integer, boolean>
  for bufnr in pairs(self._buffers) do
    bufnrs[bufnr] = true
  end
  for bufnr in pairs(next_buffers) do
    bufnrs[bufnr] = true
  end

  local changed = false ---@type boolean
  for bufnr in pairs(bufnrs) do
    local next_data = next_buffers[bufnr] ---@type era.m.lsp.diagnostic.IBufferDiagnostics|nil
    if next_data == nil and vim.api.nvim_buf_is_valid(bufnr) then
      next_data = new_buffer(bufnr)
    end
    changed = self:__apply__(bufnr, next_data) or changed
  end
  if changed then
    self._on_change()
  end
end

---Drops a deleted buffer's counts and its queued refresh.
---@param bufnr                          integer
---@return nil
function Store:forget(bufnr)
  self._pending[bufnr] = nil
  self._keys[bufnr] = nil
  if self:__apply__(bufnr, nil) then
    self._on_change()
  end
end

---@param bufnr                          integer
---@return era.m.lsp.diagnostic.IBufferDiagnostics
function Store:get(bufnr)
  return self._buffers[bufnr] or EMPTY_BUFFER
end

-- Only buffers with counts render anything, so a path is compared with their current names alone rather
-- than located among every buffer, which result lists do for each of their files.
---@param filepath                       string
---@return era.m.lsp.diagnostic.IBufferDiagnostics|nil
function Store:find(filepath)
  -- Windows names also match case-insensitively, so several buffers can match; the full lookup decides.
  if stl.env.IS_WIN then
    local bufnr = stl.nvim.buf.locate_bufnr(filepath) ---@type integer|nil
    return bufnr ~= nil and self._buffers[bufnr] or nil
  end

  local key = stl.nvim.buf.normalize_bufpath(filepath) ---@type string
  if key == "" then
    return nil
  end
  for bufnr, data in pairs(self._buffers) do
    if data.error + data.warn + data.hint + data.info > 0 and vim.api.nvim_buf_is_valid(bufnr) then
      if self:__key__(bufnr) == key then
        return data
      end
    end
  end
  return nil
end

---@return nil
function Store:dispose()
  self._refresh_pending:dispose()
  self._pending = {}
end

-- Rendered in this order, each with its own highlight.
local PARTS = {
  { field = "error", icon = "Error_alt", hlname = "f_lsp_diagnostic_error" },
  { field = "warn", icon = "Warning_alt", hlname = "f_lsp_diagnostic_warn" },
  { field = "hint", icon = "Hint_alt", hlname = "f_lsp_diagnostic_hint" },
  { field = "info", icon = "Information_alt", hlname = "f_lsp_diagnostic_info" },
}

---@class era.m.lsp.diagnostic
local M = {}

M.Store = Store

local default = Store.new({
  debounce_ms = DEBOUNCE_MS,
  on_change = function()
    dot.state.status.dirtier_statusline:mark_dirty()
    dot.state.status.dirtier_tabline:mark_dirty()
  end,
})

---Counts as text placed at `offset`, appending a highlight for each nonzero count.
---@param data                           era.m.lsp.diagnostic.IBufferDiagnostics
---@param offset                         integer
---@param highlights                     stl.t.IHighlightInline[]
---@return string
function M.format(data, offset, highlights)
  local text = "" ---@type string
  for _, part in ipairs(PARTS) do
    local count = data[part.field] ---@type integer
    if count > 0 then
      local piece = " " .. stl.icon.diagnostic[part.icon] .. " " .. count ---@type string
      highlights[#highlights + 1] = { coll = offset + #text, colr = offset + #text + #piece, hlname = part.hlname }
      text = text .. piece
    end
  end
  return text
end

---@param filepath                       string
---@param offset                         integer
---@param highlights                     stl.t.IHighlightInline[]
---@return string
function M.render(filepath, offset, highlights)
  local data = default:find(filepath) ---@type era.m.lsp.diagnostic.IBufferDiagnostics|nil
  return data ~= nil and M.format(data, offset, highlights) or ""
end

---@param bufnr                          integer
---@return era.m.lsp.diagnostic.IBufferDiagnostics
function M.get_by_bufnr(bufnr)
  return default:get(bufnr)
end

---@return nil
function M.setup()
  local augroup = stl.nvim.fn.augroup(__module_name__) ---@type integer

  vim.api.nvim_create_autocmd("DiagnosticChanged", {
    group = augroup,
    callback = function(args)
      default:refresh(args.buf)
    end,
  })

  vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
    group = augroup,
    callback = function(args)
      default:forget(args.buf)
    end,
  })

  default:refresh_all()
end

----------------------------------------------------------------------------------------------------
-- Navigation
----------------------------------------------------------------------------------------------------

---@return nil
function M.goto_next()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.diagnostic.jump({ winid = winnr, count = 1 })
end

---@return nil
function M.goto_next_error()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.diagnostic.jump({ severity = vim.diagnostic.severity.ERROR, winid = winnr, count = 1 })
end

---@return nil
function M.goto_next_hint()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.diagnostic.jump({ severity = vim.diagnostic.severity.HINT, winid = winnr, count = 1 })
end

---@return nil
function M.goto_next_info()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.diagnostic.jump({ severity = vim.diagnostic.severity.INFO, winid = winnr, count = 1 })
end

---@return nil
function M.goto_next_quickfix()
  vim.cmd("cnext")
end

---@return nil
function M.goto_next_warn()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.diagnostic.jump({ severity = vim.diagnostic.severity.WARN, winid = winnr, count = 1 })
end

---@return nil
function M.goto_prev()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.diagnostic.jump({ winid = winnr, count = -1 })
end

---@return nil
function M.goto_prev_error()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.diagnostic.jump({ severity = vim.diagnostic.severity.ERROR, winid = winnr, count = -1 })
end

---@return nil
function M.goto_prev_hint()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.diagnostic.jump({ severity = vim.diagnostic.severity.HINT, winid = winnr, count = -1 })
end

---@return nil
function M.goto_prev_info()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.diagnostic.jump({ severity = vim.diagnostic.severity.INFO, winid = winnr, count = -1 })
end

---@return nil
function M.goto_prev_quickfix()
  vim.cmd("cprev")
end

---@return nil
function M.goto_prev_warn()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.diagnostic.jump({ severity = vim.diagnostic.severity.WARN, winid = winnr, count = -1 })
end

----------------------------------------------------------------------------------------------------
-- Display
----------------------------------------------------------------------------------------------------

---@return nil
function M.line()
  local _, winnr = vim.diagnostic.open_float({
    header = "diagnostic (line)",
    scope = "line",
    focus = true,
    focusable = true,
    border = "rounded",
    source = true,
  })

  vim.schedule(function()
    if winnr ~= nil and stl.nvim.win.is_valid(winnr) then
      vim.api.nvim_set_current_win(winnr)
    end
  end)
end

---@return nil
function M.to_md()
  local diagnostics = vim.diagnostic.get() ---@type vim.Diagnostic[]

  if #diagnostics == 0 then
    stl.reporter.info({
      from = __module_name__,
      subject = "to_md",
      message = "No diagnostics found",
    })
    return
  end

  local severity_names = {
    [vim.diagnostic.severity.ERROR] = "ERROR",
    [vim.diagnostic.severity.WARN] = "WARNING",
    [vim.diagnostic.severity.INFO] = "INFO",
    [vim.diagnostic.severity.HINT] = "HINT",
  }

  local severity_symbols = {
    [vim.diagnostic.severity.ERROR] = "❌",
    [vim.diagnostic.severity.WARN] = "⚠️",
    [vim.diagnostic.severity.INFO] = "ℹ️",
    [vim.diagnostic.severity.HINT] = "💡",
  }

  local grouped_diagnostics = {} ---@type table<integer, vim.Diagnostic[]>
  for _, diagnostic in ipairs(diagnostics) do
    local severity = diagnostic.severity
    if severity then
      if not grouped_diagnostics[severity] then
        grouped_diagnostics[severity] = {}
      end
      table.insert(grouped_diagnostics[severity], diagnostic)
    end
  end

  local lines = {} ---@type string[]
  table.insert(lines, "# Diagnostics Report")
  table.insert(lines, "")

  local summary = {}
  for severity = vim.diagnostic.severity.ERROR, vim.diagnostic.severity.HINT do
    local count = grouped_diagnostics[severity] and #grouped_diagnostics[severity] or 0
    if count > 0 then
      table.insert(summary, string.format("%s %d", severity_symbols[severity], count))
    end
  end
  table.insert(lines, string.format("**Summary**: %s | Total: %d", table.concat(summary, " • "), #diagnostics))
  table.insert(lines, "")

  for severity = vim.diagnostic.severity.ERROR, vim.diagnostic.severity.HINT do
    local severity_diagnostics = grouped_diagnostics[severity]
    if severity_diagnostics and #severity_diagnostics > 0 then
      table.insert(lines, string.format("## %s (%d)", severity_names[severity], #severity_diagnostics))
      table.insert(lines, "")

      for _, diagnostic in ipairs(severity_diagnostics) do
        local bufnr = diagnostic.bufnr
        if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
          local filename = vim.api.nvim_buf_get_name(bufnr)
          local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr }) or "text" ---@type string
          local relative_path = vim.fn.fnamemodify(filename, ":.")
          local line_num = diagnostic.lnum + 1
          local col_num = diagnostic.col + 1

          local metadata = {}
          if diagnostic.source then
            table.insert(metadata, diagnostic.source)
          end
          if diagnostic.code then
            table.insert(metadata, string.format("[%s]", diagnostic.code))
          end
          local meta_str = #metadata > 0 and string.format(" • %s", table.concat(metadata, " ")) or ""

          table.insert(
            lines,
            string.format("### %s %s:%d:%d%s", severity_symbols[severity], relative_path, line_num, col_num, meta_str)
          )
          table.insert(lines, "")
          table.insert(lines, string.format("**%s**", diagnostic.message))
          table.insert(lines, "")

          if vim.api.nvim_buf_is_valid(bufnr) then
            local context_start = math.max(0, diagnostic.lnum - 2)
            local context_end = math.min(vim.api.nvim_buf_line_count(bufnr), diagnostic.lnum + 3)
            local file_lines = vim.api.nvim_buf_get_lines(bufnr, context_start, context_end, false)

            if #file_lines > 0 then
              table.insert(lines, "- **Code Context:**")
              table.insert(lines, "")
              table.insert(lines, "  ```" .. filetype)

              for j, line in ipairs(file_lines) do
                local actual_line_num = context_start + j
                local marker = actual_line_num == line_num and "→" or " "
                table.insert(lines, string.format("  %s%3d │ %s", marker, actual_line_num, line))
              end

              table.insert(lines, "  ```")
              table.insert(lines, "")
            end
          end
        end
      end
    end
  end

  local content = table.concat(lines, "\n")
  stl.nvim.fn.copy(content)
  stl.reporter.info({
    from = __module_name__,
    subject = "to_md",
    message = content,
  })
end

return M
