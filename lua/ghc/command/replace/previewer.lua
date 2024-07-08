local Printer = fml.ui.Printer
local constants = require("ghc.constant.command")

---@class ghc.command.replace.Previewer
---@field private state             ghc.command.replace.State
local M = {}
M.__index = M

---@class ghc.command.replace.previewer.IProps
---@field public state              ghc.command.replace.State

---@param props ghc.command.replace.previewer.IProps
---@return ghc.command.replace.Previewer
function M.new(props)
  local self = setmetatable({}, M)

  self.state = props.state

  return self
end

---@return integer|nil
function M:select_preview_window()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local selected_winnr = fml.api.win.pick("project") ---@type integer|nil
  if selected_winnr == nil then
    return nil
  end

  if selected_winnr == 0 then
    local width = vim.api.nvim_win_get_width(winnr)
    local max_width = 80

    vim.cmd("vsplit")
    selected_winnr = vim.api.nvim_get_current_win()
    if width / 2 > max_width then
      vim.api.nvim_win_set_width(winnr, max_width)
    end
  end

  vim.api.nvim_set_current_win(selected_winnr)
  return selected_winnr
end

---@param opts ghc.types.command.replace.previewer.IPreviewParams
function M:preview(opts)
  local winnr = opts.winnr or self:select_preview_window() or 0 ---@type integer
  local filepath = opts.filepath ---@type string
  local keep_search_pieces = opts.keep_search_pieces ---@type boolean
  local cursor_row = opts.cursor_row ---@type integer
  local cursor_col = opts.cursor_col ---@type integer

  local original_text = fml.api.buf.reload_or_load(filepath)
  local search_pattern = self.state:get_value("search_pattern") ---@type string
  local replace_pattern = self.state:get_value("replace_pattern") ---@type string
  local flag_regex = self.state:get_value("flag_regex") ---@type boolean
  local flag_case_sensitive = self.state:get_value("flag_case_sensitive") ---@type boolean

  local bufnr = vim.api.nvim_create_buf(true, true) ---@type integer
  local filetype = vim.fn.system(string.format('nvim -c "filetype detect" -c "echo &filetype" -c "quit" %s', filepath))

  vim.api.nvim_set_current_buf(bufnr)
  vim.api.nvim_set_option_value("buftype", constants.replace_preview_filetype, { buf = bufnr })
  vim.api.nvim_set_option_value("filetype", filetype, { buf = bufnr })
  vim.api.nvim_set_option_value("buflisted", true, { buf = bufnr })
  vim.cmd(string.format("%sbufdo file %s/REPLACE_PREVIEW", bufnr, bufnr)) --- Rename the buf
  local printer = Printer.new({ bufnr = bufnr, nsnr = 0 })

  ---@type fml.std.oxi.replace.IPreviewBlockItem
  local block_match = fml.oxi.replace_text_preview({
    text = original_text,
    search_pattern = search_pattern,
    replace_pattern = replace_pattern,
    keep_search_pieces = keep_search_pieces,
    flag_regex = flag_regex,
    flag_case_sensitive = flag_case_sensitive,
  })

  local text = block_match.text ---@type string
  ---@diagnostic disable-next-line: unused-local
  for _1, line in ipairs(block_match.lines) do
    ---@type fml.ui.printer.ILineHighlight[]
    local match_highlights = {}
    ---@diagnostic disable-next-line: unused-local
    for _3, piece in ipairs(line.p) do
      local hlname = piece.i % 2 == 0 and "GhcReplaceTextDeleted" or "GhcReplaceTextAdded" ---@type string
      table.insert(match_highlights, { cstart = piece.l, cend = piece.r, hlname = hlname })
    end
    printer:print(text:sub(line.l + 1, line.r), match_highlights)
  end

  vim.api.nvim_win_set_cursor(winnr, { cursor_row, cursor_col })
end

return M
