---@class ghc.command.replace.main
local M = require("ghc.command.replace.main.mod")

---@return integer|nil
function M.locate_main_buf()
  local bufnrs = vim.api.nvim_list_bufs() ---@type integer[]
  local _, bufnr = fml.array.first(bufnrs, function(bufnr)
    local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr })
    return filetype == fml.constant.FT_SEARCH_REPLACE
  end)
  return bufnr
end

---@return integer
function M.locate_or_create_main_buf()
  local bufnr = M.locate_main_buf() ---@type integer|nil
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    bufnr = vim.api.nvim_create_buf(true, true) ---@type integer
    vim.api.nvim_set_current_buf(bufnr)
    vim.api.nvim_set_option_value("buftype", fml.constant.BT_SEARCH_REPLACE, { buf = bufnr })
    vim.api.nvim_set_option_value("filetype", fml.constant.FT_SEARCH_REPLACE, { buf = bufnr })
    vim.api.nvim_set_option_value("buflisted", false, { buf = bufnr })
    vim.opt_local.list = false
    vim.cmd(string.format("%sbufdo file %s/REPLACE", bufnr, bufnr)) --- Rename the buf
    M.printer:reset({ bufnr = bufnr, nsnr = 0 })
    M.attach(bufnr)
  end
  return bufnr
end

---@param tabnr                         integer
---@return integer
function M.locate_main_win(tabnr)
  local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
  local _, winnr_matched = fml.array.first(winnrs, function(winnr)
    local bufnr = vim.api.nvim_win_get_buf(winnr)
    local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr })
    return filetype == fml.constant.FT_SEARCH_REPLACE
  end)
  return winnr_matched or winnrs[1]
end

---@return integer|nil
function M.locate_or_create_preview_window()
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
