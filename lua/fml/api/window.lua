---@class fml.api.window
local M = {}

---@param ignored_buftypes string[]
---@param ignored_filetypes string[]
---@return integer[]
function M.list_all_other_aviable_windows(ignored_buftypes, ignored_filetypes)
  local current_tabpage = vim.api.nvim_get_current_tabpage()
  local winnrs = vim.api.nvim_tabpage_list_wins(current_tabpage)
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

---@param winnr number
---@return boolean
function M.is_floating(winnr)
  local config = vim.api.nvim_win_get_config(winnr)
  return config.relative ~= nil and config.relative ~= ""
end

---@param opts { motivation: "focus" | "swap" | "project" }
---@return integer | nil
function M.pick_window(opts)
  local motivation = opts.motivation
  local bo = {}

  if motivation == "focus" then
    bo = {
      filetype = { "notify", "noice" },
      buftype = {},
    }
  elseif motivation == "swap" then
    bo = {
      filetype = { "neo-tree", "neo-tree-popup", "noice", "notify" },
      buftype = { "terminal", "quickfix" },
    }
  elseif motivation == "project" then
    bo = {
      filetype = { "neo-tree", "neo-tree-popup", "noice", "notify", "Trouble", "quickfix" },
      buftype = { "terminal", "quickfix" },
    }
  end

  local all_other_windows = M.list_all_other_aviable_windows(bo.buftype, bo.filetype)
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

return M
