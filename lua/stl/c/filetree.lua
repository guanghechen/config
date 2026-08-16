---@diagnostic disable-next-line: unused-local
local __module_name__ = "stl.c.filetree" ---@type string

---@alias stl.c.IFiletreeTraverseConditional
---| fun(ctx: stl.c.IFiletreeTraverseContext, node: stl.c.IFiletreeNode, cur: integer): stl.c.ITreeTraverseConditionalEnum

---@alias stl.c.IFiletreeQuickTraverseHandler
---| fun(ctx: stl.c.IFiletreeTraverseContext, node: stl.c.IFiletreeNode, cur: integer): nil

---@alias stl.c.IFiletreeQuickTraverseRecursive
---| fun(ctx: stl.c.IFiletreeTraverseContext, node: stl.c.IFiletreeNode, cur: integer): nil

---@alias stl.c.IFiletreeUnsafeTraverseCallback
---| fun(ctx: stl.c.IFiletreeTraverseContext): nil

---@class stl.c.IFiletreeTraverseContext
---@field public nodemap                table<string, stl.c.IFiletreeNode>
---@field public rootnode               stl.c.IFiletreeNode

---@class stl.c.IFiletreeNode : stl.c.ITreeNode
---@field public data                   stl.c.IFiletreeNodeData

---@class stl.c.IFiletreeNodeData
---@field public basename               string
---@field public fileicon               string
---@field public fileicon_hln           string
---@field public filepath               string Canonical slash-only absolute filepath.
---@field public filepath_lower         string Lowercase canonical filepath.
---@field public filetype               "directory" | "file"

----------------------------------------------------------------------------------------------------

---@type table<string, string>
local FILEPATH_TO_UUID = {
  [""] = "d41d8cd98f00b204e9800998ecf8427e",
  ["/"] = "6666cd76f96956469e7be39d750cc7d9",
}

local FILETREE_ROOT_FILEPATH = stl.env.IS_WIN and "" or "/" ---@type string
local FILETREE_ROOT_UUID = FILEPATH_TO_UUID[FILETREE_ROOT_FILEPATH] ---@type string

---@type table<string, stl.c.IFiletreeNodeData>
local FILENODE_DATAMAP = {
  [FILETREE_ROOT_UUID] = {
    basename = FILETREE_ROOT_FILEPATH,
    fileicon = "󰙅",
    fileicon_hln = "MiniIconsBlue",
    filepath = FILETREE_ROOT_FILEPATH,
    filepath_lower = FILETREE_ROOT_FILEPATH:lower(),
    filetype = "directory",
  },
}

local FILETYPE_PRIORITY_MAP = {
  directory = 5,
  file = 3,
}

---@param left                          stl.c.IFiletreeNode
---@param right                         stl.c.IFiletreeNode
---@return boolean
local function compare_nodes(left, right)
  if left.data.filetype == right.data.filetype then
    return left.data.basename < right.data.basename
  end
  local left_priority = FILETYPE_PRIORITY_MAP[left.data.filetype] or 0 ---@type integer
  local right_priority = FILETYPE_PRIORITY_MAP[right.data.filetype] or 0 ---@type integer
  return left_priority > right_priority
end

---@class stl.c.IFiletreeProps
---@field public name                   string

---@class stl.c.IReadonlyFiletree : stl.c.IReadonlyTree
---@field public fullname               string
---@field public root                   string
---@field public isdisposed             fun(self: stl.c.IReadonlyFiletree): boolean
---@field public isdescendant           fun(self: stl.c.IReadonlyFiletree, ancestor: string, uuid: string): boolean
---@field public isexistent             fun(self: stl.c.IReadonlyFiletree, uuid: string): boolean
---@field public retrieve               fun(self: stl.c.IReadonlyFiletree, uuid: string): stl.c.IFiletreeNode|nil
---@field public children               fun(self: stl.c.IReadonlyFiletree, uuid: string): string[]|nil
---@field public quick_traverse         fun(self: stl.c.IReadonlyFiletree, root: string|nil, fn: stl.c.IFiletreeQuickTraverseHandler, conditional: stl.c.IFiletreeTraverseConditional|nil): stl.c.IReadonlyFiletree
---@field public unsafe_traverse        fun(self: stl.c.IReadonlyFiletree, root: string|nil, traverse: stl.c.IFiletreeUnsafeTraverseCallback): stl.c.IReadonlyFiletree

