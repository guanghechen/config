---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.view.result_files" ---@type string

local ResultTree = require("era.view.result_tree")
local Paths = require("era.view.result_paths")

---@class era.view.ResultFiles : era.view.ResultTree
local M = setmetatable({}, { __index = ResultTree })
M.__index = M

---@param props                         table
---@return era.view.ResultFiles
function M.new(props)
  props.present = function(key, data, entry)
    if entry.nodetype == "location" then
      local text, highlights
      if props.render_treeview_location then
        text, highlights = props.render_treeview_location({}, key, data, nil, entry, 0)
      else
        text, highlights = M.present_location(entry)
      end
      return { label = text, highlight = "m_ft_text", fields = { highlights = highlights or {} } }
    end
    if entry.nodetype == "container" then
      local name = vim.fn.strtrans(data.basename or "")
      return { label = name, icon = "", highlight = "m_ft_dirname", fields = { directory_icon = name } }
    end
    local name = vim.fn.strtrans(data.basename)
    local text = name
    local highlights = {}
    local git, highlight = era.m.git.status.calc_info(data.filepath, data.filetype, #text, highlights)
    text = text .. git
    text = text .. era.m.lsp.diagnostic.render(data.filepath, #text, highlights)
    return {
      label = text,
      icon = entry.locations and #entry.locations > 0 and "" or nil,
      highlight = highlight or "m_ft_filename",
      fields = { highlights = highlights, file_icon = name },
    }
  end
  return setmetatable(ResultTree.new(props), M)
end

---@param location                      era.view.result_tree.IEntry
---@return string
---@return stl.t.IHighlightInline[]
function M.present_location(location)
  local position = location.col and string.format("%4d:%-4d", location.lnum, location.col)
    or string.format("%4d:", location.lnum)
  local text = position .. " " .. (location.text or "")
  local highlights = { { coll = 0, colr = #position, hlname = "m_ft_position" } }
  for _, highlight in ipairs(location.highlights or {}) do
    highlights[#highlights + 1] = {
      coll = #position + 1 + highlight.coll,
      colr = highlight.colr < 0 and -1 or #position + 1 + highlight.colr,
      hlname = highlight.hlname,
    }
  end
  return text, highlights
end

---@return nil
function M:_sync_entries()
  self.source:walk(nil, function(key, data)
    if not self.entries[key] then
      self.entries[key] = { nodetype = data.filetype == "directory" and "container" or "leaf", key = key }
    end
  end)
  self:invalidate()
end

---@param path                          string
---@return nil
function M:insert_dirpath(path)
  self.source:insert_directory_absolute(path)
  self:_sync_entries()
end

---@param path                          string
---@param with_locations                boolean
---@return nil
function M:insert_filepath(path, with_locations)
  local lnum, col, col_end
  if with_locations then
    path, lnum, col, col_end = stl.string.parse_filepath_with_location(path)
  end
  local key = self.source:insert_file_absolute(path)
  self:_sync_entries()
  if lnum then
    self:add_location(key, { lnum = lnum, col = col, col_end = col_end })
  end
end

---@param key                           string
---@param location                      table
---@return nil
function M:add_location(key, location)
  local leaf = assert(self.entries[key], "missing file result")
  location.nodetype, location.leafuuid = "location", key
  location.locationuuid = location.locationuuid or string.format("%s:%d:%d", key, location.lnum, location.col or 0)
  leaf.locations = leaf.locations or {}
  if not self.entries[location.locationuuid] then
    leaf.locations[#leaf.locations + 1] = location
  else
    for index, existing in ipairs(leaf.locations) do
      if existing.locationuuid == location.locationuuid then
        leaf.locations[index] = location
        break
      end
    end
  end
  self.entries[location.locationuuid] = location
  self:invalidate()
end

---@param cwd                           string
---@param paths                         string[]
---@param with_locations                ?boolean
---@return nil
function M:reset_filepaths(cwd, paths, with_locations)
  self:clear()
  self.source:reset(cwd, paths, with_locations == true)
  self:_sync_entries()
  if with_locations then
    for _, value in ipairs(paths) do
      local path, lnum, col, col_end = stl.string.parse_filepath_with_location(value)
      if lnum then
        if not yoz.canonical_path.is_absolute(path) then
          path = yoz.canonical_path.join(cwd, path, false)
        end
        self:add_location(Paths.key(path), { lnum = lnum, col = col, col_end = col_end })
      end
    end
  end
end

---@param root                          ?string
---@return string[]
function M:collect_file_uuids(root)
  return self:collect_leafs(root)
end

---@param root                          ?string
---@param visit                         fun(key: string, data: table, entry: era.view.result_tree.IEntry): nil
---@return nil
function M:traverse_filenode(root, visit)
  for _, key in ipairs(self:collect_leafs(root)) do
    visit(key, self.source:get(key), self.entries[key])
  end
end

---@param root                          string
---@param selected                      table<string, true>
---@return nil
function M:restore_subtree(root, selected)
  self:_sync_entries()
  self._restore_selection = selected
end

return M
