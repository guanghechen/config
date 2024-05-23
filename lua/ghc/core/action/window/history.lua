local History = require("guanghechen.history.History")
local guanghechen = require("guanghechen")
local popup = require("plenary.popup")

---@class ghc.core.action.window.IHistoryItem
---@field public bufnr number
---@field public filepath string

local POPUP_WINNR = nil
local IGNORED_FILETYPES = {
  [""] = true,
  ["checkhealth"] = true,
  ["lspinfo"] = true,
  ["neo-tree"] = true,
  ["notify"] = true,
  ["PlenaryTestPopup"] = true,
  ["startuptime"] = true,
  ["term"] = true,
  ["Trouble"] = true,
}
local histories = {} ---@type table<number, guanghechen.history.History>

---@param x ghc.core.action.window.IHistoryItem
---@param y ghc.core.action.window.IHistoryItem
---@return integer
local function comparator(x, y)
  if x.bufnr == y.bufnr or x.filepath == y.filepath then
    return 0
  end
  return x.bufnr - y.bufnr
end

---@class ghc.core.action.window
local M = require("ghc.core.action.window.module")

function M.back()
  local winnr = vim.api.nvim_get_current_win() ---@type number
  local history = histories[winnr]

  if history == nil then
    return
  end

  local previous = history:back(1) ---@type ghc.core.action.window.IHistoryItem|nil
  if previous ~= nil then
    vim.api.nvim_set_current_buf(previous.bufnr)
  end
end

function M.forward()
  local winnr = vim.api.nvim_get_current_win() ---@type number
  local history = histories[winnr]

  if history == nil then
    return
  end

  local next = history:forward(1) ---@type ghc.core.action.window.IHistoryItem|nil
  if next ~= nil then
    vim.api.nvim_set_current_buf(next.bufnr)
  end
end

---@param index number
function M.go(index)
  local winnr = vim.api.nvim_get_current_win() ---@type number
  local history = histories[winnr]
  if history == nil then
    return
  end

  local item = history:go(index)
  if item == nil then
    return
  end

  vim.api.nvim_set_current_buf(item.bufnr)
end

function M.push()
  local winnr = vim.api.nvim_get_current_win() ---@type number
  local history = histories[winnr]
  if history == nil then
    history = History.new({
      name = tostring(winnr),
      comparator = comparator,
    })
    histories[winnr] = history
  end

  if IGNORED_FILETYPES[vim.bo.filetype] then
    return
  end

  local bufnr = vim.api.nvim_get_current_buf() ---@type number
  local filepath = vim.api.nvim_buf_get_name(bufnr)
  local name = guanghechen.util.path.relative(guanghechen.util.path.workspace(), filepath)

  local item = {
    name = name,
    bufnr = bufnr,
    filepath = filepath,
  }
  history:push(item)
end

function M.select_item_from_history_popup()
  if POPUP_WINNR == nil then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(POPUP_WINNR)
  local index = cursor ~= nil and cursor[1] or 1

  M.toggle_history_popup()
  M.go(index)
end

function M.toggle_history_popup()
  if POPUP_WINNR and vim.api.nvim_win_is_valid(POPUP_WINNR) then
    vim.api.nvim_win_close(POPUP_WINNR, true)
    POPUP_WINNR = nil
    return
  end

  if IGNORED_FILETYPES[vim.bo.filetype] then
    return
  end

  local winnr = vim.api.nvim_get_current_win()
  local history = histories[winnr]
  if history == nil then
    return
  end

  local contents = {}
  local longest_length = 0
  local cwd = guanghechen.util.path.cwd()
  for item in history:iterator() do
    ---@cast item ghc.core.action.window.IHistoryItem
    local display_text = guanghechen.util.path.relative(cwd, item.filepath)
    table.insert(contents, display_text)
    longest_length = longest_length < #display_text and #display_text or longest_length
  end

  local minwidth = longest_length + 8
  local maxwidth = vim.api.nvim_win_get_width(winnr) - 10
  local width = minwidth < maxwidth and minwidth or maxwidth
  POPUP_WINNR = popup.create(contents, {
    title = "window history",
    borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
    width = width,
    border = true,
    enter = true,
    focusable = true,
    padding = { 0, 0, 0, 0 },
    on_cursor_move = function(popup_bnfnr, cursor_line)
      --- Clear the previous highlights
      vim.api.nvim_buf_clear_namespace(popup_bnfnr, -1, 0, 1)
      vim.api.nvim_buf_add_highlight(popup_bnfnr, 0, "Identifier", cursor_line - 1, 0, -1)
      vim.api.nvim_buf_add_highlight(popup_bnfnr, 0, "Identifier", history:present_index() - 1, 0, -1)
    end,
  })
  local bufnr = vim.api.nvim_win_get_buf(POPUP_WINNR)
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
  vim.api.nvim_set_option_value("number", true, { win = POPUP_WINNR })
  vim.api.nvim_win_set_cursor(POPUP_WINNR, { history:present_index(), 0 })
  vim.api.nvim_buf_add_highlight(bufnr, 0, "Identifier", history:present_index() - 1, 0, -1)
  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = bufnr,
    nested = true,
    once = true,
    callback = M.toggle_history_popup,
  })

  local function mapkey(mode, key, action, desc)
    vim.keymap.set(mode, key, action, { buffer = bufnr, silent = true, noremap = true, desc = desc })
  end

  mapkey("n", "q", M.toggle_history_popup, "window: toggle history popup")
  mapkey("n", "<cr>", M.select_item_from_history_popup, "window: select item from history popup")
end

function M.show_window_history()
  local winnr = vim.api.nvim_get_current_win()
  local history = histories[winnr]
  if history ~= nil then
    history:print()
  end
end