---@class stl.c.IFiletree : stl.c.ITree , stl.c.IReadonlyFiletree
---@field public fullname               string
---@field public root                   string
---@field public clear                  fun(self: stl.c.IFiletree): stl.c.IFiletree
---@field public dispose                fun(self: stl.c.IFiletree): nil
---@field public isdisposed             fun(self: stl.c.IFiletree): boolean
---@field public isdescendant           fun(self: stl.c.IFiletree, ancestor: string, uuid: string): boolean
---@field public isexistent             fun(self: stl.c.IFiletree, uuid: string): boolean
---@field public retrieve               fun(self: stl.c.IFiletree, uuid: string): stl.c.IFiletreeNode|nil
---@field public children               fun(self: stl.c.IFiletree, uuid: string): string[]|nil
---@field public quick_traverse         fun(self: stl.c.IFiletree, root: string|nil, fn: stl.c.IFiletreeQuickTraverseHandler, conditional: stl.c.IFiletreeTraverseConditional|nil): stl.c.IFiletree
---@field public unsafe_traverse        fun(self: stl.c.IFiletree, root: string|nil, traverse: stl.c.IFiletreeUnsafeTraverseCallback): stl.c.IFiletree
---@field public insert                 fun(self: stl.c.IFiletree, parent: string, uuid: string, data: stl.c.IFiletreeNodeData): stl.c.IFiletreeNode
---@field public insert_directory_absolute fun(self: stl.c.IFiletree, dirpath: string): stl.c.IFiletreeNode
---@field public insert_directory_relative fun(self: stl.c.IFiletree, cwd: string, dirpath: string): stl.c.IFiletreeNode
---@field public insert_file_absolute   fun(self: stl.c.IFiletree, filepath: string): stl.c.IFiletreeNode
---@field public insert_file_relative   fun(self: stl.c.IFiletree, cwd: string, filepath: string): stl.c.IFiletreeNode
---@field public remove                 fun(self: stl.c.IFiletree, uuid: string): stl.c.IFiletree
---@field public reset                  fun(self: stl.c.IFiletree, cwd: string, filepaths: string[], with_locations: boolean): stl.c.IFiletree

---@class stl.c.Filetree : stl.c.IFiletree
---@field public fullname               string
---@field protected _disposed           boolean
---@field protected _nodemap            table<string, stl.c.ITreeNode>
local M = {}
M.__index = M
setmetatable(M, stl.c.Tree)

---@param filepath                      string
---@return string
local function from_os_path(filepath)
  if filepath:find("\\", 1, true) == nil then
    return filepath
  end
  return yoz.canonical_path.from_os_path(filepath, false)
end

---@param filepath                      string
---@return boolean
local function is_cwd_chain(filepath)
  local cwd = yoz.canonical_path.get_cwd() ---@type string
  if cwd ~= "/" and cwd:sub(-1) == "/" then
    cwd = cwd:sub(1, -2)
  end
  if cwd == filepath or filepath == FILETREE_ROOT_FILEPATH then
    return true
  end

  local N1 = #cwd ---@type integer
  local N2 = #filepath ---@type integer
  if N1 < N2 then
    return filepath:sub(1, N1 + 1) == cwd .. "/"
  end

  return cwd:sub(1, N2 + 1) == filepath .. "/"
end

---@param filepath                      string Canonical filepath or OS filepath at ingress.
---@return string
function M.uuid(filepath)
  filepath = from_os_path(filepath)
  local uuid = FILEPATH_TO_UUID[filepath] ---@type string|nil
  if uuid == nil then
    if not yoz.canonical_path.is_absolute(filepath) then
      error(string.format("[%s.uuid] Cannot resolve UUID for relative path: %s", __module_name__, filepath))
    end

    uuid = yoz.fn.md5(filepath) ---@type string
    if is_cwd_chain(filepath) then
      FILEPATH_TO_UUID[filepath] = uuid
    end

    return uuid
  end
  return uuid
end

