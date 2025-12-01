local __module_name__ = "fml.dressing.virtcolumn" ---@type string

---@class fml.dressing.virtcolumn.config
local config = {
  nsnr = eve.var.nsnr.virtcolumn,
  virt_char = "╎",
  columns = { 100, 120 },
  hlgroups = { "h_virtcolumn_1", "h_virtcolumn_2" },
  priority = 10,
}

---@type table<string, boolean>
local DISABLED_BUFTYPES = {
  prompt = true,
  terminal = true,
  quickfix = true,
  help = true,
}

---@type table<string, boolean>
local DISABLED_FILETYPES = {
  [eve.filetype.BIGFILE] = true,
  [eve.filetype.DAP_FLOAT] = true,
  [eve.filetype.DAP_REPL] = true,
  [eve.filetype.DAP_UI_BREAKPOINTS] = true,
  [eve.filetype.DAP_UI_CONSOLE] = true,
  [eve.filetype.DAP_UI_HOVER] = true,
  [eve.filetype.DAP_UI_SCOPES] = true,
  [eve.filetype.DAP_UI_STACKS] = true,
  [eve.filetype.DAP_UI_WATCHES] = true,
  [eve.filetype.DIFFVIEW_FILES] = true,
  [eve.filetype.DIFFVIEW_FILE_HISTORY] = true,
  [eve.filetype.FLASH_PROMPT] = true,
  [eve.filetype.GITCOMMIT] = true,
  [eve.filetype.IMAGE_VIEWER] = true,
  [eve.filetype.LAZY] = true,
  [eve.filetype.MASON] = true,
  [eve.filetype.NEOTREE] = true,
  [eve.filetype.NEOTREE_POPUP] = true,
  [eve.filetype.NOTIFY] = true,
  [eve.filetype.LSPINFO] = true,
  [eve.filetype.PLENARY_TEST_POPUP] = true,
  [eve.filetype.QUICKFIX] = true,
  [eve.filetype.SELECT] = true,
  [eve.filetype.SIDEKICK_TERMINAL] = true,
  [eve.filetype.STARTUPTIME] = true,
  [eve.filetype.TERM] = true,
  [eve.filetype.TERM_MASK] = true,
  [eve.filetype.TEMP_VIEWER] = true,
  [eve.filetype.UX_CMDLINE] = true,
  [eve.filetype.UX_INPUT] = true,
  [eve.filetype.UX_MESSAGE_HISTORY] = true,
  [eve.filetype.UX_PICKER_FINDER] = true,
  [eve.filetype.UX_PICKER_PREVIEW] = true,
  [eve.filetype.UX_PICKER_RESULT] = false,
  [eve.filetype.UX_POPUPMENU] = true,
  [eve.filetype.UX_SEARCHER_FINDER] = true,
  [eve.filetype.UX_SEARCHER_PREVIEW] = true,
  [eve.filetype.UX_SEARCHER_RESULT] = false,
  [eve.filetype.WINPICKER_MASK] = true,
  [eve.filetype.WINSEP] = true,
}

---@param bufnr                         integer
---@param topline                       integer
---@param botline                       integer
---@return nil
local function render_ascii(bufnr, topline, botline)
  local leftcol = vim.fn.winsaveview().leftcol or 0
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  local endline = math.min(botline, line_count)
  local get_offset = vim.api.nvim_buf_get_offset

  for lnum = topline - 1, endline - 1 do
    vim.api.nvim_buf_clear_namespace(bufnr, config.nsnr, lnum, lnum + 1)

    local len = get_offset(bufnr, lnum + 1) - get_offset(bufnr, lnum) - 1 ---@type integer
    for i, col in ipairs(config.columns) do
      if len < col then
        vim.api.nvim_buf_set_extmark(bufnr, config.nsnr, lnum, 0, {
          virt_text = { { config.virt_char, config.hlgroups[i] } },
          hl_mode = "combine",
          virt_text_win_col = col - 1 - leftcol,
          priority = config.priority,
        })
      end
    end
  end
end

---@param bufnr                         integer
---@param topline                       integer
---@param botline                       integer
---@return nil
local function render_unicode(bufnr, topline, botline)
  local leftcol = vim.fn.winsaveview().leftcol or 0
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  local endline = math.min(botline, line_count)
  local lines = vim.api.nvim_buf_get_lines(bufnr, topline - 1, endline, false)
  local strwidth = vim.api.nvim_strwidth

  for idx, line in ipairs(lines) do
    local lnum = topline - 1 + idx - 1 ---@type integer
    vim.api.nvim_buf_clear_namespace(bufnr, config.nsnr, lnum, lnum + 1)

    local width = strwidth(line) ---@type integer
    for i, col in ipairs(config.columns) do
      if width < col then
        vim.api.nvim_buf_set_extmark(bufnr, config.nsnr, lnum, 0, {
          virt_text = { { config.virt_char, config.hlgroups[i] } },
          hl_mode = "combine",
          virt_text_win_col = col - 1 - leftcol,
          priority = config.priority,
        })
      end
    end
  end
end

---@return nil
local function refresh()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  if not vim.api.nvim_buf_is_loaded(bufnr) then
    return
  end

  local buftype = vim.bo[bufnr].buftype ---@type string
  if DISABLED_BUFTYPES[buftype] then
    return
  end

  local filetype = vim.bo[bufnr].filetype ---@type string
  if DISABLED_FILETYPES[filetype] then
    return
  end

  local info = vim.fn.getwininfo(winnr)[1]
  if info == nil then
    return
  end

  local topline = info.topline ---@type integer
  local botline = info.botline ---@type integer
  local height = info.height or 0 ---@type integer
  local extend = math.floor(height * 0.4) ---@type integer

  local offset = math.max(0, topline - extend) + 1 ---@type integer
  local endline = botline + extend ---@type integer

  if filetype == "markdown" then
    render_unicode(bufnr, offset, endline)
  else
    render_ascii(bufnr, offset, endline)
  end
end

---@type std.collection.Scheduler
local scheduler = std.Scheduler.new({
  name = __module_name__,
  mode = "debounce",
  delay = 50,
  timeout = 0,
  silent = std.fn.falsy,
  value = std.Observable.from_value(true),
  task = function()
    local enabled = eve.context.flight.dressing_virtcolumn:snapshot()
    if enabled then
      refresh()
    end
  end,
})

std.fn.observe({ eve.context.flight.dressing_virtcolumn }, function()
  local enabled = eve.context.flight.dressing_virtcolumn:snapshot() ---@type boolean
  if not enabled then
    local bufnrs = vim.api.nvim_list_bufs() ---@type integer[]
    for _, bufnr in ipairs(bufnrs) do
      vim.api.nvim_buf_clear_namespace(bufnr, config.nsnr, 0, -1)
    end
    return
  end

  scheduler:schedule()
end, true)

vim.api.nvim_create_autocmd({
  "WinScrolled",
  "WinResized",
  "TextChanged",
  "TextChangedI",
  "WinEnter",
  "BufWinEnter",
  "BufRead",
  "InsertLeave",
  "InsertEnter",
  "FileType",
  "CursorHold",
}, {
  group = eve.nvim.augroup("virtcolumn_refresh"),
  callback = function()
    scheduler:schedule({})
  end,
})
