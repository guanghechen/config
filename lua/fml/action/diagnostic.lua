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
  vim.cmd.cnext()
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
  vim.cmd.cprev()
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
    vim.notify("No diagnostics found", vim.log.levels.INFO)
    return
  end

  local severity_names = {
    [vim.diagnostic.severity.ERROR] = "Error",
    [vim.diagnostic.severity.WARN] = "Warning",
    [vim.diagnostic.severity.INFO] = "Info",
    [vim.diagnostic.severity.HINT] = "Hint",
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
  table.insert(lines, string.format("Total diagnostics: %d", #diagnostics))
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
          local relative_path = vim.fn.fnamemodify(filename, ":.")
          local line_num = diagnostic.lnum + 1
          local col_num = diagnostic.col + 1

          table.insert(lines, string.format("### %s:%d:%d", relative_path, line_num, col_num))
          table.insert(lines, "")

          if diagnostic.source then
            table.insert(lines, string.format("**Source:** %s", diagnostic.source))
          end

          if diagnostic.code then
            table.insert(lines, string.format("**Code:** %s", diagnostic.code))
          end

          table.insert(lines, string.format("**Message:** %s", diagnostic.message))
          table.insert(lines, "")

          if vim.api.nvim_buf_is_valid(bufnr) then
            local file_lines = vim.api.nvim_buf_get_lines(bufnr, diagnostic.lnum, diagnostic.lnum + 1, false)
            if #file_lines > 0 then
              table.insert(lines, "**Context:**")
              table.insert(lines, "```")
              table.insert(lines, file_lines[1])
              table.insert(lines, "```")
              table.insert(lines, "")
            end
          end
        end
      end
    end
  end

  local content = table.concat(lines, "\n")
  std.reporter.info({
    from = __module_name__,
    subject = "Diagnostics To Markdown",
    message = string.format("````markdown\n%s\n````", content),
  })
end

return M