---@param filepath                      string
---@param filetype                      "directory" | "file"
---@param force                         boolean
---@return stl.c.IFiletreeNodeData
---@return string
function M.resolve(filepath, filetype, force)
  filepath = from_os_path(filepath)
  local nodeuuid = FILEPATH_TO_UUID[filepath] ---@type string|nil
  if nodeuuid == nil then
    if not yoz.canonical_path.is_absolute(filepath) then
      error(string.format("[%s.resolve] Cannot resolve UUID for relative path: %s", __module_name__, filepath))
    end
    nodeuuid = yoz.fn.md5(filepath) ---@type string
  end

  local nodedata = FILENODE_DATAMAP[nodeuuid]
  if nodedata == nil then
    local basename = yoz.canonical_path.basename(filepath) ---@type string
    local fileicon, fileicon_hln ---@type string, string
    if filetype == "directory" then
      fileicon, fileicon_hln = stl.fileicon.get_directory_icon(basename) ---@type string, string
    else
      fileicon, fileicon_hln = stl.fileicon.get_file_icon(basename) ---@type string, string
    end

    ---@type stl.c.IFiletreeNodeData
    nodedata = {
      basename = basename,
      fileicon = fileicon,
      fileicon_hln = fileicon_hln,
      filepath = filepath,
      filepath_lower = filepath:lower(),
      filetype = filetype,
    }

    if is_cwd_chain(filepath) then
      FILEPATH_TO_UUID[filepath] = nodeuuid
      FILENODE_DATAMAP[nodeuuid] = nodedata
    end
  elseif force then
    if nodedata.filetype ~= filetype then
      local fileicon, fileicon_hln ---@type string, string
      if filetype == "directory" then
        fileicon, fileicon_hln = stl.fileicon.get_directory_icon(nodedata.basename) ---@type string, string
      else
        fileicon, fileicon_hln = stl.fileicon.get_file_icon(nodedata.basename) ---@type string, string
      end
      nodedata.fileicon = fileicon
      nodedata.fileicon_hln = fileicon_hln
      nodedata.filetype = filetype
    end
  end
  return nodedata, nodeuuid
end

---@param props                         stl.c.IFiletreeProps
---@return stl.c.Filetree
function M.new(props)
  local name = props.name ---@type string
  local fullname = string.format("%s@%s", __module_name__, name) ---@type string

  local rootdata = M.resolve(FILETREE_ROOT_FILEPATH, "directory", true)
  local tree = stl.c.Tree.new("__virtual_root__", rootdata)
  tree.fullname = fullname

  local self = setmetatable(tree, M)
  ---@cast self                         stl.c.Filetree

  self:insert(self.root, FILETREE_ROOT_UUID, rootdata)

  return self
end

---@return stl.c.Filetree
function M:clear()
  stl.c.Tree.clear(self)
  local rootdata = M.resolve(FILETREE_ROOT_FILEPATH, "directory", true)
  self:insert(self.root, FILETREE_ROOT_UUID, rootdata)
  return self
end

---@param parent                        string
---@param uuid                          string
---@param data                          stl.c.IFiletreeNodeData
---@return stl.c.IFiletreeNode
function M:insert(parent, uuid, data)
  self:__health__()

  local node = self:retrieve(uuid) ---@type stl.c.IFiletreeNode|nil
  if node ~= nil then
    if self:parent(uuid) == parent then
      return self:update(uuid, data) ---@type stl.c.IFiletreeNode
    end
    stl.c.Tree.move(self, uuid, parent)
    node = self:update(uuid, data) ---@type stl.c.IFiletreeNode
  else
    node = stl.c.Tree.insert(self, parent, uuid, data) ---@type stl.c.IFiletreeNode
  end
  local parentnode = self:retrieve(parent) ---@type stl.c.IFiletreeNode
  parentnode.dirty_co = true
  return node
end

---@param nodeuuid                      string
---@return stl.c.Filetree
function M:remove(nodeuuid)
  self:__health__()
  if nodeuuid == FILETREE_ROOT_UUID then
    return self:clear()
  end
  if not self:contains(nodeuuid) then
    stl.reporter.error({
      from = self.fullname,
      subject = "remove",
      message = string.format("Node with uuid '%s' does not exist.", nodeuuid),
      details = { uuid = nodeuuid },
    })
    return self
  end
  stl.c.Tree.remove(self, nodeuuid)
  return self
end

---@param dirpath                       string
---@return stl.c.IFiletreeNode
function M:insert_directory_absolute(dirpath)
  self:__health__()

  local nodemap = self._nodemap ---@type table<string, stl.c.ITreeNode>
  ---@cast nodemap                      table<string, stl.c.IFiletreeNode>

  local nodeuuid = M.uuid(dirpath) ---@type string
  local node = nodemap[nodeuuid] ---@type stl.c.IFiletreeNode|nil
  if node == nil or node.data.filetype ~= "directory" then
    local pieces = yoz.canonical_path.split(dirpath, false) ---@type string[]
    local N = #pieces ---@type integer

    local p = "" ---@type string
    local uuid_parent = FILETREE_ROOT_UUID ---@type string

    if #pieces[1] == 2 and pieces[1]:sub(2, 2) == ":" then
      p = pieces[1] ---@type string
      nodeuuid = M.uuid(p) ---@type string
      node = nodemap[nodeuuid] ---@type stl.c.IFiletreeNode|nil
      if node == nil or node.data.filetype ~= "directory" then
        local nodedata = M.resolve(p, "directory", true)
        node = self:insert(uuid_parent, nodeuuid, nodedata)
      end
      uuid_parent = nodeuuid ---@type string
    end

    for index = 2, N, 1 do
      p = p .. "/" .. pieces[index] ---@type string
      nodeuuid = M.uuid(p) ---@type string
      node = nodemap[nodeuuid] ---@type stl.c.IFiletreeNode|nil
      if node == nil or node.data.filetype ~= "directory" then
        local nodedata = M.resolve(p, "directory", true)
        node = self:insert(uuid_parent, nodeuuid, nodedata)
      end
      uuid_parent = nodeuuid ---@type string
    end
  end

  return node
