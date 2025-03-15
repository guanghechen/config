---@class eve.builtin.filetype
local M = {}

M.AERIAL = "aerial"
M.AVANTE = "Avante"
M.AVANTE_INPUT = "AvanteInput"
M.AVANTE_SELECTED_FILES = "AvanteSelectedFiles"
M.BIGFILE = "bigfile"
M.COPILOT_CHAT = "copilot-chat"
M.CMP_MENU = "cmp_menu"
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
M.FLASH_PROMPT = "flash_prompt"
M.GITCOMMIT = "gitcommit"
M.HELP = "help"
M.LAZY = "lazy"
M.MAN = "man"
M.MASON = "mason"
M.NEOTREE = "neo-tree"
M.NEOTREE_POPUP = "neo-tree-popup"
M.NOICE = "noice"
M.NOTIFY = "notify"
M.LSPINFO = "lspinfo"
M.PLENARY_TEST_POPUP = "PlenaryTestPopup"
M.QUICKFIX = "qf"
M.SEARCH_INPUT = "search-input"
M.SEARCH_MAIN = "search-main"
M.SEARCH_PREVIEW = "search-preview"
M.SMEAR_CURSOR = "smear-cursor"
M.STARTUPTIME = "startuptime"
M.TERM = "term"
M.TEMP_VIEWER = "temp-viewer"
M.TROUBLE = "Trouble"
M.UX_INPUT = "ux-input"
M.WINPICKER_MASK = "winpicker-mask"
M.WINSEP = "winsep"
M.YOZORA_VIEWER = "yozora-viewer"

