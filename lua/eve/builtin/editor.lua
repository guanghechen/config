---@class eve.builtin.editor
local M = {}

---@class eve.builtin.editor.winpicker_filters
M.winpicker_filters = {
  ---@param winnr                       integer
  ---@return boolean
  focusable = function(winnr)
    local config = vim.api.nvim_win_get_config(winnr) ---@type vim.api.keyset.win_config
    if not config.focusable then
      return false
    end

    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    local filetype = vim.bo[bufnr].filetype ---@type string
    return not eve.filetype.is_not_focusable_filetype(filetype)
  end,
  ---@param winnr                       integer
  ---@return boolean
  projectable = function(winnr)
    if vim.wo[winnr].winfixbuf then
      return false
    end

    if M.is_win_sourcefile(winnr) then
      return true
    end

    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    local filetype = vim.bo[bufnr].filetype ---@type string
    return not eve.filetype.is_not_projectable_filetype(filetype)
  end,
  sourcefile = function(winnr)
    return not vim.wo[winnr].winfixbuf and M.is_win_sourcefile(winnr)
  end,
  ---@param winnr                       integer
  ---@return boolean
  swappable = function(winnr)
    if vim.wo[winnr].winfixbuf then
      return false
    end

    if M.is_win_sourcefile(winnr) then
      return true
    end

    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    local filetype = vim.bo[bufnr].filetype ---@type string
    return not eve.filetype.is_not_projectable_filetype(filetype)
  end,
}

---@param winnr_source                  integer|nil
---@return integer|nil
function M.pick_focusable_win(winnr_source)
  return eve.winpicker.pick_window(M.winpicker_filters.focusable, winnr_source, false) ---@type integer|nil
end

---@param winnr_source                  integer|nil
---@return integer|nil
function M.pick_projectable_win(winnr_source)
  return eve.winpicker.pick_window(M.winpicker_filters.projectable, winnr_source, false) ---@type integer|nil
end

---@param winnr_source                  integer|nil
---@return integer|nil
function M.pick_sourcefile_win(winnr_source)
  if winnr_source ~= nil and M.is_win_valid(winnr_source) and M.winpicker_filters.sourcefile(winnr_source) then
    return winnr_source
  end

  local winnr_sourcefile = eve.winpicker.pick_window(M.winpicker_filters.sourcefile, winnr_source, true) ---@type integer|nil
  if winnr_sourcefile == nil then
    return nil
  end

  vim.w[winnr_sourcefile][eve.var.Names.FLAG_SOURCEFILE] = true
  return winnr_sourcefile
end

---@param winnr_source                  integer|nil
---@return integer|nil
function M.pick_swappable_win(winnr_source)
  return eve.winpicker.pick_window(M.winpicker_filters.swappable, winnr_source, false) ---@type integer|nil
end

---@param filetype                      string
---@return integer|nil
function M.find_winnr(filetype)
  local winnrs = vim.api.nvim_tabpage_list_wins(0) ---@type integer[]
  for _, winnr in pairs(winnrs) do
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    if vim.bo[bufnr].filetype == filetype then
      return winnr
    end
  end
  return nil
end

---@param filetype                      string|nil
---@return integer|nil
function M.find_winnr_fixed(filetype)
  local winnrs = vim.api.nvim_tabpage_list_wins(0) ---@type integer[]
  for _, winnr in pairs(winnrs) do
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    if (filetype == nil or vim.bo[bufnr].filetype == filetype) and M.is_win_fixed(winnr) then
      return winnr
    end
  end
  return nil
end

---@param filetype                      string
---@return integer|nil
function M.find_winnr_floating(filetype)
  local winnrs = vim.api.nvim_tabpage_list_wins(0) ---@type integer[]
  for _, winnr in pairs(winnrs) do
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    if vim.bo[bufnr].filetype == filetype and M.is_win_floating(winnr) then
      return winnr
    end
  end
  return nil
end

---@param filetype                      string|nil
---@return integer|nil
function M.find_winnr_sourcefile(filetype)
  local winnrs = vim.api.nvim_tabpage_list_wins(0) ---@type integer[]
  for _, winnr in pairs(winnrs) do
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    if (filetype == nil or vim.bo[bufnr].filetype == filetype) and M.is_win_sourcefile(winnr) then
      return winnr
    end
  end
  return nil
end

