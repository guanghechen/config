---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.view.treeview" ---@type string

local treeview_layout = require("stl.view.treeview.layout")

local EMPTY_CHILDREN = {} ---@type string[]
local EMPTY_LAYOUT = treeview_layout.layout({
  roots = EMPTY_CHILDREN,
  children = function()
    return EMPTY_CHILDREN
  end,
})

---@alias era.view.tree.CollapseActionEnum
---| "collapse"
---| "expand"
---| "toggle"

---@alias era.view.tree.NodeTypeEnum
---| "container"
---| "leaf"

---@alias era.view.tree.ViewtypeEnum
---| "tree"
---| "list"

---@alias era.view.tree.INodeState
---| era.view.tree.IContainerNodeState
---| era.view.tree.ILeafNodeState
---| era.view.tree.ILeafLocationState

---@alias era.view.tree.IRenderListviewLeafNode
---| fun(leafnode: stl.c.ITreeNode, leafstate: era.view.tree.ILeafNodeState): nil

---@alias era.view.tree.IRenderListviewLeafLocations
---| fun(leafnode: stl.c.ITreeNode, leafstate: era.view.tree.ILeafNodeState): nil

---@alias era.view.tree.IRenderTreeviewContainerNode
---| fun(containernode: stl.c.ITreeNode, containerstate: era.view.tree.IContainerNodeState, is_lastchild: boolean, cur: integer, dry: boolean): nil

---@alias era.view.tree.IRenderTreeviewLeafNode
---| fun(leafnode: stl.c.ITreeNode, leafstate: era.view.tree.ILeafNodeState, is_lastchild: boolean, cur: integer): nil

---@alias era.view.tree.IRenderTreeviewLeafLocations
---| fun(leafnode: stl.c.ITreeNode, leafstate: era.view.tree.ILeafNodeState, leafindent: string): nil

---@alias era.view.tree.IListviewLeafNodeRenderer
---| fun(ctx: era.view.tree.IListviewRendererContext, node: stl.c.ITreeNode, nodestate: era.view.tree.ILeafNodeState, lnum: integer): era.view.tree.INodeRenderResult

---@alias era.view.tree.IListviewLeafLocationRenderer
---| fun(ctx: era.view.tree.IListviewRendererContext, node: stl.c.ITreeNode, nodestate: era.view.tree.ILeafNodeState, location: era.view.tree.ILeafLocationState, lnum: integer): era.view.tree.INodeRenderResult

---@alias era.view.tree.ITreeviewContainerNodeRenderer
---| fun(ctx: era.view.tree.ITreeviewRendererContext, node: stl.c.ITreeNode, nodestate: era.view.tree.IContainerNodeState, lnum: integer, folded_depth: integer): era.view.tree.INodeRenderResult

---@alias era.view.tree.ITreeviewLeafNodeRenderer
---| fun(ctx: era.view.tree.ITreeviewRendererContext, node: stl.c.ITreeNode, nodestate: era.view.tree.ILeafNodeState, lnum: integer): era.view.tree.INodeRenderResult

---@alias era.view.tree.ITreeviewLeafLocationRenderer
---| fun(ctx: era.view.tree.ITreeviewRendererContext, node: stl.c.ITreeNode, nodestate: era.view.tree.ILeafNodeState, location: era.view.tree.ILeafLocationState, lnum: integer): era.view.tree.INodeRenderResult

---@class era.view.tree.IListviewRendererContext
---@field public rootnode               stl.c.ITreeNode
---@field public rootstate              era.view.tree.IContainerNodeState
---@field public tree                   stl.c.IReadonlyTree
---@field public view                   era.view.Tree

---@class era.view.tree.ITreeviewRendererContext
---@field public rootnode               stl.c.ITreeNode
---@field public rootstate              era.view.tree.INodeState
---@field public tree                   stl.c.IReadonlyTree
---@field public view                   era.view.Tree

---@class era.view.tree.IContainerNodeState
---@field public nodetype               "container"
---@field public collapsed              boolean
---@field public tick_invisible         integer
---@field public tick_matched           integer
---@field public tick_selected          integer
---@field public tick_selected_maximum  integer
---@field public cache_treeview         era.view.tree.INodeTreeviewResultCache|nil

---@class era.view.tree.ILeafNodeState
---@field public nodetype               "leaf"
---@field public collapsed              boolean
---@field public locations              era.view.tree.ILeafLocationState[]|nil
---@field public tick_invisible         integer
---@field public tick_matched           integer
---@field public tick_selected          integer
---@field public cache_listview         era.view.tree.INodeListviewResultCache|nil
---@field public cache_treeview         era.view.tree.INodeTreeviewResultCache|nil

---@class era.view.tree.ILeafLocationState
---@field public nodetype               "location"
---@field public leafuuid               string
---@field public locationuuid           string
---@field public tick_invisible         integer
---@field public data                   unknown|nil

---@class era.view.tree.INodeListviewResultCache
---@field public tick                   integer
---@field public text                   string
---@field public highlights             stl.t.IHighlightInline[]

