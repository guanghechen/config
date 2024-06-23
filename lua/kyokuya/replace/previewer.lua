local oxi = require("kyokuya.oxi")
local constants = require("kyokuya.constant")

---@class kyokuya.replace.IReplacePreviewerOptions
---@field public state              kyokuya.replace.ReplaceState
---@field public nsnr               integer

---@class kyokuya.replace.IReplacePreviewerPreviewOptions
---@field public winnr              integer|nil
---@field public filepath           string
---@field public keep_search_pieces boolean
---@field public cursor_row         integer
---@field public cursor_col         integer

---@class kyokuya.replace.ReplacePreviewer
---@field private state             kyokuya.replace.ReplaceState
---@field private nsnr              integer
local M = {}
M.__index = M

---@param opts kyokuya.replace.IReplacePreviewerOptions
---@return kyokuya.replace.ReplacePreviewer
function M.new(opts)
  local self = setmetatable({}, M)
  local nsnr = opts.nsnr ---@type integer

  self.state = opts.state
  self.nsnr = nsnr

  return self
end

---@return integer|nil
function M:select_preview_window()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local selected_winnr = fml.api.window.pick_window({ motivation = "project" }) ---@type integer|nil
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

---@param opts kyokuya.replace.IReplacePreviewerPreviewOptions
function M:preview(opts)
  local winnr = opts.winnr or self:select_preview_window() or 0 ---@type integer
  local filepath = opts.filepath ---@type string
  local keep_search_pieces = opts.keep_search_pieces ---@type boolean
  local cursor_row = opts.cursor_row ---@type integer
  local cursor_col = opts.cursor_col ---@type integer

  local original_text = fml.api.buffer.read_of_load_buf_with_filepath(filepath)
  local search_pattern = self.state:get_value("search_pattern") ---@type string
  local replace_pattern = self.state:get_value("replace_pattern") ---@type string
  local flag_regex = self.state:get_value("flag_regex") ---@type boolean
  local flag_case_sensitive = self.state:get_value("flag_case_sensitive") ---@type boolean

  local bufnr = vim.api.nvim_create_buf(true, true) ---@type integer
  local filetype = vim.fn.system(string.format('nvim -c "filetype detect" -c "echo &filetype" -c "quit" %s', filepath))

  vim.api.nvim_set_current_buf(bufnr)
  vim.api.nvim_set_option_value("buftype", constants.kyokuya_replace_preview_buftype, { buf = bufnr })
  vim.api.nvim_set_option_value("filetype", filetype, { buf = bufnr })
  vim.api.nvim_set_option_value("buflisted", true, { buf = bufnr })
  vim.cmd(string.format("%sbufdo file %s/REPLACE_PREVIEW", bufnr, bufnr)) --- Rename the buf
  local nsnr = self.nsnr ---@type integer
  local printer = fml.ui.Printer.new({ bufnr = bufnr, nsnr = nsnr })

  ---@type kyokuya.oxi.replace.IReplacePreviewBlockItem
  local block_match = oxi.replace_text_preview({
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
    ---@type kyokuya.replace.IReplaceViewLineHighlights[]
    local match_highlights = {}
    ---@diagnostic disable-next-line: unused-local
    for _3, piece in ipairs(line.p) do
      local hlname = piece.i % 2 == 0 and "kyokuya_replace_text_deleted" or "kyokuya_replace_text_added" ---@type string
      table.insert(match_highlights, { cstart = piece.l, cend = piece.r, hlname = hlname })
    end
    printer:print(text:sub(line.l + 1, line.r), match_highlights)
  end

  vim.api.nvim_win_set_cursor(winnr, { cursor_row, cursor_col })
end

return M
