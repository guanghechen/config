---@class fml.dressing.foldexpr
local M = {}

---@return string
function M.foldexpr()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  if not vim.api.nvim_buf_is_loaded(bufnr) then
    return "0"
  end

  local filetype = vim.bo[bufnr].filetype ---@type string
  if not eve.filetype.is_language(filetype) then
    return "0"
  end

  local buftype = vim.bo[bufnr].buftype ---@type string
  if buftype == "terminal" then
    return "0"
  end

  local has_ts_parser = vim.b[bufnr].has_ts_parser ---@type boolean|nil
  if has_ts_parser == nil then
    local ok = pcall(vim.treesitter.get_parser, bufnr)
    vim.b[bufnr].has_ts_parser = ok
    has_ts_parser = ok
  end

  local lnum = vim.v.lnum ---@type integer|nil
  return has_ts_parser and vim.treesitter.foldexpr(lnum) or "0" ---@type string
end

---@return [string, string][]
---@see https://www.reddit.com/r/neovim/comments/1fzn1zt/custom_fold_text_function_with_treesitter_syntax/
function M.foldtext()
  local start_text = vim.fn.getline(vim.v.foldstart):gsub("\t", string.rep(" ", vim.o.tabstop)) ---@type string
  local linecount = vim.v.foldend - vim.v.foldstart ---@type integer
  local lnum = vim.v.foldstart - 1 ---@type integer

  local result = {} ---@type [string, string][]
  local text, hl = "", nil ---@type string, string|nil
  for i = 1, #start_text do
    local char = start_text:sub(i, i)
    local captured_highlights = vim.treesitter.get_captures_at_pos(0, lnum, i - 1)
    local outmost_highlight = captured_highlights[#captured_highlights]
    if outmost_highlight then
      local new_hl = "@" .. outmost_highlight.capture
      if new_hl ~= hl then
        -- as soon as new hl appears, push substring with current hl to table
        table.insert(result, { text, hl })
        text = ""
        hl = nil
      end
      text = text .. char
      hl = new_hl
    else
      text = text .. char
    end
  end
  table.insert(result, { text, hl })
  table.insert(result, { " ↙ " .. linecount .. " lines", "f_fold_virt_text" })
  return result
end

vim.o.foldmethod = "expr"
vim.o.foldexpr = "v:lua.require'fml.dressing.foldexpr'.foldexpr()"
vim.o.foldtext = "v:lua.require'fml.dressing.foldexpr'.foldtext()"

return M