end

---@param cwd                           string
---@param dirpath                       string
---@return stl.c.IFiletreeNode
function M:insert_directory_relative(cwd, dirpath)
  self:__health__()

  local nodemap = self._nodemap ---@type table<string, stl.c.ITreeNode>
  ---@cast nodemap                      table<string, stl.c.IFiletreeNode>

  local cwduuid = M.uuid(cwd) ---@type string
  local cwdnode = nodemap[cwduuid] ---@type stl.c.IFiletreeNode|nil
  if cwdnode == nil or cwdnode.data.filetype ~= "directory" then
    cwdnode = self:insert_directory_absolute(cwd)
  end

  local nodeuuid = M.uuid(cwd .. "/" .. dirpath) ---@type string
  local node = nodemap[nodeuuid] ---@type stl.c.IFiletreeNode|nil
  if node == nil or node.data.filetype ~= "directory" then
    local pieces = yoz.canonical_path.split(dirpath, false) ---@type string[]
    local N = #pieces ---@type integer

    local p = cwd ---@type string
    local uuid_parent = cwduuid ---@type string

    for index = 1, N, 1 do
      p = p .. "/" .. pieces[index] ---@type string
      nodeuuid = M.uuid(p) ---@type string
      node = nodemap[nodeuuid] ---@type stl.c.IFiletreeNode|nil
      if node == nil or node.data.filetype ~= "directory" then
        local nodedata = M.resolve(p, "directory", true)
        node = self:insert(uuid_parent, nodeuuid, nodedata)
      end
      uuid_parent = nodeuuid ---@type string
    end
  end

  return node
end

---@param filepath                      string
---@return stl.c.IFiletreeNode
function M:insert_file_absolute(filepath)
  self:__health__()

  local nodemap = self._nodemap ---@type table<string, stl.c.ITreeNode>
  ---@cast nodemap                      table<string, stl.c.IFiletreeNode>

  local nodeuuid = M.uuid(filepath) ---@type string
  local node = nodemap[nodeuuid] ---@type stl.c.IFiletreeNode|nil
  if node == nil or node.data.filetype ~= "file" then
    local pieces = yoz.canonical_path.split(filepath, false) ---@type string[]
    local N = #pieces - 1 ---@type integer

    local p = "" ---@type string
    local uuid_parent = FILETREE_ROOT_UUID ---@type string

    if #pieces[1] == 2 and pieces[1]:sub(2, 2) == ":" then
      p = pieces[1] ---@type string
      nodeuuid = M.uuid(p) ---@type string
      node = nodemap[nodeuuid] ---@type stl.c.IFiletreeNode|nil
      if node == nil or node.data.filetype ~= "directory" then
        local nodedata = M.resolve(p, "directory", true)
        node = self:insert(uuid_parent, nodeuuid, nodedata)
      end
      uuid_parent = nodeuuid ---@type string
    end

    for index = 2, N, 1 do
      p = p .. "/" .. pieces[index] ---@type string
      nodeuuid = M.uuid(p) ---@type string
      node = nodemap[nodeuuid] ---@type stl.c.IFiletreeNode|nil
      if node == nil or node.data.filetype ~= "directory" then
        local nodedata = M.resolve(p, "directory", true)
        node = self:insert(uuid_parent, nodeuuid, nodedata)
      end

      uuid_parent = nodeuuid ---@type string
    end

    local basename = pieces[N + 1] ---@type string
    p = p .. "/" .. basename ---@type string
    nodeuuid = M.uuid(p) ---@type string
    node = nodemap[nodeuuid] ---@type stl.c.IFiletreeNode|nil
    if node == nil or node.data.filetype ~= "file" then
      local nodedata = M.resolve(p, "file", true)
      node = self:insert(uuid_parent, nodeuuid, nodedata)
    end
  end

  return node
