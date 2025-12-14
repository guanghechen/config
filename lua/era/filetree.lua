local __module_name__ = "era.filetree" ---@type string

---@alias era.t.IFiletreeTraverseConditional
---| fun(ctx: era.t.IFiletreeTraverseContext, node: era.t.IFiletreeNode, cur: integer): era.t.ITreeTraverseConditionalEnum

---@alias era.t.IFiletreeTraverseHandler
---| fun(ctx: era.t.IFiletreeTraverseContext, node: era.t.IFiletreeNode, cur: integer, is_lastchild: boolean, onlychild: string|nil, childcount: integer): nil

---@alias era.t.IFiletreeTraverseRecursive
---| fun(ctx: era.t.IFiletreeTraverseContext, node: era.t.IFiletreeNode, cur: integer, is_lastchild: boolean): nil

---@alias era.t.IFiletreeQuickTraverseHandler
---| fun(ctx: era.t.IFiletreeTraverseContext, node: era.t.IFiletreeNode, cur: integer): nil

---@alias era.t.IFiletreeQuickTraverseRecursive
---| fun(ctx: era.t.IFiletreeTraverseContext, node: era.t.IFiletreeNode, cur: integer): nil

---@alias era.t.IFiletreeUnsafeTraverseCallback
---| fun(ctx: era.t.IFiletreeTraverseContext): nil

---@class era.t.IFiletreeTraverseContext
---@field public nodemap                table<string, era.t.IFiletreeNode>
---@field public rootnode               era.t.IFiletreeNode

---@class era.t.IFiletreeNode : era.t.ITreeNode
---@field public data                   era.t.IFiletreeNodeData

---@class era.t.IFiletreeNodeData
---@field public basename               string
---@field public fileicon               string
---@field public fileicon_hln           string
---@field public filepath               string
---@field public filepath_lower         string
---@field public filetype               "directory" | "file"

----------------------------------------------------------------------------------------------------

---@type table<string, string>
local FILEPATH_TO_UUID = {
  [""] = "d41d8cd98f00b204e9800998ecf8427e",
  ["/"] = "6666cd76f96956469e7be39d750cc7d9",
}

local FILETREE_ROOT_FILEPATH = dot.env.IS_WIN and "" or "/" ---@type string
local FILETREE_ROOT_UUID = FILEPATH_TO_UUID[FILETREE_ROOT_FILEPATH] ---@type string

---@type table<string, era.t.IFiletreeNodeData>
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

---@class era.IFiletreeProps
---@field public name                   string

---@class era.IReadonlyFiletree : era.IReadonlyTree
---@field public fullname               string
---@field public root                   string
---@field public isdisposed             fun(self: era.IReadonlyFiletree): boolean
---@field public isdescendant           fun(self: era.IReadonlyFiletree, ancestor: string, uuid: string): boolean
---@field public isexistent             fun(self: era.IReadonlyFiletree, uuid: string): boolean
---@field public retrieve               fun(self: era.IReadonlyFiletree, uuid: string): era.t.IFiletreeNode|nil
---@field public quick_traverse         fun(self: era.IReadonlyFiletree, root: string|nil, fn: era.t.IFiletreeQuickTraverseHandler, conditional: era.t.IFiletreeTraverseConditional|nil): era.IReadonlyFiletree
---@field public traverse               fun(self: era.IReadonlyFiletree, root: string|nil, fn: era.t.IFiletreeTraverseHandler, conditional: era.t.IFiletreeTraverseConditional|nil): era.IReadonlyFiletree
---@field public unsafe_traverse        fun(self: era.IReadonlyFiletree, root: string|nil, traverse: era.t.IFiletreeUnsafeTraverseCallback): era.IReadonlyFiletree
---@field public calc_include_uuid_set  fun(self: era.IReadonlyFiletree, uuids: string[]): table<string, boolean>

