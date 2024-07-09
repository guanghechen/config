local state = require("ghc.command.replace.state")

---@class ghc.command.replace.main
local M = require("ghc.command.replace.main.mod")

---@class ghc.command.replace.main.IRenderParams
---@field public winnr                  integer
---@field public force                  ?boolean

---@param params                          ghc.command.replace.main.IRenderParams
function M.render(params)
  local winnr = params.winnr ---@type integer
  local force = not not params.force ---@type boolean
  local bufnr = M.locate_or_create_main_buf() ---@type integer

  if winnr == 0 then
    winnr = vim.api.nvim_get_current_win()
  end

  vim.api.nvim_win_set_buf(winnr, bufnr)
  vim.api.nvim_set_option_value("readonly", false, { buf = bufnr })
  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })

  pcall(M.internal_render, winnr, force)

  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
  vim.api.nvim_set_option_value("readonly", true, { buf = bufnr })
end

---@param winnr                         integer
---@param force                         boolean
function M.internal_render(winnr, force)
  M.printer:clear()
  M.internal_render_cfg(state)
  M.internal_print("")
  M.internal_print("")
  M.internal_render_result(state, force)

  ---Set cursor position.
  local current_lnum = M.printer:get_current_lnum() ---@type integer
  if M.cursor_row > current_lnum then
    M.cursor_row = current_lnum
  end
  local maximum_column_of_line = #vim.fn.getline(M.cursor_row)
  if M.cursor_col > maximum_column_of_line then
    M.cursor_col = maximum_column_of_line
  end
  vim.api.nvim_win_set_cursor(winnr, { M.cursor_row, M.cursor_col })
end

return M
