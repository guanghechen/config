---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.diffview.buffer" ---@type string

local const = require("era.m.diffview.config")

---@class era.m.diffview.buffer
local M = {}

----------------------------------------------------------------------------------------------------
-- Buffer creation
----------------------------------------------------------------------------------------------------

---Create a panel buffer (filetree or commits)
---@param filetype                     string
---@return integer                     bufnr
function M.create_panel_buffer(filetype)
  local bufnr = vim.api.nvim_create_buf(false, true)

  for opt, val in pairs(const.BUFOPTS_PANEL) do
    vim.api.nvim_set_option_value(opt, val, { buf = bufnr })
  end
  vim.api.nvim_set_option_value("filetype", filetype, { buf = bufnr })

  return bufnr
end

---Create or find a side-by-side buffer
---@param name                         string                          unique buffer name
---@return integer                     bufnr
function M.create_sbs_buffer(name)
  local existing = vim.fn.bufnr(name)
  if existing ~= -1 then
    return existing
  end

  local bufnr = vim.api.nvim_create_buf(false, false)
  vim.api.nvim_buf_set_name(bufnr, name)

  for opt, val in pairs(const.BUFOPTS_SBS) do
    vim.api.nvim_set_option_value(opt, val, { buf = bufnr })
  end
  vim.api.nvim_set_option_value("filetype", const.FT.SBS, { buf = bufnr })

  return bufnr
end

---Find or create a local file buffer
---@param filepath                     string                          absolute path
---@return integer                     bufnr
function M.find_or_create_local_buffer(filepath)
  local bufnr = vim.fn.bufnr(filepath)
  if bufnr ~= -1 then
    vim.api.nvim_set_option_value("buflisted", true, { buf = bufnr })
    return bufnr
  end

  bufnr = vim.fn.bufadd(filepath)
  vim.fn.bufload(bufnr)
  vim.api.nvim_set_option_value("buflisted", true, { buf = bufnr })

  return bufnr
end

----------------------------------------------------------------------------------------------------
-- Buffer content loading
----------------------------------------------------------------------------------------------------

---Load content from git object into buffer.
---@async
---@param object                      string                          git object (e.g., "HEAD:path" or ":path")
---@param bufnr                       integer                         target buffer
---@param token                       ?stl.c.CancellationToken
---@return boolean ok
function M.load_git_content(object, bufnr, token)
  local ok, result = pcall(function()
    return stl.git.exec.exec({ "show", object }, { cwd = dot.path.workspace() }, token):await()
  end)

  if not ok then
    vim.notify("load_git_content exec error: " .. tostring(result), vim.log.levels.ERROR)
    return false
  end

  -- Check if result is nil (can happen if Future was never resolved)
  if not result then
    vim.notify("load_git_content: exec returned nil result for object: " .. object, vim.log.levels.ERROR)
    return false
  end

  -- Need to be on main thread for nvim API calls
  local ok2, err2 = pcall(stl.async.scheduler)
  if not ok2 then
    vim.notify("load_git_content scheduler error: " .. tostring(err2), vim.log.levels.ERROR)
    return false
  end

  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end

  if result.code ~= 0 then
    vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
    vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
    return false
  end

  local lines = result.lines

  -- Remove trailing empty line if present (vim.diff artifact)
  if #lines > 0 and lines[#lines] == "" then
    lines[#lines] = nil
  end

  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
  vim.api.nvim_set_option_value("modified", false, { buf = bufnr })

  return true
end

---Set buffer lines directly
---@param bufnr                        integer
---@param lines                        string[]
function M.set_lines(bufnr, lines)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local was_modifiable = vim.api.nvim_get_option_value("modifiable", { buf = bufnr })
  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", was_modifiable, { buf = bufnr })
  vim.api.nvim_set_option_value("modified", false, { buf = bufnr })
end

----------------------------------------------------------------------------------------------------
-- Buffer cleanup
----------------------------------------------------------------------------------------------------

---Safely delete a buffer
---@param bufnr                        integer|nil
function M.safe_delete(bufnr)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  -- Don't delete if it's being used in other windows
  local wins = vim.fn.win_findbuf(bufnr)
  if #wins > 0 then
    return
  end

  pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
end

----------------------------------------------------------------------------------------------------
-- Null buffer (for deleted files or binary files)
----------------------------------------------------------------------------------------------------

local null_bufnr = nil ---@type integer|nil

---Get or create the null buffer
---@return integer
function M.get_null_buffer()
  if null_bufnr and vim.api.nvim_buf_is_valid(null_bufnr) then
    return null_bufnr
  end

  null_bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(null_bufnr, "diffview://null")

  for opt, val in pairs(const.BUFOPTS_PANEL) do
    vim.api.nvim_set_option_value(opt, val, { buf = null_bufnr })
  end
  vim.api.nvim_set_option_value("filetype", const.FT.SBS, { buf = null_bufnr })

  return null_bufnr
end

---Load null buffer into window
---@param winnr                        integer
function M.load_null_buffer(winnr)
  if vim.api.nvim_win_is_valid(winnr) then
    vim.api.nvim_win_set_buf(winnr, M.get_null_buffer())
  end
end

return M
