---@class fml.dressing.foldexpr
local M = {}

---@return string
function M.foldexpr()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local lnum = vim.v.lnum ---@type integer
  local support_foldingRange = vim.b[bufnr].support_foldingRange or 0 ---@type integer
  if support_foldingRange > 0 then
    return vim.lsp.foldexpr(lnum) or "0" ---@type string
  end

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
  table.insert(result, { "  ", "f_transparent" })
  table.insert(result, { eve.icon.symbols.sep_left, "f_fold_virt_text_inv" })
  table.insert(result, { string.format("%s %d lines", "↙", linecount), "f_fold_virt_text" })
  table.insert(result, { eve.icon.symbols.sep_right, "f_fold_virt_text_inv" })
  return result
end

vim.o.foldmethod = "expr"
vim.o.foldexpr = "v:lua.require'fml.dressing.foldexpr'.foldexpr()"
vim.o.foldtext = "v:lua.require'fml.dressing.foldexpr'.foldtext()"

vim.api.nvim_create_autocmd({ "BufWinEnter" }, {
  group = eve.nvim.augroup("fml_dressing_foldexpr"),
  callback = function()
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    local support_foldingRange = vim.b[bufnr].support_foldingRange or 0 ---@type integer
    if support_foldingRange > 0 then
      vim.wo[winnr].foldmethod = "expr"
      vim.wo[winnr].foldexpr = "v:lua.vim.lsp.foldexpr()"
    else
      vim.wo[winnr].foldmethod = "expr"
      vim.wo[winnr].foldexpr = "v:lua.require'fml.dressing.foldexpr'.foldexpr()"
    end
  end,
})

return M
