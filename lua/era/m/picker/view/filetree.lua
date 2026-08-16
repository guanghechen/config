---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.picker.view.filetree" ---@type string

local tree_cache = require("era.view.tree.cache")
local tree_collapse = require("era.view.tree.collapse")
local tree_lifecycle = require("era.view.tree.lifecycle")
local tree_selection = require("era.view.tree.selection")
local tree_store = require("era.view.tree.store")
local tree_traversal = require("era.view.tree.traversal")
local tree_visibility = require("era.view.tree.visibility")

---@alias era.m.picker.view.filetree.INodeState
---| era.m.picker.view.filetree.IDirectoryNodeState
---| era.m.picker.view.filetree.IFileNodeState
---| era.m.picker.view.filetree.ILocationNodeState

---@alias era.m.picker.view.filetree.IListviewFileRenderer
---| fun(ctx: era.m.picker.view.filetree.IListviewRendererContext, node: stl.c.IFiletreeNode, nodestate: era.m.picker.view.filetree.IFileNodeState, lnum: integer): string, stl.t.IHighlightInline[]|nil

---@alias era.m.picker.view.filetree.IListviewLocationRenderer
---| fun(ctx: era.m.picker.view.filetree.IListviewRendererContext, node: stl.c.IFiletreeNode, nodestate: era.m.picker.view.filetree.IFileNodeState, locationstate: era.m.picker.view.filetree.ILocationNodeState, lnum: integer): string, stl.t.IHighlightInline[]|nil

---@alias era.m.picker.view.filetree.ITreeviewDirectoryRenderer
---| fun(ctx: era.m.picker.view.filetree.ITreeviewRendererContext, node: stl.c.IFiletreeNode, nodestate: era.m.picker.view.filetree.IDirectoryNodeState, lnum: integer, folded_depth: integer): string, stl.t.IHighlightInline[]|nil

---@alias era.m.picker.view.filetree.ITreeviewFileRenderer
---| fun(ctx: era.m.picker.view.filetree.ITreeviewRendererContext, node: stl.c.IFiletreeNode, nodestate: era.m.picker.view.filetree.IFileNodeState, lnum: integer): string, stl.t.IHighlightInline[]|nil

---@alias era.m.picker.view.filetree.ITreeviewLocationRenderer
---| fun(ctx: era.m.picker.view.filetree.ITreeviewRendererContext, node: stl.c.IFiletreeNode, nodestate: era.m.picker.view.filetree.IFileNodeState, locationstate: era.m.picker.view.filetree.ILocationNodeState, lnum: integer): string, stl.t.IHighlightInline[]|nil

---@class era.m.picker.view.filetree.IDirectoryNodeState : era.view.tree.IContainerNodeState

---@class era.m.picker.view.filetree.IFileNodeState : era.view.tree.ILeafNodeState
---@field public locations              era.m.picker.view.filetree.ILocationNodeState|nil
---@field public cache_match            era.m.picker.view.filetree.INodeMatchResultCache|nil

---@class era.m.picker.view.filetree.ILocationNodeState : era.view.tree.ILeafLocationState
---@field public lnum                   integer
---@field public col                    ?integer
---@field public col_end                ?integer
---@field public text                   ?string
---@field public highlights             ?stl.t.IHighlightInline[]

---@class era.m.picker.view.filetree.IListviewRendererContext : era.view.tree.IListviewRendererContext
---@field public rootnode               stl.c.IFiletreeNode
---@field public rootstate              era.m.picker.view.filetree.IDirectoryNodeState
---@field public tree                   stl.c.IReadonlyFiletree
---@field public view                   era.m.picker.FiletreeView

---@class era.m.picker.view.filetree.ITreeviewRendererContext : era.view.tree.IListviewRendererContext
---@field public rootnode               stl.c.IFiletreeNode
---@field public rootstate              era.m.picker.view.filetree.IDirectoryNodeState
---@field public tree                   stl.c.IReadonlyFiletree
---@field public view                   era.m.picker.FiletreeView

---@class era.m.picker.view.filetree.INodeMatchContext
---@field public rootuuid               string
---@field public pattern                string
---@field public case_sensitive         boolean
---@field public fuzzy                  boolean
---@field public regex                  boolean

---@class era.m.picker.view.filetree.INodeMatchResult
---@field public context                era.m.picker.view.filetree.INodeMatchContext
---@field public uuids                  string[]

---@class era.m.picker.view.filetree.INodeMatchResultCache
---@field public score                  integer
---@field public matches                dot.t.IMatchPoint[]

