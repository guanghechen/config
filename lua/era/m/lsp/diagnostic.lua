local __module_name__ = "era.m.lsp.diagnostic" ---@type string

local DEBOUNCE_MS = 50 ---@type integer

---@param data                           era.m.lsp.diagnostic.IBufferDiagnostics
---@return nil
local function reset_buffer(data)
  data.error = 0
  data.warn = 0
  data.info = 0
  data.hint = 0
  data.total = 0
end

---@param a                              era.m.lsp.diagnostic.IBufferDiagnostics
---@param b                              era.m.lsp.diagnostic.IBufferDiagnostics
---@return boolean
local function equals_buffer(a, b)
  return a.error == b.error and a.warn == b.warn and a.info == b.info and a.hint == b.hint
end

---@class era.m.lsp.diagnostic
local M = {}

---@type table<integer, era.m.lsp.diagnostic.IBufferDiagnostics>
M._buffers = {}

---@type stl.c.Subscribers
M._subscribers_all = stl.c.Subscribers.new()

---@type table<integer, stl.c.Subscribers>
M._subscribers_bufnr = {}

---@type integer
M._total_error = 0

---@type integer
M._total_warn = 0

---@type integer
M._total_info = 0

---@type integer
M._total_hint = 0

---@type stl.timer.IDisposableCallable
local refresh_debounced

