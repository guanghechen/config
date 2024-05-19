local context_config = require("ghc.core.context.config")
local icons = require("ghc.core.setting.icons")

---@type boolean
local transparency = context_config.transparency:get_snapshot()

--- @class ghc.ui.statusline.component.diagnostics
local M = {
  name = "ghc_statusline_diagnostics",
  color = {
    error = {
      fg = "red",
      bg = transparency and "none" or "statusline_bg",
    },
    warn = {
      fg = "yellow",
      bg = transparency and "none" or "statusline_bg",
    },
    hint = {
      fg = "nord_blue",
      bg = transparency and "none" or "statusline_bg",
    },
    info = {
      fg = "green",
      bg = transparency and "none" or "statusline_bg",
    },
  },
}

function M.condition()
  return not not rawget(vim, "lsp")
end

function M.renderer()
  ---@type number
  local bufnr = vim.api.nvim_win_get_buf(vim.g.statusline_winid or 0)

  local count_error = #vim.diagnostic.get(bufnr, { severity = vim.diagnostic.severity.ERROR })
  local count_warn = #vim.diagnostic.get(bufnr, { severity = vim.diagnostic.severity.WARN })
  local count_hint = #vim.diagnostic.get(bufnr, { severity = vim.diagnostic.severity.HINT })
  local count_info = #vim.diagnostic.get(bufnr, { severity = vim.diagnostic.severity.INFO })

  local color_error = "%#" .. M.name .. "_error#"
  local color_warn = "%#" .. M.name .. "_warn#"
  local color_hint = "%#" .. M.name .. "_hint#"
  local color_info = "%#" .. M.name .. "_info#"

  local text_error = (count_error and count_error > 0) and ("%#St_lspError#" .. icons.diagnostics.Error .. " " .. count_error .. " ") or ""
  local text_warn = (count_warn and count_warn > 0) and ("%#St_lspWarning#" .. icons.diagnostics.Warning .. " " .. count_warn .. " ") or ""
  local text_hint = (count_hint and count_hint > 0) and ("%#St_lspHints#" .. icons.diagnostics.Hint .. " " .. count_hint .. " ") or ""
  local text_info = (count_info and count_info > 0) and ("%#St_lspInfo#" .. icons.diagnostics.Information .. " " .. count_info .. " ") or ""
  return " " .. color_error .. text_error .. color_warn .. text_warn .. color_hint .. text_hint .. color_info .. text_info
end

return M