---@class era.m.picker.view.filetree.IMatchParams
---@field public rootuuid               string|nil
---@field public pattern                string
---@field public case_sensitive         boolean
---@field public fuzzy                  boolean
---@field public regex                  boolean

----------------------------------------------------------------------------------------------------

local DEFAULT_NSNR_MATCHES = dot.var.nsnr.view_filetree_matches ---@type integer
---@class era.m.picker.view.IFiletreeProps
---@field public name                   string
---@field public tree                   stl.c.IFiletree
---@field public indent                 ?string
---@field public indent_hln             ?string
---
---@field public render_listview_leaf   ?era.m.picker.view.filetree.IListviewFileRenderer
---@field public render_listview_location   ?era.m.picker.view.filetree.IListviewLocationRenderer
---@field public render_treeview_container  ?era.m.picker.view.filetree.ITreeviewDirectoryRenderer
---@field public render_treeview_leaf   ?era.m.picker.view.filetree.ITreeviewFileRenderer
---@field public render_treeview_location   ?era.m.picker.view.filetree.ITreeviewLocationRenderer

local tree_render = era.view.TreeRenderer ---@type era.view.TreeRenderer

---@class era.m.picker.FiletreeView
---@field protected _tree               stl.c.IFiletree
---@field protected _last_match_result  era.m.picker.view.filetree.INodeMatchResult
---@field public insert                 fun(self: era.m.picker.FiletreeView, uuid: string, state: era.view.tree.INodeState): era.m.picker.FiletreeView
local M = {}
M.__index = M
M.isselected = tree_selection.isselected
M.collect_selected = tree_selection.collect_selected
M.set_selected = tree_selection.set_selected
M.toggle_select = tree_selection.toggle_select
M.__refresh_selected_maximum__ = tree_selection.refresh_selected_maximum
M.isvisible = tree_visibility.isvisible
M.mark_node_invisible = tree_visibility.mark_node_invisible
M.mark_cache_invisible_dirty = tree_visibility.mark_cache_invisible_dirty
M.collapse = tree_collapse.collapse
M.mark_cache_listview_dirty = tree_cache.mark_listview_dirty
M.mark_cache_treeview_dirty = tree_cache.mark_treeview_dirty
M.collect_leafs = tree_store.collect_leafs
M.insert = tree_store.insert
M.remove = tree_store.remove
M.remove_all_locations = tree_store.remove_all_locations
M.remove_location = tree_store.remove_location
M.isdisposed = tree_lifecycle.isdisposed
M.__health__ = tree_lifecycle.health

---@param props                         era.m.picker.view.IFiletreeProps
---@return era.m.picker.FiletreeView
function M.new(props)
  local name = props.name ---@type string
  local fullname = string.format("%s -> %s", name, __module_name__) ---@type string
  local indent = props.indent ---@type string|nil
  local indent_hln = props.indent_hln ---@type string|nil
  local tree = props.tree ---@type stl.c.IFiletree

  local render_listview_leaf = props.render_listview_leaf or M.default_render_listview_leaf ---@type era.m.picker.view.filetree.IListviewFileRenderer
  local render_listview_location = props.render_listview_location or M.default_render_listview_location ---@type era.m.picker.view.filetree.IListviewLocationRenderer
  local render_treeview_container = props.render_treeview_container or M.default_render_treeview_container ---@type era.m.picker.view.filetree.ITreeviewDirectoryRenderer
  local render_treeview_leaf = props.render_treeview_leaf or M.default_render_treeview_leaf ---@type era.m.picker.view.filetree.ITreeviewFileRenderer
  local render_treeview_location = props.render_treeview_location or M.default_render_treeview_location ---@type era.m.picker.view.filetree.ITreeviewLocationRenderer

  local self = tree_lifecycle.create({
    name = name,
    fullname = fullname,
    indent = indent,
    indent_hln = indent_hln,
    tree = tree,
    render_listview_leaf = render_listview_leaf,
    render_listview_location = render_listview_location,
    render_treeview_container = render_treeview_container,
    render_treeview_leaf = render_treeview_leaf,
    render_treeview_location = render_treeview_location,
  }, __module_name__)
  setmetatable(self, M)
  ---@cast self                         era.m.picker.FiletreeView

  self._last_match_result = nil
  return self
end

----------------------------------------------------------------------------------------------------

---@return era.m.picker.FiletreeView
function M:clear()
  self:__health__()

  tree_lifecycle.clear(self)
  self._last_match_result = nil
  return self
end

---@return nil
function M:dispose()
  if self._disposed then
    return nil
  end

  tree_lifecycle.dispose(self)
  self._last_match_result = nil
end

