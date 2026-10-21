---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.diffview.fn" ---@type string

local session = require("era.m.diffview.session")

---Diffview entry points: each finds the current tab's session and dispatches to it.
---@class era.m.diffview.fn
local M = {}

---Open the repository Git workspace.
---@param opts                        { layout: integer|nil }|nil
function M.open_workspace(opts)
  session.open_workspace(opts)
end

---Open File History view (opens commits view with path filter)
---@param opts                        { filepath: string|nil, layout: integer|nil }|nil
function M.open_file_history(opts)
  local filepath = opts and opts.filepath ---@type string|nil
  local layout = opts and opts.layout ---@type integer|nil

  if not filepath then
    -- Use current buffer file
    local bufnr = vim.api.nvim_get_current_buf()
    filepath = vim.api.nvim_buf_get_name(bufnr)
  end

  if not filepath or filepath == "" then
    stl.reporter.warn({
      from = __module_name__,
      subject = "open_file_history",
      message = "No file specified",
    })
    return
  end

  local workspace = dot.path.workspace()
  if not workspace then
    stl.reporter.warn({
      from = __module_name__,
      subject = "open_file_history",
      message = "Not in a git repository",
    })
    return
  end

  -- Call commits with path filter
  session.open_log({
    layout = layout,
    path = stl.os.path.relative(workspace, filepath),
  })
end

---Open commits view (git log)
---@param opts                        { layout: integer|nil, path: string|nil }|nil
function M.open_commits(opts)
  session.open_log(opts)
end

---Close current Diffview
function M.close()
  local current = session.current()
  if current then
    current:close()
  end
end

---Refresh current Diffview
function M.refresh()
  local current = session.current()
  if current then
    current:refresh()
  end
end

---Handle window navigation that depends on the active Diffview layout.
---@param direction                    "h"|"j"|"k"|"l"
---@return boolean
function M.navigate_window(direction)
  local current = session.current()
  return current ~= nil and current:navigate_window(direction)
end

---Reveal the active item in the view's navigation panel, or hide that panel when already focused.
function M.reveal()
  local current = session.current()
  if current then
    current:reveal()
  end
end

---Toggle repository History in workspace or commits in the standalone log view.
function M.toggle_commits()
  local current = session.current()
  if current then
    current:toggle_commits()
  end
end

---Toggle the workspace sidebar or the standalone commits filetree.
function M.toggle_files()
  local current = session.current()
  if current then
    current:toggle_files()
  end
end

return M
