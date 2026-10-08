---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.explorer.path_display" ---@type string

local txt = stl.nvim.fn.txt
local filepath = require("ux.filetree.path")

---@param path                          string
---@return string
local function display_path(path)
  -- Display may shorten a logical prefix; filesystem operations retain it.
  if stl.env.IS_WIN then
    path = path:gsub("^//%?/UNC/", "//"):gsub("^//%?/([A-Za-z]:/)", "%1")
    path = path:gsub("^%a:", string.upper)
  end
  if path == "/" or path:match("^%a:/$") then
    return path
  end
  return (path:gsub("/+$", ""))
end

local CWD = display_path(filepath.from_os(dot.path.cwd())) ---@type string
local WORKSPACE = display_path(filepath.from_os(dot.path.workspace())) ---@type string
local WORKSPACE_NAME = WORKSPACE:match("([^/]+)$") or WORKSPACE ---@type string
local HOME_USER = display_path(filepath.from_os(stl.env.HOME_USER)) ---@type string

---@param path                          string
---@param prefix                        string
---@return boolean
local function has_path_prefix(path, prefix)
  if prefix == "" then
    return false
  end
  if path == prefix then
    return true
  end
  local boundary = prefix:sub(-1) == "/" and prefix or prefix .. "/"
  return path:sub(1, #boundary) == boundary
end

local CWD_IN_WORKSPACE = CWD ~= WORKSPACE and has_path_prefix(CWD, WORKSPACE) ---@type boolean

---@class era.m.explorer.path_display
local M = {}

---@param status                        string
---@param priority                      "error"|"progress"
---@param width                         integer
---@return string
function M.fit_status(status, priority, width)
  local text = vim.fn.strtrans(status)
  if vim.api.nvim_strwidth(text) <= width then
    return text
  end
  if priority == "error" then
    if width >= 9 then
      return "error · R"
    end
    return width >= 3 and "! R" or "!"
  end
  text = text:gsub(" items / ", " / ")
  if vim.api.nvim_strwidth(text) <= width then
    return text
  end
  text = vim.fn.strcharpart(text, 0, width - 1)
  while vim.api.nvim_strwidth(text) > width - 1 do
    text = vim.fn.strcharpart(text, 0, vim.fn.strchars(text) - 1)
  end
  return text .. "…"
end

---@param root_filepath                 ?string
---@param position                      stl.t.NvimbarPositionEnum
---@param status                        string
---@return string path_text
---@return string path_hl_text
---@return string detached_text
---@return string detached_hl_text
function M.format(root_filepath, position, status)
  local path = display_path(root_filepath or WORKSPACE)
  local is_cwd = has_path_prefix(path, CWD)
  local display
  if is_cwd and (CWD == WORKSPACE or CWD_IN_WORKSPACE) then
    local offset = #WORKSPACE + (WORKSPACE:sub(-1) == "/" and 1 or 2)
    local relative = path:sub(offset):gsub("/+$", "")
    local separator = WORKSPACE_NAME:sub(-1) == "/" and "" or "/"
    display = CWD == WORKSPACE and WORKSPACE_NAME .. (relative == "" and "" or separator .. relative) or relative
  else
    if has_path_prefix(path, HOME_USER) then
      path = "~" .. path:sub(#HOME_USER + 1)
    end
    display = dot.path.shorten(path)
  end
  local icon = is_cwd and stl.icon.filetype.FolderWithHeart or stl.icon.filetype.Folder
  local text = icon .. " " .. vim.fn.strtrans(display)
  if status ~= "" then
    text = text .. " [" .. vim.fn.strtrans(status) .. "]"
  end
  local detached = is_cwd and "" or " " .. stl.icon.ui.CircleMedium
  local hlname = position .. (is_cwd and "_explorer_path" or "_explorer_path_detached")
  return text, txt(text, hlname), detached, txt(detached, position .. "_explorer_detached")
end

return M
