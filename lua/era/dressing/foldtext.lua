---@see https://www.reddit.com/r/neovim/comments/1fzn1zt/custom_fold_text_function_with_treesitter_syntax/
---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.dressing.foldtext" ---@type string

---@class era.dressing.foldtext
local M = {}

local foldtext = "v:lua.era.dressing.foldtext.foldtext()" ---@type string
local initialized = false ---@type boolean

---@param captures                     table[]
---@return string|nil
local function resolve_highlight(captures)
  local selected = nil ---@type table|nil
  local selected_priority = -math.huge ---@type number

  for _, capture in ipairs(captures) do
    local metadata = capture.metadata or {} ---@type table
    local capture_metadata = metadata[capture.id] or {} ---@type table
    local priority = tonumber(metadata.priority or capture_metadata.priority) or vim.hl.priorities.treesitter
    if priority >= selected_priority then
      selected = capture
      selected_priority = priority
    end
  end

  if selected == nil then
    return nil
  end
  local hl = "@" .. selected.capture ---@type string
  if selected.lang ~= nil and selected.lang ~= "" then
    hl = hl .. "." .. selected.lang
  end
  return hl
end

---@return [string, string][]
function M.foldtext()
  local start_text = vim.fn.getline(vim.v.foldstart) ---@type string
  local linecount = vim.v.foldend - vim.v.foldstart ---@type integer
  local lnum = vim.v.foldstart - 1 ---@type integer
  local byte_positions = vim.str_utf_pos(start_text) ---@type integer[]
  local display_col = 0 ---@type integer

  local result = {} ---@type [string, string][]
  local text, hl = "", nil ---@type string, string|nil
  for index, byte_index in ipairs(byte_positions) do
    local next_byte_index = byte_positions[index + 1] or #start_text + 1 ---@type integer
    local char = start_text:sub(byte_index, next_byte_index - 1) ---@type string
    local captured_highlights = vim.treesitter.get_captures_at_pos(0, lnum, byte_index - 1)
    local next_hl = resolve_highlight(captured_highlights) ---@type string|nil

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
