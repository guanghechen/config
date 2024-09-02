local util = require("fml.util")

---@class fml.api.state
local M = require("fml.api.state.mod")

---@param filepath                      string|nil
---@return integer|nil
function M.locate_bufnr_by_filepath(filepath)
  if filepath == nil or #filepath < 1 then
    return nil
  end

  for bufnr, buf in pairs(M.bufs) do
    if buf.filepath == filepath then
      return bufnr
    end
  end

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      local bufname = vim.api.nvim_buf_get_name(bufnr)
      local buf_filepath = vim.fn.fnamemodify(bufname, ":p")
      if buf_filepath == filepath then
        M.schedule_refresh_bufs()
        return bufnr
      end
    end
  end
  return nil
end

---@param winnr                         integer
---@param filepath                      string
---@return boolean
function M.open_filepath(winnr, filepath)
  filepath = eve.path.normalize(filepath) ---! normalize the filepath
  if vim.api.nvim_win_is_valid(winnr) then
    local bufnr = M.locate_bufnr_by_filepath(filepath) ---@type integer|nil
    if bufnr ~= nil then
      vim.api.nvim_win_set_buf(winnr, bufnr)
      return true
    end

    local winnr_cur = vim.api.nvim_get_current_win() ---@type integer
    if winnr_cur == winnr then
      vim.cmd("edit " .. vim.fn.fnameescape(filepath))
    else
      vim.api.nvim_set_current_win(winnr)
      vim.cmd("edit " .. vim.fn.fnameescape(filepath))
      vim.api.nvim_set_current_win(winnr_cur)
    end

    vim.schedule(function()
      vim.cmd("stopinsert")
    end)

    return true
  end
  return false
end

---@return nil
function M.refresh_bufs()
  local bufnrs = vim.api.nvim_list_bufs() ---@type integer[]
  local bufs = {} ---@type table<integer, fml.types.api.state.IBufItem>
  for _, bufnr in ipairs(bufnrs) do
    local buf = M.refresh_buf(bufnr) ---@type fml.types.api.state.IBufItem|nil
    if buf ~= nil then
      bufs[bufnr] = buf
    end
  end

  M.bufs = bufs
end

---@param bufnr                         integer|nil
---@return fml.types.api.state.IBufItem|nil
function M.refresh_buf(bufnr)
  if bufnr == nil or type(bufnr) ~= "number" then
    return
  end

  if not M.validate_buf(bufnr) then
    M.bufs[bufnr] = nil
    return
  end

  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
  local filetype = vim.bo[bufnr].filetype ---@type string

  local buf = M.bufs[bufnr] ---@type fml.types.api.state.IBufItem|nil
  if buf == nil then
    local filename = eve.path.basename(filepath) ---@type string
    filename = (not filename or filename == "") and eve.constants.BUF_UNTITLED or filename
    local fileicon, fileicon_hl = util.calc_fileicon(filename) ---@type string, string
    local real_paths = eve.path.split_prettier(eve.path.get_cwd_pieces(), filepath) ---@type string[]

    ---@type fml.types.api.state.IBufItem
    buf = {
      fileicon = fileicon,
      fileicon_hl = fileicon_hl,
      filename = filename,
      filepath = filepath,
      filetype = filetype,
      real_paths = real_paths,
      pinned = false,
    }
    M.bufs[bufnr] = buf
  elseif buf.filepath ~= filepath or buf.filetype ~= filetype then
    local filename = eve.path.basename(filepath) ---@type string
    filename = #filename > 0 and filename or eve.constants.BUF_UNTITLED
    local fileicon, fileicon_hl = util.calc_fileicon(filename) ---@type string, string
    local real_paths = eve.path.split_prettier(eve.path.get_cwd_pieces(), filepath) ---@type string[]

    buf.fileicon = fileicon
    buf.fileicon_hl = fileicon_hl
    buf.filename = filename
    buf.filepath = filepath
    buf.filetype = filetype
    buf.real_paths = real_paths
  end
  return buf
end

---@param bufnrs                        ?integer[]
---@return integer
function M.remove_unrefereced_bufs(bufnrs)
  bufnrs = bufnrs or vim.api.nvim_list_bufs() ---@type integer[]
  local bufnrs_to_remove = {} ---@type integer[]
  for _, bufnr in ipairs(bufnrs) do
    if M.validate_buf(bufnr) then
      local has_copy = false ---@type boolean
      for _, tab in pairs(M.tabs) do
        if tab.bufnr_set[bufnr] then
          has_copy = true
          break
        end
      end

      if not has_copy then
        M.bufs[bufnr] = nil
        table.insert(bufnrs_to_remove, bufnr)
      end
    else
      M.bufs[bufnr] = nil
    end
  end

  for _, bufnr in ipairs(bufnrs_to_remove) do
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
  return #bufnrs_to_remove
end
