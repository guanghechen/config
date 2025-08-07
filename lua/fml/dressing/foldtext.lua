---@class fml.dressing.foldtext
local M = {}

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

vim.o.foldtext = "v:lua.require'fml.dressing.foldtext'.foldtext()"

return M