---@class era.IFiletree : era.ITree , era.IReadonlyFiletree
---@field public fullname               string
---@field public root                   string
---@field public clear                  fun(self: era.IFiletree): era.IFiletree
---@field public dispose                fun(self: era.IFiletree): nil
---@field public isdisposed             fun(self: era.IFiletree): boolean
---@field public isdescendant           fun(self: era.IFiletree, ancestor: string, uuid: string): boolean
---@field public isexistent             fun(self: era.IFiletree, uuid: string): boolean
---@field public retrieve               fun(self: era.IFiletree, uuid: string): era.t.IFiletreeNode|nil
---@field public quick_traverse         fun(self: era.IFiletree, root: string|nil, fn: era.t.IFiletreeQuickTraverseHandler, conditional: era.t.IFiletreeTraverseConditional|nil): era.IFiletree
---@field public traverse               fun(self: era.IFiletree, root: string|nil, fn: era.t.IFiletreeTraverseHandler, conditional: era.t.IFiletreeTraverseConditional|nil): era.IFiletree
---@field public unsafe_traverse        fun(self: era.IFiletree, root: string|nil, traverse: era.t.IFiletreeUnsafeTraverseCallback): era.IFiletree
---@field public calc_include_uuid_set  fun(self: era.IFiletree, uuids: string[]): table<string, boolean>
---@field public empty                  fun(self: era.IFiletree, uuid: string): era.IFiletree
---@field public insert                 fun(self: era.IFiletree, parent: string, uuid: string, data: era.t.IFiletreeNodeData): era.t.IFiletreeNode
---@field public insert_directory_absolute fun(self: era.IFiletree, dirpath: string): era.t.IFiletreeNode
---@field public insert_directory_relative fun(self: era.IFiletree, cwd: string, dirpath: string): era.t.IFiletreeNode
---@field public insert_file_absolute   fun(self: era.IFiletree, filepath: string): era.t.IFiletreeNode
---@field public insert_file_relative   fun(self: era.IFiletree, cwd: string, filepath: string): era.t.IFiletreeNode
---@field public print                  fun(self: era.IFiletree, rootuuid: string|nil): string[]
---@field public remove                 fun(self: era.IFiletree, uuid: string): era.IFiletree
---@field public reset                  fun(self: era.IFiletree, cwd: string, filepaths: string[], with_locations: boolean): era.IFiletree

---@class era.Filetree : era.IFiletree
---@field public fullname               string
---@field protected _disposed           boolean
---@field protected _nodemap            table<string, era.t.ITreeNode>
local M = {}
M.__index = M
setmetatable(M, era.Tree)

---@param filepath                      string
---@return boolean
local function is_cwd_chain(filepath)
  local cwd = era.path.cwd() ---@type string
  if cwd == filepath or filepath == FILETREE_ROOT_FILEPATH then
    return true
  end

  local N1 = #cwd ---@type integer
  local N2 = #filepath ---@type integer
  if N1 < N2 then
    return filepath:sub(1, N1 + 1) == cwd .. dot.env.PATH_SEP
  end

  return cwd:sub(1, N2 + 1) == filepath .. dot.env.PATH_SEP
end

---@param filepath                      string
---@return string
function M.uuid(filepath)
  local uuid = FILEPATH_TO_UUID[filepath] ---@type string|nil
  if uuid == nil then
    if not yoz.path.is_absolute(filepath) then
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
---@return era.t.IFiletreeNodeData
---@return string
function M.resolve(filepath, filetype, force)
  local nodeuuid = FILEPATH_TO_UUID[filepath] ---@type string|nil
  if nodeuuid == nil then
    if not yoz.path.is_absolute(filepath) then
      error(string.format("[%s.resolve] Cannot resolve UUID for relative path: %s", __module_name__, filepath))
    end
    nodeuuid = yoz.fn.md5(filepath) ---@type string
  end

  local nodedata = FILENODE_DATAMAP[nodeuuid]
  if nodedata == nil then
    local basename = yoz.path.basename(filepath) ---@type string
    local fileicon, fileicon_hln ---@type string, string
    if filetype == "directory" then
      fileicon, fileicon_hln = dot.fileicon.get_directory_icon(basename) ---@type string, string
    else
      fileicon, fileicon_hln = dot.fileicon.get_file_icon(basename) ---@type string, string
    end

    ---@type era.t.IFiletreeNodeData
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
        fileicon, fileicon_hln = dot.fileicon.get_directory_icon(nodedata.basename) ---@type string, string
      else
        fileicon, fileicon_hln = dot.fileicon.get_file_icon(nodedata.basename) ---@type string, string
      end
      nodedata.fileicon = fileicon
      nodedata.fileicon_hln = fileicon_hln
      nodedata.filetype = filetype
    end
  end
  return nodedata, nodeuuid
end