---@return era.m.picker.FiletreeView
function M:mark_cache_match_dirty()
  self:__health__()
  self._last_match_result = nil ---@type era.m.picker.view.filetree.INodeMatchResult|nil
  return self
end

---@param uuid                          string
---@return era.m.picker.view.filetree.INodeState|nil
function M:retrieve(uuid)
  self:__health__()

  local statemap = self.statemap ---@type table<string, era.view.tree.INodeState>
  ---@cast statemap                     table<string, era.m.picker.view.filetree.INodeState>

  local nodestate = statemap[uuid] ---@type era.m.picker.view.filetree.INodeState|nil
  return nodestate
end

----------------------------------------------------------------------------------------------------

---@param root                          string|nil
---@return string[]
function M:collect_file_uuids(root)
  return self:collect_leafs(root)
end

---@param params                        era.m.picker.view.filetree.IMatchParams
---@return string[]
function M:match(params)
  self:__health__()

  local tree = self._tree ---@type stl.c.IReadonlyFiletree
  local statemap = self.statemap ---@type table<string, era.view.tree.INodeState>
  ---@cast statemap                     table<string, era.m.picker.view.filetree.INodeState>

  local root = params.rootuuid or tree.root ---@type string
  local case_sensitive = params.case_sensitive ---@type boolean
  local fuzzy = params.fuzzy ---@type boolean
  local regex = params.regex ---@type boolean
  local pattern = case_sensitive and params.pattern or params.pattern:lower() ---@type string

  ---@type era.m.picker.view.filetree.INodeMatchContext
  local context = {
    rootuuid = root,
    pattern = pattern,
    case_sensitive = case_sensitive,
    fuzzy = fuzzy,
    regex = regex,
  }

  local last_match_result = self._last_match_result ---@type era.m.picker.view.filetree.INodeMatchResult|nil
  local last_match_context = last_match_result and last_match_result.context or nil ---@type era.m.picker.view.filetree.INodeMatchContext|nil
  local last_matched_uuids = last_match_result and last_match_result.uuids or nil ---@type string[]|nil
  local tick_matched = self._tick_matched + 1 ---@type integer

  ---@type boolean
  local is_limit_in_last_matched = (
    last_match_context ~= nil
    and last_matched_uuids ~= nil
    and last_match_context.rootuuid == root
    and last_match_context.case_sensitive == case_sensitive
    and last_match_context.fuzzy == fuzzy
    and (last_match_context.regex == regex and not regex)
    and vim.startswith(pattern, last_match_context.pattern)
  )

  local uuids ---@type string[]
  if is_limit_in_last_matched then
    uuids = last_matched_uuids and vim.list_slice(last_matched_uuids) or {} ---@type string[]
  else
    local k = 0 ---@type integer
    uuids = {} ---@type string[]

    tree_traversal.preorder(tree, root, function(uuid)
      local state = statemap[uuid]
      if state.nodetype == "leaf" then
        k = k + 1
        uuids[k] = uuid
      end
    end)
  end

  local lines = {} ---@type string[]
  if case_sensitive then
    for index, uuid in ipairs(uuids) do
      local data = tree:get(uuid) ---@type stl.c.IFiletreeNodeData|nil
      if data ~= nil then
        lines[index] = data.filepath ---@type string
      end
    end
  else
    for index, uuid in ipairs(uuids) do
      local data = tree:get(uuid) ---@type stl.c.IFiletreeNodeData|nil
      if data ~= nil then
        lines[index] = data.filepath_lower ---@type string
      end
    end
  end

  ---@type yoz.search.ISearchInLinesOptions
  local search_params = {
    pattern = pattern,
    lines = lines,
    flag_fuzzy = fuzzy,
    flag_regex = regex,
    flag_case_sensitive = case_sensitive,
  }
  local search_result, search_err = yoz.search.search_in_lines(search_params) ---@type yoz.search.ISearchTextResult|nil, string|nil
  if search_err then
    stl.reporter.error({
      from = __module_name__,
      subject = "search_in_lines failed",
      details = {
        error = search_err,
        params = search_params,
      },
    })
    search_result = nil
  end
  if search_result ~= nil and search_result.lines ~= nil then
    local line_matches = search_result.lines ---@type yoz.search.ISearchInLinesLineMatch[]
    table.sort(line_matches, function(a, b)
      if a.lnum == b.lnum then
        return a.score > b.score
      end
      return a.lnum < b.lnum
    end)

    for _, line_match in ipairs(line_matches) do
      local lnum = line_match.lnum ---@type integer
      local uuid = uuids[lnum] ---@type string
      local matches = line_match.matches ---@type dot.t.IMatchPoint[]
      local state = statemap[uuid]
      state.tick_matched = tick_matched ---@type integer
      state.cache_match = { score = line_match.score, matches = matches } ---@type era.m.picker.view.filetree.INodeMatchResultCache
    end

    local N = #line_matches ---@type integer
    if N < #uuids then
      for index = 1, N, 1 do
        local line_match = line_matches[index]
        local lnum = line_match.lnum ---@type integer
        uuids[index] = uuids[lnum] ---@type string
      end
      stl.table.truncate_inline(uuids, N)
    end
  end

  for _, uuid in ipairs(uuids) do
    local parentuuid = tree:parent(uuid) ---@type string|nil
    while parentuuid ~= nil and parentuuid ~= tree.root do
      local state = statemap[parentuuid]
      if state.tick_matched == tick_matched then
        break
      end

      state.tick_matched = tick_matched
      parentuuid = tree:parent(parentuuid)
    end
  end

  ---@type era.m.picker.view.filetree.INodeMatchResult
  local match_result = {
    context = context,
    uuids = uuids,
  }
  self._last_match_result = match_result
  self._tick_matched = tick_matched
  return uuids
