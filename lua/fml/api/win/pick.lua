---@class fml.api.win
local M = require("fml.api.win.mod")

local pick_config_map = {
  focus = {
    bo = {
      filetype = { "notify", "noice" },
      buftype = {},
    },
  },
  swap = {
    bo = {
      filetype = { "neo-tree", "neo-tree-popup", "noice", "notify" },
      buftype = { "terminal", "quickfix" },
    },
  },
  project = {
    bo = {
      filetype = { "neo-tree", "neo-tree-popup", "noice", "notify", "Trouble", "quickfix" },
      buftype = { "terminal", "quickfix" },
    },
  },
}

---@param ignored_buftypes string[]
---@param ignored_filetypes string[]
---@return integer[]
function M.list_other_availables(ignored_buftypes, ignored_filetypes)
  local tabnr_cur = vim.api.nvim_get_current_tabpage()
  local winnrs = vim.api.nvim_tabpage_list_wins(tabnr_cur)
  local winnr_current = vim.api.nvim_get_current_win()
  local results = {} ---@type integer[]

  for _, winnr in ipairs(winnrs) do
    if winnr ~= winnr_current then
      local bufnr = vim.api.nvim_win_get_buf(winnr)
      local buftype = vim.api.nvim_get_option_value("buftype", { buf = bufnr })
      local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr })
      if not vim.tbl_contains(ignored_buftypes, buftype) and not vim.tbl_contains(ignored_filetypes, filetype) then
        table.insert(results, bufnr)
      end
    end
  end
  return results
end

---@param motivation                    "focus" | "swap" | "project"
function M.pick(motivation)
  local config = pick_config_map[motivation]
  local bo = config and config.bo or {}

  local all_other_windows = M.list_other_availables(bo.buftype, bo.filetype)
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
