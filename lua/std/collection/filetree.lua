local __module_name__ = "std.collection.filetree" ---@type string

---@alias std.collection.filetree.ITraverseConditional
---| fun(ctx: std.collection.filetree.ITraverseContext, node: std.collection.filetree.INode, cur: integer): std.collection.tree.TraverseConditionalEnum

---@alias std.collection.filetree.ITraverseHandler
---| fun(ctx: std.collection.filetree.ITraverseContext, node: std.collection.filetree.INode, cur: integer, is_lastchild: boolean, onlychild: string|nil, childcount: integer): nil

---@alias std.collection.filetree.ITraverseRecursive
---| fun(ctx: std.collection.filetree.ITraverseContext, node: std.collection.filetree.INode, cur: integer, is_lastchild: boolean): nil

---@alias std.collection.filetree.IQuickTraverseHandler
---| fun(ctx: std.collection.filetree.ITraverseContext, node: std.collection.filetree.INode, cur: integer): nil

---@alias std.collection.filetree.IQuickTraverseRecursive
---| fun(ctx: std.collection.filetree.ITraverseContext, node: std.collection.filetree.INode, cur: integer): nil

---@alias std.collection.filetree.IUnsafeTraverseCallback
---| fun(ctx: std.collection.filetree.ITraverseContext): nil

---@class std.collection.filetree.ITraverseContext
---@field public nodemap                table<string, std.collection.filetree.INode>
---@field public rootnode               std.collection.filetree.INode

---@class std.collection.filetree.INode : std.collection.tree.INode
---@field public data                   std.collection.filetree.INodeData

---@class std.collection.filetree.INodeData
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

---@type table<string, std.collection.filetree.INodeData>
local FILENODE_DATAMAP = {}

local FILETREE_ROOT_FILEPATH = std.env.IS_WIN and "" or "/" ---@type string
local FILETREE_ROOT_UUID = FILEPATH_TO_UUID[FILETREE_ROOT_FILEPATH] ---@type string

local FILETYPE_PRIORITY_MAP = {
  directory = 5,
  file = 3,
}

---@class std.collection.IFiletreeProps
---@field public name                   string

---@class std.collection.IReadonlyFiletree : std.collection.IReadonlyTree
---@field public fullname               string
---@field public root                   string
---@field public isdisposed             fun(self: std.collection.IReadonlyFiletree): boolean
---@field public isdescendant           fun(self: std.collection.IReadonlyFiletree, ancestor: string, uuid: string): boolean
---@field public isexistent             fun(self: std.collection.IReadonlyFiletree, uuid: string): boolean
---@field public retrieve               fun(self: std.collection.IReadonlyFiletree, uuid: string): std.collection.filetree.INode|nil
---@field public quick_traverse         fun(self: std.collection.IReadonlyFiletree, root: string|nil, fn: std.collection.filetree.IQuickTraverseHandler, conditional: std.collection.filetree.ITraverseConditional|nil): std.collection.IReadonlyFiletree
---@field public traverse               fun(self: std.collection.IReadonlyFiletree, root: string|nil, fn: std.collection.filetree.ITraverseHandler, conditional: std.collection.filetree.ITraverseConditional|nil): std.collection.IReadonlyFiletree
---@field public unsafe_traverse        fun(self: std.collection.IReadonlyFiletree, root: string|nil, traverse: std.collection.filetree.IUnsafeTraverseCallback): std.collection.IReadonlyFiletree
---@field public calc_include_uuid_set  fun(self: std.collection.IReadonlyFiletree, uuids: string[]): table<string, boolean>

---@class std.collection.IFiletree : std.collection.ITree , std.collection.IReadonlyFiletree
---@field public fullname               string
---@field public root                   string
---@field public clear                  fun(self: std.collection.IFiletree): std.collection.IFiletree
---@field public dispose                fun(self: std.collection.IFiletree): nil
---@field public isdisposed             fun(self: std.collection.IFiletree): boolean
---@field public isdescendant           fun(self: std.collection.IFiletree, ancestor: string, uuid: string): boolean
---@field public isexistent             fun(self: std.collection.IFiletree, uuid: string): boolean
---@field public retrieve               fun(self: std.collection.IFiletree, uuid: string): std.collection.filetree.INode|nil
---@field public quick_traverse         fun(self: std.collection.IFiletree, root: string|nil, fn: std.collection.filetree.IQuickTraverseHandler, conditional: std.collection.filetree.ITraverseConditional|nil): std.collection.IFiletree
---@field public traverse               fun(self: std.collection.IFiletree, root: string|nil, fn: std.collection.filetree.ITraverseHandler, conditional: std.collection.filetree.ITraverseConditional|nil): std.collection.IFiletree
---@field public unsafe_traverse        fun(self: std.collection.IFiletree, root: string|nil, traverse: std.collection.filetree.IUnsafeTraverseCallback): std.collection.IFiletree
---@field public calc_include_uuid_set  fun(self: std.collection.IFiletree, uuids: string[]): table<string, boolean>
---@field public empty                  fun(self: std.collection.IFiletree, uuid: string): std.collection.IFiletree
---@field public insert                 fun(self: std.collection.IFiletree, parent: string, uuid: string, data: std.collection.filetree.INodeData): std.collection.IFiletree
---@field public print                  fun(self: std.collection.IFiletree, rootuuid: string|nil): string[]
---@field public remove                 fun(self: std.collection.IFiletree, uuid: string): std.collection.IFiletree
---@field public reset                  fun(self: std.collection.IFiletree, cwd: string, filepaths: string[], with_locations: boolean): std.collection.IFiletree