---@param props                         era.IFiletreeProps
---@return era.Filetree
function M.new(props)
  local name = props.name ---@type string
  local fullname = string.format("%s@%s", __module_name__, name) ---@type string

  ---@type era.Tree
  local tree = era.Tree.new({
    name = name,
    fullname = fullname,
    rootnodedata = M.resolve(FILETREE_ROOT_FILEPATH, "directory", true),
    node_sorter = function(left, right)
      ---@cast left                     era.t.IFiletreeNode
      ---@cast right                    era.t.IFiletreeNode
      if left.data.filetype == right.data.filetype then
        return left.data.basename < right.data.basename
      end

      local left_priority = FILETYPE_PRIORITY_MAP[left.data.filetype] or 0 ---@type integer
      local right_priority = FILETYPE_PRIORITY_MAP[right.data.filetype] or 0 ---@type integer
      return left_priority > right_priority
    end,
  })

  local self = setmetatable(tree, M)
  ---@cast self                         era.Filetree

  return self
end

---@param dirpath                       string
---@return era.t.IFiletreeNode
function M:insert_directory_absolute(dirpath)
  self:__health__()

  local nodemap = self._nodemap ---@type table<string, era.t.ITreeNode>
  ---@cast nodemap                      table<string, era.t.IFiletreeNode>

  local nodeuuid = M.uuid(dirpath) ---@type string
  local node = nodemap[nodeuuid] ---@type era.t.IFiletreeNode|nil
  if node == nil or node.data.filetype ~= "directory" then
    local pieces = yoz.path.split(dirpath, false) ---@type string[]
    local N = #pieces ---@type integer

    local p = "" ---@type string
    local uuid_parent = FILETREE_ROOT_UUID ---@type string

    if dot.env.IS_WIN then
      p = pieces[1] ---@type string
      nodeuuid = M.uuid(p) ---@type string
      node = nodemap[nodeuuid] ---@type era.t.IFiletreeNode|nil
      if node == nil or node.data.filetype ~= "directory" then
        local nodedata = M.resolve(p, "directory", true)
        node = self:insert(uuid_parent, nodeuuid, nodedata)
      end
      uuid_parent = nodeuuid ---@type string
    end

    for index = 2, N, 1 do
      p = p .. dot.env.PATH_SEP .. pieces[index] ---@type string
      nodeuuid = M.uuid(p) ---@type string
      node = nodemap[nodeuuid] ---@type era.t.IFiletreeNode|nil
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
---@return era.t.IFiletreeNode
function M:insert_directory_relative(cwd, dirpath)
  self:__health__()

  local nodemap = self._nodemap ---@type table<string, era.t.ITreeNode>
  ---@cast nodemap                      table<string, era.t.IFiletreeNode>

  local cwduuid = M.uuid(cwd) ---@type string
  local cwdnode = nodemap[cwduuid] ---@type era.t.IFiletreeNode|nil
  if cwdnode == nil or cwdnode.data.filetype ~= "directory" then
    cwdnode = self:insert_directory_absolute(cwd)
  end

  local nodeuuid = M.uuid(cwd .. dot.env.PATH_SEP .. dirpath) ---@type string
  local node = nodemap[nodeuuid] ---@type era.t.IFiletreeNode|nil
  if node == nil or node.data.filetype ~= "directory" then
    local pieces = yoz.path.split(dirpath, false) ---@type string[]
    local N = #pieces ---@type integer

    local p = cwd ---@type string
    local uuid_parent = cwduuid ---@type string

    for index = 1, N, 1 do
      p = p .. dot.env.PATH_SEP .. pieces[index] ---@type string
      nodeuuid = M.uuid(p) ---@type string
      node = nodemap[nodeuuid] ---@type era.t.IFiletreeNode|nil
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
---@return era.t.IFiletreeNode
function M:insert_file_absolute(filepath)
  self:__health__()

  local nodemap = self._nodemap ---@type table<string, era.t.ITreeNode>
  ---@cast nodemap                      table<string, era.t.IFiletreeNode>

  local nodeuuid = M.uuid(filepath) ---@type string
  local node = nodemap[nodeuuid] ---@type era.t.IFiletreeNode|nil
  if node == nil or node.data.filetype ~= "file" then
    local pieces = yoz.path.split(filepath, false) ---@type string[]
    local N = #pieces - 1 ---@type integer

    local p = "" ---@type string
    local uuid_parent = FILETREE_ROOT_UUID ---@type string

    if dot.env.IS_WIN then
      p = pieces[1] ---@type string
      nodeuuid = M.uuid(p) ---@type string
      node = nodemap[nodeuuid] ---@type era.t.IFiletreeNode|nil
      if node == nil or node.data.filetype ~= "directory" then
        local nodedata = M.resolve(p, "directory", true)
        node = self:insert(uuid_parent, nodeuuid, nodedata)
      end
      uuid_parent = nodeuuid ---@type string
    end

    for index = 2, N, 1 do
      p = p .. dot.env.PATH_SEP .. pieces[index] ---@type string
      nodeuuid = M.uuid(p) ---@type string
      node = nodemap[nodeuuid] ---@type era.t.IFiletreeNode|nil
      if node == nil or node.data.filetype ~= "directory" then
        local nodedata = M.resolve(p, "directory", true)
        node = self:insert(uuid_parent, nodeuuid, nodedata)
      end

      uuid_parent = nodeuuid ---@type string
    end

    local basename = pieces[N + 1] ---@type string
    p = p .. dot.env.PATH_SEP .. basename ---@type string
    nodeuuid = M.uuid(p) ---@type string
    node = nodemap[nodeuuid] ---@type era.t.IFiletreeNode|nil
    if node == nil or node.data.filetype ~= "file" then
      local nodedata = M.resolve(p, "file", true)
      node = self:insert(uuid_parent, nodeuuid, nodedata)
    end
  end

  return node
