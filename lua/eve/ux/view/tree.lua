local __module_name__ = "eve.ux.view.treeview" ---@type string

---@alias eve.ux.view.tree.CollapseActionEnum
---| "collapse"
---| "expand"
---| "toggle"

---@alias eve.ux.view.tree.NodeTypeEnum
---| "container"
---| "leaf"

---@alias eve.ux.view.tree.ViewtypeEnum
---| "tree"
---| "list"

---@alias eve.ux.view.tree.INodeState
---| eve.ux.view.tree.IContainerNodeState
---| eve.ux.view.tree.ILeafNodeState
---| eve.ux.view.tree.ILeafLocationState

---@alias eve.ux.view.tree.IRenderListviewLeafNode
---| fun(leafnode: std.collection.tree.INode, leafstate: eve.ux.view.tree.ILeafNodeState): nil

---@alias eve.ux.view.tree.IRenderListviewLeafLocations
---| fun(leafnode: std.collection.tree.INode, leafstate: eve.ux.view.tree.ILeafNodeState): nil

---@alias eve.ux.view.tree.IRenderTreeviewContainerNode
---| fun(containernode: std.collection.tree.INode, containerstate: eve.ux.view.tree.IContainerNodeState, is_lastchild: boolean, cur: integer, dry: boolean): nil

---@alias eve.ux.view.tree.IRenderTreeviewLeafNode
---| fun(leafnode: std.collection.tree.INode, leafstate: eve.ux.view.tree.ILeafNodeState, is_lastchild: boolean, cur: integer): nil

---@alias eve.ux.view.tree.IRenderTreeviewLeafLocations
---| fun(leafnode: std.collection.tree.INode, leafstate: eve.ux.view.tree.ILeafNodeState, leafindent: string): nil

---@alias eve.ux.view.tree.IListviewLeafNodeRenderer
---| fun(ctx: eve.ux.view.tree.IListviewRendererContext, node: std.collection.tree.INode, nodestate: eve.ux.view.tree.ILeafNodeState, lnum: integer): eve.ux.view.tree.INodeRenderResult

---@alias eve.ux.view.tree.IListviewLeafLocationRenderer
---| fun(ctx: eve.ux.view.tree.IListviewRendererContext, node: std.collection.tree.INode, nodestate: eve.ux.view.tree.ILeafNodeState, location: eve.ux.view.tree.ILeafLocationState, lnum: integer): eve.ux.view.tree.INodeRenderResult

---@alias eve.ux.view.tree.ITreeviewContainerNodeRenderer
---| fun(ctx: eve.ux.view.tree.ITreeviewRendererContext, node: std.collection.tree.INode, nodestate: eve.ux.view.tree.IContainerNodeState, lnum: integer, folded_depth: integer): eve.ux.view.tree.INodeRenderResult

---@alias eve.ux.view.tree.ITreeviewLeafNodeRenderer
---| fun(ctx: eve.ux.view.tree.ITreeviewRendererContext, node: std.collection.tree.INode, nodestate: eve.ux.view.tree.ILeafNodeState, lnum: integer): eve.ux.view.tree.INodeRenderResult

---@alias eve.ux.view.tree.ITreeviewLeafLocationRenderer
---| fun(ctx: eve.ux.view.tree.ITreeviewRendererContext, node: std.collection.tree.INode, nodestate: eve.ux.view.tree.ILeafNodeState, location: eve.ux.view.tree.ILeafLocationState, lnum: integer): eve.ux.view.tree.INodeRenderResult

---@class eve.ux.view.tree.IListviewRendererContext
---@field public rootnode               std.collection.tree.INode
---@field public rootstate              eve.ux.view.tree.IContainerNodeState
---@field public tree                   std.collection.IReadonlyTree
---@field public view                   eve.ux.view.Tree

---@class eve.ux.view.tree.ITreeviewRendererContext
---@field public rootnode               std.collection.tree.INode
---@field public rootstate              eve.ux.view.tree.INodeState
---@field public tree                   std.collection.IReadonlyTree
---@field public view                   eve.ux.view.Tree

---@class eve.ux.view.tree.IContainerNodeState
---@field public nodetype               "container"
---@field public collapsed              boolean
---@field public tick_invisible         integer
---@field public tick_matched           integer
---@field public tick_selected          integer
---@field public tick_selected_maximum  integer
---@field public cache_treeview         eve.ux.view.tree.INodeTreeviewResultCache|nil

---@class eve.ux.view.tree.ILeafNodeState
---@field public nodetype               "leaf"
---@field public collapsed              boolean
---@field public locations              eve.ux.view.tree.ILeafLocationState[]|nil
---@field public tick_invisible         integer
---@field public tick_matched           integer
---@field public tick_selected          integer
---@field public cache_listview         eve.ux.view.tree.INodeListviewResultCache|nil
---@field public cache_treeview         eve.ux.view.tree.INodeTreeviewResultCache|nil

---@class eve.ux.view.tree.ILeafLocationState
---@field public nodetype               "location"
---@field public leafuuid               string
---@field public locationuuid           string
---@field public tick_invisible         integer
---@field public data                   unknown|nil

---@class eve.ux.view.tree.INodeListviewResultCache
---@field public tick                   integer
---@field public text                   string
---@field public highlights             std.t.IHighlightInline[]

---@class eve.ux.view.tree.INodeTreeviewResultCache
---@field public tick                   integer
---@field public text                   string
---@field public highlights             std.t.IHighlightInline[]

---@class eve.ux.view.tree.INodeRenderResult
---@field public text                   string
---@field public highlights             std.t.IHighlightInline[]|nil

---@class eve.ux.view.tree.IRenderResult
---@field public childline              integer[]|nil
---@field public indents                string[]
---@field public lnum2uuid              table<integer, string>
---@field public uuid2lnum              table<string, integer>

---@class eve.ux.view.tree.IRenderListviewParams
---@field public bufnr                  integer
---@field public rootuuid               string|nil
---@field public orders                 string[]|nil
---@field public only_matched           boolean
---@field public only_selected          boolean
---@field public only_visible           boolean

---@class eve.ux.view.tree.IRenderTreeviewParams
---@field public bufnr                  integer
---@field public rootuuid               string|nil
---@field public foldempty              boolean
---@field public only_expanded          boolean
---@field public only_matched           boolean
---@field public only_selected          boolean
---@field public only_visible           boolean

----------------------------------------------------------------------------------------------------

local NSNR_DEFAULT = eve.var.nsnr.view_tree ---@type integer

