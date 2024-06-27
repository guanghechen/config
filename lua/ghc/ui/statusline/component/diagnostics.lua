---@type fml.types.core.statusline.IRawComponent
local M = {
  name = "diagnostics",
  condition = function()
    return not not rawget(vim, "lsp")
  end,
  pieces = {
    {
      hlname = function()
        return "f_sl_diagnostics_error"
      end,
      text = function(context)
        local count_error = #vim.diagnostic.get(context.bufnr, { severity = vim.diagnostic.severity.ERROR })
        return count_error > 0 and fml.ui.icons.diagnostics.Error .. " " .. count_error .. " " or ""
      end,
    },
    {
      hlname = function()
        return "f_sl_diagnostics_warn"
      end,
      text = function(context)
        local count_warn = #vim.diagnostic.get(context.bufnr, { severity = vim.diagnostic.severity.WARN })
        return count_warn > 0 and fml.ui.icons.diagnostics.Warning .. " " .. count_warn .. " " or ""
      end,
    },
    {
      hlname = function()
        return "f_sl_diagnostics_hint"
      end,
      text = function(context)
        local count_hint = #vim.diagnostic.get(context.bufnr, { severity = vim.diagnostic.severity.HINT })
        return count_hint > 0 and fml.ui.icons.diagnostics.Hint .. " " .. count_hint .. " " or ""
      end,
    },
    {
      hlname = function()
        return "f_sl_diagnostics_info"
      end,
      text = function(context)
        local count_info = #vim.diagnostic.get(context.bufnr, { severity = vim.diagnostic.severity.INFO })
        return count_info > 0 and fml.ui.icons.diagnostics.Information .. " " .. count_info .. " " or ""
      end,
    },
  },
}

return M