end

---@param cwd                           string
---@param filepath                      string
---@return stl.c.IFiletreeNode
function M:insert_file_relative(cwd, filepath)
  self:__health__()

  local nodemap = self._nodemap ---@type table<string, stl.c.ITreeNode>
  ---@cast nodemap                      table<string, stl.c.IFiletreeNode>

  local cwduuid = M.uuid(cwd) ---@type string
  local cwdnode = nodemap[cwduuid] ---@type stl.c.IFiletreeNode|nil
  if cwdnode == nil or cwdnode.data.filetype ~= "directory" then
    cwdnode = self:insert_directory_absolute(cwd)
  end

  local nodeuuid = M.uuid(cwd .. "/" .. filepath) ---@type string
  local node = nodemap[nodeuuid] ---@type stl.c.IFiletreeNode|nil
  if node == nil or node.data.filetype ~= "file" then
    local pieces = yoz.canonical_path.split(filepath, false) ---@type string[]
    local N = #pieces - 1 ---@type integer

    local p = cwd ---@type string
    local uuid_parent = cwduuid ---@type string

    for index = 1, N, 1 do
      p = p .. "/" .. pieces[index] ---@type string
      nodeuuid = M.uuid(p) ---@type string
      node = nodemap[nodeuuid] ---@type stl.c.IFiletreeNode|nil
      if node == nil or node.data.filetype ~= "directory" then
        local nodedata = M.resolve(p, "directory", true)
        node = self:insert(uuid_parent, nodeuuid, nodedata)
      end

      uuid_parent = nodeuuid ---@type string
    end

    local basename = pieces[N + 1] ---@type string
    p = p .. "/" .. basename ---@type string
    nodeuuid = M.uuid(p) ---@type string
    node = nodemap[nodeuuid] ---@type stl.c.IFiletreeNode|nil
    if node == nil or node.data.filetype ~= "file" then
      local nodedata = M.resolve(p, "file", true)
      node = self:insert(uuid_parent, nodeuuid, nodedata)
    end
  end

  return node
end

---@param cwd                           string Canonical cwd or OS cwd at ingress.
---@param filepaths                     string[] Canonical relative/absolute filepaths; OS separators are accepted at ingress.
---@param with_locations                boolean
---@return stl.c.Filetree
function M:reset(cwd, filepaths, with_locations)
  self:__health__()
  self:clear()

  if #filepaths < 1 then
    return self
  end

  cwd = yoz.canonical_path.from_os_path(cwd, false)
  local P = cwd == "/" and "/" or (cwd .. "/") ---@type string
  local L = #P ---@type integer

  local visited_filepaths = {} ---@type table<string, boolean>

  ---@param filepath                    string
  local function insert_relative_filepath(filepath)
    if visited_filepaths[filepath] then
      return
    end
    visited_filepaths[filepath] = true

    self:insert_file_relative(cwd, filepath)
  end

  if with_locations then
    for _, p in ipairs(filepaths) do
      local filepath = stl.string.parse_filepath_with_location(p) ---@type string, integer|nil, integer|nil
      filepath = from_os_path(filepath)
      if yoz.canonical_path.is_absolute(filepath) then
        if filepath:sub(1, L) ~= P then
          self:insert_file_absolute(filepath)
        else
          filepath = filepath:sub(L + 1) ---@type string
          insert_relative_filepath(filepath)
        end
      else
        insert_relative_filepath(filepath)
      end
    end
  else
    for _, filepath in ipairs(filepaths) do
      filepath = from_os_path(filepath)
      if yoz.canonical_path.is_absolute(filepath) then
        if filepath:sub(1, L) ~= P then
          self:insert_file_absolute(filepath)
        else
          filepath = filepath:sub(L + 1) ---@type string
          insert_relative_filepath(filepath)
        end
      else
        insert_relative_filepath(filepath)
      end
    end
  end
  return self
end

---@protected
---@param node                          stl.c.IFiletreeNode
---@return nil
function M:__sort_children__(node)
  node.dirty_co = false
  if #node.children > 1 then
    local nodemap = self._nodemap ---@type table<string, stl.c.IFiletreeNode>
    table.sort(node.children, function(left_uuid, right_uuid)
      return compare_nodes(nodemap[left_uuid], nodemap[right_uuid])
    end)
  end
end

----------------------------------------------------------------------------------------------------

---@protected
---@return nil
function M:__health__()
  if self._disposed then
    local message = string.format("%s has been disposed.", self.fullname) ---@type string
    error(message)
  end
end

return M
