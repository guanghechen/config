---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.view.git_files" ---@type string

local Files = require("era.view.result_files")
local Tree = require("era.view.result_tree")
local Paths = require("era.view.result_paths")
local namespace = vim.api.nvim_create_namespace("era.git_files")
local codes = { "U", "D", "A", "R", "C", "M", "T", "?" }

---@alias era.view.git_files.Scope "staged"|"unstaged"

---@class era.view.git_files.IMetadata
---@field scope                         era.view.git_files.Scope
---@field status                        string
---@field path                          ?string Repository-relative file path.
---@field previous                      ?string Rename/copy source.
---@field insertions                    ?integer
---@field deletions                     ?integer
---@field count                         integer
---@field unknown                       integer Files without numeric stats.
---@field directory                     ?boolean

---@class era.view.git_files.IEntry : era.view.result_tree.IEntry
---@field git                           era.view.git_files.IMetadata
---@field column_widths                 era.view.git_files.IColumnWidths

---@class era.view.git_files.IColumnWidths
---@field insertions                    integer
---@field deletions                     integer
---@field status                        integer
---@field unknown                       integer

---@class era.view.git_files.IPlan
---@field source                        era.view.ResultPaths
---@field entries                       table<string, era.view.git_files.IEntry>
---@field root                          string
---@field totals                        era.view.git_files.IMetadata
---@field columns                       era.view.git_files.IColumnWidths

---@class era.view.GitFiles : era.view.ResultFiles
---@field source                        era.view.ResultPaths
---@field scope                         era.view.git_files.Scope
---@field root                          ?string
---@field totals                        ?era.view.git_files.IMetadata
---@field pattern                       string
local M = setmetatable({}, { __index = Files })
M.__index = M

---@param status                        string
---@param scope                         era.view.git_files.Scope
---@return string
local function status_highlight(status, scope)
  if status:find("U", 1, true) then
    return "m_ft_git_unmerged"
  elseif status:find("D", 1, true) then
    return "m_ft_git_delete"
  elseif status == "?" then
    return "m_ft_git_untracked"
  end
  return scope == "staged" and "m_ft_git_staged" or "m_ft_git_unstaged"
end

