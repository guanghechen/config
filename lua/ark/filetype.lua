---@class ark.filetype
local M = {}

M.AI_TERMINAL = "ai_terminal"
M.BIGFILE = "bigfile"
M.BOARD = "board"
M.CHECKHEALTH = "checkhealth"
M.DAP_FLOAT = "dap-float"
M.DAP_REPL = "dap-repl"
M.DAP_UI_BREAKPOINTS = "dapui_breakpoints"
M.DAP_UI_CONSOLE = "dapui_console"
M.DAP_UI_HOVER = "dapui_hover"
M.DAP_UI_SCOPES = "dapui_scopes"
M.DAP_UI_STACKS = "dapui_stacks"
M.DAP_UI_WATCHES = "dapui_watches"
M.DIFFVIEW_FILES = "DiffviewFiles"
M.DIFFVIEW_FILE_HISTORY = "DiffviewFileHistory"
M.EXPLORER = "explorer"
M.FLASH_PROMPT = "flash_prompt"
M.GITCOMMIT = "gitcommit"
M.HELP = "help"
M.IMAGE_VIEWER = "image-viewer"
M.LAZY = "lazy"
M.LSPINFO = "lspinfo"
M.MAN = "man"
M.MASON = "mason"
M.NOTIFY = "notify"
M.QUICKFIX = "qf"
M.SELECT = "select"
M.STARTUPTIME = "startuptime"
M.TERM = "term"
M.TERM_MASK = "term-mask"
M.TEMP_VIEWER = "temp-viewer"
M.UX_CMDLINE = "ux-cmdline"
M.UX_INPUT = "ux-input"
M.UX_MESSAGE_HISTORY = "ux-message-history"
M.NOTEPAD = "notepad"
M.UX_PICKER_FINDER = "ux-picker-finder"
M.UX_PICKER_PREVIEW = "ux-picker-preview"
M.UX_PICKER_RESULT = "ux-picker-result"
M.UX_POPUPMENU = "ux-popupmenu"
M.UX_SEARCHER_FINDER = "ux-searcher-finder"
M.UX_SEARCHER_PREVIEW = "ux-searcher-preview"
M.UX_SEARCHER_RESULT = "ux-searcher-result"
M.WINPICKER_MASK = "winpicker-mask"
M.WINSEP = "winsep"

---@class ark.filetype.filetypes
local filetypes = {
  -- stylua: ignore start
  code = {
    assembly         = true,
    bash             = true,
    clojure          = true,
    conf             = true,
    cpp              = true,
    csharp           = true,
    css              = true,
    dart             = true,
    dockerfile       = true,
    elixir           = true,
    erlang           = true,
    fish             = true,
    fortran          = true,
    fsharp           = true,
    go               = true,
    groovy           = true,
    haskell          = true,
    html             = true,
    ini              = true,
    java             = true,
    javascript       = true,
    javascriptreact  = true,
    json             = true,
    julia            = true,
    kotlin           = true,
    lua              = true,
    makefile         = true,
    markdown         = true,
    nim              = true,
    ['objective-c']  = true,
    pascal           = true,
    perl             = true,
    php              = true,
    powershell       = true,
    ps1              = true,
    python           = true,
    r                = true,
    ruby             = true,
    rust             = true,
    scala            = true,
    sh               = true,
    shell            = true,
    sql              = true,
    swift            = true,
    text             = true,
    tmux             = true,
    toml             = true,
    typescript       = true,
    typescriptreact  = true,
    vim              = true,
    vue              = true,
    xml              = true,
    yaml             = true,
  },
  -- stylua: ignore end
  cmp_others = {
    [M.UX_PICKER_FINDER] = true,
  },
  has_external_winline = {
    [M.DAP_REPL] = true,
    [M.DAP_UI_BREAKPOINTS] = true,
    [M.DAP_UI_CONSOLE] = true,
    [M.DAP_UI_SCOPES] = true,
    [M.DAP_UI_STACKS] = true,
    [M.DAP_UI_WATCHES] = true,
    [M.EXPLORER] = true,
    [M.NOTEPAD] = true,
  },
  hipattern = {},
  language = {
    -- stylua: ignore start
    assembly         = true,
    bash             = true,
    conf             = true,
    cpp              = true,
    csharp           = true,
    css              = true,
    dart             = true,
    dockerfile       = true,
    elixir           = true,
    erlang           = true,
    fish             = true,
    fortran          = true,
    fsharp           = true,
    go               = true,
    groovy           = true,
    haskell          = true,
    html             = true,
    ini              = true,
    java             = true,
    javascript       = true,
    javascriptreact  = true,
    json             = true,
    julia            = true,
    kotlin           = true,
    lua              = true,
    makefile         = true,
    markdown         = true,
    nim              = true,
    ['objective-c']  = true,
    pascal           = true,
    powershell       = true,
    ps1              = true,
    python           = true,
    rust             = true,
    scala            = true,
    sh               = true,
    shell            = true,
    sql              = true,
    swift            = true,
    tmux             = true,
    toml             = true,
    typescript       = true,
    typescriptreact  = true,
    vue              = true,
    xml              = true,
    yaml             = true,
    -- stylua: ignore end
  },
  markdown = {
    [M.IMAGE_VIEWER] = true,
    [M.NOTEPAD] = true,
    ["markdown"] = true,
  },
  not_sourcefile = {
    [M.AI_TERMINAL] = true,
    [M.BOARD] = true,
    [M.CHECKHEALTH] = true,
    [M.DAP_FLOAT] = true,
    [M.DAP_REPL] = true,
    [M.DAP_UI_BREAKPOINTS] = true,
    [M.DAP_UI_CONSOLE] = true,
    [M.DAP_UI_HOVER] = true,
    [M.DAP_UI_SCOPES] = true,
    [M.DAP_UI_STACKS] = true,
    [M.DAP_UI_WATCHES] = true,
    [M.DIFFVIEW_FILE_HISTORY] = true,
    [M.DIFFVIEW_FILES] = true,
    [M.EXPLORER] = true,
    [M.GITCOMMIT] = true,
    [M.HELP] = true,
    [M.IMAGE_VIEWER] = true,
    [M.LAZY] = true,
    [M.LSPINFO] = true,
    [M.MAN] = true,
    [M.MASON] = true,
    [M.NOTIFY] = true,
    [M.QUICKFIX] = true,
    [M.SELECT] = true,
    [M.STARTUPTIME] = true,
    [M.TEMP_VIEWER] = true,
    [M.TERM] = true,
    [M.TERM_MASK] = true,
    [M.UX_CMDLINE] = true,
    [M.UX_INPUT] = true,
    [M.UX_MESSAGE_HISTORY] = true,
    [M.UX_PICKER_FINDER] = true,
    [M.UX_PICKER_PREVIEW] = true,
    [M.UX_PICKER_RESULT] = true,
    [M.UX_SEARCHER_FINDER] = true,
    [M.UX_SEARCHER_PREVIEW] = true,
    [M.UX_SEARCHER_RESULT] = true,
    [M.UX_POPUPMENU] = true,
    [M.WINSEP] = true,
    [M.WINPICKER_MASK] = true,
  },
  no_flash = {
    [M.AI_TERMINAL] = true,
    [M.FLASH_PROMPT] = true,
    [M.IMAGE_VIEWER] = true,
    [M.NOTIFY] = true,
    [M.LSPINFO] = true,
    [M.WINSEP] = true,
    [M.WINPICKER_MASK] = true,
    [M.UX_CMDLINE] = true,
    [M.UX_POPUPMENU] = true,
  },
}

