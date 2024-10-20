---@type t.fml.ux.nvimbar.IRawComponent
local M = {
  name = "diagnostics",
  condition = function()
    return not not rawget(vim, "lsp")
  end,
  render = function(context)
    local count_error = #vim.diagnostic.get(context.bufnr, { severity = vim.diagnostic.severity.ERROR })
    local text_count_error = count_error > 0 and eve.icons.diagnostics.Error .. " " .. count_error .. " " or ""

    local count_warn = #vim.diagnostic.get(context.bufnr, { severity = vim.diagnostic.severity.WARN })
    local text_count_warn = count_warn > 0 and eve.icons.diagnostics.Warning .. " " .. count_warn .. " " or ""

    local count_hint = #vim.diagnostic.get(context.bufnr, { severity = vim.diagnostic.severity.HINT })
    local text_count_hint = count_hint > 0 and eve.icons.diagnostics.Hint .. " " .. count_hint .. " " or ""

    local count_info = #vim.diagnostic.get(context.bufnr, { severity = vim.diagnostic.severity.INFO })
    local text_count_info = count_info > 0 and eve.icons.diagnostics.Information .. " " .. count_info .. " " or ""

    local text_hl = eve.nvimbar.txt(text_count_error, "f_sl_diagnostics_error")
        .. eve.nvimbar.txt(text_count_warn, "f_sl_diagnostics_warn")
        .. eve.nvimbar.txt(text_count_hint, "f_sl_diagnostics_hint")
        .. eve.nvimbar.txt(text_count_info, "f_sl_diagnostics_info")
    local width = vim.api.nvim_strwidth(text_count_error)
        + vim.api.nvim_strwidth(text_count_warn)
        + vim.api.nvim_strwidth(text_count_hint)
        + vim.api.nvim_strwidth(text_count_info)

    return text_hl, width
  end,
}

return M