---@class era.view.tree.INodeTreeviewResultCache
---@field public tick                   integer
---@field public text                   string
---@field public highlights             stl.t.IHighlightInline[]

---@class era.view.tree.INodeRenderResult
---@field public text                   string
---@field public highlights             stl.t.IHighlightInline[]|nil

---@class era.view.tree.IRenderResult
---@field public childline              integer[]|nil
---@field public indents                string[]
---@field public layout                 stl.view.TreeLayout|nil Tree mode only.
---@field public lnum2uuid              table<integer, string>|nil List mode only.
---@field public uuid2lnum              table<string, integer>|nil List mode only.

---@class era.view.tree.IRenderListviewParams
---@field public bufnr                  integer
---@field public rootuuid               string|nil
---@field public orders                 string[]|nil
---@field public only_matched           boolean
---@field public only_selected          boolean
---@field public only_visible           boolean

---@class era.view.tree.IRenderTreeviewParams
---@field public bufnr                  integer
---@field public rootuuid               string|nil
---@field public foldempty              boolean
---@field public only_expanded          boolean
---@field public only_matched           boolean
---@field public only_selected          boolean
---@field public only_visible           boolean

----------------------------------------------------------------------------------------------------

local NSNR_DEFAULT = dot.var.nsnr.view_tree ---@type integer

---@param bufnr                         integer
---@param nsnr                          integer
---@param hlname                        string
---@param row                           integer
---@param coll                          integer
---@param colr                          integer
---@param line_length                   integer
---@return nil
local function set_inline_highlight(bufnr, nsnr, hlname, row, coll, colr, line_length)
  coll = math.max(0, math.min(coll, line_length))
  colr = colr < 0 and line_length or math.max(0, math.min(colr, line_length))
  if coll >= colr then
    return
  end

  -- vim.hl.range resolves Vim positions and regions for every call. These ranges are already
  -- validated single-line byte offsets, so a direct extmark avoids that cost on large results.
  vim.api.nvim_buf_set_extmark(bufnr, nsnr, row, coll, {
    end_row = row,
    end_col = colr,
    hl_group = hlname,
    priority = vim.hl.priorities.user,
    strict = false,
  })
end

