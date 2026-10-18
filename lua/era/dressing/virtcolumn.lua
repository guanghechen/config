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
---@field public tabstop                integer

-- The window being drawn, set by on_win for its on_line calls.
local window = { leftcol = 0, tabstop = 8 } ---@type era.dressing.virtcolumn.IWindow

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
  if DISABLED_FILETYPES[vim.api.nvim_get_option_value("filetype", { buf = bufnr })] then
    return false
  end

  window.leftcol = vim.fn.getwininfo(winnr)[1].leftcol
  window.tabstop = vim.api.nvim_get_option_value("tabstop", { buf = bufnr })
  return true
end

-- A tab advances to the next tabstop, and other characters take their display width.
---@param line                          string
---@param tabstop                       integer
---@return integer
local function display_width(line, tabstop)
  local width, start = 0, 1 ---@type integer, integer
  while true do
    local tab = line:find("\t", start, true) ---@type integer|nil
    width = width + vim.api.nvim_strwidth(line:sub(start, tab and tab - 1 or #line))
    if not tab then
      return width
    end
    width = width + tabstop - width % tabstop
    start = tab + 1
  end
end

---@param bufnr                         integer
---@param row                           integer
---@return nil
local function on_line(bufnr, row)
  local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, true)[1] ---@type string
  -- The bytes of ASCII text are its display cells, so only tabs and multibyte characters need measuring.
  local width = line:find("[\t\128-\255]") and display_width(line, window.tabstop) or #line ---@type integer

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
