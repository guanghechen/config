---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.explorer.icons" ---@type string

local Future = require("stl.c.future")
local fileicon = require("stl.fileicon")
local M = {}

---@class era.m.explorer.IIcon
---@field kind                          string
---@field directory                     boolean
---@field label                         string
---@field path                          ?string
---@field icon                          string[]
---@field empty                         boolean

---@class era.m.explorer.IIconCache
---@field revision                      string
---@field values                        table<string, era.m.explorer.IIcon>

---@class era.m.explorer.IIcons
---@field cache                         era.m.explorer.IIconCache
---@field icons                         string[][]
---@field links                         boolean[]

---@param session                       era.m.explorer.Session
---@param frame                         yoz.ux.treeview.Frame
---@param rows                          ux.treeview.IRows
---@param previous                      ?era.m.explorer.IIconCache
---@param current                       fun(): boolean
---@return stl.c.Future
function M.prepare(session, frame, rows, previous, current)
  local source = frame:source()
  local revision = frame:header().data_revision
  local cached = previous and previous.values or {}
  local result = { cache = { revision = revision, values = {} }, icons = {}, links = {} }
  return Future.new(function(resolve, reject)
    local index = 1
    local step
    ---@return nil
    step = function()
      if not current() then
        resolve(false)
        return
      end
      local started = vim.uv.hrtime()
      while index <= #rows.ids and current() do
        local id = rows.ids[index]
        local value = cached[id]
        if not value or not previous or previous.revision ~= revision then
          local resource = session.data:inspect(source, id)
          local info = resource:info()
          local path
          if not info.directory then
            local ok, name = pcall(resource.path, resource)
            path = ok and name or nil
          end
          local icon = value
              and value.kind == info.kind
              and value.directory == info.directory
              and value.label == info.label
              and value.path == path
              and value.icon
            or nil
          if not icon then
            local glyph, group
            if info.directory then
              local fallback
              glyph, group, fallback = fileicon.get_directory_icon(info.label)
              if fallback then
                glyph, group = stl.icon.filetype.Folder, "m_ft_dirname"
              end
            elseif path then
              glyph, group = fileicon.get_file_icon(path)
            else
              -- Unrepresentable paths retain label-based icons without filetype detection.
              glyph, group = fileicon.get_file_icon(info.label, "")
            end
            icon = { glyph, group }
          end
          local node = info.directory and source:node(id) or nil
          value = {
            kind = info.kind,
            directory = info.directory,
            label = info.label,
            path = path,
            icon = icon,
            empty = node ~= nil and node.completeness == "complete" and node.child_count == 0,
          }
        end
        local icon = value.icon
        if value.directory and rows.expanded[index] then
          icon = { value.empty and stl.icon.filetype.FolderEmptyOpen or stl.icon.filetype.FolderOpen, icon[2] }
        end
        result.cache.values[id], result.icons[index], result.links[index] = value, icon, value.kind == "link"
        index = index + 1
        if index <= #rows.ids and vim.uv.hrtime() - started >= 2000000 then
          vim.schedule(function()
            local ok, error = pcall(step)
            if not ok then
              reject(error)
            end
          end)
          return
        end
      end
      resolve(current() and result or false)
    end
    step()
  end)
end

return M