end

---@param cwd                           string
---@param filepath                      string
---@return era.t.IFiletreeNode
function M:insert_file_relative(cwd, filepath)
  self:__health__()

  local nodemap = self._nodemap ---@type table<string, era.t.ITreeNode>
  ---@cast nodemap                      table<string, era.t.IFiletreeNode>

  local cwduuid = M.uuid(cwd) ---@type string
  local cwdnode = nodemap[cwduuid] ---@type era.t.IFiletreeNode|nil
  if cwdnode == nil or cwdnode.data.filetype ~= "directory" then
    cwdnode = self:insert_directory_absolute(cwd)
  end

  local nodeuuid = M.uuid(cwd .. dot.env.PATH_SEP .. filepath) ---@type string
  local node = nodemap[nodeuuid] ---@type era.t.IFiletreeNode|nil
  if node == nil or node.data.filetype ~= "file" then
    local pieces = yoz.path.split(filepath, false) ---@type string[]
    local N = #pieces - 1 ---@type integer

    local p = cwd ---@type string
    local uuid_parent = cwduuid ---@type string

    for index = 1, N, 1 do
      p = p .. dot.env.PATH_SEP .. pieces[index] ---@type string
      nodeuuid = M.uuid(p) ---@type string
      node = nodemap[nodeuuid] ---@type era.t.IFiletreeNode|nil
      if node == nil or node.data.filetype ~= "directory" then
        local nodedata = M.resolve(p, "directory", true)
        node = self:insert(uuid_parent, nodeuuid, nodedata)
      end

      uuid_parent = nodeuuid ---@type string
    end

    local basename = pieces[N + 1] ---@type string
    p = p .. dot.env.PATH_SEP .. basename ---@type string
    nodeuuid = M.uuid(p) ---@type string
    node = nodemap[nodeuuid] ---@type era.t.IFiletreeNode|nil
    if node == nil or node.data.filetype ~= "file" then
      local nodedata = M.resolve(p, "file", true)
      node = self:insert(uuid_parent, nodeuuid, nodedata)
    end
  end

  return node
end

---@param cwd                           string
---@param filepaths                     string[]
---@param with_locations                boolean
---@return era.Filetree
function M:reset(cwd, filepaths, with_locations)
  self:__health__()
  self:clear()

  if #filepaths < 1 then
    return self
  end

  local rootdata, rootuuid = M.resolve(FILETREE_ROOT_FILEPATH, "directory", true) ---@type era.t.IFiletreeNodeData, string
  self:insert(rootuuid, rootuuid, rootdata)

  cwd = era.path.normalize(cwd) ---@type string
  local P = cwd == "/" and "/" or (cwd .. dot.env.PATH_SEP) ---@type string
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
      local filepath = ark.string.parse_filepath_with_location(p) ---@type string, integer|nil, integer|nil
      if yoz.path.is_absolute(filepath) then
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
      if yoz.path.is_absolute(filepath) then
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
