local constants = require("eve.std.constants")

---@type table<string, table<string, true>>
local filetypes = {
  -- stylua: ignore 
  cmp_code = {
    [constants.FT_COPILOT_CHAT] = true,
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
  },
  not_plain = {
    [constants.FT_AERIAL] = true,
    [constants.FT_CHECKHEALTH] = true,
    [constants.FT_COPILOT_CHAT] = true,
    [constants.FT_DIFFVIEW_FILES] = true,
    [constants.FT_GITCOMMIT] = true,
    [constants.FT_HELP] = true,
    [constants.FT_LAZY] = true,
    [constants.FT_MAN] = true,
    [constants.FT_MASON] = true,
    [constants.FT_NEOTREE] = true,
    [constants.FT_NOICE] = true,
    [constants.FT_NOTIFY] = true,
    [constants.FT_LSPINFO] = true,
    [constants.FT_PLENARY_TEST_POPUP] = true,
    [constants.FT_QUICKFIX] = true,
    [constants.FT_SEARCH_INPUT] = true,
    [constants.FT_SEARCH_MAIN] = true,
    [constants.FT_SEARCH_PREVIEW] = true,
    [constants.FT_STARTUPTIME] = true,
    [constants.FT_TERM] = true,
    [constants.FT_TROUBLE] = true,
    [constants.FT_WINSEP] = true,
  },
  no_ibl = {
    [constants.FT_AERIAL] = true,
    [constants.FT_CHECKHEALTH] = true,
    [constants.FT_COPILOT_CHAT] = true,
    [constants.FT_DIFFVIEW_FILES] = true,
    [constants.FT_GITCOMMIT] = true,
    [constants.FT_HELP] = true,
    [constants.FT_LAZY] = true,
    [constants.FT_MAN] = true,
    [constants.FT_MASON] = true,
    [constants.FT_NEOTREE] = true,
    [constants.FT_NOICE] = true,
    [constants.FT_NOTIFY] = true,
    [constants.FT_LSPINFO] = true,
    [constants.FT_PLENARY_TEST_POPUP] = true,
    [constants.FT_QUICKFIX] = true,
    [constants.FT_SEARCH_INPUT] = true,
    [constants.FT_SEARCH_MAIN] = true,
    [constants.FT_STARTUPTIME] = true,
    [constants.FT_TERM] = true,
    [constants.FT_TROUBLE] = true,
    [constants.FT_WINSEP] = true,
  },
  no_flash = {
    [constants.FT_CMP_MENU] = true,
    [constants.FT_FLASH_PROMPT] = true,
    [constants.FT_NOICE] = true,
    [constants.FT_NOTIFY] = true,
    [constants.FT_LSPINFO] = true,
    [constants.FT_PLENARY_TEST_POPUP] = true,
    [constants.FT_WINSEP] = true,
  },
  no_window_picker_focusable = {
    [constants.FT_NOICE] = true,
    [constants.FT_LSPINFO] = true,
    [constants.FT_PLENARY_TEST_POPUP] = true,
    [constants.FT_WINSEP] = true,
  },
  no_window_picker_projectable = {
    [constants.FT_AERIAL] = true,
    [constants.FT_CHECKHEALTH] = true,
    [constants.FT_COPILOT_CHAT] = true,
    [constants.FT_DIFFVIEW_FILES] = true,
    [constants.FT_GITCOMMIT] = true,
    [constants.FT_HELP] = true,
    [constants.FT_LAZY] = true,
    [constants.FT_MAN] = true,
    [constants.FT_MASON] = true,
    [constants.FT_NEOTREE] = true,
    [constants.FT_NOICE] = true,
    [constants.FT_NOTIFY] = true,
    [constants.FT_LSPINFO] = true,
    [constants.FT_PLENARY_TEST_POPUP] = true,
    [constants.FT_QUICKFIX] = true,
    [constants.FT_SEARCH_INPUT] = true,
    [constants.FT_SEARCH_MAIN] = true,
    [constants.FT_SEARCH_PREVIEW] = true,
    [constants.FT_STARTUPTIME] = true,
    [constants.FT_TERM] = true,
    [constants.FT_TROUBLE] = true,
    [constants.FT_WINSEP] = true,
  },
  no_window_picker_swappable = {
    [constants.FT_AERIAL] = true,
    [constants.FT_CHECKHEALTH] = true,
    [constants.FT_COPILOT_CHAT] = true,
    [constants.FT_DIFFVIEW_FILES] = true,
    [constants.FT_GITCOMMIT] = true,
    [constants.FT_HELP] = true,
    [constants.FT_LAZY] = true,
    [constants.FT_MASON] = true,
    [constants.FT_NEOTREE] = true,
    [constants.FT_NOICE] = true,
    [constants.FT_NOTIFY] = true,
    [constants.FT_LSPINFO] = true,
    [constants.FT_PLENARY_TEST_POPUP] = true,
    [constants.FT_QUICKFIX] = true,
    [constants.FT_SEARCH_INPUT] = true,
    [constants.FT_SEARCH_MAIN] = true,
    [constants.FT_SEARCH_PREVIEW] = true,
    [constants.FT_STARTUPTIME] = true,
    [constants.FT_TERM] = true,
    [constants.FT_TROUBLE] = true,
    [constants.FT_WINSEP] = true,
  },
  quitable_with_q = {
    [constants.FT_AERIAL] = true,
    [constants.FT_CHECKHEALTH] = true,
    [constants.FT_COPILOT_CHAT] = true,
    [constants.FT_GITCOMMIT] = true,
    [constants.FT_HELP] = true,
    [constants.FT_LAZY] = true,
    [constants.FT_MAN] = true,
    [constants.FT_MASON] = true,
    [constants.FT_NEOTREE] = true,
    [constants.FT_NOICE] = true,
    [constants.FT_NOTIFY] = true,
    [constants.FT_LSPINFO] = true,
    [constants.FT_PLENARY_TEST_POPUP] = true,
    [constants.FT_QUICKFIX] = true,
    [constants.FT_STARTUPTIME] = true,
    [constants.FT_TROUBLE] = true,
    [constants.FT_WINSEP] = true,
  },
}

---@class eve.std.filetype
local M = {}

---@return string[]
function M.get_cmp_code_filetypes()
  return vim.tbl_keys(filetypes.cmp_code)
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
function M.get_no_illuminate_filetypes()
  return vim.tbl_keys(filetypes.no_ibl)
end

---@return string[]
function M.get_no_window_picker_focusable_filetypes()
  return vim.tbl_keys(filetypes.no_window_picker_focusable)
end

---@return string[]
function M.get_no_window_picker_projectable_filetypes()
  return vim.tbl_keys(filetypes.no_window_picker_projectable)
end

---@return string[]
function M.get_no_window_picker_swappable_filetypes()
  return vim.tbl_keys(filetypes.no_window_picker_swappable)
end

---@return string[]
function M.get_quitable_with_q_filetypes()
  return vim.tbl_keys(filetypes.quitable_with_q)
end

---@param filetype                      string|nil
---@return boolean
function M.is_plain_file(filetype)
  if filetypes.not_plain[filetype] then
    return false
  end
  return true
end

---@return boolean
function M.is_no_ibl_filetype(filetype)
  if filetype == nil or #filetype < 1 then
    return true
  end
  return filetypes.no_ibl[filetype]
end

return M
