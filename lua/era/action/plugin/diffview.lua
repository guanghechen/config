local __module_name__ = "era.action.plugin.diffview" ---@type string

---@class era.action.plugin.diffview
local M = {}

---@return nil
function M.diffview()
  require("diffview").open()
end

---@return nil
function M.close()
  require("diffview").close()
end

---@return nil
function M.history()
  require("diffview").file_history()
end

---@return nil
function M.history_file()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local bufnr_sourcefile = dot.tab.retrieve_bufnr_sourcefile(tabnr) ---@type integer|nil
  if bufnr_sourcefile == nil then
    stl.reporter.warn({
      from = __module_name__,
      message = "No source file found in current tab",
    })
    return
  end

  local filepath = vim.api.nvim_buf_get_name(bufnr_sourcefile) ---@type string
  require("diffview").file_history(nil, { filepath })
end

---@return nil
function M.toggle()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local tabtype = dot.tab.resolve_type(tabnr, false) ---@type stl.nvim.tab.TypeEnum

  if tabtype == stl.nvim.tab.Types.DIFFVIEW then
    require("diffview").emit("toggle_files")
  else
    require("diffview").open()
  end
end

---@return nil
function M.refresh()
  require("diffview").emit("refresh_files")
  stl.reporter.info({
    from = __module_name__,
    message = "Refreshed!",
  })
end

---@return nil
function M.diff_staged()
  require("diffview").open({ "--staged" })
end

return M