local extnames = {
  no_printable = {
    [".class"] = true,
    [".dll"] = true,
    [".jpeg"] = true,
    [".jpg"] = true,
    [".gz"] = true,
    [".jar"] = true,
    [".mkv"] = true,
    [".mp3"] = true,
    [".mp4"] = true,
    [".pdf"] = true,
    [".png"] = true,
    [".so"] = true,
    [".tar"] = true,
    [".xz"] = true,
    [".zip"] = true,
  },
  printable_without_extname = {
    ["config"] = true,
    ["license"] = true,
    ["readme"] = true,
    ["sshd_config"] = true,
  },
}

local BUFNR_DETECT_FILETYPE = -1 ---@type integer

---@return nil
local function cleanup_filetype_buffer()
  if BUFNR_DETECT_FILETYPE > 0 and vim.api.nvim_buf_is_valid(BUFNR_DETECT_FILETYPE) then
    vim.api.nvim_buf_delete(BUFNR_DETECT_FILETYPE, { force = true })
    BUFNR_DETECT_FILETYPE = -1
  end
end

---@param filename                      string
---@return string|nil
function M.detect(filename)
  if BUFNR_DETECT_FILETYPE < 1 or not vim.api.nvim_buf_is_valid(BUFNR_DETECT_FILETYPE) then
    BUFNR_DETECT_FILETYPE = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(BUFNR_DETECT_FILETYPE, "guanghechen://detect-filetype/" .. BUFNR_DETECT_FILETYPE)

    -- Set up cleanup when Neovim exits
    vim.api.nvim_create_autocmd("VimLeavePre", {
      callback = cleanup_filetype_buffer,
      once = true,
    })
  end
  return vim.filetype.match({ filename = filename, buf = BUFNR_DETECT_FILETYPE })
end

----------------------------------------------------------------------------------------------------

---@return string[]
function M.get_hipattern_filetypes()
  return vim.tbl_keys(filetypes.hipattern)
end

---@return string[]
function M.get_markdown_filetypes()
  return vim.tbl_keys(filetypes.markdown)
end

---@return string[]
function M.get_no_flash_filetypes()
  return vim.tbl_keys(filetypes.no_flash)
end

---@param filetype                      string|nil
---@return boolean
function M.has_external_winline(filetype)
  if filetype == nil or #filetype < 1 then
    return false
  end
  return filetypes.has_external_winline[filetype]
end

---@param filetype                      string|nil
---@return boolean
function M.is_cmp_enabled(filetype)
  if filetype == nil or #filetype < 1 then
    return false
  end
  if filetypes.code[filetype] or filetypes.cmp_others[filetype] then
    return true
  end
  return false
end

---@param filetype                      string|nil
---@return boolean
function M.is_language(filetype)
  if filetype == nil or #filetype < 1 then
    return false
  end
  return filetypes.language[filetype] == true
end

---@param filetype                      string|nil
---@return boolean
function M.is_not_sourcefile(filetype)
  if filetype == nil or #filetype < 1 then
    return false
  end
  return filetypes.not_sourcefile[filetype] == true
end

---@param filename                      string
---@return boolean
function M.is_printable_file(filename)
  filename = filename:lower() ---@type string
  local extname = filename:match("%.[^.]+$") or ""
  if extnames.no_printable[extname] then
    return false
  end

  if extname == "" then
    return extnames.printable_without_extname[filename] or false
  end

  return true
end

---@param filetype                      string|nil
---@return boolean
function M.is_sourcefile(filetype)
  if filetype == nil or #filetype < 1 then
    return false
  end
  return filetypes.not_sourcefile[filetype] ~= true
end

---@return string[]
function M.list_code_filetypes()
  return vim.tbl_keys(filetypes.code)
end

---@return string[]
function M.list_not_sourcefile_filetypes()
  return vim.tbl_keys(filetypes.not_sourcefile)
end

return M
