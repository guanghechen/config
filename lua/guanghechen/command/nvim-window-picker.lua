local uuids = eve.commander.uuids ---@type eve.builtin.commander.uuids

local pick_config_map = {
  focus = {
    bo = {
      filetype = eve.filetype.get_no_window_picker_focusable_filetypes(),
      buftype = {},
    },
  },
  swap = {
    bo = {
      filetype = eve.filetype.get_no_window_picker_swappable_filetypes(),
      buftype = { "terminal", "quickfix" },
    },
  },
  project = {
    bo = {
      filetype = eve.filetype.get_no_window_picker_projectable_filetypes(),
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

eve.commander
  .register({
    uuid = uuids.win_focus,
    desc = "win: focus",
    action = function()
      local winnr_cur = vim.api.nvim_get_current_win()
      local winnr_target = pick("focus")
      if winnr_target and winnr_cur ~= winnr_target then
        vim.api.nvim_set_current_win(winnr_target)
      end
    end,
  })
  .register({
    uuid = uuids.win_project,
    desc = "win: project",
    action = function()
      local winnr_cur = vim.api.nvim_get_current_win() ---@type integer
      local winnr_target = pick("project") ---@type integer|nil
      if not winnr_target or winnr_cur == winnr_target then
        return
      end

      local bufnr_cur = vim.api.nvim_win_get_buf(winnr_cur) ---@type integer
      local cursor_current = vim.api.nvim_win_get_cursor(winnr_cur)

      vim.api.nvim_win_set_buf(winnr_target, bufnr_cur)
      vim.api.nvim_win_set_cursor(winnr_target, cursor_current)
      vim.api.nvim_set_current_win(winnr_target)
    end,
  })
  .register({
    uuid = uuids.win_swap,
    desc = "win: swap",
    action = function()
      local winnr_current = vim.api.nvim_get_current_win()
      local winnr_target = pick("swap")
      if not winnr_target or winnr_current == winnr_target then
        return
      end

      local wincfg_current = vim.api.nvim_win_get_config(winnr_current) ---@type vim.api.keyset.win_config
      local wincfg_target = vim.api.nvim_win_get_config(winnr_current) ---@type vim.api.keyset.win_config
      vim.api.nvim_win_set_config(winnr_current, wincfg_target)
      vim.api.nvim_win_set_config(winnr_target, wincfg_current)
    end,
  })
