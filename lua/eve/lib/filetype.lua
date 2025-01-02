local constant = require("eve.lib.constant")

---@type table<string, table<string, true>>
local filetypes = {
  -- stylua: ignore 
  cmp_code = {
    [constant.FT_COPILOT_CHAT] = true,
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
  cmp_search = {
    [constant.FT_SEARCH_INPUT] = true,
  },
  not_plain = {
    [constant.FT_AERIAL] = true,
    [constant.FT_CHECKHEALTH] = true,
    [constant.FT_COPILOT_CHAT] = true,
    [constant.FT_DIFFVIEW_FILE_HISTORY] = true,
    [constant.FT_DIFFVIEW_FILES] = true,
    [constant.FT_GITCOMMIT] = true,
    [constant.FT_HELP] = true,
    [constant.FT_LAZY] = true,
    [constant.FT_MAN] = true,
    [constant.FT_MASON] = true,
    [constant.FT_NEOTREE] = true,
    [constant.FT_NEOTREE_POPUP] = true,
    [constant.FT_NOICE] = true,
    [constant.FT_NOTIFY] = true,
    [constant.FT_LSPINFO] = true,
    [constant.FT_PLENARY_TEST_POPUP] = true,
    [constant.FT_QUICKFIX] = true,
    [constant.FT_SEARCH_INPUT] = true,
    [constant.FT_SEARCH_MAIN] = true,
    [constant.FT_SEARCH_PREVIEW] = true,
    [constant.FT_STARTUPTIME] = true,
    [constant.FT_TERM] = true,
    [constant.FT_TROUBLE] = true,
    [constant.FT_WINSEP] = true,
  },
  no_ibl = {
    [constant.FT_AERIAL] = true,
    [constant.FT_CHECKHEALTH] = true,
    [constant.FT_COPILOT_CHAT] = true,
    [constant.FT_DIFFVIEW_FILE_HISTORY] = true,
    [constant.FT_DIFFVIEW_FILES] = true,
    [constant.FT_GITCOMMIT] = true,
    [constant.FT_HELP] = true,
    [constant.FT_LAZY] = true,
    [constant.FT_MAN] = true,
    [constant.FT_MASON] = true,
    [constant.FT_NEOTREE] = true,
    [constant.FT_NEOTREE_POPUP] = true,
    [constant.FT_NOICE] = true,
    [constant.FT_NOTIFY] = true,
    [constant.FT_LSPINFO] = true,
    [constant.FT_PLENARY_TEST_POPUP] = true,
    [constant.FT_QUICKFIX] = true,
    [constant.FT_SEARCH_INPUT] = true,
    [constant.FT_SEARCH_MAIN] = true,
    [constant.FT_STARTUPTIME] = true,
    [constant.FT_TERM] = true,
    [constant.FT_TROUBLE] = true,
    [constant.FT_WINSEP] = true,
  },
  no_flash = {
    [constant.FT_CMP_MENU] = true,
    [constant.FT_FLASH_PROMPT] = true,
    [constant.FT_NOICE] = true,
    [constant.FT_NOTIFY] = true,
    [constant.FT_LSPINFO] = true,
    [constant.FT_PLENARY_TEST_POPUP] = true,
    [constant.FT_WINSEP] = true,
  },
  no_window_picker_focusable = {
    [constant.FT_NOICE] = true,
    [constant.FT_LSPINFO] = true,
    [constant.FT_PLENARY_TEST_POPUP] = true,
    [constant.FT_WINSEP] = true,
  },
  no_window_picker_projectable = {
    [constant.FT_AERIAL] = true,
    [constant.FT_CHECKHEALTH] = true,
    [constant.FT_COPILOT_CHAT] = true,
    [constant.FT_DIFFVIEW_FILE_HISTORY] = true,
    [constant.FT_DIFFVIEW_FILES] = true,
    [constant.FT_GITCOMMIT] = true,
    [constant.FT_HELP] = true,
    [constant.FT_LAZY] = true,
    [constant.FT_MAN] = true,
    [constant.FT_MASON] = true,
    [constant.FT_NEOTREE] = true,
    [constant.FT_NEOTREE_POPUP] = true,
    [constant.FT_NOICE] = true,
    [constant.FT_NOTIFY] = true,
    [constant.FT_LSPINFO] = true,
    [constant.FT_PLENARY_TEST_POPUP] = true,
    [constant.FT_QUICKFIX] = true,
    [constant.FT_SEARCH_INPUT] = true,
    [constant.FT_SEARCH_MAIN] = true,
    [constant.FT_SEARCH_PREVIEW] = true,
    [constant.FT_STARTUPTIME] = true,
    [constant.FT_TERM] = true,
    [constant.FT_TROUBLE] = true,
    [constant.FT_WINSEP] = true,
  },
  quitable_with_q = {
    [constant.FT_AERIAL] = true,
    [constant.FT_CHECKHEALTH] = true,
    [constant.FT_COPILOT_CHAT] = true,
    [constant.FT_GITCOMMIT] = true,
    [constant.FT_HELP] = true,
    [constant.FT_LAZY] = true,
    [constant.FT_MAN] = true,
    [constant.FT_MASON] = true,
    [constant.FT_NEOTREE] = true,
    [constant.FT_NEOTREE_POPUP] = true,
    [constant.FT_NOICE] = true,
    [constant.FT_NOTIFY] = true,
    [constant.FT_LSPINFO] = true,
    [constant.FT_PLENARY_TEST_POPUP] = true,
    [constant.FT_QUICKFIX] = true,
    [constant.FT_STARTUPTIME] = true,
    [constant.FT_TROUBLE] = true,
    [constant.FT_WINSEP] = true,
  },
}

---@class eve.lib.filetype
local M = {}

---@return string[]
function M.get_cmp_code_filetypes()
  return vim.tbl_keys(filetypes.cmp_code)
end

---@return string[]
function M.get_cmp_search_filetypes()
  return vim.tbl_keys(filetypes.cmp_search)
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
function M.get_quitable_with_q_filetypes()
  return vim.tbl_keys(filetypes.quitable_with_q)
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

return M
