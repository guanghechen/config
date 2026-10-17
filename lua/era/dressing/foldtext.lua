---@see https://www.reddit.com/r/neovim/comments/1fzn1zt/custom_fold_text_function_with_treesitter_syntax/
---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.dressing.foldtext" ---@type string

---@class era.dressing.foldtext
local M = {}

local foldtext = "v:lua.era.dressing.foldtext.foldtext()" ---@type string
local initialized = false ---@type boolean

-- The highlight of every byte on `row`, chosen among the captures there as the highest priority, the
-- later capture on a tie. One query pass per tree replaces a capture lookup per character.
---@param bufnr                         integer
---@param row                           integer
---@param length                        integer
---@return table<integer, string>
local function row_highlights(bufnr, row, length)
  local highlights = {} ---@type table<integer, string>
  local highlighter = vim.treesitter.highlighter.active[bufnr]
  if highlighter == nil then
    return highlights
  end

  local priorities = {} ---@type table<integer, number>
  highlighter.tree:for_each_tree(function(tstree, tree)
    if not tstree then
      return
    end
    local root = tstree:root()
    local root_start_row, _, root_end_row = root:range()
    -- Only worry about trees within the line range
    if root_start_row > row or root_end_row < row then
      return
    end
    local lang = tree:lang() ---@type string
    local query = vim.treesitter.query.get(lang, "highlights")
    -- Some injected languages may not have highlight queries.
    if query == nil then
      return
    end

    for id, node, metadata in query:iter_captures(root, bufnr, row, row + 1) do
      local capture = query.captures[id] ---@type string|nil
      local start_row, start_col, end_row, end_col = node:range()
      if capture ~= nil and start_row <= row and row <= end_row then
        local capture_metadata = metadata[id] or {} ---@type table
        local priority = tonumber(metadata.priority or capture_metadata.priority) or vim.hl.priorities.treesitter
        local hl = lang ~= "" and ("@" .. capture .. "." .. lang) or ("@" .. capture) ---@type string
        for col = start_row < row and 0 or start_col, (end_row > row and length or end_col) - 1 do
          if priority >= (priorities[col] or -math.huge) then
            priorities[col] = priority
            highlights[col] = hl
          end
        end
      end
    end
  end)
  return highlights
end

---@return [string, string][]
function M.foldtext()
  local start_text = vim.fn.getline(vim.v.foldstart) ---@type string
  local linecount = vim.v.foldend - vim.v.foldstart ---@type integer
  local lnum = vim.v.foldstart - 1 ---@type integer
  local byte_positions = vim.str_utf_pos(start_text) ---@type integer[]
  local highlights = row_highlights(vim.api.nvim_get_current_buf(), lnum, #start_text) ---@type table<integer, string>
  local display_col = 0 ---@type integer

  local result = {} ---@type [string, string][]
  local text, hl = "", nil ---@type string, string|nil
  for index, byte_index in ipairs(byte_positions) do
    local next_byte_index = byte_positions[index + 1] or #start_text + 1 ---@type integer
    local char = start_text:sub(byte_index, next_byte_index - 1) ---@type string
    local next_hl = highlights[byte_index - 1] ---@type string|nil

    if next_hl ~= hl then
      if text ~= "" then
        table.insert(result, { text, hl })
      end
      text = ""
      hl = next_hl
    end

    if char == "\t" then
      local width = vim.fn.strdisplaywidth(char, display_col) ---@type integer
      char = string.rep(" ", width)
      display_col = display_col + width
    else
      display_col = display_col + vim.api.nvim_strwidth(char)
    end
    text = text .. char
  end
  if text ~= "" then
    table.insert(result, { text, hl })
  end
  table.insert(result, { "  ", "f_transparent" })
  table.insert(result, { stl.icon.symbols.sep_left, "f_fold_virt_text_inv" })
  table.insert(result, { string.format("%s %d lines", "↙", linecount), "f_fold_virt_text" })
  table.insert(result, { stl.icon.symbols.sep_right, "f_fold_virt_text_inv" })
  return result
end

---@return nil
function M.dressing()
  if initialized then
    return
  end
  initialized = true

  vim.api.nvim_set_option_value("foldtext", foldtext, { scope = "global" })
  local winnrs = vim.api.nvim_list_wins() ---@type integer[]
  for _, winnr in ipairs(winnrs) do
    vim.api.nvim_set_option_value("foldtext", foldtext, { win = winnr })
  end
end

return M