---@class std.collection.Filetree : std.collection.IFiletree
---@field public fullname               string
---@field protected _disposed           boolean
local M = {}
M.__index = M
setmetatable(M, std.Tree)

---@param filepath                      string
---@return string
function M.uuid(filepath)
  local uuid = FILEPATH_TO_UUID[filepath] ---@type string|nil
  if uuid == nil then
    if std.path.is_absolute(filepath) then
      uuid = std.fn.md5(filepath) ---@type string
      FILEPATH_TO_UUID[filepath] = uuid
      return uuid
    end

    error("Cannot resolve UUID for relative path: " .. filepath)
  end
  return uuid
end

---@param filepath                      string
---@param force                         ?boolean
---@return std.collection.filetree.INodeData|nil
function M.resolve(filepath, force)
  local uuid = FILEPATH_TO_UUID[filepath] ---@type string|nil
  if uuid == nil and std.path.is_absolute(filepath) then
    uuid = std.fn.md5(filepath) ---@type string
    FILEPATH_TO_UUID[filepath] = uuid
  end

  if uuid == nil then
    return
  end

  local nodedata = FILENODE_DATAMAP[uuid]
  if nodedata == nil or force then
    local basename = std.path.basename(filepath) ---@type string
    local fileicon, fileicon_hln = std.fileicon.get_file_icon(basename)

    ---@type std.collection.filetree.INodeData
    nodedata = {
      basename = basename,
      fileicon = fileicon,
      fileicon_hln = fileicon_hln,
      filepath = filepath,
      filepath_lower = filepath:lower(),
      filetype = "file",
    }
    FILENODE_DATAMAP[uuid] = nodedata
  end
  return nodedata
end

---@param props                         std.collection.IFiletreeProps
---@return std.collection.Filetree
function M.new(props)
  local name = props.name ---@type string
  local fullname = string.format("%s@%s", __module_name__, name) ---@type string

  ---@type std.collection.Tree
  local tree = std.Tree.new({
    name = name,
    fullname = fullname,
    rootnodedata = M.resolve(FILETREE_ROOT_FILEPATH, false),
    node_sorter = function(left, right)
      ---@cast left                     std.collection.filetree.INode
      ---@cast right                    std.collection.filetree.INode
      if left.data.filetype == right.data.filetype then
        return left.data.basename < right.data.basename
      end

      local left_priority = FILETYPE_PRIORITY_MAP[left.data.filetype] or 0 ---@type integer
      local right_priority = FILETYPE_PRIORITY_MAP[right.data.filetype] or 0 ---@type integer
      return left_priority > right_priority
    end,
  })

  local self = setmetatable(tree, M)
  ---@cast self                         std.collection.Filetree

  return self
end

