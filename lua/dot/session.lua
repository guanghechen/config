---@diagnostic disable-next-line: unused-local
local __module_name__ = "dot.session" ---@type string

---@class dot.session
local M = {}

---@return boolean
---@return string|nil
local function prepare_maximize_tabs()
  local tabnrs = vim.api.nvim_list_tabpages() ---@type integer[]
  for index = #tabnrs, 1, -1 do
    local tabnr = tabnrs[index] ---@type integer
    if vim.t[tabnr].tabtype == stl.e.TabTypeEnum.MAXIMIZE then
      local normal = dot.state.maximized.get_normal() ---@type dot.state.maximized.INormalContext|nil
      if normal == nil or normal.maximize_tabnr ~= tabnr then
        normal = nil
      else
        dot.state.maximized.sync_normal(normal)
      end

      if #vim.api.nvim_list_tabpages() <= 1 then
        vim.t[tabnr].tabtype = stl.e.TabTypeEnum.NORMAL
        dot.tab.resolve(tabnr, true)

        if normal ~= nil then
          dot.state.maximized.dispose_normal(normal)
        end
        dot.state.status.dirtier_tabline:mark_dirty()
        return true, nil
      end

      local tabid = vim.api.nvim_tabpage_get_number(tabnr) ---@type integer
      local ok, err = pcall(vim.api.nvim_cmd, { cmd = "tabclose", args = { tostring(tabid) } }, {})
      if vim.api.nvim_tabpage_is_valid(tabnr) then
        return false, not ok and tostring(err) or "tab remained open"
      end
      if normal ~= nil then
        dot.state.maximized.dispose_normal(normal)
      end
      if not ok then
        stl.reporter.warn({
          from = __module_name__,
          subject = "save_session",
          message = "Transient tab closed with errors",
          details = { error = tostring(err) },
        })
      end
    end
  end
  return true, nil
end

---@return boolean
local function prepare_session_save()
  local closed, close_error = prepare_maximize_tabs() ---@type boolean, string|nil
  if closed then
    return true
  end

  stl.reporter.warn({
    from = __module_name__,
    subject = "save_session",
    message = "Failed to close transient tabs before saving session",
    details = { error = close_error },
  })
  return false
end

---@param filepath                      string
---@return nil
local function write_session(filepath)
  stl.env.mkdirs(filepath, false)
  local tmp = vim.o.sessionoptions
  vim.o.sessionoptions = dot.var.session.persistent_options
  vim.cmd("mks! " .. vim.fn.fnameescape(filepath))
  vim.o.sessionoptions = tmp
end

---@param filepath                      string
---@return nil
function M.load_session(filepath)
  if vim.fn.filereadable(filepath) ~= 0 then
    vim.cmd("silent! source " .. vim.fn.fnameescape(filepath))
  end
end

---@param filepath                      string
---@return nil
function M.save_session(filepath)
  if not prepare_session_save() then
    return
  end
  write_session(filepath)
end

---@return nil
function M.restore()
  if dot.path.is_git_repo() then
    local storage = dot.context.get_storage() ---@type dot.context.storage

    local nvim_session_filepath = nil ---@type string|nil
    if storage.nvim_session and vim.fn.filereadable(storage.nvim_session) ~= 0 then
      nvim_session_filepath = storage.nvim_session
    elseif storage.nvim_session_autosaved and vim.fn.filereadable(storage.nvim_session_autosaved) ~= 0 then
      nvim_session_filepath = storage.nvim_session_autosaved
    end

    if nvim_session_filepath then
      M.load_session(nvim_session_filepath)
      dot.context.load({
        editor = storage.editor,
        session = storage.session,
        workspace = storage.workspace,
      }, true)
      vim.schedule(dot.tab.refresh)
    end
  end
end

---@return nil
function M.restore_autosaved()
  if dot.path.is_git_repo() then
    local storage = dot.context.get_storage() ---@type dot.context.storage

    local nvim_session_filepath = nil ---@type string|nil
    if storage.nvim_session_autosaved and vim.fn.filereadable(storage.nvim_session_autosaved) ~= 0 then
      nvim_session_filepath = storage.nvim_session_autosaved
    end

    if nvim_session_filepath then
      M.load_session(nvim_session_filepath)
      dot.context.load({
        editor = storage.editor,
        session = storage.session,
        workspace = storage.workspace,
      }, true)
      vim.schedule(dot.tab.refresh)
    end
  end
end

---@return nil
function M.save()
  if dot.path.is_git_repo() then
    local storage = dot.context.get_storage() ---@type dot.context.storage
    if not prepare_session_save() then
      return
    end

    dot.context.save({
      session = storage.session,
      workspace = storage.workspace,
    })
    write_session(storage.nvim_session)

    stl.reporter.info({
      from = __module_name__,
      message = "Session saved successfully!",
    })
  end
end

return M
