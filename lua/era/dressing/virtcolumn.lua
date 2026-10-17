---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.dressing.virtcolumn" ---@type string

---@class era.dressing.virtcolumn
local M = {}

---@class era.dressing.virtcolumn.config
local config = {
  nsnr = dot.var.nsnr.virtcolumn,
  virt_char = "╎",
  columns = { 100, 120 },
  hlgroups = { "h_virtcolumn_1", "h_virtcolumn_2" },
  priority = 10,
}

local initialized = false ---@type boolean
local enabled = false ---@type boolean

---@type table<string, boolean>
local DISABLED_BUFTYPES = {
  prompt = true,
  terminal = true,
  quickfix = true,
  help = true,
}

---@type table<string, boolean>
local DISABLED_FILETYPES = {
  [stl.filetype.BIGFILE] = true,
  [stl.filetype.DIFFVIEW_FILES] = true,
  [stl.filetype.DIFFVIEW_COMMITS] = true,
  [stl.filetype.EXPLORER] = true,
  [stl.filetype.FLASH_PROMPT] = true,
  [stl.filetype.GITCOMMIT] = true,
  [stl.filetype.IMAGE_VIEWER] = true,
  [stl.filetype.LSPINFO] = true,
  [stl.filetype.MASON] = true,
  [stl.filetype.NOTIFY] = true,
  [stl.filetype.QUICKFIX] = true,
  [stl.filetype.SELECT] = true,
  [stl.filetype.STARTUPTIME] = true,
  [stl.filetype.TERM] = true,
  [stl.filetype.TERM_MASK] = true,
  [stl.filetype.TEMP_VIEWER] = true,
  [stl.filetype.UX_CMDLINE] = true,
  [stl.filetype.UX_INPUT] = true,
  [stl.filetype.UX_MESSAGE_HISTORY] = true,
  [stl.filetype.UX_PICKER_FINDER] = true,
  [stl.filetype.UX_PICKER_PREVIEW] = true,
  [stl.filetype.UX_PICKER_RESULT] = false,
  [stl.filetype.UX_POPUPMENU] = true,
  [stl.filetype.UX_SEARCHER_FINDER] = true,
  [stl.filetype.UX_SEARCHER_PREVIEW] = true,
  [stl.filetype.UX_SEARCHER_RESULT] = false,
  [stl.filetype.WINPICKER_MASK] = true,
  [stl.filetype.WINSEP] = true,
}

---@class era.dressing.virtcolumn.IWindow
---@field public leftcol                integer
---@field public unicode                boolean

-- The window being drawn, set by on_win for its on_line calls.
local window = { leftcol = 0, unicode = false } ---@type era.dressing.virtcolumn.IWindow

-- Floating windows only draw guides while focused, so popups and previews stay clean.
---@param winnr                         integer
---@param bufnr                         integer
---@return boolean
local function on_win(winnr, bufnr)
  if not enabled then
    return false
  end
  if vim.api.nvim_win_get_config(winnr).relative ~= "" and winnr ~= vim.api.nvim_get_current_win() then
    return false
  end
  if DISABLED_BUFTYPES[vim.api.nvim_get_option_value("buftype", { buf = bufnr })] then
    return false
  end
  local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr }) ---@type string
  if DISABLED_FILETYPES[filetype] then
    return false
  end

  window.leftcol = vim.fn.getwininfo(winnr)[1].leftcol
  window.unicode = filetype == "markdown" or filetype == stl.filetype.NOTEPAD
  return true
end

-- Prose measures display cells; code measures bytes, which is cheaper and equal for ASCII.
---@param bufnr                         integer
---@param row                           integer
---@return nil
local function on_line(bufnr, row)
  local width ---@type integer
  if window.unicode then
    width = vim.api.nvim_strwidth(vim.api.nvim_buf_get_lines(bufnr, row, row + 1, true)[1])
  else
    width = vim.api.nvim_buf_get_offset(bufnr, row + 1) - vim.api.nvim_buf_get_offset(bufnr, row) - 1
  end

  for index, col in ipairs(config.columns) do
    local win_col = col - 1 - window.leftcol ---@type integer
    if width < col and win_col >= 0 then
      vim.api.nvim_buf_set_extmark(bufnr, config.nsnr, row, 0, {
        virt_text = { { config.virt_char, config.hlgroups[index] } },
        virt_text_win_col = win_col,
        hl_mode = "combine",
        priority = config.priority,
        ephemeral = true,
      })
    end
  end
end

-- Guides are drawn per screen line while Nvim redraws, so only rows that change are measured again.
---@return nil
function M.dressing()
  if initialized then
    return
  end
  initialized = true

  enabled = dot.context.flight.dressing_virtcolumn:snapshot()
  stl.fn.observe({ dot.context.flight.dressing_virtcolumn }, function()
    enabled = dot.context.flight.dressing_virtcolumn:snapshot()
    vim.api.nvim__redraw({ valid = false })
  end, true)

  vim.api.nvim_set_decoration_provider(config.nsnr, {
    on_win = function(_, winnr, bufnr)
      return on_win(winnr, bufnr)
    end,
    on_line = function(_, _, bufnr, row)
      on_line(bufnr, row)
    end,
  })
end

return M