---@param childline                     integer[]
---@param location_lnums                integer[]
---@return integer|nil
local function assign_childline_location(childline, location_lnums)
  local lnum_last_location = location_lnums[#location_lnums] ---@type integer|nil
  if lnum_last_location ~= nil then
    for _, location_lnum in ipairs(location_lnums) do
      childline[location_lnum] = lnum_last_location ---@type integer
    end
  end
  return lnum_last_location
end

---@param parent_leaf_lines             table<string, integer[]>
---@param parentuuid                    string|nil
---@param lnum_leaf                     integer
---@return nil
local function track_parent_leaf_line(parent_leaf_lines, parentuuid, lnum_leaf)
  if parentuuid == nil then
    return
  end

  local parentleafs = parent_leaf_lines[parentuuid] ---@type integer[]|nil
  if parentleafs == nil then
    parentleafs = {}
    parent_leaf_lines[parentuuid] = parentleafs
  end
  parentleafs[#parentleafs + 1] = lnum_leaf ---@type integer
end

---@param childline                     integer[]
---@param parent_leaf_lines             table<string, integer[]>
---@param leaf_has_location             table<integer, boolean>
---@return nil
local function finalize_parent_leaf_childline(childline, parent_leaf_lines, leaf_has_location)
  for _, leaflines in pairs(parent_leaf_lines) do
    local last_leaf = leaflines[#leaflines] ---@type integer|nil
    if last_leaf ~= nil then
      for _, leafline in ipairs(leaflines) do
        if not leaf_has_location[leafline] then
          childline[leafline] = last_leaf ---@type integer
        end
      end
    end
  end
end

---@class era.view.ITreeProps
---@field public name                   string
---@field public fullname               ?string
---@field public indent                 ?string
---@field public indent_hln             ?string
---@field public tree                   stl.c.IReadonlyTree
---@field public render_listview_leaf   era.view.tree.IListviewLeafNodeRenderer
---@field public render_listview_location   era.view.tree.IListviewLeafLocationRenderer
---@field public render_treeview_container  era.view.tree.ITreeviewContainerNodeRenderer
---@field public render_treeview_leaf   era.view.tree.ITreeviewLeafNodeRenderer
---@field public render_treeview_location   era.view.tree.ITreeviewLeafLocationRenderer

---@class era.view.Tree
---@field public fullname               string
---@field public statemap               table<string, era.view.tree.INodeState>
---
---@field protected _disposed           boolean
---@field protected _indent             string
---@field protected _indent_hln         string
---@field protected _tree               stl.c.IReadonlyTree
---
---@field protected _dirty_selected     boolean
---@field protected _tick_invisible     integer
---@field protected _tick_matched       integer
---@field protected _tick_selected      integer
---@field protected _tick_render_listview integer
---@field protected _tick_render_treeview integer
---
---@field protected _render_listview_leaf       era.view.tree.IListviewLeafNodeRenderer
---@field protected _render_listview_location   era.view.tree.IListviewLeafLocationRenderer
---@field protected _render_treeview_container  era.view.tree.ITreeviewContainerNodeRenderer
---@field protected _render_treeview_leaf       era.view.tree.ITreeviewLeafNodeRenderer
---@field protected _render_treeview_location   era.view.tree.ITreeviewLeafLocationRenderer
local M = {}
M.__index = M

---@param props                         era.view.ITreeProps
---@return era.view.Tree
function M.new(props)
  local name = props.name ---@type string
  local fullname = props.fullname or string.format("%s -> %s", name, __module_name__) ---@type string
  local indent = props.indent or "" ---@type string
  local indent_hln = props.indent_hln or "f_utw_indent" ---@type string
  local tree = props.tree ---@type stl.c.IReadonlyTree

  local render_listview_leaf = props.render_listview_leaf ---@type era.view.tree.IListviewLeafNodeRenderer
  local render_listview_location = props.render_listview_location ---@type era.view.tree.IListviewLeafLocationRenderer
  local render_treeview_container = props.render_treeview_container ---@type era.view.tree.ITreeviewContainerNodeRenderer
  local render_treeview_leaf = props.render_treeview_leaf ---@type era.view.tree.ITreeviewLeafNodeRenderer
  local render_treeview_location = props.render_treeview_location ---@type era.view.tree.ITreeviewLeafLocationRenderer

  local statemap = {} ---@type table<string, era.view.tree.INodeState>

  local self = setmetatable({}, M)
  self.fullname = fullname
  self.statemap = statemap
  self._disposed = false
  self._indent = indent
  self._indent_hln = indent_hln
  self._tree = tree

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

---@return era.view.Tree
function M:clear()
  self:__health__()

  table.clear(self.statemap)
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
  local nodestate = self.statemap ~= nil and self.statemap[uuid] or nil ---@type era.view.tree.INodeState|nil
  return nodestate ~= nil and nodestate.tick_selected == self._tick_selected
end

---@param uuid                          string
---@return boolean
function M:isvisible(uuid)
  local nodestate = self.statemap ~= nil and self.statemap[uuid] or nil ---@type era.view.tree.INodeState|nil
  return nodestate ~= nil and nodestate.tick_invisible ~= self._tick_invisible
end

----------------------------------------------------------------------------------------------------

---@param params                        era.view.tree.IRenderListviewParams
---@return era.view.tree.IRenderResult
function M:render_listview(params)
  self:__health__()

  local statemap = self.statemap ---@type table<string, era.view.tree.INodeState>
  local tree = self._tree ---@type stl.c.IReadonlyTree

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

  local rootnode = tree:retrieve(rootuuid) ---@type stl.c.ITreeNode|nil
  local rootstate = statemap[rootuuid] ---@type era.view.tree.INodeState|nil
  if rootnode == nil or (rootstate ~= nil and rootstate.tick_invisible == tick_invisible) then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
    local result = { indents = {}, lnum2uuid = {}, uuid2lnum = {} } ---@type era.view.tree.IRenderResult
    return result
  end

  if only_selected then
    self:__refresh_selected_maximum__()
  end

  ---@cast rootstate                    era.view.tree.IContainerNodeState
  ---@type era.view.tree.IListviewRendererContext
  local ctx = {
    rootnode = rootnode,
    rootstate = rootstate,
    tree = tree,
    view = self,
  }

  local nsnr = NSNR_DEFAULT ---@type integer
  local INDENT_COMMON = self._indent ---@type string
  local render_listview_leaf = self._render_listview_leaf ---@type era.view.tree.IListviewLeafNodeRenderer
  local render_listview_location = self._render_listview_location ---@type era.view.tree.IListviewLeafLocationRenderer

  local indent_leaf = INDENT_COMMON ---@type string
  local indent_location = indent_leaf .. "├─" ---@type string
  local indent_location_lastchild = indent_leaf .. "╰─" ---@type string

  local childline = {} ---@type integer[]
  local indents = {} ---@type string[]
  local lines = {} ---@type string[]
  local highlights_list = {} ---@type (stl.t.IHighlightInline[]|nil)[]
  local lnum2uuid = {} ---@type string[]
  local uuid2lnum = {} ---@type table<string, integer>
  local parent_leaf_lines = {} ---@type table<string, integer[]>
  local leaf_has_location = {} ---@type table<integer, boolean>

  local lnum = 0 ---@type integer

  ---@type era.view.tree.IRenderListviewLeafLocations
  local function render_leaf_locations(leafnode, leafstate)
    if leafstate.locations == nil or #leafstate.locations <= 0 then
      return
    end

    local N = #leafstate.locations ---@type integer
    local last_child_index = 0 ---@type integer
    for index = N, 1, -1 do
      local location = leafstate.locations[index] ---@type era.view.tree.ILeafLocationState
      if location.tick_invisible ~= tick_invisible then
        last_child_index = index ---@type integer
        break
      end
    end

    if last_child_index > 0 then
      local location_lnums = {} ---@type integer[]
      for index = 1, N, 1 do
        local location = leafstate.locations[index] ---@type era.view.tree.ILeafLocationState
        if location.tick_invisible ~= tick_invisible then
          lnum = lnum + 1 ---@type integer
          local indent = index == last_child_index and indent_location_lastchild or indent_location ---@type string
          local result = render_listview_location(ctx, leafnode, leafstate, location, lnum)

          indents[lnum] = indent ---@type string
          lines[lnum] = indent .. result.text ---@type string
          highlights_list[lnum] = result.highlights ---@type stl.t.IHighlightInline[]|nil
          lnum2uuid[lnum] = location.locationuuid
          uuid2lnum[location.locationuuid] = lnum
          location_lnums[#location_lnums + 1] = lnum
        end
      end
      if #location_lnums > 0 then
        return assign_childline_location(childline, location_lnums)
      end
    end

    return nil
  end

  ---@type era.view.tree.IRenderListviewLeafNode
  local function render_leafnode(leafnode, leafstate)
    local indent = indent_leaf ---@type string

    lnum = lnum + 1 ---@type integer
    local lnum_leaf = lnum ---@type integer

    local cache = leafstate.cache_listview ---@type era.view.tree.INodeListviewResultCache|nil
    if cache == nil or cache.tick ~= tick_render_listview then
      local result = render_listview_leaf(ctx, leafnode, leafstate, lnum)
      ---@type era.view.tree.INodeListviewResultCache
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
    highlights_list[lnum] = cache.highlights ---@type stl.t.IHighlightInline[]|nil
    lnum2uuid[lnum] = leafnode.uuid
    uuid2lnum[leafnode.uuid] = lnum

    local lnum_last_location = render_leaf_locations(leafnode, leafstate) ---@type integer|nil
    if lnum_last_location ~= nil then
      childline[lnum_leaf] = lnum_last_location ---@type integer
      leaf_has_location[lnum_leaf] = true
    end

    track_parent_leaf_line(parent_leaf_lines, leafnode.parent, lnum_leaf)

    return lnum
  end

  ---@param nodestate                   era.view.tree.INodeState|nil
  ---@return boolean
  local function includes_subtree(nodestate)
    if nodestate == nil or nodestate.tick_invisible == tick_invisible then
      return false
    end
    if only_matched and nodestate.tick_matched ~= tick_matched then
      return false
    end
    if only_selected and nodestate.tick_selected_maximum ~= tick_selected then
      return false
    end
    return true
  end

  ---@param nodestate                   era.view.tree.INodeState|nil
  ---@return boolean
  local function includes_leaf(nodestate)
    if nodestate == nil or nodestate.nodetype ~= "leaf" or nodestate.tick_invisible == tick_invisible then
      return false
    end
    if only_matched and nodestate.tick_matched ~= tick_matched then
      return false
    end
    if only_selected and nodestate.tick_selected ~= tick_selected then
      return false
    end
    return true
  end

  if orders ~= nil then
    for _, uuid in ipairs(orders) do
      local node = tree:retrieve(uuid) ---@type stl.c.ITreeNode|nil
      local nodestate = statemap[uuid] ---@type era.view.tree.INodeState|nil
      if node ~= nil and includes_leaf(nodestate) then
        ---@cast nodestate              era.view.tree.ILeafNodeState
        render_leafnode(node, nodestate)
      end
    end
  else
    local roots = rootuuid == tree.root and (tree:children(rootuuid) or EMPTY_CHILDREN) or { rootuuid } ---@type string[]
    local stack_children = { roots } ---@type string[][]
    local stack_indexes = { 1 } ---@type integer[]
    local stack_size = 1 ---@type integer

    while stack_size > 0 do
      local childids = stack_children[stack_size] ---@type string[]
      local child_index = stack_indexes[stack_size] ---@type integer
      if child_index > #childids then
        stack_children[stack_size] = nil
        stack_indexes[stack_size] = nil
        stack_size = stack_size - 1
      else
        stack_indexes[stack_size] = child_index + 1
        local uuid = childids[child_index] ---@type string
        local nodestate = statemap[uuid] ---@type era.view.tree.INodeState|nil
        if includes_subtree(nodestate) then
          if includes_leaf(nodestate) then
            local node = tree:retrieve(uuid) ---@type stl.c.ITreeNode
            ---@cast nodestate          era.view.tree.ILeafNodeState
            render_leafnode(node, nodestate)
          else
            local descendants = tree:children(uuid) or EMPTY_CHILDREN ---@type string[]
            if #descendants > 0 then
              stack_size = stack_size + 1
              stack_children[stack_size] = descendants
              stack_indexes[stack_size] = 1
            end
          end
        end
      end
    end
  end

  finalize_parent_leaf_childline(childline, parent_leaf_lines, leaf_has_location)

  vim.api.nvim_buf_clear_namespace(bufnr, nsnr, 0, -1)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  for index = 1, #lines, 1 do
    local row = index - 1 ---@type integer
    local highlights = highlights_list[index] ---@type stl.t.IHighlightInline[]|nil
    local indent = indents[index] ---@type string
    local offset = #indent
    local line_length = #lines[index] ---@type integer
    set_inline_highlight(bufnr, nsnr, self._indent_hln, row, #INDENT_COMMON, offset, line_length)

    if highlights ~= nil then
      local H = #highlights ---@type integer
      for hi = 1, H, 1 do
        local highlight = highlights[hi] ---@type stl.t.IHighlightInline
        local hlname = highlight.hlname ---@type string
        local colr = highlight.colr ---@type integer
        local coll = highlight.coll ---@type integer
        set_inline_highlight(bufnr, nsnr, hlname, row, offset + coll, colr < 0 and -1 or offset + colr, line_length)
      end
    end
  end

  ---@type era.view.tree.IRenderResult
  local result = { childline = childline, indents = indents, lnum2uuid = lnum2uuid, uuid2lnum = uuid2lnum }
  return result
end

---@param params                        era.view.tree.IRenderTreeviewParams
---@return era.view.tree.IRenderResult
function M:render_treeview(params)
  self:__health__()

  local statemap = self.statemap ---@type table<string, era.view.tree.INodeState>
  local tree = self._tree ---@type stl.c.IReadonlyTree

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

  local rootnode = tree:retrieve(root) ---@type stl.c.ITreeNode|nil
  local rootstate = statemap[root] ---@type era.view.tree.INodeState|nil
  if rootnode == nil or (rootstate ~= nil and rootstate.tick_invisible == tick_invisible) then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
    local result = { childline = {}, indents = {}, layout = EMPTY_LAYOUT } ---@type era.view.tree.IRenderResult
    return result
  end

  if only_selected then
    self:__refresh_selected_maximum__()
  end

  ---@cast rootstate                    era.view.tree.IContainerNodeState
  ---@type era.view.tree.ITreeviewRendererContext
  local ctx = {
    rootnode = rootnode,
    rootstate = rootstate,
    tree = tree,
    view = self,
  }

  local nsnr = NSNR_DEFAULT ---@type integer
  local INDENT_COMMON = self._indent ---@type string
  local render_treeview_container = self._render_treeview_container ---@type era.view.tree.ITreeviewContainerNodeRenderer
  local render_treeview_leaf = self._render_treeview_leaf ---@type era.view.tree.ITreeviewLeafNodeRenderer
  local render_treeview_location = self._render_treeview_location ---@type era.view.tree.ITreeviewLeafLocationRenderer

  local childline = {} ---@type integer[]
  local indents = {} ---@type string[]
  local lines = {} ---@type string[]
  local highlights_list = {} ---@type (stl.t.IHighlightInline[]|nil)[]
  local parent_leaf_lines = {} ---@type table<string, integer[]>
  local leaf_has_location = {} ---@type table<integer, boolean>

  ---@param uuid                        string
  ---@return boolean
  local function includes(uuid)
    local nodestate = statemap[uuid] ---@type era.view.tree.INodeState|nil
    if nodestate == nil or nodestate.tick_invisible == tick_invisible then
      return false
    end
    if only_matched and nodestate.tick_matched ~= tick_matched then
      return false
    end
    if only_selected and nodestate.tick_selected_maximum ~= tick_selected then
      return false
    end
    return true
  end

  ---@param uuid                        string
  ---@return string[]
  local function project_tree_children(uuid)
    local source = tree:children(uuid) or EMPTY_CHILDREN ---@type string[]
    local N = #source ---@type integer
    local first_excluded = nil ---@type integer|nil
    for index = 1, N, 1 do
      if not includes(source[index]) then
        first_excluded = index
        break
      end
    end
    if first_excluded == nil then
      return source
    end

    local projected = {} ---@type string[]
    for index = 1, first_excluded - 1, 1 do
      projected[index] = source[index]
    end
    for index = first_excluded + 1, N, 1 do
      local uuid_child = source[index] ---@type string
      if includes(uuid_child) then
        projected[#projected + 1] = uuid_child
      end
    end
    return projected
  end

  ---@param uuid                        string
  ---@return string[]
  local function children(uuid)
    local nodestate = statemap[uuid] ---@type era.view.tree.INodeState|nil
    if nodestate == nil or nodestate.nodetype == "location" then
      return EMPTY_CHILDREN
    end
    if only_expanded and nodestate.collapsed then
      return EMPTY_CHILDREN
    end
    if nodestate.nodetype == "container" then
      return project_tree_children(uuid)
    end

    local locations = nodestate.locations ---@type era.view.tree.ILeafLocationState[]|nil
    if locations == nil or #locations == 0 then
      return EMPTY_CHILDREN
    end

    local projected = {} ---@type string[]
    for _, location in ipairs(locations) do
      if location.tick_invisible ~= tick_invisible then
        projected[#projected + 1] = location.locationuuid
      end
    end
    return projected
  end

  local roots ---@type string[]
  if root == tree.root then
    roots = project_tree_children(root)
  elseif includes(root) then
    roots = { root }
  else
    roots = EMPTY_CHILDREN
  end

  local layout = treeview_layout.layout({
    roots = roots,
    children = children,
    can_fold = foldempty and function(parentuuid, childuuid)
      local parentstate = statemap[parentuuid] ---@type era.view.tree.INodeState|nil
      local childstate = statemap[childuuid] ---@type era.view.tree.INodeState|nil
      return parentstate ~= nil
        and parentstate.nodetype == "container"
        and childstate ~= nil
        and childstate.nodetype == "container"
    end or nil,
  })

  local prefixes = { [0] = INDENT_COMMON } ---@type table<integer, string>
  for lnum = 1, layout:len(), 1 do
    local uuid = layout:id(lnum) ---@type string
    local nodestate = statemap[uuid] ---@type era.view.tree.INodeState
    local depth = layout:depth(lnum) ---@type integer
    local is_lastchild = layout:is_last(lnum) ---@type boolean
    local prefix = prefixes[depth] or INDENT_COMMON ---@type string
    local indent = depth == 0 and INDENT_COMMON or (prefix .. (is_lastchild and "╰─" or "├─")) ---@type string
    local child_indent = depth == 0 and INDENT_COMMON or (prefix .. (is_lastchild and "  " or "│ ")) ---@type string
    prefixes[depth + 1] = child_indent

    local folded_ids = layout:folded_ids(lnum) ---@type string[]|nil
    indents[lnum] = indent

    local text ---@type string
    local highlights ---@type stl.t.IHighlightInline[]|nil
    if nodestate.nodetype == "location" then
      local leafnode = tree:retrieve(nodestate.leafuuid) ---@type stl.c.ITreeNode
      local leafstate = statemap[nodestate.leafuuid] ---@type era.view.tree.ILeafNodeState
      local result = render_treeview_location(ctx, leafnode, leafstate, nodestate, lnum)
      text = result.text
      highlights = result.highlights

      local parent_lnum = layout:parent_lnum(lnum) ---@type integer
      childline[lnum] = layout:last_child_lnum(parent_lnum) or lnum
    elseif nodestate.nodetype == "leaf" then
      local leafnode = tree:retrieve(uuid) ---@type stl.c.ITreeNode
      local cache = nodestate.cache_treeview ---@type era.view.tree.INodeTreeviewResultCache|nil
      if cache == nil or cache.tick ~= tick_render_treeview then
        local result = render_treeview_leaf(ctx, leafnode, nodestate, lnum) ---@type era.view.tree.INodeRenderResult
        cache = {
          tick = tick_render_treeview,
          text = result.text,
          highlights = result.highlights or {},
        }
        nodestate.cache_treeview = cache
      end
      text = cache.text
      highlights = cache.highlights

      local lnum_last_location = layout:last_descendant_lnum(lnum) ---@type integer
      childline[lnum] = lnum_last_location
      if lnum_last_location > lnum then
        leaf_has_location[lnum] = true
      end
      track_parent_leaf_line(parent_leaf_lines, leafnode.parent, lnum)
    elseif nodestate.nodetype == "container" then
      local containernode = tree:retrieve(uuid) ---@type stl.c.ITreeNode
      local folded_depth = folded_ids ~= nil and #folded_ids - 1 or 0 ---@type integer
      local result ---@type era.view.tree.INodeTreeviewResultCache|era.view.tree.INodeRenderResult
      if folded_depth > 0 then
        result = render_treeview_container(ctx, containernode, nodestate, lnum, folded_depth)
      else
        local cache = nodestate.cache_treeview ---@type era.view.tree.INodeTreeviewResultCache|nil
        if cache == nil or cache.tick ~= tick_render_treeview then
          local rendered = render_treeview_container(ctx, containernode, nodestate, lnum, 0)
          cache = {
            tick = tick_render_treeview,
            text = rendered.text,
            highlights = rendered.highlights or {},
          }
          nodestate.cache_treeview = cache
        end
        result = cache
      end
      text = result.text
      highlights = result.highlights
      local lnum_last_descendant = layout:last_descendant_lnum(lnum) ---@type integer
      if lnum_last_descendant > lnum then
        childline[lnum] = lnum_last_descendant
      end
    else
      error(string.format("[%s] unknown nodetype for '%s': %s", __module_name__, uuid, tostring(nodestate.nodetype)))
    end

    lines[lnum] = indent .. text
    highlights_list[lnum] = highlights
  end

  finalize_parent_leaf_childline(childline, parent_leaf_lines, leaf_has_location)

  vim.api.nvim_buf_clear_namespace(bufnr, nsnr, 0, -1)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  for index = 1, #lines, 1 do
    local row = index - 1 ---@type integer
    local highlights = highlights_list[index] ---@type stl.t.IHighlightInline[]|nil
    local indent = indents[index] ---@type string
    local offset = #indent
    local line_length = #lines[index] ---@type integer
    set_inline_highlight(bufnr, nsnr, self._indent_hln, row, #INDENT_COMMON, offset, line_length)

    if highlights ~= nil then
      local H = #highlights ---@type integer
      for hi = 1, H, 1 do
        local highlight = highlights[hi] ---@type stl.t.IHighlightInline
        local hlname = highlight.hlname ---@type string
        local colr = highlight.colr ---@type integer
        local coll = highlight.coll ---@type integer
        set_inline_highlight(bufnr, nsnr, hlname, row, offset + coll, colr < 0 and -1 or offset + colr, line_length)
      end
    end
  end

  ---@type era.view.tree.IRenderResult
  local result = {
    childline = childline,
    indents = indents,
    layout = layout,
  }
  return result
end

----------------------------------------------------------------------------------------------------

---@param root                          string|nil
---@return string[]
function M:collect_leafs(root)
  self:__health__()

  local statemap = self.statemap ---@type table<string, era.view.tree.INodeState>
  local uuids = {} ---@type string[]

  self._tree:quick_traverse(root, function(_, node)
    local state = statemap[node.uuid] ---@type era.view.tree.INodeState|nil
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

  local statemap = self.statemap ---@type table<string, era.view.tree.INodeState>
  local tick_selected = self._tick_selected ---@type integer
  local selected_set = {} ---@type table<string, true>

  self._tree:quick_traverse(root, function(_, node)
    local state = statemap[node.uuid] ---@type era.view.tree.INodeState|nil
    if state ~= nil and state.tick_selected == tick_selected then
      selected_set[node.uuid] = true
    end
  end)
  return selected_set
end

---@param uuid                          string
---@param state                         era.view.tree.INodeState
---@return era.view.Tree
function M:insert(uuid, state)
  self:__health__()

  local statemap = self.statemap ---@type table<string, era.view.tree.INodeState>
  local oldstate = statemap[uuid] ---@type era.view.tree.INodeState|nil
  if oldstate ~= nil and oldstate.locations ~= nil then
    for _, location in ipairs(oldstate.locations) do
      statemap[location.locationuuid] = nil ---@type nil
    end
  end

  statemap[uuid] = state
  if state.locations ~= nil then
    for _, location in ipairs(state.locations) do
      statemap[location.locationuuid] = location
    end
  end
  return self
end

---@param uuid                          string
---@return era.view.Tree
function M:remove(uuid)
  self:__health__()

  local statemap = self.statemap ---@type table<string, era.view.tree.INodeState>
  local tree = self._tree ---@type stl.c.IReadonlyTree

  tree:quick_traverse(uuid, function(_, node)
    local state = statemap[node.uuid] ---@type era.view.tree.INodeState|nil
    if state ~= nil then
      statemap[node.uuid] = nil
      if state.locations ~= nil then
        for _, location in ipairs(state.locations) do
          statemap[location.locationuuid] = nil ---@type nil
        end
      end
    end
  end)

  return self
end

---@param leafnodestate                 era.view.tree.ILeafNodeState
---@return nil
function M:remove_all_locations(leafnodestate)
  self:__health__()

  if leafnodestate.locations ~= nil then
    local statemap = self.statemap ---@type table<string, era.view.tree.INodeState>
    local locations = leafnodestate.locations ---@type era.view.tree.ILeafLocationState[]
    local L = #locations ---@type integer
    for i = 1, L, 1 do
      local location = locations[i] ---@type era.view.tree.ILeafLocationState
      statemap[location.locationuuid] = nil
    end
    leafnodestate.locations = nil ---@type era.view.tree.ILeafLocationState[]|nil
  end
end

---@param leafnodestate                 era.view.tree.ILeafNodeState
---@param locationuuid                  string
---@return nil
function M:remove_location(leafnodestate, locationuuid)
  self:__health__()

  if leafnodestate.locations ~= nil then
    local statemap = self.statemap ---@type table<string, era.view.tree.INodeState>
    local locations = leafnodestate.locations ---@type era.view.tree.ILeafLocationState[]
    local L = #locations ---@type integer
    local k = 0 ---@type integer
    for i = 1, L, 1 do
      local location = locations[i] ---@type era.view.tree.ILeafLocationState
      if location.locationuuid == locationuuid then
        statemap[location.locationuuid] = nil
      else
        k = k + 1 ---@type integer
        locations[k] = location ---@type era.view.tree.ILeafLocationState
      end
    end
    stl.table.truncate_inline(locations, k)
  end
end

---@param uuid                          string
---@return era.view.tree.INodeState|nil
function M:retrieve(uuid)
  self:__health__()
  return self.statemap[uuid] ---@type era.view.tree.INodeState|nil
end

---@param nodeuuid                      string
---@param selected                      boolean
---@return era.view.Tree
function M:set_selected(nodeuuid, selected)
  self:__health__()

  local tick_selected = self._tick_selected ---@type integer
  local nodestate = self.statemap[nodeuuid] ---@type era.view.tree.INodeState|nil
  if nodestate ~= nil then
    if selected then
      if nodestate.tick_selected ~= tick_selected then
        nodestate.tick_selected = tick_selected ---@type integer
      end
    else
      if nodestate.tick_selected == tick_selected then
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
---@return era.view.Tree
function M:toggle_select(uuid, selected, only_visible)
  self:__health__()

  local statemap = self.statemap ---@type table<string, era.view.tree.INodeState>
  local tree = self._tree ---@type stl.c.IReadonlyTree
  local tick_invisible = only_visible and self._tick_invisible or -1 ---@type integer
  local tick_selected = self._tick_selected ---@type integer

  if selected then
    tree:quick_traverse(uuid, function(_, node)
      local nodestate = statemap[node.uuid] ---@type era.view.tree.INodeState|nil
      if
        nodestate ~= nil
        and nodestate.tick_invisible ~= tick_invisible
        and nodestate.tick_selected ~= tick_selected
      then
        nodestate.tick_selected = tick_selected ---@type integer
      end
    end)
  else
    tree:quick_traverse(uuid, function(_, node)
      local nodestate = statemap[node.uuid] ---@type era.view.tree.INodeState|nil
      if
        nodestate ~= nil
        and nodestate.tick_invisible ~= tick_invisible
        and nodestate.tick_selected == tick_selected
      then
        nodestate.tick_selected = -1 ---@type integer
      end
    end)
  end

  self._dirty_selected = true ---@type boolean
  return self
end

----------------------------------------------------------------------------------------------------

---@param uuid                          string
---@param value                         era.view.tree.CollapseActionEnum
---@param recursive                     ?boolean
---@return era.view.Tree
function M:collapse(uuid, value, recursive)
  self:__health__()

  local tree = self._tree ---@type stl.c.IReadonlyTree
  if not tree:isexistent(uuid) then
    stl.reporter.error({
      from = self.fullname,
      subject = "collapse",
      message = "The node isn't exist",
      details = { uuid = uuid, value = value, recursive = recursive },
    })
    return self
  end

  local statemap = self.statemap ---@type table<string, era.view.tree.INodeState>
  local state = statemap[uuid] ---@type era.view.tree.INodeState|nil
  if state == nil then
    stl.reporter.error({
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
      local s = statemap[node.uuid] ---@type era.view.tree.INodeState
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
---@return era.view.Tree
function M:mark_node_invisible(nodeuuid)
  self:__health__()
  local statemap = self.statemap ---@type table<string, era.view.tree.INodeState>
  local nodestate = statemap[nodeuuid] ---@type era.view.tree.INodeState|nil
  if nodestate ~= nil then
    nodestate.tick_invisible = self._tick_invisible ---@type integer
  end
  return self
end

---@return era.view.Tree
function M:mark_cache_invisible_dirty()
  self:__health__()
  self._tick_invisible = self._tick_invisible + 1
  return self
end

---@return era.view.Tree
function M:mark_cache_listview_dirty()
  self:__health__()
  self._tick_render_listview = self._tick_render_listview + 1
  return self
end

---@return era.view.Tree
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

  local tree = self._tree ---@type stl.c.IReadonlyTree
  local statemap = self.statemap ---@type table<string, era.view.tree.INodeState>
  local roots = tree:children(tree.root) or EMPTY_CHILDREN ---@type string[]
  local stack_uuids = {} ---@type string[]
  local stack_indexes = {} ---@type integer[]
  local stack_maximums = {} ---@type integer[]

  for _, rootuuid in ipairs(roots) do
    local stack_size = 1 ---@type integer
    local rootstate = statemap[rootuuid] ---@type era.view.tree.INodeState
    stack_uuids[1] = rootuuid
    stack_indexes[1] = 1
    stack_maximums[1] = rootstate.tick_selected

    while stack_size > 0 do
      local uuid = stack_uuids[stack_size] ---@type string
      local children = tree:children(uuid) or EMPTY_CHILDREN ---@type string[]
      local child_index = stack_indexes[stack_size] ---@type integer
      if child_index <= #children then
        local childuuid = children[child_index] ---@type string
        local childstate = statemap[childuuid] ---@type era.view.tree.INodeState
        stack_indexes[stack_size] = child_index + 1
        stack_size = stack_size + 1
        stack_uuids[stack_size] = childuuid
        stack_indexes[stack_size] = 1
        stack_maximums[stack_size] = childstate.tick_selected
      else
        local maximum = stack_maximums[stack_size] ---@type integer
        statemap[uuid].tick_selected_maximum = maximum
        stack_uuids[stack_size] = nil
        stack_indexes[stack_size] = nil
        stack_maximums[stack_size] = nil
        stack_size = stack_size - 1
        if stack_size > 0 and stack_maximums[stack_size] < maximum then
          stack_maximums[stack_size] = maximum
        end
      end
    end
  end
  self._dirty_selected = false ---@type boolean
end

return M