---@class eve.ux.view.ITreeProps
---@field public name                   string
---@field public fullname               ?string
---@field public indent                 ?string
---@field public indent_hln             ?string
---@field public tree                   std.collection.IReadonlyTree
---@field public render_listview_leaf       eve.ux.view.tree.IListviewLeafNodeRenderer
---@field public render_listview_location   eve.ux.view.tree.IListviewLeafLocationRenderer
---@field public render_treeview_container  eve.ux.view.tree.ITreeviewContainerNodeRenderer
---@field public render_treeview_leaf       eve.ux.view.tree.ITreeviewLeafNodeRenderer
---@field public render_treeview_location   eve.ux.view.tree.ITreeviewLeafLocationRenderer

---@class eve.ux.view.Tree
---@field public fullname               string
---@field public statemap               table<string, eve.ux.view.tree.INodeState>
---
---@field protected _disposed           boolean
---@field protected _indent             string
---@field protected _indent_hln         string
---@field protected _tree               std.collection.IReadonlyTree
---
---@field protected _count_selected       integer
---@field protected _dirty_selected       boolean
---@field protected _tick_invisible       integer
---@field protected _tick_matched         integer
---@field protected _tick_selected        integer
---@field protected _tick_render_listview integer
---@field protected _tick_render_treeview integer
---
---@field protected _render_listview_leaf       eve.ux.view.tree.IListviewLeafNodeRenderer
---@field protected _render_listview_location   eve.ux.view.tree.IListviewLeafLocationRenderer
---@field protected _render_treeview_container  eve.ux.view.tree.ITreeviewContainerNodeRenderer
---@field protected _render_treeview_leaf       eve.ux.view.tree.ITreeviewLeafNodeRenderer
---@field protected _render_treeview_location   eve.ux.view.tree.ITreeviewLeafLocationRenderer
local M = {}
M.__index = M

---@param props                         eve.ux.view.ITreeProps
---@return eve.ux.view.Tree
function M.new(props)
  local name = props.name ---@type string
  local fullname = props.fullname or string.format("%s -> %s", name, __module_name__) ---@type string
  local indent = props.indent or "" ---@type string
  local indent_hln = props.indent_hln or "f_utw_indent" ---@type string
  local tree = props.tree ---@type std.collection.IReadonlyTree

  local render_listview_leaf = props.render_listview_leaf ---@type eve.ux.view.tree.IListviewLeafNodeRenderer
  local render_listview_location = props.render_listview_location ---@type eve.ux.view.tree.IListviewLeafLocationRenderer
  local render_treeview_container = props.render_treeview_container ---@type eve.ux.view.tree.ITreeviewContainerNodeRenderer
  local render_treeview_leaf = props.render_treeview_leaf ---@type eve.ux.view.tree.ITreeviewLeafNodeRenderer
  local render_treeview_location = props.render_treeview_location ---@type eve.ux.view.tree.ITreeviewLeafLocationRenderer

  local statemap = {} ---@type table<string, eve.ux.view.tree.INodeState>

  local self = setmetatable({}, M)
  self.fullname = fullname
  self.statemap = statemap
  self._disposed = false
  self._indent = indent
  self._indent_hln = indent_hln
  self._tree = tree

  self._count_selected = 0
  self._dirty_selected = false
  self._tick_invisible = 1
  self._tick_matched = 0
  self._tick_selected = 1
  self._tick_render_listview = 0
  self._tick_render_treeview = 0

  self._render_listview_leaf = render_listview_leaf
  self._render_listview_location = render_listview_location
  self._render_treeview_container = render_treeview_container
  self._render_treeview_leaf = render_treeview_leaf
  self._render_treeview_location = render_treeview_location
  return self
end

---@return eve.ux.view.Tree
function M:clear()
  self:__health__()

  self.statemap = {}
  self._count_selected = 0
  self._dirty_selected = false
  self._tick_invisible = self._tick_invisible + 1
  self._tick_matched = self._tick_matched + 1
  self._tick_selected = self._tick_selected + 1
  self._tick_render_listview = self._tick_render_listview + 1
  self._tick_render_treeview = self._tick_render_treeview + 1
  return self
end

---@return nil
function M:dispose()
  if self._disposed then
    return nil
  end
  self._disposed = true

  self.statemap = nil
  self._indent = nil
  self._indent_hln = nil
  self._tree = nil

  self._count_selected = 0
  self._dirty_selected = nil
  self._tick_invisible = nil
  self._tick_matched = nil
  self._tick_selected = nil
  self._tick_render_listview = nil
  self._tick_render_treeview = nil

  self._render_listview_leaf = nil
  self._render_listview_location = nil
  self._render_treeview_container = nil
  self._render_treeview_leaf = nil
  self._render_treeview_location = nil
end

---@return boolean
function M:isdisposed()
  return self._disposed
end

---@param uuid                          string
---@return boolean
function M:isselected(uuid)
  local nodestate = self.statemap ~= nil and self.statemap[uuid] or nil ---@type eve.ux.view.tree.INodeState|nil
  return nodestate ~= nil and nodestate.tick_selected == self._tick_selected
end

---@param uuid                          string
---@return boolean
function M:isvisible(uuid)
  local nodestate = self.statemap ~= nil and self.statemap[uuid] or nil ---@type eve.ux.view.tree.INodeState|nil
  return nodestate ~= nil and nodestate.tick_invisible ~= self._tick_invisible
end

---@return integer
function M:count_selected()
  return self._count_selected
end

----------------------------------------------------------------------------------------------------

