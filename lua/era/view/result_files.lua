---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.view.result_files" ---@type string

local ResultTree = require("era.view.result_tree")
local Paths = require("era.view.result_paths")
local namespace = vim.api.nvim_create_namespace("era.result_files")

---@param location                      era.view.result_tree.IEntry
---@return string
local function location_prefix(location)
  return location.col and string.format("%4d:%-4d", location.lnum, location.col) or string.format("%4d:", location.lnum)
end

---@class era.view.ResultFiles : era.view.ResultTree
---@field public source                 era.view.ResultPaths
---@field public data                   fun(self: era.view.ResultFiles, key?: string, frame?: yoz.ux.treeview.Frame): era.view.result_paths.IFile|nil
---@field public iter_rows              fun(self: era.view.ResultFiles, frame: yoz.ux.treeview.Frame, first?: integer, last?: integer): fun(): integer|nil, string|nil, era.view.result_paths.IFile|nil, era.view.result_tree.IEntry|nil
local M = setmetatable({}, { __index = ResultTree })
M.__index = M

---@param props                         table
---@return era.view.ResultFiles
function M.new(props)
  props.present = function(_, data, entry)
    if entry.nodetype == "location" then
      return { label = location_prefix(entry) .. " " .. (entry.text or ""), highlight = "m_ft_text" }
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
      fields = { highlights = #highlights > 0 and highlights or nil, file_icon = name },
    }
  end
  return setmetatable(ResultTree.new(props) --[[@as era.view.ResultFiles]], M)
end

---@param location                      era.view.result_tree.IEntry
---@return string
---@return stl.t.IHighlightInline[]
function M.present_location(location)
  local position = location_prefix(location)
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

---@param view                          ux.treeview.View
---@param frame                         yoz.ux.treeview.Frame
---@param row                           integer
---@param id                            string
---@param col                           integer
---@param label                         string
---@param expanded                      boolean
---@return nil
function M:decorate_row(view, frame, row, id, col, label, expanded)
  local node = ResultTree.decorate_row(self, view, frame, row, id, col, label, expanded)
  local version = self._versions[self:_read(frame).header.data_revision]
  local entry = node and version and version.entries[node.key]
  if not entry or entry.nodetype ~= "location" then
    return
  end
  local text, highlights = M.present_location(entry)
  local offset = #label - #text
  for _, highlight in ipairs(highlights) do
    local first = offset + highlight.coll
    local last = highlight.colr < 0 and #label or math.min(#label, offset + highlight.colr)
    if first < last then
      vim.api.nvim_buf_set_extmark(view.bufnr, namespace, row, col + first, {
        ephemeral = true,
        end_col = col + last,
        hl_group = highlight.hlname,
        priority = 160,
      })
    end
  end
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
  local revision = self.source.revision
  local icons, directories = self._icons, self._directory_icons
  self:clear()
  self.source:reset(cwd, paths, with_locations == true)
  if self.source.revision == revision then
    self._icons, self._directory_icons = icons, directories
  end
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

---@param source                        era.view.ResultPaths
---@param entries                       table<string, era.view.result_tree.IEntry>
---@return nil
function M:adopt_filepaths(source, entries)
  local reused = source == self.source
  local icons, directories = self._icons, self._directory_icons
  self:clear()
  if not reused then
    self.source:adopt(source)
  else
    self._icons, self._directory_icons = icons, directories
  end
  self.entries = entries
  self:clear_match()
end

---@param root                          ?string
---@return string[]
function M:collect_file_uuids(root)
  return self:collect_leafs(root)
end

---@param root                          ?string
---@param visit                         fun(key: string, data: era.view.result_paths.IFile, entry: era.view.result_tree.IEntry): nil
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