end

---@param dirpath                       string
---@return era.m.picker.FiletreeView
function M:insert_dirpath(dirpath)
  self:__health__()

  local filetree = self._tree ---@type stl.c.IFiletree
  local statemap = self.statemap ---@type table<string, era.view.tree.INodeState>
  ---@cast statemap                     table<string, era.m.picker.view.filetree.INodeState>

  local filenode = filetree:insert_directory_absolute(dirpath)
  local fileuuid = filenode.uuid ---@type string
  local filestate = statemap[fileuuid] ---@type era.m.picker.view.filetree.INodeState|nil

  if filestate == nil or filestate.nodetype ~= "container" then
    local node = filetree:retrieve(filenode.parent) ---@type stl.c.IFiletreeNode|nil
    while node ~= nil and node.uuid ~= node.parent do
      local nodestate = statemap[node.uuid] ---@type era.m.picker.view.filetree.INodeState|nil
      if nodestate ~= nil and nodestate.nodetype == "container" then
        break
      end

      ---@type era.m.picker.view.filetree.IDirectoryNodeState
      nodestate = {
        nodetype = "container",
        collapsed = false,
        tick_invisible = 0,
        tick_matched = 0,
        tick_selected = 0,
        tick_selected_maximum = 0,
      }
      statemap[node.uuid] = nodestate
      node = filetree:retrieve(node.parent) ---@type stl.c.IFiletreeNode|nil
    end

    ---@type era.m.picker.view.filetree.IDirectoryNodeState
    filestate = {
      nodetype = "container",
      collapsed = false,
      tick_invisible = 0,
      tick_matched = 0,
      tick_selected = 0,
      tick_selected_maximum = 0,
    }
    statemap[filenode.uuid] = filestate
  end

  return self
end