---@type table<string, table<string, true>>
local filetypes = {
  -- stylua: ignore 
  cmp_code = {
    ["assembly"]         = true,
    ["bash"]             = true,
    ["clojure"]          = true,
    ["conf"]             = true,
    ["cpp"]              = true,
    ["csharp"]           = true,
    ["css"]              = true,
    ["dart"]             = true,
    ["dockerfile"]       = true,
    ["elixir"]           = true,
    ["erlang"]           = true,
    ["fortran"]          = true,
    ["fsharp"]           = true,
    ["go"]               = true,
    ["groovy"]           = true,
    ["haskell"]          = true,
    ["html"]             = true,
    ["ini"]              = true,
    ["java"]             = true,
    ["javascript"]       = true,
    ["javascriptreact"]  = true,
    ["json"]             = true,
    ["julia"]            = true,
    ["kotlin"]           = true,
    ["lua"]              = true,
    ["makefile"]         = true,
    ["markdown"]         = true,
    ["nim"]              = true,
    ["objective-c"]      = true,
    ["pascal"]           = true,
    ["perl"]             = true,
    ["php"]              = true,
    ["powershell"]       = true,
    ["python"]           = true,
    ["r"]                = true,
    ["ruby"]             = true,
    ["rust"]             = true,
    ["scala"]            = true,
    ["shell"]            = true,
    ["sql"]              = true,
    ["swift"]            = true,
    ["tmux"]             = true,
    ["toml"]             = true,
    ["typescript"]       = true,
    ["typescriptreact"]  = true,
    ["vue"]              = true,
    ["xml"]              = true,
    ["yaml"]             = true,
    [M.AVANTE_INPUT]     = true,
    [M.COPILOT_CHAT]     = true,
  },
  cmp_search = {
    [M.SEARCH_INPUT] = true,
  },
  disable_autopairs = {
    [M.AERIAL] = true,
    [M.AVANTE] = true,
    [M.AVANTE_SELECTED_FILES] = true,
    [M.CHECKHEALTH] = true,
    [M.COPILOT_CHAT] = true,
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
    [M.GITCOMMIT] = true,
    [M.HELP] = true,
    [M.LAZY] = true,
    [M.MAN] = true,
    [M.MASON] = true,
    [M.NEOTREE] = true,
    [M.NEOTREE_POPUP] = true,
    [M.NOICE] = true,
    [M.NOTIFY] = true,
    [M.LSPINFO] = true,
    [M.PLENARY_TEST_POPUP] = true,
    [M.QUICKFIX] = true,
    [M.SEARCH_INPUT] = true,
    [M.SEARCH_MAIN] = true,
    [M.SMEAR_CURSOR] = true,
    [M.STARTUPTIME] = true,
    [M.TEMP_VIEWER] = true,
    [M.TERM] = true,
    [M.TROUBLE] = true,
    [M.UX_INPUT] = true,
    [M.WINSEP] = true,
    [M.WINPICKER_MASK] = true,
  },
  hipattern = {
    [M.AVANTE] = true,
    [M.AVANTE_INPUT] = true,
  },
  markdown = {
    ["markdown"] = true,
    [M.AVANTE] = true,
    [M.YOZORA_VIEWER] = true,
  },
  not_plain = {
    [M.AERIAL] = true,
    [M.AVANTE] = true,
    [M.AVANTE_INPUT] = true,
    [M.AVANTE_SELECTED_FILES] = true,
    [M.CHECKHEALTH] = true,
    [M.COPILOT_CHAT] = true,
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
    [M.GITCOMMIT] = true,
    [M.HELP] = true,
    [M.LAZY] = true,
    [M.MAN] = true,
    [M.MASON] = true,
    [M.NEOTREE] = true,
    [M.NEOTREE_POPUP] = true,
    [M.NOICE] = true,
    [M.NOTIFY] = true,
    [M.LSPINFO] = true,
    [M.PLENARY_TEST_POPUP] = true,
    [M.QUICKFIX] = true,
    [M.SEARCH_INPUT] = true,
    [M.SEARCH_MAIN] = true,
    [M.SEARCH_PREVIEW] = true,
    [M.SMEAR_CURSOR] = true,
    [M.STARTUPTIME] = true,
    [M.TEMP_VIEWER] = true,
    [M.TERM] = true,
    [M.TROUBLE] = true,
    [M.UX_INPUT] = true,
    [M.WINSEP] = true,
    [M.WINPICKER_MASK] = true,
    [M.YOZORA_VIEWER] = true,
  },
  no_customized_winline = {
    [M.AVANTE] = true,
    [M.AVANTE_INPUT] = true,
    [M.AVANTE_SELECTED_FILES] = true,
    [M.DAP_REPL] = true,
    [M.DAP_UI_BREAKPOINTS] = true,
    [M.DAP_UI_CONSOLE] = true,
    [M.DAP_UI_SCOPES] = true,
    [M.DAP_UI_STACKS] = true,
    [M.DAP_UI_WATCHES] = true,
  },
  no_ibl = {
    [M.AERIAL] = true,
    [M.AVANTE] = true,
    [M.AVANTE_INPUT] = true,
    [M.AVANTE_SELECTED_FILES] = true,
    [M.CHECKHEALTH] = true,
    [M.COPILOT_CHAT] = true,
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
    [M.GITCOMMIT] = true,
    [M.HELP] = true,
    [M.LAZY] = true,
    [M.MAN] = true,
    [M.MASON] = true,
    [M.NEOTREE] = true,
    [M.NEOTREE_POPUP] = true,
    [M.NOICE] = true,
    [M.NOTIFY] = true,
    [M.LSPINFO] = true,
    [M.PLENARY_TEST_POPUP] = true,
    [M.QUICKFIX] = true,
    [M.SEARCH_INPUT] = true,
    [M.SEARCH_MAIN] = true,
    [M.SMEAR_CURSOR] = true,
    [M.STARTUPTIME] = true,
    [M.TEMP_VIEWER] = true,
    [M.TERM] = true,
    [M.TROUBLE] = true,
    [M.UX_INPUT] = true,
    [M.WINSEP] = true,
    [M.WINPICKER_MASK] = true,
    [M.YOZORA_VIEWER] = true,
  },
  no_flash = {
    [M.CMP_MENU] = true,
    [M.FLASH_PROMPT] = true,
    [M.NOICE] = true,
    [M.NOTIFY] = true,
    [M.LSPINFO] = true,
    [M.PLENARY_TEST_POPUP] = true,
    [M.SMEAR_CURSOR] = true,
    [M.WINSEP] = true,
    [M.WINPICKER_MASK] = true,
    [M.YOZORA_VIEWER] = true,
  },
  no_sourcefile = {
    [M.AERIAL] = true,
    [M.AVANTE] = true,
    [M.AVANTE_INPUT] = true,
    [M.AVANTE_SELECTED_FILES] = true,
    [M.CHECKHEALTH] = true,
    [M.COPILOT_CHAT] = true,
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
    [M.GITCOMMIT] = true,
    [M.HELP] = true,
    [M.LAZY] = true,
    [M.MAN] = true,
    [M.MASON] = true,
    [M.NEOTREE] = true,
    [M.NEOTREE_POPUP] = true,
    [M.NOICE] = true,
    [M.NOTIFY] = true,
    [M.LSPINFO] = true,
    [M.PLENARY_TEST_POPUP] = true,
    [M.QUICKFIX] = true,
    [M.SEARCH_INPUT] = true,
    [M.SEARCH_MAIN] = true,
    [M.SEARCH_PREVIEW] = true,
    [M.SMEAR_CURSOR] = true,
    [M.STARTUPTIME] = true,
    [M.TEMP_VIEWER] = true,
    [M.TERM] = true,
    [M.TROUBLE] = true,
    [M.UX_INPUT] = true,
    [M.WINSEP] = true,
    [M.WINPICKER_MASK] = true,
    [M.YOZORA_VIEWER] = true,
  },
  no_window_picker_focusable = {
    [M.NOICE] = true,
    [M.LSPINFO] = true,
    [M.PLENARY_TEST_POPUP] = true,
    [M.SMEAR_CURSOR] = true,
    [M.WINSEP] = true,
  },
  no_window_picker_projectable = {
    [M.AERIAL] = true,
    [M.AVANTE] = true,
    [M.AVANTE_INPUT] = true,
    [M.AVANTE_SELECTED_FILES] = true,
    [M.CHECKHEALTH] = true,
    [M.COPILOT_CHAT] = true,
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
    [M.GITCOMMIT] = true,
    [M.HELP] = true,
    [M.LAZY] = true,
    [M.MAN] = true,
    [M.MASON] = true,
    [M.NEOTREE] = true,
    [M.NEOTREE_POPUP] = true,
    [M.NOICE] = true,
    [M.NOTIFY] = true,
    [M.LSPINFO] = true,
    [M.PLENARY_TEST_POPUP] = true,
    [M.QUICKFIX] = true,
    [M.SEARCH_INPUT] = true,
    [M.SEARCH_MAIN] = true,
    [M.SEARCH_PREVIEW] = true,
    [M.SMEAR_CURSOR] = true,
    [M.STARTUPTIME] = true,
    [M.TEMP_VIEWER] = true,
    [M.TERM] = true,
    [M.TROUBLE] = true,
    [M.UX_INPUT] = true,
    [M.WINSEP] = true,
    [M.WINPICKER_MASK] = true,
    [M.YOZORA_VIEWER] = true,
  },
  quitable_with_q = {
    [M.AERIAL] = true,
    [M.CHECKHEALTH] = true,
    [M.COPILOT_CHAT] = true,
    [M.DAP_FLOAT] = true,
    [M.DAP_UI_HOVER] = true,
    [M.GITCOMMIT] = true,
    [M.HELP] = true,
    [M.LAZY] = true,
    [M.MAN] = true,
    [M.MASON] = true,
    [M.NEOTREE] = true,
    [M.NEOTREE_POPUP] = true,
    [M.NOICE] = true,
    [M.NOTIFY] = true,
    [M.LSPINFO] = true,
    [M.PLENARY_TEST_POPUP] = true,
    [M.QUICKFIX] = true,
    [M.STARTUPTIME] = true,
    [M.TEMP_VIEWER] = true,
    [M.TROUBLE] = true,
    [M.WINPICKER_MASK] = true,
    [M.YOZORA_VIEWER] = true,
  },
  winsep_float = {
    [M.SEARCH_INPUT] = true,
    [M.SEARCH_MAIN] = true,
    [M.SEARCH_PREVIEW] = true,
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

---@return string[]
function M.get_cmp_code_filetypes()
  return vim.tbl_keys(filetypes.cmp_code)
end

---@return string[]
function M.get_cmp_search_filetypes()
  return vim.tbl_keys(filetypes.cmp_search)
end

---@return string[]
function M.get_disable_autopairs_filetypes()
  return vim.tbl_keys(filetypes.disable_autopairs)
end

---@return string[]
function M.get_hipattern_filetypes()
  return vim.tbl_keys(filetypes.hipattern)
end

---@return string[]
function M.get_markdown_filetypes()
  return vim.tbl_keys(filetypes.markdown)
end

---@return string[]
function M.get_no_ibl_filetypes()
  return vim.tbl_keys(filetypes.no_ibl)
end

---@return string[]
function M.get_no_flash_filetypes()
  return vim.tbl_keys(filetypes.no_flash)
end

---@return string[]
function M.get_quitable_with_q_filetypes()
  return vim.tbl_keys(filetypes.quitable_with_q)
end

function M.is_no_customized_winline_filetype(filetype)
  if filetype == nil or #filetype < 1 then
    return false
  end
  return filetypes.no_customized_winline[filetype]
end

---@return boolean
function M.is_no_ibl_filetype(filetype)
  if filetype == nil or #filetype < 1 then
    return true
  end
  return filetypes.no_ibl[filetype]
end

---@param filetype                      string|nil
---@return boolean
function M.is_plain_file(filetype)
  if filetype == nil or #filetype < 1 or filetypes.not_plain[filetype] then
    return false
  end
  return true
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
function M.is_winsep_float(filetype)
  return filetype ~= nil and filetypes.winsep_float[filetype]
end

---@param filetype                      string|nil
---@return boolean
function M.is_not_plain_file(filetype)
  return filetype == nil or #filetype < 1 or filetypes.not_plain[filetype]
end

---@param filetype                      string|nil
---@return boolean
function M.is_not_focusable_filetype(filetype)
  return filetype == nil or filetypes.no_window_picker_focusable[filetype]
end

---@param filetype                      string|nil
---@return boolean
function M.is_not_projectable_filetype(filetype)
  return filetype == nil or filetypes.no_window_picker_projectable[filetype]
end

---@param filetype                      string|nil
---@return boolean
function M.is_not_sourcefile_filetype(filetype)
  return filetype == nil or filetypes.no_sourcefile[filetype]
end

return M