---@param bufnr                          integer
---@return boolean
local function is_file_buffer(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end
  local bufname = vim.api.nvim_buf_get_name(bufnr) ---@type string
  return bufname ~= "" and not vim.startswith(bufname, "term://")
end

---@param bufnr                          integer
---@return era.m.lsp.diagnostic.IBufferDiagnostics
local function get_or_create_buffer(bufnr)
  local data = M._buffers[bufnr] ---@type era.m.lsp.diagnostic.IBufferDiagnostics|nil
  if data == nil then
    data = { bufnr = bufnr, error = 0, warn = 0, info = 0, hint = 0, total = 0 }
    M._buffers[bufnr] = data
  end
  return data
end

---@type era.m.lsp.diagnostic.IBufferDiagnostics
local EMPTY_BUFFER = { bufnr = -1, error = 0, warn = 0, info = 0, hint = 0, total = 0 }

local function do_refresh()
  local prev_totals = {
    error = M._total_error,
    warn = M._total_warn,
    info = M._total_info,
    hint = M._total_hint,
  }

  local changed_bufnrs = {} ---@type table<integer, { prev: era.m.lsp.diagnostic.IBufferDiagnostics, next: era.m.lsp.diagnostic.IBufferDiagnostics }>

  M._total_error = 0
  M._total_warn = 0
  M._total_info = 0
  M._total_hint = 0

  for bufnr, data in pairs(M._buffers) do
    changed_bufnrs[bufnr] = {
      prev = {
        bufnr = bufnr,
        error = data.error,
        warn = data.warn,
        info = data.info,
        hint = data.hint,
        total = data.total,
      },
      next = data,
    }
    reset_buffer(data)
  end

  local diagnostics = vim.diagnostic.get() ---@type vim.Diagnostic[]
  for _, diagnostic in ipairs(diagnostics) do
    local bufnr = diagnostic.bufnr ---@type integer|nil
    if bufnr ~= nil and is_file_buffer(bufnr) then
      local data = get_or_create_buffer(bufnr) ---@type era.m.lsp.diagnostic.IBufferDiagnostics
      if changed_bufnrs[bufnr] == nil then
        changed_bufnrs[bufnr] = {
          prev = { bufnr = bufnr, error = 0, warn = 0, info = 0, hint = 0, total = 0 },
          next = data,
        }
      end

      local severity = diagnostic.severity ---@type vim.diagnostic.Severity
      if severity == vim.diagnostic.severity.ERROR then
        data.error = data.error + 1
        M._total_error = M._total_error + 1
      elseif severity == vim.diagnostic.severity.WARN then
        data.warn = data.warn + 1
        M._total_warn = M._total_warn + 1
      elseif severity == vim.diagnostic.severity.INFO then
        data.info = data.info + 1
        M._total_info = M._total_info + 1
      elseif severity == vim.diagnostic.severity.HINT then
        data.hint = data.hint + 1
        M._total_hint = M._total_hint + 1
      end

      data.total = data.total + 1
    end
  end

  for bufnr, change in pairs(changed_bufnrs) do
    if not equals_buffer(change.prev, change.next) then
      local subscribers = M._subscribers_bufnr[bufnr] ---@type stl.c.Subscribers|nil
      if subscribers ~= nil then
        subscribers:notify(change.next)
      end
    end
  end

  local totals_changed = prev_totals.error ~= M._total_error
    or prev_totals.warn ~= M._total_warn
    or prev_totals.info ~= M._total_info
    or prev_totals.hint ~= M._total_hint

  if totals_changed or next(changed_bufnrs) ~= nil then
    M._subscribers_all:notify(nil)
    dot.state.status.dirtier_statusline:mark_dirty()
    dot.state.status.dirtier_tabline:mark_dirty()
  end
end

refresh_debounced = stl.timer.debounce(do_refresh, DEBOUNCE_MS)

---@param filepath                       string
---@param offset                         integer
---@param highlights                     stl.t.IHighlightInline[]
---@return string
function M.render(filepath, offset, highlights)
  local bufnr = stl.nvim.buf.locate_bufnr(filepath) ---@type integer|nil
  if bufnr == nil or bufnr < 1 then
    return ""
  end

  local data = M._buffers[bufnr] ---@type era.m.lsp.diagnostic.IBufferDiagnostics|nil
  if data == nil then
    return ""
  end

  local text = "" ---@type string

  if data.error > 0 then
    local part = " " .. stl.icon.diagnostic.Error_alt .. " " .. data.error ---@type string
    local offset_next = offset + #part ---@type integer
    text = text .. part ---@type string
    highlights[#highlights + 1] = { coll = offset, colr = offset_next, hlname = "f_lsp_diagnostic_error" }
    offset = offset_next
  end

  if data.warn > 0 then
    local part = " " .. stl.icon.diagnostic.Warning_alt .. " " .. data.warn ---@type string
    local offset_next = offset + #part ---@type integer
    text = text .. part ---@type string
    highlights[#highlights + 1] = { coll = offset, colr = offset_next, hlname = "f_lsp_diagnostic_warn" }
    offset = offset_next
  end

  if data.hint > 0 then
    local part = " " .. stl.icon.diagnostic.Hint_alt .. " " .. data.hint ---@type string
    local offset_next = offset + #part ---@type integer
    text = text .. part ---@type string
    highlights[#highlights + 1] = { coll = offset, colr = offset_next, hlname = "f_lsp_diagnostic_hint" }
    offset = offset_next
  end

  if data.info > 0 then
    local part = " " .. stl.icon.diagnostic.Information_alt .. " " .. data.info ---@type string
    local offset_next = offset + #part ---@type integer
    text = text .. part ---@type string
    highlights[#highlights + 1] = { coll = offset, colr = offset_next, hlname = "f_lsp_diagnostic_info" }
    offset = offset_next
  end

  return text
end

---@return integer
---@return integer
---@return integer
---@return integer
function M.get_totals()
  return M._total_error, M._total_warn, M._total_info, M._total_hint
end

---@param bufnr                          integer
---@return era.m.lsp.diagnostic.IBufferDiagnostics
function M.get_by_bufnr(bufnr)
  return M._buffers[bufnr] or EMPTY_BUFFER
end

---@param filepath                       string
---@return era.m.lsp.diagnostic.IBufferDiagnostics
function M.get_by_filepath(filepath)
  local bufnr = stl.nvim.buf.locate_bufnr(filepath) ---@type integer|nil
  if bufnr == nil or bufnr < 1 then
    return EMPTY_BUFFER
  end
  return M._buffers[bufnr] or EMPTY_BUFFER
end

---@param filepath                       string
---@param severity                       vim.diagnostic.Severity|nil
---@return boolean
function M.has_diagnostics(filepath, severity)
  local data = M.get_by_filepath(filepath) ---@type era.m.lsp.diagnostic.IBufferDiagnostics
  if severity == nil then
    return data.total > 0
  elseif severity == vim.diagnostic.severity.ERROR then
    return data.error > 0
  elseif severity == vim.diagnostic.severity.WARN then
    return data.warn > 0
  elseif severity == vim.diagnostic.severity.HINT then
    return data.hint > 0
  elseif severity == vim.diagnostic.severity.INFO then
    return data.info > 0
  end
  return false
end

---@return nil
function M.refresh()
  refresh_debounced()
end

---@param subscriber                     stl.c.ISubscriber
---@return stl.c.IUnsubscribable
function M.subscribe_all(subscriber)
  return M._subscribers_all:subscribe(subscriber)
end

---@param bufnr                          integer
---@param subscriber                     stl.c.ISubscriber
---@return stl.c.IUnsubscribable
function M.subscribe_bufnr(bufnr, subscriber)
  local subscribers = M._subscribers_bufnr[bufnr] ---@type stl.c.Subscribers|nil
  if subscribers == nil then
    subscribers = stl.c.Subscribers.new()
    M._subscribers_bufnr[bufnr] = subscribers
  end
  return subscribers:subscribe(subscriber)
end

---@return nil
function M.setup()
  local augroup = stl.nvim.fn.augroup(__module_name__) ---@type integer

  vim.api.nvim_create_autocmd("DiagnosticChanged", {
    group = augroup,
    callback = function()
      M.refresh()
    end,
  })

  vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
    group = augroup,
    callback = function(args)
      local bufnr = args.buf ---@type integer
      M._buffers[bufnr] = nil
      local subscribers = M._subscribers_bufnr[bufnr] ---@type stl.c.Subscribers|nil
      if subscribers ~= nil then
        subscribers:dispose()
        M._subscribers_bufnr[bufnr] = nil
      end
    end,
  })

  do_refresh()
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
          local filetype = vim.bo[bufnr].filetype or "text" ---@type string
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