---@return string
function M.get_selected_text()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local filetype = vim.bo[bufnr].filetype ---@type string
  if filetype == eve.filetype.TERM then
    return ""
  end

  local saved_reg = vim.fn.getreg("v")
  vim.cmd([[noautocmd sil norm! "vy]])

  local selected_text = vim.fn.getreg("v")
  vim.fn.setreg("v", saved_reg)
  return selected_text or ""
end

---@return integer
---@return integer
function M.get_visual_lnum_range()
  local lnum_1 = vim.fn.getcurpos()[2] ---@type integer
  local lnum_2 = vim.fn.line("v") ---@type integer
  if lnum_1 < lnum_2 then
    return lnum_1, lnum_2
  end
  return lnum_2, lnum_1
end

---@param tabnr                         integer
---@return string[]
function M.get_visible_bufnrs(tabnr)
  local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
  local bufnrs = {} ---@type table<integer, boolean>
  for _, winnr in ipairs(winnrs) do
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    bufnrs[bufnr] = true
  end
  return bufnrs
end

---@param bufnr                         integer
---@return boolean
function M.is_buf_sourcefile(bufnr)
  local is_sourcefile = vim.b[bufnr][eve.var.Names.FLAG_SOURCEFILE] ---@type boolean|nil
  if is_sourcefile ~= nil then
    return is_sourcefile
  end

  if not vim.bo[bufnr].buflisted then
    return false
  end

  local buftype = vim.bo[bufnr].buftype ---@type string
  if buftype == "nofile" then
    return false
  end

  local filetype = vim.bo[bufnr].filetype ---@type string
  if #filetype < 1 then
    local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
    local flag = vim.fn.filereadable(filepath) == 1
    vim.b[bufnr][eve.var.Names.FLAG_SOURCEFILE] = flag
    return flag
  end

  if eve.filetype.is_not_sourcefile(filetype) then
    vim.b[bufnr][eve.var.Names.FLAG_SOURCEFILE] = false
    return false
  end

  vim.b[bufnr][eve.var.Names.FLAG_SOURCEFILE] = true
  return true
end

---@param bufnr                         integer
---@return boolean
function M.is_buf_editable(bufnr)
  return vim.bo[bufnr].buftype == "" and vim.bo[bufnr].modifiable and not vim.bo[bufnr].readonly
end

---@param winnr                         integer
---@return boolean
function M.is_win_fixed(winnr)
  local config = vim.api.nvim_win_get_config(winnr) ---@type vim.api.keyset.win_config
  return config == nil or config.relative == ""
end

---@param winnr                         integer
---@return boolean
function M.is_win_floating(winnr)
  local config = vim.api.nvim_win_get_config(winnr) ---@type vim.api.keyset.win_config
  return config.relative ~= nil and config.relative ~= ""
end

---@param winnr                         integer
---@return boolean
function M.is_win_sourcefile(winnr)
  local is_sourcefile = vim.w[winnr][eve.var.Names.FLAG_SOURCEFILE] ---@type boolean|nil
  if is_sourcefile ~= nil then
    return is_sourcefile
  end

  if M.is_win_floating(winnr) then
    vim.w[winnr][eve.var.Names.FLAG_SOURCEFILE] = false
    return false
  end

  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local filetype = vim.bo[bufnr].filetype ---@type string
  if filetype == nil or #filetype < 1 then
    return false
  end

  if eve.filetype.is_not_sourcefile_filetype(filetype) then
    vim.w[winnr][eve.var.Names.FLAG_SOURCEFILE] = false
    return false
  end

  return true
end

---@param winnr                         integer
---@return boolean
function M.is_win_valid(winnr)
  return winnr > 0 and vim.api.nvim_win_is_valid(winnr)
end

---@param filepath                      string|nil
---@return boolean
function M.is_valid_filepath(filepath)
  if filepath == nil or filepath == "" or filepath == eve.setting.BUF_UNTITLED then
    return false
  end
  return eve.path.is_exist_filepath(filepath)
end

---@param winnr_source                  integer|nil
---@param filepath                      string
---@param lnum                          ?integer
---@param col                           ?integer
---@return boolean
function M.open_filepath(winnr_source, filepath, lnum, col)
  filepath = eve.path.normalize(filepath)

  local winnr = M.pick_sourcefile_win(winnr_source) ---@type integer|nil
  if winnr == nil then
    return false
  end

  vim.api.nvim_set_current_win(winnr)
  vim.cmd("edit " .. vim.fn.fnameescape(filepath))

  vim.schedule(function()
    vim.cmd.stopinsert()

    if lnum ~= nil and col ~= nil then
      pcall(function()
        vim.api.nvim_win_set_cursor(winnr, { lnum, col })
      end)
    end
  end)
  return true
end

---@param winnr_source                  integer|nil
---@param filepaths                     string[]
---@return nil
function M.open_filepaths(winnr_source, filepaths)
  if #filepaths < 1 then
    return
  end

  ---@type integer|nil
  local winnr = (
    winnr_source ~= nil
    and winnr_source > 0
    and vim.api.nvim_win_is_valid(winnr_source)
    and M.winpicker_filters.sourcefile(winnr_source)
  )
      and winnr_source
    or eve.winpicker.pick_window(M.winpicker_filters.sourcefile, winnr_source, true)

  if winnr == nil then
    return
  end

  vim.api.nvim_set_current_win(winnr)
  for _, filepath in ipairs(filepaths) do
    vim.cmd("edit " .. vim.fn.fnameescape(filepath))
  end

  vim.schedule(function()
    vim.cmd.stopinsert()
  end)
end

---@param tabnr                         integer
---@param force                         boolean
---@return eve.e.TabTypeEnum
function M.resolve_tabtype(tabnr, force)
  local tabtype = vim.t[tabnr][eve.var.Names.TAB_TYPE] ---@type eve.e.TabTypeEnum|nil
  if tabtype ~= nil and not force then
    return tabtype
  end

  local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]

  ---! Check if the diffview tab
  for _, winnr in ipairs(winnrs) do
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    local filetype = vim.bo[bufnr].filetype ---@type string
    if filetype == eve.filetype.DIFFVIEW_FILES or filetype == eve.filetype.DIFFVIEW_FILE_HISTORY then
      tabtype = eve.var.TabTypes.DIFFVIEW ---@type eve.e.TabTypeEnum
      break
    end
  end

  tabtype = tabtype or eve.var.TabTypes.NORMAL ---@type eve.e.TabTypeEnum
  vim.t[tabnr][eve.var.Names.TAB_TYPE] = tabtype
  return tabtype
end

---@param tabnr                         integer
---@param tabtype                       eve.e.TabTypeEnum
function M.set_tabtype(tabnr, tabtype)
  vim.t[tabnr][eve.var.Names.TAB_TYPE] = tabtype
end

return M
