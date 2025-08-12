local __module_name__ = "fml.action.diagnostic" ---@type string

---@class fml.action.diagnostic
local M = {}

---@return nil
function M.goto_next()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.diagnostic.jump({ win_id = winnr, count = 1 })
end

---@return nil
function M.goto_next_error()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.diagnostic.jump({ severity = vim.diagnostic.severity.ERROR, win_id = winnr, count = 1 })
end

---@return nil
function M.goto_next_warn()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.diagnostic.jump({ severity = vim.diagnostic.severity.WARN, win_id = winnr, count = 1 })
end

---@return nil
function M.goto_next_hint()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.diagnostic.jump({ severity = vim.diagnostic.severity.HINT, win_id = winnr, count = 1 })
end

---@return nil
function M.goto_next_info()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.diagnostic.jump({ severity = vim.diagnostic.severity.INFO, win_id = winnr, count = 1 })
end

---@return nil
function M.goto_next_quickfix()
  vim.cmd("cnext")
end

---@return nil
function M.goto_prev()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.diagnostic.jump({ win_id = winnr, count = -1 })
end

---@return nil
function M.goto_prev_error()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.diagnostic.jump({ severity = vim.diagnostic.severity.ERROR, win_id = winnr, count = -1 })
end

---@return nil
function M.goto_prev_warn()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.diagnostic.jump({ severity = vim.diagnostic.severity.WARN, win_id = winnr, count = -1 })
end

---@return nil
function M.goto_prev_hint()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.diagnostic.jump({ severity = vim.diagnostic.severity.HINT, win_id = winnr, count = -1 })
end

---@return nil
function M.goto_prev_info()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.diagnostic.jump({ severity = vim.diagnostic.severity.INFO, win_id = winnr, count = -1 })
end

---@return nil
function M.goto_prev_quickfix()
  vim.cmd("cprev")
end

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
    if winnr ~= nil and eve.win.is_valid(winnr) then
      vim.api.nvim_set_current_win(winnr)
    end
  end)
end

---@return nil
function M.to_md()
  local diagnostics = vim.diagnostic.get() ---@type vim.Diagnostic[]

  if #diagnostics == 0 then
    std.reporter.info({
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
  pcall(vim.fn.setreg, "+", content)
  std.reporter.info({
    from = __module_name__,
    subject = "to_md",
    message = content,
  })
end

return M
