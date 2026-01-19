---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.diffview.util" ---@type string

local S = era.m.diffview

---@class era.m.diffview.util
local M = {}

----------------------------------------------------------------------------------------------------
-- Path utilities
----------------------------------------------------------------------------------------------------

---Get display name for file entry
---@param entry                        era.m.diffview.IFileEntry
---@return string
function M.get_display_name(entry)
  local basename = vim.fn.fnamemodify(entry.filepath, ":t")
  local dirname = vim.fn.fnamemodify(entry.filepath, ":h")
  if dirname == "." then
    return basename
  end
  return basename .. " " .. dirname
end

---Get status icon for file entry
---@param status                       string
---@return string
function M.get_status_icon(status)
  return S.config.STATUS_ICONS[status] or "?"
end

---Get status highlight group
---@param status                       string
---@return string
function M.get_status_hlgroup(status)
  if status == "A" or status == "?" then
    return "m_dv_ft_status_add"
  elseif status == "D" then
    return "m_dv_ft_status_delete"
  elseif status == "M" or status == "T" or status == "U" then
    return "m_dv_ft_status_modify"
  elseif status == "R" or status == "C" then
    return "m_dv_ft_status_rename"
  end
  return "m_dv_ft_filename"
end

----------------------------------------------------------------------------------------------------
-- Tab utilities
----------------------------------------------------------------------------------------------------

---@type table<string, boolean>
local DIFFVIEW_TABTYPES = {
  diffview_workspace = true,
  diffview_commits = true,
}

---Check if tab is a diffview tab
---@param tabnr                        integer|nil
---@return boolean
function M.is_diffview_tab(tabnr)
  tabnr = tabnr or vim.api.nvim_get_current_tabpage()
  local tabtype = vim.t[tabnr].tabtype ---@type string|nil
  return tabtype ~= nil and DIFFVIEW_TABTYPES[tabtype] == true
end

---Mark current tab as diffview
---@param tabnr                        integer
---@param tabtype                      stl.nvim.tab.TypeEnum
function M.mark_as_diffview_tab(tabnr, tabtype)
  vim.t[tabnr].tabtype = tabtype
end

---Unmark diffview tab
---@param tabnr                        integer
function M.unmark_diffview_tab(tabnr)
  vim.t[tabnr].tabtype = nil
end

----------------------------------------------------------------------------------------------------
-- Git object utilities
----------------------------------------------------------------------------------------------------

---Generate git object path for staged file
---@param filepath                     string                          relative path
---@return string
function M.staged_object(filepath)
  return ":" .. filepath
end

---Generate git object path for HEAD version
---@param filepath                     string                          relative path
---@return string
function M.head_object(filepath)
  return "HEAD:" .. filepath
end

---Generate git object path for specific commit
---@param commit_hash                  string
---@param filepath                     string                          relative path
---@return string
function M.commit_object(commit_hash, filepath)
  return commit_hash .. ":" .. filepath
end

----------------------------------------------------------------------------------------------------
-- Buffer name utilities
----------------------------------------------------------------------------------------------------

---Generate buffer name for old version
---@param filepath                     string
---@param rev                          string                          revision (e.g., "HEAD", "index")
---@return string
function M.gen_old_bufname(filepath, rev)
  local workspace = dot.path.workspace()
  return string.format("diffview://%s/%s/%s", workspace, rev, filepath)
end

---Generate buffer name for new version (index)
---@param filepath                     string
---@return string
function M.gen_index_bufname(filepath)
  local workspace = dot.path.workspace()
  return string.format("diffview://%s/index/%s", workspace, filepath)
end

----------------------------------------------------------------------------------------------------
-- Stat formatting
----------------------------------------------------------------------------------------------------

---Format insertions/deletions for display
---@param insertions                   integer|nil
---@param deletions                    integer|nil
---@return string
function M.format_stat(insertions, deletions)
  local parts = {}
  if insertions and insertions > 0 then
    parts[#parts + 1] = string.format("+%d", insertions)
  end
  if deletions and deletions > 0 then
    parts[#parts + 1] = string.format("-%d", deletions)
  end
  if #parts == 0 then
    return ""
  end
  return table.concat(parts, " ")
end

----------------------------------------------------------------------------------------------------
-- Date formatting
----------------------------------------------------------------------------------------------------

---Format unix timestamp to relative time
---@param timestamp                    integer
---@return string
function M.format_relative_time(timestamp)
  local now = os.time()
  local diff = now - timestamp

  if diff < 60 then
    return "just now"
  elseif diff < 3600 then
    local mins = math.floor(diff / 60)
    return string.format("%d min%s ago", mins, mins == 1 and "" or "s")
  elseif diff < 86400 then
    local hours = math.floor(diff / 3600)
    return string.format("%d hour%s ago", hours, hours == 1 and "" or "s")
  elseif diff < 604800 then
    local days = math.floor(diff / 86400)
    return string.format("%d day%s ago", days, days == 1 and "" or "s")
  elseif diff < 2592000 then
    local weeks = math.floor(diff / 604800)
    return string.format("%d week%s ago", weeks, weeks == 1 and "" or "s")
  elseif diff < 31536000 then
    local months = math.floor(diff / 2592000)
    return string.format("%d month%s ago", months, months == 1 and "" or "s")
  else
    local years = math.floor(diff / 31536000)
    return string.format("%d year%s ago", years, years == 1 and "" or "s")
  end
end

---Format unix timestamp to date string
---@param timestamp                    integer
---@return string
function M.format_date(timestamp)
  return os.date("%Y-%m-%d %H:%M", timestamp) --[[@as string]]
end

return M
