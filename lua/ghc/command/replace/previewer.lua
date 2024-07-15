local Printer = fml.ui.Printer
local state = require("ghc.command.replace.state")

---@class ghc.types.command.replace.previewer.IPreviewParams
---@field public winnr              integer
---@field public filepath           string
---@field public keep_search_pieces boolean
---@field public cursor_row         integer
---@field public cursor_col         integer

---@class ghc.command.replace.Previewer
local M = {}

---@param opts ghc.types.command.replace.previewer.IPreviewParams
function M.preview(opts)
  local winnr = opts.winnr ---@type integer
  local filepath = opts.filepath ---@type string
  local keep_search_pieces = opts.keep_search_pieces ---@type boolean
  local cursor_row = opts.cursor_row ---@type integer
  local cursor_col = opts.cursor_col ---@type integer

  local original_text = fml.api.buf.reload_or_load(filepath) ---@type string
  local search_pattern = state.get_search_pattern() ---@type string
  local replace_pattern = state.get_replace_pattern() ---@type string
  local flag_regex = state.get_flag_regex() ---@type boolean
  local flag_case_sensitive = state.get_flag_case_sensitive() ---@type boolean

  local bufnr = vim.api.nvim_create_buf(true, true) ---@type integer
  local filetype = vim.fn.system(string.format('nvim -c "filetype detect" -c "echo &filetype" -c "quit" %s', filepath))

  vim.api.nvim_set_current_buf(bufnr)
  vim.api.nvim_set_option_value("buftype", fml.constant.BT_REPLACE_PREVIEW, { buf = bufnr })
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
    ---@type fml.types.ui.printer.ILineHighlight[]
    local match_highlights = {}
    ---@diagnostic disable-next-line: unused-local
    for _3, piece in ipairs(line.p) do
      local hlname = piece.i % 2 == 0 and "f_sr_text_deleted" or "f_sr_text_added" ---@type string
      table.insert(match_highlights, { cstart = piece.l, cend = piece.r, hlname = hlname })
    end
    printer:print(text:sub(line.l + 1, line.r), match_highlights)
  end

  vim.api.nvim_win_set_cursor(winnr, { cursor_row, cursor_col })
end

return M