---@param filepath                      string
---@param with_locations                boolean
---@return era.m.picker.FiletreeView
function M:insert_filepath(filepath, with_locations)
  self:__health__()

  local filetree = self._tree ---@type stl.c.IFiletree
  local statemap = self.statemap ---@type table<string, era.view.tree.INodeState>
  ---@cast statemap                     table<string, era.m.picker.view.filetree.INodeState>

  local lnum, col, col_end ---@type integer|nil, integer|nil, integer|nil

  if with_locations then
    filepath, lnum, col, col_end = stl.string.parse_filepath_with_location(filepath)
  end

  local filenode = filetree:insert_file_absolute(filepath)
  local fileuuid = filenode.uuid ---@type string
  local filestate = statemap[fileuuid] ---@type era.m.picker.view.filetree.INodeState|nil

  if filestate == nil or filestate.nodetype ~= "leaf" then
    local node = filetree:retrieve(filenode.parent) ---@type stl.c.IFiletreeNode|nil
    while node ~= nil and node.uuid ~= node.parent do
      local nodestate = statemap[node.uuid] ---@type era.m.picker.view.filetree.INodeState|nil
      if nodestate ~= nil and nodestate.nodetype == "container" then
        break
      end

      ---@type era.m.picker.view.filetree.IDirectoryNodeState
      nodestate = {
        nodetype = "container",
        collapsed = false,
        tick_invisible = 0,
        tick_matched = 0,
        tick_selected = 0,
        tick_selected_maximum = 0,
      }
      statemap[node.uuid] = nodestate
      node = filetree:retrieve(node.parent) ---@type stl.c.IFiletreeNode|nil
    end

    ---@type era.m.picker.view.filetree.IFileNodeState
    filestate = {
      nodetype = "leaf",
      collapsed = false,
      tick_invisible = 0,
      tick_matched = 0,
      tick_selected = 0,
    }
    statemap[filenode.uuid] = filestate
  end

  if lnum ~= nil then
    local locationuuid = string.format("%s:%d:%d", fileuuid, lnum, col or 0) ---@type string

    ---@type era.m.picker.view.filetree.ILocationNodeState
    local location = {
      nodetype = "location",
      leafuuid = fileuuid,
      locationuuid = locationuuid,
      tick_invisible = 0,
      lnum = lnum,
      col = col,
      col_end = col_end,
    }
    statemap[locationuuid] = location

    local locations = filestate.locations or {} ---@type era.m.picker.view.filetree.ILocationNodeState[]
    locations[#locations + 1] = location ---@type era.m.picker.view.filetree.ILocationNodeState
    filestate.locations = locations ---@type era.m.picker.view.filetree.ILocationNodeState[]
  end

  return self
end

---@param cwd                           string
---@param filepaths                     string[]
---@param with_locations                boolean
---@return era.m.picker.FiletreeView
function M:reset_filepaths(cwd, filepaths, with_locations)
  self:__health__()

  local selected_set = self:collect_selected() ---@type table<string, true>
  self:clear()

  local filetree = self._tree ---@type stl.c.IFiletree
  local tick_selected = self._tick_selected ---@type integer
  local statemap = self.statemap ---@type table<string, era.view.tree.INodeState>
  ---@cast statemap                     table<string, era.m.picker.view.filetree.INodeState>

  filetree:reset(cwd, filepaths, with_locations)
  tree_traversal.preorder(filetree, filetree.root, function(uuid)
    local data = filetree:get(uuid) ---@type stl.c.IFiletreeNodeData
    if data.filetype == "directory" then
      ---@type era.m.picker.view.filetree.IDirectoryNodeState
      local nodestate = {
        nodetype = "container",
        collapsed = false,
        tick_invisible = 0,
        tick_matched = 0,
        tick_selected = selected_set[uuid] and tick_selected or 0,
        tick_selected_maximum = 0,
      }
      statemap[uuid] = nodestate
      return
    end

    if data.filetype == "file" then
      ---@type era.m.picker.view.filetree.IFileNodeState
      local nodestate = {
        nodetype = "leaf",
        collapsed = false,
        tick_invisible = 0,
        tick_matched = 0,
        tick_selected = selected_set[uuid] and tick_selected or 0,
      }
      statemap[uuid] = nodestate
      return
    end

    stl.reporter.error({
      from = self.fullname,
      subject = "reset_filepaths",
      message = "Unexpected filetype",
      details = {
        nodeuuid = uuid,
        nodedata = data,
      },
    })
  end)

  if with_locations then
    for _, p in ipairs(filepaths) do
      local filepath, lnum, col, col_end = stl.string.parse_filepath_with_location(p) ---@type string, integer|nil, integer|nil
      if lnum ~= nil then
        if not yoz.path.is_absolute(filepath) then
          filepath = cwd .. stl.env.PATH_SEP .. filepath ---@type string
        end

        local fileuuid = stl.c.Filetree.uuid(filepath) ---@type string
        local filenode = filetree:retrieve(fileuuid) ---@type stl.c.IFiletreeNode|nil
        local nodestate = statemap[fileuuid]

        if filenode ~= nil and nodestate ~= nil then
          local locationuuid = string.format("%s:%d:%d", fileuuid, lnum, col or 0) ---@type string

          ---@type era.m.picker.view.filetree.ILocationNodeState
          local location = {
            nodetype = "location",
            leafuuid = fileuuid,
            locationuuid = locationuuid,
            tick_invisible = 0,
            lnum = lnum,
            col = col,
            col_end = col_end,
          }
          statemap[locationuuid] = location

          local locations = nodestate.locations or {} ---@type era.m.picker.view.filetree.ILocationNodeState[]
          locations[#locations + 1] = location ---@type era.m.picker.view.filetree.ILocationNodeState
          nodestate.locations = locations ---@type era.m.picker.view.filetree.ILocationNodeState[]
        end
      end
    end
  end

  return self
end

---@param rootuuid                     string
---@param selected_set                 table<string, true>
---@return era.m.picker.FiletreeView
function M:restore_subtree(rootuuid, selected_set)
  self:__health__()

  local filetree = self._tree ---@type stl.c.IFiletree
  local tick_selected = self._tick_selected ---@type integer
  local statemap = self.statemap ---@type table<string, era.view.tree.INodeState>
  ---@cast statemap                     table<string, era.m.picker.view.filetree.INodeState>

  tree_traversal.preorder(filetree, rootuuid, function(uuid)
    local data = filetree:get(uuid) ---@type stl.c.IFiletreeNodeData
    if data.filetype == "directory" then
      statemap[uuid] = {
        nodetype = "container",
        collapsed = false,
        tick_invisible = 0,
        tick_matched = 0,
        tick_selected = selected_set[uuid] and tick_selected or 0,
        tick_selected_maximum = 0,
      }
      return
    end

    if data.filetype == "file" then
      statemap[uuid] = {
        nodetype = "leaf",
        collapsed = false,
        tick_invisible = 0,
        tick_matched = 0,
        tick_selected = selected_set[uuid] and tick_selected or 0,
      }
      return
    end

    stl.reporter.error({
      from = self.fullname,
      subject = "restore_subtree",
      message = "Unexpected filetype",
      details = { nodeuuid = uuid, nodedata = data },
    })
  end)

  self:mark_cache_treeview_dirty()
  return self
end

---@param root                          string|nil
---@param handle                        fun(node: stl.c.IFiletreeNode, nodestate: era.m.picker.view.filetree.IFileNodeState): nil
---@return string[]
function M:traverse_filenode(root, handle)
  self:__health__()

  local statemap = self.statemap ---@type table<string, era.view.tree.INodeState>
  local uuids = {} ---@type string[]

  self._tree:quick_traverse(root, function(_, node)
    local nodestate = statemap[node.uuid] ---@type era.view.tree.INodeState|nil
    if nodestate ~= nil and nodestate.nodetype == "leaf" then
      ---@cast nodestate                era.m.picker.view.filetree.IFileNodeState
      handle(node, nodestate)
    end
  end)
  return uuids
end

----------------------------------------------------------------------------------------------------

---@param params                        era.view.tree.IRenderListviewParams
---@return era.view.tree.IRenderResult
function M:render_listview(params)
  self:__health__()

  local nsnr = DEFAULT_NSNR_MATCHES ---@type integer
  local bufnr = params.bufnr ---@type integer
  local only_matched = params.only_matched ---@type boolean

  local result = tree_render.render_listview(self, params)
  local uuids = result.lnum2uuid ---@type string[]
  local N = #uuids ---@type integer

  vim.api.nvim_buf_clear_namespace(bufnr, nsnr, 0, -1)

  if N < 1 then
    return result
  end

  local filetree = self._tree ---@type stl.c.IReadonlyFiletree
  local statemap = self.statemap ---@type table<string, era.view.tree.INodeState>
  ---@cast statemap                     table<string, era.m.picker.view.filetree.INodeState>

  local tick_matched = self._tick_matched ---@type integer

  local rootuuid = params.rootuuid ~= nil and params.rootuuid or filetree.root ---@type string
  local rootnode = filetree:retrieve(rootuuid) ---@type stl.c.IFiletreeNode|nil
  if rootnode == nil then
    stl.reporter.error({
      from = self.fullname,
      subject = "render_listview",
      message = "Cannot retrieve the root node",
      details = {
        bufnr = bufnr,
        rootuuid = rootuuid,
      },
    })
    return result
  end

  if only_matched then
    local indents = result.indents ---@type string[]
    for lnum = 1, N, 1 do
      local uuid = uuids[lnum] ---@type string
      local nodestate = statemap[uuid] ---@type era.m.picker.view.filetree.INodeState|nil
      if nodestate ~= nil and nodestate.tick_matched == tick_matched and nodestate.cache_match ~= nil then
        local node = filetree:retrieve(uuid) ---@type stl.c.IFiletreeNode|nil
        if node ~= nil then
          local row = lnum - 1 ---@type integer
          local offset_final = #indents[lnum] + #node.data.fileicon + 1 ---@type integer
          local rootpath = rootnode.data.filepath ---@type string
          local displayed_filepath = #rootpath < 2 and node.data.filepath or node.data.filepath:sub(#rootpath + 2) ---@type string
          local L = #displayed_filepath ---@type integer
          local offset_filepath = #node.data.filepath - L ---@type integer

          local matches = nodestate.cache_match.matches ---@type dot.t.IMatchPoint[]
          for _, m in ipairs(matches) do
            local l = m.l - offset_filepath
            local r = m.r - offset_filepath
            if r > 0 and l < L then
              l = l < 0 and 0 or l ---@type integer
              r = r < L and r or L ---@type integer
              vim.hl.range(bufnr, nsnr, "m_pk_matches", { row, offset_final + l }, { row, offset_final + r })
            end
          end
        end
      end
    end
  end
  return result
end

---@param params                        era.view.tree.IRenderTreeviewParams
---@return era.view.tree.IRenderResult
function M:render_treeview(params)
  self:__health__()
  local nsnr = DEFAULT_NSNR_MATCHES ---@type integer
  local bufnr = params.bufnr ---@type integer
  local only_matched = params.only_matched ---@type boolean

  local result = tree_render.render_treeview(self, params)
  local layout = result.layout ---@type stl.view.TreeLayout
  local N = layout:len() ---@type integer

  vim.api.nvim_buf_clear_namespace(bufnr, nsnr, 0, -1)

  if N < 1 then
    return result
  end

  local indents = result.indents ---@type string[]
  local filetree = self._tree ---@type stl.c.IReadonlyFiletree
  local tick_matched = self._tick_matched ---@type integer
  local statemap = self.statemap ---@type table<string, era.view.tree.INodeState>
  ---@cast statemap                     table<string, era.m.picker.view.filetree.INodeState>

  if only_matched then
    for lnum = 1, N, 1 do
      local uuid = layout:id(lnum) ---@type string
      local nodestate = statemap[uuid] ---@type era.m.picker.view.filetree.INodeState|nil
      if
        nodestate ~= nil
        and nodestate.nodetype == "leaf"
        and nodestate.tick_matched == tick_matched
        and nodestate.cache_match ~= nil
      then
        local node = filetree:retrieve(uuid) ---@type stl.c.IFiletreeNode|nil
        if node ~= nil then
          local row = lnum - 1 ---@type integer
          local offset_final = #indents[lnum] + #node.data.fileicon + 1 ---@type integer
          local basename = node.data.basename ---@type string
          local L = #basename ---@type integer
          local offset_basename = #node.data.filepath - L ---@type integer

          local matches = nodestate.cache_match.matches ---@type dot.t.IMatchPoint[]
          for _, m in ipairs(matches) do
            local l = m.l - offset_basename ---@type integer
            local r = m.r - offset_basename ---@type integer
            if r > 0 and l < L then
              l = l < 0 and 0 or l ---@type integer
              r = r < L and r or L ---@type integer
              vim.hl.range(bufnr, nsnr, "m_pk_matches", { row, offset_final + l }, { row, offset_final + r })
            end
          end
        end
      end
    end
  end

  return result
end

----------------------------------------------------------------------------------------------------

---@type era.m.picker.view.filetree.IListviewFileRenderer
function M.default_render_listview_leaf(ctx, node)
  local rootnode = ctx.rootnode ---@type stl.c.IFiletreeNode
  local fileicon = node.data.fileicon ---@type string
  local fileicon_hln = node.data.fileicon_hln ---@type string
  local filepath = #rootnode.data.filepath < 2 and node.data.filepath
    or node.data.filepath:sub(#rootnode.data.filepath + 2)
  local text = string.format("%s %s", fileicon, filepath) ---@type string

  ---@type stl.t.IHighlightInline[]
  local highlights = {
    { coll = 0, colr = #fileicon + 1, hlname = fileicon_hln },
  }

  local highlight_index = #highlights + 1 ---@type integer
  highlights[highlight_index] = { coll = #fileicon + 1, colr = #text, hlname = "m_ft_text" }

  ---@type string, string|nil
  local git_text, git_name_highlight =
    era.m.git.status.calc_info(node.data.filepath, node.data.filetype, #text, highlights)
  if git_name_highlight ~= nil then
    highlights[highlight_index].hlname = git_name_highlight
  end
  text = text .. git_text ---@type string

  local diagnostic_text = era.m.lsp.diagnostic.render(node.data.filepath, #text, highlights) ---@type string
  text = text .. diagnostic_text ---@type string
  return text, highlights
end

---@type era.m.picker.view.filetree.IListviewLocationRenderer
function M.default_render_listview_location(_, _, _, locationstate)
  local lnum = locationstate.lnum ---@type integer
  local col = locationstate.col ---@type integer|nil
  local text = col ~= nil and string.format("%4d:%-4d", lnum, col) or string.format("%4d:", lnum) ---@type string
  local offset = #text ---@type integer

  ---@type stl.t.IHighlightInline[]
  local highlights = {
    { coll = 0, colr = offset, hlname = "m_ft_position" },
    { coll = offset, colr = -1, hlname = "m_ft_text" },
  }

  if locationstate.text ~= nil then
    text = text .. " " .. locationstate.text ---@type string
  end
  if locationstate.highlights ~= nil then
    for _, hl in ipairs(locationstate.highlights) do
      highlights[#highlights + 1] =
        { coll = offset + 1 + hl.coll, colr = hl.colr < 0 and -1 or offset + 1 + hl.colr, hlname = hl.hlname }
    end
  end
  return text, highlights
end

---@type era.m.picker.view.filetree.ITreeviewDirectoryRenderer
function M.default_render_treeview_container(ctx, node, nodestate, _, folded_depth)
  local basename = node.data.basename ---@type string
  local fileicon = node.data.fileicon ---@type string
  local fileicon_hln = node.data.fileicon_hln ---@type string
  if not nodestate.collapsed then
    fileicon = stl.icon.filetype.FolderOpen
  end

  if folded_depth < 1 then
    local text = string.format("%s %s", fileicon, basename) ---@type string

    ---@type stl.t.IHighlightInline[]
    local highlights = {
      { coll = 0, colr = #fileicon + 1, hlname = fileicon_hln },
      { coll = #fileicon + 1, colr = #text, hlname = "m_ft_dirname" },
    }

    return text, highlights
  end

  local tree = ctx.tree ---@type stl.c.IReadonlyFiletree

  local basenames = {} ---@type string[]
  basenames[folded_depth + 1] = basename ---@type string

  local o = node ---@type stl.c.IFiletreeNode
  for index = folded_depth, 1, -1 do
    local uuid_parent = o.parent ---@type string
    o = tree:retrieve(uuid_parent) or o ---@type stl.c.IFiletreeNode
    basenames[index] = o.data.basename ---@type string
  end

  local start_index = 1 ---@type integer
  local text ---@type string
  if basenames[1] == "/" then
    text = string.format("%s %s", fileicon, "/" .. basenames[2]) ---@type string
    start_index = 2
  else
    text = string.format("%s %s", fileicon, basenames[1]) ---@type string
  end

  ---@type stl.t.IHighlightInline[]
  local highlights = {
    { coll = 0, colr = #fileicon + 1, hlname = fileicon_hln },
    { coll = #fileicon + 1, colr = #text, hlname = "m_ft_dirname" },
  }

  for index = start_index + 1, #basenames, 1 do
    local piece = basenames[index] ---@type string
    local offset = #text ---@type integer
    text = text .. string.format("/%s", piece)
    highlights[#highlights + 1] = { coll = offset, colr = offset + 1, hlname = "m_ft_pathsep" }
    highlights[#highlights + 1] = { coll = offset + 1, colr = #text, hlname = "m_ft_dirname" }
  end

  return text, highlights
end

---@type era.m.picker.view.filetree.ITreeviewFileRenderer
function M.default_render_treeview_leaf(_, node)
  local basename = node.data.basename ---@type string
  local fileicon = node.data.fileicon ---@type string
  local fileicon_hln = node.data.fileicon_hln ---@type string
  local text = string.format("%s %s", fileicon, basename) ---@type string

  ---@type stl.t.IHighlightInline[]
  local highlights = {
    { coll = 0, colr = #fileicon + 1, hlname = fileicon_hln },
    { coll = #fileicon + 1, colr = #text, hlname = "m_ft_filename" },
  }

  ---@type string, string|nil
  local git_text, git_name_highlight =
    era.m.git.status.calc_info(node.data.filepath, node.data.filetype, #text, highlights)
  if git_name_highlight ~= nil then
    highlights[2].hlname = git_name_highlight
  end
  text = text .. git_text ---@type string

  local diagnostic_text = era.m.lsp.diagnostic.render(node.data.filepath, #text, highlights) ---@type string
  text = text .. diagnostic_text ---@type string
  return text, highlights
end

---@type era.m.picker.view.filetree.ITreeviewLocationRenderer
function M.default_render_treeview_location(_, _, _, locationstate)
  local lnum = locationstate.lnum ---@type integer
  local col = locationstate.col ---@type integer|nil
  local text = col ~= nil and string.format("%4d:%-4d", lnum, col) or string.format("%4d:", lnum) ---@type string
  local offset = #text ---@type integer

  ---@type stl.t.IHighlightInline[]
  local highlights = {
    { coll = 0, colr = offset, hlname = "m_ft_position" },
    { coll = offset, colr = -1, hlname = "m_ft_text" },
  }

  if locationstate.text ~= nil then
    text = text .. " " .. locationstate.text ---@type string
  end
  if locationstate.highlights ~= nil then
    for _, hl in ipairs(locationstate.highlights) do
      highlights[#highlights + 1] =
        { coll = offset + 1 + hl.coll, colr = hl.colr < 0 and -1 or offset + 1 + hl.colr, hlname = hl.hlname }
    end
  end
  return text, highlights
end

return M