---@param cwd                           string
---@param filepaths                     string[]
---@param with_locations                boolean
---@return std.collection.Filetree
function M:reset(cwd, filepaths, with_locations)
  self:__health__()
  self:clear()

  if #filepaths < 1 then
    return self
  end

  ---@type std.collection.filetree.INodeData
  local rootdata = {
    basename = FILETREE_ROOT_FILEPATH,
    fileicon = "󰙅",
    fileicon_hln = "MiniIconsBlue",
    filepath = FILETREE_ROOT_FILEPATH,
    filepath_lower = FILETREE_ROOT_FILEPATH:lower(),
    filetype = "directory",
  }
  self:insert(FILETREE_ROOT_UUID, FILETREE_ROOT_UUID, rootdata)

  cwd = std.path.normalize(cwd) ---@type string
  local cwd_with_slash = cwd == "/" and "/" or (cwd .. std.env.PATH_SEP) ---@type string
  local cwd_with_slash_length = #cwd_with_slash ---@type integer
  if cwd ~= "/" then
    local pieces = std.path.split(cwd) ---@type string[]
    local N = #pieces ---@type integer

    local filepath = "" ---@type string
    local uuid_parent = FILETREE_ROOT_UUID ---@type string
    local start_index = std.env.IS_WIN and 1 or 2 ---@type integer
    for index = start_index, N, 1 do
      local basename = pieces[index] ---@type string
      filepath = index == 1 and basename or (filepath .. std.env.PATH_SEP .. basename) ---@type string
      local uuid = M.uuid(filepath) ---@type string
      local fileicon, fileicon_hln = std.fileicon.get_directory_icon(basename)

      ---@type std.collection.filetree.INodeData
      local nodedata = {
        basename = basename,
        fileicon = fileicon,
        fileicon_hln = fileicon_hln,
        filepath = filepath,
        filepath_lower = filepath:lower(),
        filetype = "directory",
      }
      self:insert(uuid_parent, uuid, nodedata)
      uuid_parent = uuid
    end
  end

  local cwd_uuid = M.uuid(cwd) ---@type string
  local visited_absolute_filepaths = {} ---@type table<string, boolean>
  local visited_relative_filepaths = {} ---@type table<string, boolean>

  ---@param p                           string
  local function insert_absolute_filepath(p)
    if visited_absolute_filepaths[p] then
      return
    end
    visited_absolute_filepaths[p] = true

    local pieces = std.path.split(p) ---@type string[]
    local N = #pieces - 1 ---@type integer

    local filepath = "" ---@type string
    local uuid_parent = FILETREE_ROOT_UUID ---@type string
    local start_index = std.env.IS_WIN and 1 or 2 ---@type integer
    for index = start_index, N, 1 do
      local basename = pieces[index] ---@type string
      filepath = index == 1 and basename or (filepath .. std.env.PATH_SEP .. basename) ---@type string
      local uuid = M.uuid(filepath) ---@type string
      local fileicon, fileicon_hln = std.fileicon.get_directory_icon(basename)

      ---@type std.collection.filetree.INodeData
      local nodedata = {
        basename = basename,
        fileicon = fileicon,
        fileicon_hln = fileicon_hln,
        filepath = filepath,
        filepath_lower = filepath:lower(),
        filetype = "directory",
      }
      self:insert(uuid_parent, uuid, nodedata)
      uuid_parent = uuid ---@type string
    end

    local basename = pieces[#pieces] ---@type string
    filepath = filepath .. std.env.PATH_SEP .. basename ---@type string
    local uuid = M.uuid(filepath) ---@type string
    local fileicon, fileicon_hln = std.fileicon.get_file_icon(basename)

    ---@type std.collection.filetree.INodeData
    local nodedata = {
      basename = basename,
      fileicon = fileicon,
      fileicon_hln = fileicon_hln,
      filepath = filepath,
      filepath_lower = filepath:lower(),
      filetype = "file",
    }
    self:insert(uuid_parent, uuid, nodedata)
  end

  ---@param p                           string
  local function insert_relative_filepath(p)
    if visited_relative_filepaths[p] then
      return
    end
    visited_relative_filepaths[p] = true

    local pieces = std.path.split(p) ---@type string[]
    local N = #pieces - 1 ---@type integer

    local filepath = cwd == "/" and "" or cwd ---@type string
    local uuid_parent = cwd_uuid ---@type string
    for index = 1, N, 1 do
      local basename = pieces[index] ---@type string
      filepath = filepath .. std.env.PATH_SEP .. basename ---@type string
      local uuid = M.uuid(filepath) ---@type string
      local fileicon, fileicon_hln = std.fileicon.get_directory_icon(basename)

      ---@type std.collection.filetree.INodeData
      local nodedata = {
        basename = basename,
        fileicon = fileicon,
        fileicon_hln = fileicon_hln,
        filepath = filepath,
        filepath_lower = filepath:lower(),
        filetype = "directory",
      }
      self:insert(uuid_parent, uuid, nodedata)
      uuid_parent = uuid ---@type string
    end

    local basename = pieces[#pieces] ---@type string
    filepath = filepath .. std.env.PATH_SEP .. basename ---@type string
    local uuid = M.uuid(filepath) ---@type string
    local fileicon, fileicon_hln = std.fileicon.get_file_icon(basename)

    ---@type std.collection.filetree.INodeData
    local nodedata = {
      basename = basename,
      fileicon = fileicon,
      fileicon_hln = fileicon_hln,
      filepath = filepath,
      filepath_lower = filepath:lower(),
      filetype = "file",
    }
    self:insert(uuid_parent, uuid, nodedata)
  end

  if with_locations then
    for _, p in ipairs(filepaths) do
      local filepath = std.string.parse_filepath_with_location(p) ---@type string, integer|nil, integer|nil
      if std.path.is_absolute(filepath) then
        if filepath:sub(1, cwd_with_slash_length) ~= cwd_with_slash then
          insert_absolute_filepath(filepath)
        else
          filepath = filepath:sub(cwd_with_slash_length + 1) ---@type string
          insert_relative_filepath(filepath)
        end
      else
        insert_relative_filepath(filepath)
      end
    end
  else
    for _, filepath in ipairs(filepaths) do
      if std.path.is_absolute(filepath) then
        if filepath:sub(1, cwd_with_slash_length) ~= cwd_with_slash then
          insert_absolute_filepath(filepath)
        else
          filepath = filepath:sub(cwd_with_slash_length + 1) ---@type string
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
