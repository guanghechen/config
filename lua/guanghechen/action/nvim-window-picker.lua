local ft = require("eve.lib.filetype")

local pick_config_map = {
  focus = {
    bo = {
      filetype = ft.get_no_window_picker_focusable_filetypes(),
      buftype = {},
    },
  },
  swap = {
    bo = {
      filetype = ft.get_no_window_picker_swappable_filetypes(),
      buftype = { "terminal", "quickfix" },
    },
  },
  project = {
    bo = {
      filetype = ft.get_no_window_picker_projectable_filetypes(),
      buftype = { "terminal", "quickfix" },
    },
  },
}

---@param ignored_buftypes string[]
---@param ignored_filetypes string[]
---@return integer[]
local function list_other_availables(ignored_buftypes, ignored_filetypes)
  local tabnr_cur = vim.api.nvim_get_current_tabpage()
  local winnrs = vim.api.nvim_tabpage_list_wins(tabnr_cur)
  local winnr_current = vim.api.nvim_get_current_win()
  local bufnrs = {} ---@type integer[]

  for _, winnr in ipairs(winnrs) do
    if winnr ~= winnr_current then
      local bufnr = vim.api.nvim_win_get_buf(winnr)
      local buftype = vim.api.nvim_get_option_value("buftype", { buf = bufnr })
      local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr })
      if not vim.tbl_contains(ignored_buftypes, buftype) and not vim.tbl_contains(ignored_filetypes, filetype) then
        bufnrs[#bufnrs + 1] = bufnr
      end
    end
  end
  return bufnrs
end

---@param motivation                    "focus" | "swap" | "project"
local function pick(motivation)
  local config = pick_config_map[motivation]
  local bo = config and config.bo or {}

  local all_other_windows = list_other_availables(bo.buftype, bo.filetype)
  if #all_other_windows > 0 then
    local ok, window_picker = pcall(require, "window-picker")
    if not ok then
      return all_other_windows[1]
    end

    return window_picker.pick_window({
      show_prompt = false,
      filter_rules = {
        autoselect_one = true,
        include_current_win = false,
        bo = bo,
      },
    })
  end

  return 0
end

---@class guanghechen.action.nvim_window_picker
local M = {}

---@param context                       eve.lib.command.IContext
---@return nil
function M.focus(context)
  local winnr_cur = context.winnr ---@type integer
  local winnr_target = pick("focus")
  if winnr_target and winnr_cur ~= winnr_target then
    vim.api.nvim_set_current_win(winnr_target)
  end
end

---@param context                       eve.lib.command.IContext
---@return nil
function M.project(context)
  local winnr_cur = context.winnr ---@type integer
  local winnr_target = pick("project") ---@type integer|nil
  if not winnr_target or winnr_cur == winnr_target then
    return
  end

  local bufnr_cur = context.bufnr ---@type integer
  local cursor_current = vim.api.nvim_win_get_cursor(winnr_cur)

  vim.api.nvim_win_set_buf(winnr_target, bufnr_cur)
  vim.api.nvim_win_set_cursor(winnr_target, cursor_current)
  vim.api.nvim_set_current_win(winnr_target)
end

---@param context                       eve.lib.command.IContext
---@return nil
function M.swap(context)
  local winnr_cur = context.winnr ---@type integer
  local winnr_target = pick("swap")
  if not winnr_target or winnr_cur == winnr_target then
    return
  end

  local wincfg_current = vim.api.nvim_win_get_config(winnr_cur) ---@type vim.api.keyset.win_config
  local wincfg_target = vim.api.nvim_win_get_config(winnr_cur) ---@type vim.api.keyset.win_config
  vim.api.nvim_win_set_config(winnr_cur, wincfg_target)
  vim.api.nvim_win_set_config(winnr_target, wincfg_current)
end

return M
