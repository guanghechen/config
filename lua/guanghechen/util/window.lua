---@class ghc.core.util.window
local M = {}

function M.has_other_window_to_choose(ignored_buftypes, ignored_filetypes)
  local current_tabpage = vim.api.nvim_get_current_tabpage()
  local winnrs = vim.api.nvim_tabpage_list_wins(current_tabpage)
  local winnr_current = vim.api.nvim_get_current_win()

  for _, winnr in ipairs(winnrs) do
    if winnr ~= winnr_current then
      local bufnr = vim.api.nvim_win_get_buf(winnr)
      local buftype = vim.api.nvim_get_option_value("buftype", { buf = bufnr })
      local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr })
      if not vim.tbl_contains(ignored_buftypes, buftype) and not vim.tbl_contains(ignored_filetypes, filetype) then
        return true
      end
    end
  end

  return false
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

  if M.has_other_window_to_choose(bo.buftype, bo.filetype) then
    return require("window-picker").pick_window({
      show_prompt = false,
      filter_rules = {
        autoselect_one = true,
        include_current_win = false,
        bo = bo,
      },
    })
  end

  return -1
end

return M