---Root totals bound every file and directory; measure both sides before publication.
---@param totals                        era.view.git_files.IMetadata[]
---@return era.view.git_files.IColumnWidths
function M.measure_columns(totals)
  local columns = { insertions = 2, deletions = 2, status = 1, unknown = 0 }
  for _, git in ipairs(totals) do
    columns.insertions = math.max(columns.insertions, #(tostring(git.insertions or 0)) + 1)
    columns.deletions = math.max(columns.deletions, #(tostring(git.deletions or 0)) + 1)
    columns.status = math.max(columns.status, #git.status)
    columns.unknown = math.max(columns.unknown, git.unknown > 0 and 2 or 0)
  end
  return columns
end

---@param git                           era.view.git_files.IMetadata
---@param columns                       era.view.git_files.IColumnWidths
---@return [string, string][]
function M.overlay(git, columns)
  local insertions = git.insertions ~= nil and "+" .. git.insertions or ""
  local deletions = git.deletions ~= nil and "-" .. git.deletions or ""
  local chunks = {
    { " " .. stl.string.pad_start(insertions, columns.insertions, " "), "m_ft_git_add" },
    { " " .. stl.string.pad_start(deletions, columns.deletions, " "), "m_ft_git_delete" },
  }
  if columns.unknown > 0 then
    local marker = git.unknown > 0 and (git.directory and "?" or "—") or ""
    chunks[#chunks + 1] = { stl.string.pad_start(marker, columns.unknown, " "), "m_ft_git_other" }
  end
  chunks[#chunks + 1] = {
    " " .. stl.string.pad_end(git.status, columns.status, " "),
    status_highlight(git.status, git.scope),
  }
  return chunks
end

---@param name                          string
---@param scope                         era.view.git_files.Scope
---@return era.view.GitFiles
function M.new(name, scope)
  assert(scope == "staged" or scope == "unstaged", "invalid Git Files scope")
  local self = Tree.new({
    name = name,
    tree = Paths.new(),
    present = function(_, data, entry)
      local directory = entry.nodetype == "container"
      local label = vim.fn.strtrans(data.basename)
      local fields = { git = entry.git, git_columns = entry.column_widths }
      fields[directory and "directory_icon" or "file_icon"] = label
      return {
        label = label,
        icon = directory and "" or nil,
        highlight = directory and "m_ft_dirname" or status_highlight(entry.git.status, scope),
        fields = fields,
      }
    end,
  })
  ---@cast self era.view.GitFiles
  self.scope, self.pattern = scope, ""
  return setmetatable(self, M)
end

---Build one side privately; the widget prepares both sides before adopting either.
---@param root                          string
---@param paths                         string[] Absolute paths from the same Git snapshot.
---@param snapshot                      yoz.git.StatusData
---@param checkpoint                    fun(): nil
---@return era.view.git_files.IPlan
function M:prepare(root, paths, snapshot, checkpoint)
  local source = self.source:prepare(root, paths, checkpoint)
  local entries, statuses = {}, {}
  for key, record in pairs(source.records) do
    local directory = record.data.filetype == "directory"
    entries[key] = {
      key = key,
      nodetype = directory and "container" or "leaf",
      git = {
        scope = self.scope,
        status = "",
        count = 0,
        unknown = 0,
        insertions = 0,
        deletions = 0,
        directory = directory,
      },
    }
    statuses[key] = {}
    checkpoint()
  end
  for _, path in ipairs(paths) do
    local key = Paths.key(path)
    local info = assert(snapshot.status_map[path], "Git path missing from its snapshot")
    local flags = info[self.scope]
    local stat = snapshot.numstats and snapshot.numstats[self.scope][info.relative]
    local git = entries[key].git
    git.path, git.previous = info.relative, info[self.scope .. "_prev_relative"]
    git.count, git.unknown = 1, stat and 0 or 1
    git.insertions, git.deletions = stat and stat.insertions, stat and stat.deletions
    local current = key ---@type string|nil
    while current do
      local aggregate = entries[current].git
      if current ~= key then
        aggregate.count = aggregate.count + 1
        aggregate.insertions = aggregate.insertions + (git.insertions or 0)
        aggregate.deletions = aggregate.deletions + (git.deletions or 0)
        aggregate.unknown = aggregate.unknown + git.unknown
      end
      for code, present in pairs(flags) do
        if present then
          statuses[current][code] = true
        end
      end
      current = source:parent(current)
      checkpoint()
    end
  end
  local root_key = Paths.key(root)
  local totals = entries[root_key].git
  local columns = M.measure_columns({ totals })
  for key, entry in pairs(entries) do
    local display = {}
    for _, code in ipairs(codes) do
      if statuses[key][code] then
        display[#display + 1] = code
      end
    end
    entry.git.status = table.concat(display)
    columns.status = math.max(columns.status, #entry.git.status)
    entry.column_widths = columns
    checkpoint()
  end
  return { source = source, entries = entries, root = root_key, totals = totals, columns = columns }
end

---@param plan                          era.view.git_files.IPlan
---@return nil
function M:apply(plan)
  local retained = self.root
  Files.adopt_filepaths(self, plan.source, plan.entries)
  self.root = retained and self.source:contains(retained) and retained or plan.root
  self.totals = plan.totals
end

---@param pattern                       string
---@param foldempty                     boolean
---@return stl.c.Future
function M:render(pattern, foldempty)
  self.pattern = pattern
  local orders
  if pattern ~= "" then
    orders =
      self:match({ rootuuid = self.root, pattern = pattern, fuzzy = true, regex = false, case_sensitive = false })
  else
    self:clear_match()
  end
  local matches = orders and self._matches or nil
  local request = {
    mode = "tree",
    rootuuid = self.root or self.source.root,
    foldempty = foldempty,
    orders = orders,
    only_matched = orders ~= nil,
  }
  self._render = request
  return self:publish(request):map(function(reply)
    if self._render == request and reply.kind == "Applied" then
      self._shown_matches = matches
    end
    return reply
  end)
end

---Expand directory targets using the displayed metadata revision and active path filter.
---Collapsed descendants remain eligible; filtered-out files and the other pane do not.
---@param keys                          string[]
---@param frame                         ?yoz.ux.treeview.Frame
---@return era.view.git_files.IMetadata[]
function M:targets(keys, frame)
  frame = frame or self:frame()
  local version = frame and self._versions[frame:header().data_revision]
  if not version then
    return {}
  end
  local targets, directories, files = {}, {}, {}
  for _, key in ipairs(keys) do
    local data, entry = self:data(key, frame), self:retrieve(key, frame)
    if data and entry then
      if entry.nodetype == "container" then
        directories[#directories + 1] = data.filepath .. "/"
      else
        files[key] = true
      end
    end
  end
  for key, entry in pairs(version.entries) do
    if entry.nodetype == "leaf" and (not self._shown_matches or self._shown_matches[key]) then
      local path = version.data[key].filepath
      local included = files[key]
      for _, prefix in ipairs(directories) do
        if path:sub(1, #prefix) == prefix then
          included = true
          break
        end
      end
      if included then
        targets[#targets + 1] = entry.git
      end
    end
  end
  table.sort(targets, function(left, right)
    return left.path < right.path
  end)
  return targets
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
  local node = Tree.decorate_row(self, view, frame, row, id, col, label, expanded)
  local git = node and node.fields.git
  if not node or not git or git.count == 0 then
    return
  end
  vim.api.nvim_buf_set_extmark(view.bufnr, namespace, row, 0, {
    ephemeral = true,
    virt_text = M.overlay(git, node.fields.git_columns),
    virt_text_pos = "right_align",
    hl_mode = "combine",
    priority = 160,
  })
end

return M