---@param params                        eve.ux.view.tree.IRenderListviewParams
---@return eve.ux.view.tree.IRenderResult
function M:render_listview(params)
  self:__health__()

  local statemap = self.statemap ---@type table<string, eve.ux.view.tree.INodeState>
  local tree = self._tree ---@type std.collection.IReadonlyTree

  local bufnr = params.bufnr ---@type integer
  local rootuuid = params.rootuuid ~= nil and params.rootuuid or tree.root ---@type string
  local orders = params.orders ---@type string[]|nil
  local only_visible = params.only_visible ---@type boolean
  local only_matched = params.only_matched ---@type boolean
  local only_selected = params.only_selected ---@type boolean

  local tick_invisible = only_visible and self._tick_invisible or -1 ---@type integer
  local tick_matched = self._tick_matched ---@type integer
  local tick_selected = self._tick_selected ---@type integer
  local tick_render_listview = self._tick_render_listview ---@type integer

  local rootnode = tree:retrieve(rootuuid) ---@type std.collection.tree.INode|nil
  local rootstate = statemap[rootuuid] ---@type eve.ux.view.tree.INodeState|nil
  if rootnode == nil or (rootstate ~= nil and rootstate.tick_invisible == tick_invisible) then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
    local result = { indents = {}, lnum2uuid = {}, uuid2lnum = {} } ---@type eve.ux.view.tree.IRenderResult
    return result
  end

  if only_selected then
    self:__refresh_selected_maximum__()
  end

  ---@cast rootstate                    eve.ux.view.tree.IContainerNodeState
  ---@type eve.ux.view.tree.IListviewRendererContext
  local ctx = {
    rootnode = rootnode,
    rootstate = rootstate,
    tree = tree,
    view = self,
  }

  local nsnr = NSNR_DEFAULT ---@type integer
  local INDENT_COMMON = self._indent ---@type string
  local render_listview_leaf = self._render_listview_leaf ---@type eve.ux.view.tree.IListviewLeafNodeRenderer
  local render_listview_location = self._render_listview_location ---@type eve.ux.view.tree.IListviewLeafLocationRenderer

  local indent_leaf = INDENT_COMMON ---@type string
  local indent_location = indent_leaf .. "├─" ---@type string
  local indent_location_lastchild = indent_leaf .. "╰─" ---@type string

  local childline = {} ---@type integer[]
  local indents = {} ---@type string[]
  local lines = {} ---@type string[]
  local highlights_list = {} ---@type (std.t.IHighlightInline[]|nil)[]
  local lnum2uuid = {} ---@type string[]
  local uuid2lnum = {} ---@type table<string, integer>

  local lnum = 0 ---@type integer

  ---@type eve.ux.view.tree.IRenderListviewLeafLocations
  local function render_leaf_locations(leafnode, leafstate)
    if leafstate.locations == nil or #leafstate.locations <= 0 then
      return
    end

    local N = #leafstate.locations ---@type integer
    local last_child_index = 0 ---@type integer
    for index = N, 1, -1 do
      local location = leafstate.locations[index] ---@type eve.ux.view.tree.ILeafLocationState
      if location.tick_invisible ~= tick_invisible then
        last_child_index = index ---@type integer
        break
      end
    end

    if last_child_index > 0 then
      for index = 1, N, 1 do
        local location = leafstate.locations[index] ---@type eve.ux.view.tree.ILeafLocationState
        if location.tick_invisible ~= tick_invisible then
          lnum = lnum + 1 ---@type integer
          local indent = index == last_child_index and indent_location_lastchild or indent_location ---@type string
          local result = render_listview_location(ctx, leafnode, leafstate, location, lnum)

          childline[lnum] = lnum ---@type integer
          indents[lnum] = indent ---@type string
          lines[lnum] = indent .. result.text ---@type string
          highlights_list[lnum] = result.highlights ---@type std.t.IHighlightInline[]|nil
          lnum2uuid[lnum] = location.locationuuid
          uuid2lnum[location.locationuuid] = lnum
        end
      end
    end

    return lnum
  end

  ---@type eve.ux.view.tree.IRenderListviewLeafNode
  local function render_leafnode(leafnode, leafstate)
    local indent = indent_leaf ---@type string

    lnum = lnum + 1 ---@type integer
    local lnum_leaf = lnum ---@type integer

    local cache = leafstate.cache_listview ---@type eve.ux.view.tree.INodeListviewResultCache|nil
    if cache == nil or cache.tick ~= tick_render_listview then
      local result = render_listview_leaf(ctx, leafnode, leafstate, lnum)
      ---@type eve.ux.view.tree.INodeListviewResultCache
      cache = {
        tick = tick_render_listview,
        text = result.text,
        highlights = result.highlights or {},
      }
      leafstate.cache_listview = cache
    end

    childline[lnum_leaf] = lnum
    indents[lnum] = indent ---@type string
    lines[lnum] = indent .. cache.text ---@type string
    highlights_list[lnum] = cache.highlights ---@type std.t.IHighlightInline[]|nil
    lnum2uuid[lnum] = leafnode.uuid
    uuid2lnum[leafnode.uuid] = lnum

    render_leaf_locations(leafnode, leafstate)
    return lnum
  end

  if orders == nil then
    local conditional ---@type std.collection.tree.ITraverseConditional
    if only_matched then
      if only_selected then
        ---@type std.collection.tree.ITraverseConditional
        conditional = function(_, node)
          local nodestate = statemap[node.uuid] ---@type eve.ux.view.tree.INodeState|nil
          if
            nodestate == nil
            or nodestate.tick_invisible == tick_invisible
            or nodestate.tick_matched ~= tick_matched
            or nodestate.tick_selected_maximum ~= tick_selected
          then
            return "badroot"
          end
          return "goodroot"
        end
      else
        ---@type std.collection.tree.ITraverseConditional
        conditional = function(_, node)
          local nodestate = statemap[node.uuid] ---@type eve.ux.view.tree.INodeState|nil
          if
            nodestate == nil
            or nodestate.tick_invisible == tick_invisible
            or nodestate.tick_matched ~= tick_matched
          then
            return "badroot"
          end
          return "goodroot"
        end
      end
    else
      if only_selected then
        ---@type std.collection.tree.ITraverseConditional
        conditional = function(_, node)
          local nodestate = statemap[node.uuid] ---@type eve.ux.view.tree.INodeState|nil
          if
            nodestate == nil
            or nodestate.tick_invisible == tick_invisible
            or nodestate.tick_selected_maximum ~= tick_selected
          then
            return "badroot"
          end
          return "goodroot"
        end
      else
        ---@type std.collection.tree.ITraverseConditional
        conditional = function(_, node)
          local nodestate = statemap[node.uuid] ---@type eve.ux.view.tree.INodeState|nil
          if nodestate == nil or nodestate.tick_invisible == tick_invisible then
            return "badroot"
          end
          return "goodroot"
        end
      end
    end

    local traverse ---@type std.collection.tree.ITraverseHandler
    if only_matched then
      if only_selected then
        ---@type std.collection.tree.ITraverseHandler
        traverse = function(_, node)
          local nodestate = statemap[node.uuid] ---@type eve.ux.view.tree.INodeState|nil
          if
            nodestate ~= nil
            and nodestate.nodetype == "leaf"
            and nodestate.tick_invisible ~= tick_invisible
            and nodestate.tick_matched == tick_matched
            and nodestate.tick_selected == tick_selected
          then
            render_leafnode(node, nodestate)
          end
        end
      else
        ---@type std.collection.tree.ITraverseHandler
        traverse = function(_, node)
          local nodestate = statemap[node.uuid] ---@type eve.ux.view.tree.INodeState|nil
          if
            nodestate ~= nil
            and nodestate.nodetype == "leaf"
            and nodestate.tick_invisible ~= tick_invisible
            and nodestate.tick_matched == tick_matched
          then
            render_leafnode(node, nodestate)
          end
        end
      end
    else
      if only_selected then
        ---@type std.collection.tree.ITraverseHandler
        traverse = function(_, node)
          local nodestate = statemap[node.uuid] ---@type eve.ux.view.tree.INodeState|nil
          if
            nodestate ~= nil
            and nodestate.nodetype == "leaf"
            and nodestate.tick_invisible ~= tick_invisible
            and nodestate.tick_selected == tick_selected
          then
            render_leafnode(node, nodestate)
          end
        end
      else
        ---@type std.collection.tree.ITraverseHandler
        traverse = function(_, node)
          local nodestate = statemap[node.uuid] ---@type eve.ux.view.tree.INodeState|nil
          if nodestate ~= nil and nodestate.nodetype == "leaf" and nodestate.tick_invisible ~= tick_invisible then
            render_leafnode(node, nodestate)
          end
        end
      end
    end

    tree:traverse(rootuuid, traverse, conditional)
  else
    if only_matched then
      if only_selected then
        for _, uuid in ipairs(orders) do
          local node = tree:retrieve(uuid) ---@type std.collection.tree.INode|nil
          local nodestate = statemap[uuid] ---@type eve.ux.view.tree.INodeState|nil
          if
            node ~= nil
            and nodestate ~= nil
            and nodestate.nodetype == "leaf"
            and nodestate.tick_invisible ~= tick_invisible
            and nodestate.tick_matched == tick_matched
            and nodestate.tick_selected == tick_selected
          then
            render_leafnode(node, nodestate)
          end
        end
      else
        for _, uuid in ipairs(orders) do
          local node = tree:retrieve(uuid) ---@type std.collection.tree.INode|nil
          local nodestate = statemap[uuid] ---@type eve.ux.view.tree.INodeState|nil
          if
            node ~= nil
            and nodestate ~= nil
            and nodestate.nodetype == "leaf"
            and nodestate.tick_invisible ~= tick_invisible
            and nodestate.tick_matched == tick_matched
          then
            render_leafnode(node, nodestate)
          end
        end
      end
    else
      if only_selected then
        for _, uuid in ipairs(orders) do
          local node = tree:retrieve(uuid) ---@type std.collection.tree.INode|nil
          local nodestate = statemap[uuid] ---@type eve.ux.view.tree.INodeState|nil
          if
            node ~= nil
            and nodestate ~= nil
            and nodestate.nodetype == "leaf"
            and nodestate.tick_invisible ~= tick_invisible
            and nodestate.tick_selected == tick_selected
          then
            render_leafnode(node, nodestate)
          end
        end
      else
        for _, uuid in ipairs(orders) do
          local node = tree:retrieve(uuid) ---@type std.collection.tree.INode|nil
          local nodestate = statemap[uuid] ---@type eve.ux.view.tree.INodeState|nil
          if
            node ~= nil
            and nodestate ~= nil
            and nodestate.nodetype == "leaf"
            and nodestate.tick_invisible ~= tick_invisible
          then
            render_leafnode(node, nodestate)
          end
        end
      end
    end
  end

  vim.api.nvim_buf_clear_namespace(bufnr, nsnr, 0, -1)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  for index = 1, #lines, 1 do
    local row = index - 1 ---@type integer
    local highlights = highlights_list[index] ---@type std.t.IHighlightInline[]|nil
    local indent = indents[index] ---@type string
    local offset = #indent
    vim.hl.range(bufnr, nsnr, self._indent_hln, { row, #INDENT_COMMON }, { row, offset })

    if highlights ~= nil then
      local H = #highlights ---@type integer
      for hi = 1, H, 1 do
        local highlight = highlights[hi] ---@type std.t.IHighlightInline
        local hlname = highlight.hlname ---@type string
        local colr = highlight.colr ---@type integer
        local coll = highlight.coll ---@type integer
        vim.hl.range(bufnr, nsnr, hlname, { row, offset + coll }, { row, colr < 0 and -1 or offset + colr })
      end
    end
  end

  ---@type eve.ux.view.tree.IRenderResult
  local result = { childline = childline, indents = indents, lnum2uuid = lnum2uuid, uuid2lnum = uuid2lnum }
  return result
end

---@param params                        eve.ux.view.tree.IRenderTreeviewParams
---@return eve.ux.view.tree.IRenderResult
function M:render_treeview(params)
  self:__health__()

  local statemap = self.statemap ---@type table<string, eve.ux.view.tree.INodeState>
  local tree = self._tree ---@type std.collection.IReadonlyTree

  local bufnr = params.bufnr ---@type integer
  local root = params.rootuuid ~= nil and params.rootuuid or tree.root ---@type string
  local foldempty = params.foldempty == true ---@type boolean
  local only_expanded = params.only_expanded ---@type boolean
  local only_visible = params.only_visible ---@type boolean
  local only_matched = params.only_matched ---@type boolean
  local only_selected = params.only_selected ---@type boolean

  local tick_invisible = only_visible and self._tick_invisible or -1 ---@type integer
  local tick_matched = self._tick_matched ---@type integer
  local tick_selected = self._tick_selected ---@type integer
  local tick_render_treeview = self._tick_render_treeview ---@type integer

  local rootnode = tree:retrieve(root) ---@type std.collection.tree.INode|nil
  local rootstate = statemap[root] ---@type eve.ux.view.tree.INodeState|nil
  if rootnode == nil or (rootstate ~= nil and rootstate.tick_invisible == tick_invisible) then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
    local result = { indents = {}, lnum2uuid = {}, uuid2lnum = {} } ---@type eve.ux.view.tree.IRenderResult
    return result
  end

  if only_selected then
    self:__refresh_selected_maximum__()
  end

  ---@cast rootstate                    eve.ux.view.tree.IContainerNodeState
  ---@type eve.ux.view.tree.ITreeviewRendererContext
  local ctx = {
    rootnode = rootnode,
    rootstate = rootstate,
    tree = tree,
    view = self,
  }

  local nsnr = NSNR_DEFAULT ---@type integer
  local INDENT_COMMON = self._indent ---@type string
  local render_treeview_container = self._render_treeview_container ---@type eve.ux.view.tree.ITreeviewContainerNodeRenderer
  local render_treeview_leaf = self._render_treeview_leaf ---@type eve.ux.view.tree.ITreeviewLeafNodeRenderer
  local render_treeview_location = self._render_treeview_location ---@type eve.ux.view.tree.ITreeviewLeafLocationRenderer

  local childline = {} ---@type integer[]
  local indents = {} ---@type string[]
  local lines = {} ---@type string[]
  local highlights_list = {} ---@type (std.t.IHighlightInline[]|nil)[]
  local lnum2uuid = {} ---@type string[]
  local uuid2lnum = {} ---@type table<string, integer>

  local folded_depth = 0 ---@type integer
  local folded_indent = INDENT_COMMON ---@type string
  local last_cur = 0 ---@type integer
  local lnum = 0 ---@type integer
  local stack_indent = {} ---@type string[]
  local stack_depth = {} ---@type integer[]
  local stack_lnum_roots = {} ---@type integer[]

  ---@type eve.ux.view.tree.IRenderTreeviewLeafLocations
  local function render_leaf_locations(leafnode, leafstate, leafindent)
    if leafstate.locations == nil or #leafstate.locations <= 0 or (leafstate.collapsed and only_expanded) then
      return
    end

    local N = #leafstate.locations ---@type integer
    local last_child_index = 0 ---@type integer
    for index = N, 1, -1 do
      local location = leafstate.locations[index] ---@type eve.ux.view.tree.ILeafLocationState
      if location.tick_invisible ~= tick_invisible then
        last_child_index = index ---@type integer
        break
      end
    end

    if last_child_index > 0 then
      for index = 1, N, 1 do
        local location = leafstate.locations[index] ---@type eve.ux.view.tree.ILeafLocationState
        if location.tick_invisible ~= tick_invisible then
          lnum = lnum + 1 ---@type integer
          local indent = leafindent .. (index == last_child_index and "╰─" or "├─") ---@type string
          local result = render_treeview_location(ctx, leafnode, leafstate, location, lnum)

          lines[lnum] = indent .. result.text ---@type string
          highlights_list[lnum] = result.highlights ---@type std.t.IHighlightInline[]|nil
          indents[lnum] = indent ---@type string
          childline[lnum] = lnum ---@type integer
          lnum2uuid[lnum] = location.locationuuid
          uuid2lnum[location.locationuuid] = lnum
        end
      end
    end

    return lnum
  end

  ---@type eve.ux.view.tree.IRenderTreeviewLeafNode
  local function render_leaf(leafnode, leafstate, is_lastchild, cur)
    local depth = cur == 1 and 1 or (stack_depth[cur - 1] + 1) ---@type integer
    local indent = INDENT_COMMON ---@type string
    local child_indent = INDENT_COMMON ---@type string

    if cur > 1 then
      local last_stack_indent = stack_indent[cur - 1] ---@type string
      indent = last_stack_indent .. (is_lastchild and "╰─" or "├─") ---@type string
      child_indent = last_stack_indent .. (is_lastchild and "  " or "│ ") ---@type string
    end

    last_cur = cur ---@type integer
    stack_depth[cur] = depth ---@type integer
    stack_indent[cur] = child_indent ---@type string
    stack_lnum_roots[cur] = lnum + 1 ---@type integer

    lnum = lnum + 1 ---@type integer
    local lnum_leaf = lnum ---@type integer

    local cache = leafstate.cache_treeview ---@type eve.ux.view.tree.INodeTreeviewResultCache|nil
    if cache == nil or cache.tick ~= tick_render_treeview then
      local result = render_treeview_leaf(ctx, leafnode, leafstate, lnum) ---@type eve.ux.view.tree.INodeRenderResult
      ---@type eve.ux.view.tree.INodeTreeviewResultCache
      cache = {
        tick = tick_render_treeview,
        text = result.text,
        highlights = result.highlights or {},
      }
      leafstate.cache_treeview = cache
    end

    lines[lnum] = indent .. cache.text ---@type string
    highlights_list[lnum] = cache.highlights ---@type std.t.IHighlightInline[]|nil
    indents[lnum] = indent ---@type string
    childline[lnum_leaf] = lnum
    lnum2uuid[lnum] = leafnode.uuid
    uuid2lnum[leafnode.uuid] = lnum

    render_leaf_locations(leafnode, leafstate, child_indent)
    return lnum
  end

  local render_container ---@type eve.ux.view.tree.IRenderTreeviewContainerNode
  if foldempty then
    ---@type eve.ux.view.tree.IRenderTreeviewContainerNode
    render_container = function(containernode, containerstate, is_lastchild, cur, dry)
      local depth = cur == 1 and 1 or (stack_depth[cur - 1] + 1) ---@type integer
      local indent = INDENT_COMMON ---@type string
      local child_indent = INDENT_COMMON ---@type string

      if cur > 1 then
        local last_stack_indent = stack_indent[cur - 1] ---@type string
        if folded_depth == 0 then
          indent = last_stack_indent .. (is_lastchild and "╰─" or "├─") ---@type string
          child_indent = last_stack_indent .. (is_lastchild and "  " or "│ ") ---@type string
          folded_indent = indent
        else
          indent = last_stack_indent ---@type string
          child_indent = last_stack_indent ---@type string
        end
      end

      last_cur = cur ---@type integer
      stack_depth[cur] = depth ---@type integer
      stack_indent[cur] = child_indent ---@type string
      stack_lnum_roots[cur] = lnum + 1 ---@type integer
      if dry then
        uuid2lnum[containernode.uuid] = lnum
        return lnum
      end

      lnum = lnum + 1 ---@type integer

      local nodestate = statemap[containernode.uuid] ---@type eve.ux.view.tree.INodeState
      local result ---@type eve.ux.view.tree.INodeTreeviewResultCache|eve.ux.view.tree.INodeRenderResult

      if folded_depth > 0 then
        result = render_treeview_container(ctx, containernode, containerstate, lnum, folded_depth)
      else
        local cache = nodestate.cache_treeview ---@type eve.ux.view.tree.INodeTreeviewResultCache|nil
        if cache == nil or cache.tick ~= tick_render_treeview then
          result = render_treeview_container(ctx, containernode, containerstate, lnum, folded_depth)
          ---@type eve.ux.view.tree.INodeTreeviewResultCache
          cache = {
            tick = tick_render_treeview,
            text = result.text,
            highlights = result.highlights or {},
          }
          nodestate.cache_treeview = cache
        else
          result = cache
        end
      end

      indent = folded_depth > 0 and folded_indent or indent ---@type string

      lines[lnum] = indent .. result.text ---@type string
      highlights_list[lnum] = result.highlights ---@type std.t.IHighlightInline[]|nil
      indents[lnum] = indent ---@type string
      uuid2lnum[containernode.uuid] = lnum
      lnum2uuid[lnum] = containernode.uuid
      return lnum
    end
  else
    ---@type eve.ux.view.tree.IRenderTreeviewContainerNode
    render_container = function(containernode, containerstate, is_lastchild, cur, dry)
      local depth = cur == 1 and 1 or (stack_depth[cur - 1] + 1) ---@type integer
      local indent = INDENT_COMMON ---@type string
      local child_indent = INDENT_COMMON ---@type string

      if cur > 1 then
        local last_stack_indent = stack_indent[cur - 1] ---@type string
        indent = last_stack_indent .. (is_lastchild and "╰─" or "├─") ---@type string
        child_indent = last_stack_indent .. (is_lastchild and "  " or "│ ") ---@type string
      end

      last_cur = cur ---@type integer
      stack_depth[cur] = depth ---@type integer
      stack_indent[cur] = child_indent ---@type string
      stack_lnum_roots[cur] = lnum + 1 ---@type integer
      if dry then
        uuid2lnum[containernode.uuid] = lnum
        return lnum
      end

      lnum = lnum + 1 ---@type integer

      local nodestate = statemap[containernode.uuid] ---@type eve.ux.view.tree.INodeState
      local result ---@type eve.ux.view.tree.INodeTreeviewResultCache|eve.ux.view.tree.INodeRenderResult

      local cache = nodestate.cache_treeview ---@type eve.ux.view.tree.INodeTreeviewResultCache|nil
      if cache == nil or cache.tick ~= tick_render_treeview then
        result = render_treeview_container(ctx, containernode, containerstate, lnum, 0)
        ---@type eve.ux.view.tree.INodeTreeviewResultCache
        cache = {
          tick = tick_render_treeview,
          text = result.text,
          highlights = result.highlights or {},
        }
        nodestate.cache_treeview = cache
      else
        result = cache
      end

      lines[lnum] = indent .. result.text ---@type string
      highlights_list[lnum] = result.highlights ---@type std.t.IHighlightInline[]|nil
      indents[lnum] = indent ---@type string
      uuid2lnum[containernode.uuid] = lnum
      lnum2uuid[lnum] = containernode.uuid
      return lnum
    end
  end

  local conditional ---@type std.collection.tree.ITraverseConditional
  if only_expanded then
    if only_matched then
      if only_selected then
        ---@type std.collection.tree.ITraverseConditional
        conditional = function(_, node)
          local nodestate = statemap[node.uuid] ---@type eve.ux.view.tree.INodeState|nil
          if
            nodestate == nil
            or nodestate.tick_invisible == tick_invisible
            or nodestate.tick_matched ~= tick_matched
            or nodestate.tick_selected_maximum ~= tick_selected
          then
            return "badroot"
          end
          return nodestate.collapsed and "goodnode" or "goodroot"
        end
      else
        ---@type std.collection.tree.ITraverseConditional
        conditional = function(_, node)
          local nodestate = statemap[node.uuid] ---@type eve.ux.view.tree.INodeState|nil
          if
            nodestate == nil
            or nodestate.tick_invisible == tick_invisible
            or nodestate.tick_matched ~= tick_matched
          then
            return "badroot"
          end
          return nodestate.collapsed and "goodnode" or "goodroot"
        end
      end
    else
      if only_selected then
        ---@type std.collection.tree.ITraverseConditional
        conditional = function(_, node)
          local nodestate = statemap[node.uuid] ---@type eve.ux.view.tree.INodeState|nil
          if
            nodestate == nil
            or nodestate.tick_invisible == tick_invisible
            or nodestate.tick_selected_maximum ~= tick_selected
          then
            return "badroot"
          end
          return nodestate.collapsed and "goodnode" or "goodroot"
        end
      else
        ---@type std.collection.tree.ITraverseConditional
        conditional = function(_, node)
          local nodestate = statemap[node.uuid] ---@type eve.ux.view.tree.INodeState|nil
          if nodestate == nil or nodestate.tick_invisible == tick_invisible then
            return "badroot"
          end
          return nodestate.collapsed and "goodnode" or "goodroot"
        end
      end
    end
  else
    if only_matched then
      if only_selected then
        ---@type std.collection.tree.ITraverseConditional
        conditional = function(_, node)
          local nodestate = statemap[node.uuid] ---@type eve.ux.view.tree.INodeState|nil
          if
            nodestate == nil
            or nodestate.tick_invisible == tick_invisible
            or nodestate.tick_matched ~= tick_matched
            or nodestate.tick_selected_maximum ~= tick_selected
          then
            return "badroot"
          end
          return "goodroot"
        end
      else
        ---@type std.collection.tree.ITraverseConditional
        conditional = function(_, node)
          local nodestate = statemap[node.uuid] ---@type eve.ux.view.tree.INodeState|nil
          if
            nodestate == nil
            or nodestate.tick_invisible == tick_invisible
            or nodestate.tick_matched ~= tick_matched
          then
            return "badroot"
          end
          return "goodroot"
        end
      end
    else
      if only_selected then
        ---@type std.collection.tree.ITraverseConditional
        conditional = function(_, node)
          local nodestate = statemap[node.uuid] ---@type eve.ux.view.tree.INodeState|nil
          if
            nodestate == nil
            or nodestate.tick_invisible == tick_invisible
            or nodestate.tick_selected_maximum ~= tick_selected
          then
            return "badroot"
          end
          return "goodroot"
        end
      else
        ---@type std.collection.tree.ITraverseConditional
        conditional = function(_, node)
          local nodestate = statemap[node.uuid] ---@type eve.ux.view.tree.INodeState|nil
          if nodestate == nil or nodestate.tick_invisible == tick_invisible then
            return "badroot"
          end
          return "goodroot"
        end
      end
    end
  end

  local traverse ---@type std.collection.tree.ITraverseHandler
  if foldempty then
    ---@type std.collection.tree.ITraverseHandler
    traverse = function(_, node, cur, is_lastchild, onlychild)
      if cur < last_cur then
        for index = cur, last_cur, 1 do
          local lnum_root = stack_lnum_roots[index] ---@type integer
          childline[lnum_root] = lnum ---@type integer
        end
      end

      local nodestate = statemap[node.uuid]

      if onlychild ~= nil then
        local state_onlychild = statemap[onlychild] ---@type eve.ux.view.tree.INodeState
        if state_onlychild.nodetype == "container" then
          ---@cast nodestate            eve.ux.view.tree.IContainerNodeState
          render_container(node, nodestate, is_lastchild, cur, true)
          folded_depth = folded_depth + 1 ---@type integer
          return
        end
      end

      if nodestate.nodetype == "leaf" then
        folded_depth = 0 ---@type integer
        return render_leaf(node, nodestate, is_lastchild, cur)
      end

      if nodestate.nodetype == "container" then
        local result = render_container(node, nodestate, is_lastchild, cur, false)
        folded_depth = 0 ---@type integer
        return result
      end

      std.reporter.error({
        from = self.fullname,
        subject = "render_treeview",
        message = "Unknown nodetype",
        details = {
          node = node,
          nodestate = nodestate,
          foldempty = foldempty,
          cur = cur,
          is_lastchild = is_lastchild,
          onlychild = onlychild,
        },
      })
    end
  else
    ---@type std.collection.tree.ITraverseHandler
    traverse = function(_, node, cur, is_lastchild)
      if cur < last_cur then
        for index = cur, last_cur, 1 do
          local lnum_root = stack_lnum_roots[index] ---@type integer
          childline[lnum_root] = lnum ---@type integer
        end
      end

      local nodestate = statemap[node.uuid] ---@type eve.ux.view.tree.INodeState|nil

      if nodestate.nodetype == "leaf" then
        return render_leaf(node, nodestate, is_lastchild, cur)
      end

      if nodestate.nodetype == "container" then
        return render_container(node, nodestate, is_lastchild, cur, false)
      end

      std.reporter.error({
        from = self.fullname,
        subject = "render_treeview",
        message = "Unknown nodetype",
        details = {
          node = node,
          nodestate = nodestate,
          foldempty = foldempty,
          cur = cur,
          is_lastchild = is_lastchild,
        },
      })
    end
  end

  tree:traverse(root, traverse, conditional)
  for index = 1, last_cur, 1 do
    local lnum_container = stack_lnum_roots[index] ---@type integer
    childline[lnum_container] = lnum ---@type integer
  end

  vim.api.nvim_buf_clear_namespace(bufnr, nsnr, 0, -1)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  for index = 1, #lines, 1 do
    local row = index - 1 ---@type integer
    local highlights = highlights_list[index] ---@type std.t.IHighlightInline[]|nil
    local indent = indents[index] ---@type string
    local offset = #indent
    vim.hl.range(bufnr, nsnr, self._indent_hln, { row, #INDENT_COMMON }, { row, offset })

    if highlights ~= nil then
      local H = #highlights ---@type integer
      for hi = 1, H, 1 do
        local highlight = highlights[hi] ---@type std.t.IHighlightInline
        local hlname = highlight.hlname ---@type string
        local colr = highlight.colr ---@type integer
        local coll = highlight.coll ---@type integer
        vim.hl.range(bufnr, nsnr, hlname, { row, offset + coll }, { row, colr < 0 and -1 or offset + colr })
      end
    end
  end

  ---@type eve.ux.view.tree.IRenderResult
  local result = { childline = childline, indents = indents, lnum2uuid = lnum2uuid, uuid2lnum = uuid2lnum }
  return result
end

----------------------------------------------------------------------------------------------------

---@param root                          string|nil
---@return string[]
function M:collect_leafs(root)
  self:__health__()

  local statemap = self.statemap ---@type table<string, eve.ux.view.tree.INodeState>
  local uuids = {} ---@type string[]

  self._tree:quick_traverse(root, function(_, node)
    local state = statemap[node.uuid] ---@type eve.ux.view.tree.INodeState|nil
    if state ~= nil and state.nodetype == "leaf" then
      uuids[#uuids + 1] = node.uuid
    end
  end)
  return uuids
end

---@param root                          string|nil
---@return table<string, true>
function M:collect_selected(root)
  self:__health__()

  local statemap = self.statemap ---@type table<string, eve.ux.view.tree.INodeState>
  local tick_selected = self._tick_selected ---@type integer
  local selected_set = {} ---@type table<string, true>

  self._tree:quick_traverse(root, function(_, node)
    local state = statemap[node.uuid] ---@type eve.ux.view.tree.INodeState|nil
    if state ~= nil and state.tick_selected == tick_selected then
      selected_set[node.uuid] = true
    end
  end)
  return selected_set
end

---@param uuid                          string
---@return eve.ux.view.Tree
function M:empty(uuid)
  self:__health__()
  local statemap = self.statemap ---@type table<string, eve.ux.view.tree.INodeState>
  self._tree:quick_traverse(uuid, function(_, node)
    if node.uuid ~= uuid then
      statemap[node.uuid] = nil
    end
  end)
  return self
end

---@param uuid                          string
---@param state                         eve.ux.view.tree.INodeState
---@return eve.ux.view.Tree
function M:insert(uuid, state)
  self:__health__()
  self.statemap[uuid] = state
  return self
end

---@param uuid                          string
---@return eve.ux.view.Tree
function M:remove(uuid)
  self:__health__()

  local statemap = self.statemap ---@type table<string, eve.ux.view.tree.INodeState>
  local tree = self._tree ---@type std.collection.IReadonlyTree

  tree:quick_traverse(uuid, function(_, node)
    statemap[node.uuid] = nil
  end)

  return self
end

---@param uuid                          string
---@return eve.ux.view.tree.INodeState|nil
function M:retrieve(uuid)
  self:__health__()
  return self.statemap[uuid] ---@type eve.ux.view.tree.INodeState|nil
end

---@param nodeuuid                      string
---@param selected                      boolean
---@return eve.ux.view.Tree
function M:set_selected(nodeuuid, selected)
  self:__health__()

  local tick_selected = self._tick_selected ---@type integer
  local nodestate = self.statemap[nodeuuid] ---@type eve.ux.view.tree.INodeState|nil
  if nodestate ~= nil then
    if selected then
      if nodestate.tick_selected ~= tick_selected then
        self._count_selected = self._count_selected + 1
        nodestate.tick_selected = tick_selected ---@type integer
      end
    else
      if nodestate.tick_selected == tick_selected then
        self._count_selected = self._count_selected - 1
        nodestate.tick_selected = -1 ---@type integer
      end
    end
  end

  self._dirty_selected = true
  return self
end

---@param uuid                          string
---@param selected                      boolean
---@param only_visible                  boolean|nil
---@return eve.ux.view.Tree
function M:toggle_select(uuid, selected, only_visible)
  self:__health__()

  local statemap = self.statemap ---@type table<string, eve.ux.view.tree.INodeState>
  local tree = self._tree ---@type std.collection.IReadonlyTree
  local count_selected = self._count_selected ---@type integer
  local tick_invisible = only_visible and self._tick_invisible or -1 ---@type integer
  local tick_selected = self._tick_selected ---@type integer

  if selected then
    tree:quick_traverse(uuid, function(_, node)
      local nodestate = statemap[node.uuid] ---@type eve.ux.view.tree.INodeState|nil
      if
        nodestate ~= nil
        and nodestate.tick_invisible ~= tick_invisible
        and nodestate.tick_selected ~= tick_selected
      then
        count_selected = count_selected + 1
        nodestate.tick_selected = tick_selected ---@type integer
      end
    end)
  else
    tree:quick_traverse(uuid, function(_, node)
      local nodestate = statemap[node.uuid] ---@type eve.ux.view.tree.INodeState|nil
      if
        nodestate ~= nil
        and nodestate.tick_invisible ~= tick_invisible
        and nodestate.tick_selected == tick_selected
      then
        count_selected = count_selected + 1
        nodestate.tick_selected = -1 ---@type integer
      end
    end)
  end

  self._count_selected = count_selected
  self._dirty_selected = true ---@type boolean
  return self
end

----------------------------------------------------------------------------------------------------

---@param uuid                          string
---@param value                         eve.ux.view.tree.CollapseActionEnum
---@param recursive                     ?boolean
---@return eve.ux.view.Tree
function M:collapse(uuid, value, recursive)
  self:__health__()

  local tree = self._tree ---@type std.collection.IReadonlyTree
  if not tree:isexistent(uuid) then
    std.reporter.error({
      from = self.fullname,
      subject = "collapse",
      message = "The node isn't exist",
      details = { uuid = uuid, value = value, recursive = recursive },
    })
    return self
  end

  local statemap = self.statemap ---@type table<string, eve.ux.view.tree.INodeState>
  local state = statemap[uuid] ---@type eve.ux.view.tree.INodeState|nil
  if state == nil then
    std.reporter.error({
      from = self.fullname,
      subject = "collapse",
      message = "The node state isn't exist",
      details = { uuid = uuid, value = value, recursive = recursive },
    })
    return self
  end

  local collapsed = state.collapsed ---@type boolean
  if value == "toggle" then
    collapsed = not collapsed
  elseif value == "collapse" then
    collapsed = true
  elseif value == "expand" then
    collapsed = false
  end

  if recursive then
    tree:quick_traverse(uuid, function(_, node)
      local s = statemap[node.uuid] ---@type eve.ux.view.tree.INodeState
      if s.collapsed ~= collapsed then
        s.collapsed = collapsed
        s.cache_listview = nil
        s.cache_treeview = nil
      end
    end)
  else
    if state.collapsed ~= collapsed then
      state.collapsed = collapsed
      state.cache_listview = nil
      state.cache_treeview = nil
    end
  end

  return self
end

---@param nodeuuid                      string
---@return eve.ux.view.Tree
function M:mark_node_invisible(nodeuuid)
  self:__health__()
  local statemap = self.statemap ---@type table<string, eve.ux.view.tree.INodeState>
  local nodestate = statemap[nodeuuid] ---@type eve.ux.view.tree.INodeState|nil
  if nodestate ~= nil then
    nodestate.tick_invisible = self._tick_invisible ---@type integer
  end
  return self
end

---@param uuid                          string
---@return eve.ux.view.Tree
function M:mark_subroot_invisible(uuid)
  self:__health__()

  local statemap = self.statemap ---@type table<string, eve.ux.view.tree.INodeState>
  local tree = self._tree ---@type std.collection.IReadonlyTree
  local tick_invisible = self._tick_invisible ---@type integer

  tree:quick_traverse(uuid, function(_, node)
    local nodestate = statemap[node.uuid] ---@type eve.ux.view.tree.INodeState|nil
    if nodestate ~= nil then
      nodestate.tick_invisible = tick_invisible ---@type integer
    end
  end)

  return self
end

---@return eve.ux.view.Tree
function M:mark_cache_invisible_dirty()
  self:__health__()
  self._tick_invisible = self._tick_invisible + 1
  return self
end

---@return eve.ux.view.Tree
function M:mark_cache_selected_dirty()
  self:__health__()
  self._dirty_selected = true
  self._tick_selected = self._tick_selected + 1
  return self
end

---@return eve.ux.view.Tree
function M:mark_cache_listview_dirty()
  self:__health__()
  self._tick_render_listview = self._tick_render_listview + 1
  return self
end

---@return eve.ux.view.Tree
function M:mark_cache_treeview_dirty()
  self:__health__()
  self._tick_render_treeview = self._tick_render_treeview + 1
  return self
end

----------------------------------------------------------------------------------------------------

---@protected
---@return nil
function M:__health__()
  if self._disposed then
    local message = string.format("[%s] has been disposed.", self.fullname) ---@type string
    error(message)
  end
end

---@return nil
function M:__refresh_selected_maximum__()
  if not self._dirty_selected then
    return
  end
  self._dirty_selected = false ---@type boolean

  local tree = self._tree ---@type std.collection.IReadonlyTree
  local statemap = self.statemap ---@type table<string, eve.ux.view.tree.INodeState>

  tree:unsafe_traverse(nil, function(ctx)
    local rootnode = ctx.rootnode ---@type std.collection.tree.INode
    local nodemap = ctx.nodemap ---@type table<string, std.collection.tree.INode>

    ---@param node                      std.collection.tree.INode
    ---@return integer
    local function recursive(node)
      local childstate = statemap[node.uuid] ---@type eve.ux.view.tree.INodeState
      local tick = childstate.tick_selected ---@type integer
      for _, childuuid in ipairs(node.children) do
        local childnode = nodemap[childuuid] ---@type std.collection.tree.INode
        local t = recursive(childnode) ---@type integer
        tick = tick < t and t or tick ---@type integer
      end
      childstate.tick_selected_maximum = tick ---@type integer
      return tick
    end

    for _, childuuid in ipairs(rootnode.children) do
      local childnode = nodemap[childuuid] ---@type std.collection.tree.INode
      recursive(childnode) ---@type integer
    end
  end)
end

return M
