---@class fml.api.buf
local M = {}

---@param bufnr                         integer the stable unique number of the buffer
---@return nil
function M.go(bufnr)
  local winnr = eve.locations.get_current_winnr() ---@type integer|nil
  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    vim.api.nvim_win_set_buf(winnr, bufnr)
  end
end

---@param filepath                      string|nil
---@return integer|nil
function M.locate_by_filepath(filepath)
  if filepath == nil or #filepath < 1 then
    return nil
  end

  for bufnr, buf in pairs(eve.context.state.bufs) do
    if buf.filepath == filepath then
      return bufnr
    end
  end

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      local bufname = vim.api.nvim_buf_get_name(bufnr)
      local buf_filepath = vim.fn.fnamemodify(bufname, ":p")
      if buf_filepath == filepath then
        M.schedule_refresh_all()
        return bufnr
      end
    end
  end
  return nil
end

---@param winnr                         integer
---@param filepath                      string
---@param lnum                          ?integer
---@param col                           ?integer
---@return boolean
function M.open_filepath(winnr, filepath, lnum, col)
  filepath = eve.path.normalize(filepath) ---! normalize the filepath
  if vim.api.nvim_win_is_valid(winnr) then
    local bufnr = M.locate_by_filepath(filepath) ---@type integer|nil
    if bufnr ~= nil then
      vim.api.nvim_win_set_buf(winnr, bufnr)
    else
      local winnr_cur = vim.api.nvim_get_current_win() ---@type integer
      if winnr_cur == winnr then
        vim.cmd("edit " .. vim.fn.fnameescape(filepath))
      else
        vim.api.nvim_set_current_win(winnr)
        vim.cmd("edit " .. vim.fn.fnameescape(filepath))
        vim.api.nvim_set_current_win(winnr_cur)
      end
    end

    vim.schedule(function()
      vim.cmd("stopinsert")
    end)

    if lnum ~= nil and col ~= nil then
      vim.schedule(function()
        pcall(function()
          vim.api.nvim_win_set_cursor(winnr, { lnum, col })
        end)
      end)
    end
    return true
  end
  return false
end

---@param filepath                      string
---@param lnum                          ?integer
---@param col                           ?integer
---@return boolean
function M.open_filepath_in_current_valid_win(filepath, lnum, col)
  local winnr = eve.locations.get_current_winnr() ---@type integer|nil
  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    return M.open_filepath(winnr, filepath, lnum, col)
  end
  return false
end

---@param bufnr                         integer|nil
---@return t.eve.context.state.buf.IItem|nil
function M.refresh(bufnr)
  if bufnr == nil or type(bufnr) ~= "number" then
    return
  end

  if not eve.buf.is_valid(bufnr) then
    eve.context.state.bufs[bufnr] = nil
    return
  end

  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
  local filetype = vim.bo[bufnr].filetype ---@type string

  local buf = eve.context.state.bufs[bufnr] ---@type t.eve.context.state.buf.IItem|nil
  if buf == nil then
    local filename = eve.path.basename(filepath) ---@type string
    filename = (not filename or filename == "") and eve.constants.BUF_UNTITLED or filename
    local fileicon, fileicon_hl = eve.nvim.calc_fileicon(filename) ---@type string, string
    local relpath = eve.path.split_prettier(eve.path.cwd(), filepath) ---@type string[]

    ---@type t.eve.context.state.buf.IItem
    buf = {
      fileicon = fileicon,
      fileicon_hl = fileicon_hl,
      filename = filename,
      filepath = filepath,
      filetype = filetype,
      relpath = relpath,
      pinned = false,
    }
    eve.context.state.bufs[bufnr] = buf
  elseif buf.filepath ~= filepath or buf.filetype ~= filetype then
    local filename = eve.path.basename(filepath) ---@type string
    filename = #filename > 0 and filename or eve.constants.BUF_UNTITLED
    local fileicon, fileicon_hl = eve.nvim.calc_fileicon(filename) ---@type string, string
    local relpath = eve.path.split_prettier(eve.path.cwd(), filepath) ---@type string[]

    buf.fileicon = fileicon
    buf.fileicon_hl = fileicon_hl
    buf.filename = filename
    buf.filepath = filepath
    buf.filetype = filetype
    buf.relpath = relpath
  end
  return buf
end

---@return nil
function M.refresh_all()
  local bufnrs = vim.api.nvim_list_bufs() ---@type integer[]
  local bufs = {} ---@type table<integer, t.eve.context.state.buf.IItem>
  for _, bufnr in ipairs(bufnrs) do
    local buf = M.refresh(bufnr) ---@type t.eve.context.state.buf.IItem|nil
    if buf ~= nil then
      bufs[bufnr] = buf
    end
  end
  eve.context.state.bufs = bufs
end

---@param bufnrs                        ?integer[]
---@return integer
function M.remove_unrefereced_bufs(bufnrs)
  bufnrs = bufnrs or vim.api.nvim_list_bufs() ---@type integer[]
  local bufnrs_to_remove = {} ---@type integer[]
  for _, bufnr in ipairs(bufnrs) do
    if eve.buf.is_valid(bufnr) then
      local has_copy = false ---@type boolean
      for _, tab in pairs(eve.context.state.tabs) do
        if tab.bufnr_set[bufnr] then
          has_copy = true
          break
        end
      end

      if not has_copy then
        eve.context.state.bufs[bufnr] = nil
        table.insert(bufnrs_to_remove, bufnr)
      end
    else
      eve.context.state.bufs[bufnr] = nil
    end
  end

  for _, bufnr in ipairs(bufnrs_to_remove) do
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
  return #bufnrs_to_remove
end

---@type fun(): nil
M.schedule_refresh_all = eve.scheduler.schedule("fml.api.buf.refresh_all", M.refresh_all)

return M
