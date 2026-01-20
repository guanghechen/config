---@diagnostic disable: assign-type-mismatch, unused-local, inject-field, undefined-field, return-type-mismatch
---@diagnostic disable-next-line: unused-local
local __module_name__ = "stl.view.treeview" ---@type string

----------------------------------------------------------------------------------------------------
-- Type Definitions
----------------------------------------------------------------------------------------------------

---@alias stl.view.treeview.CollapseAction "collapse"|"expand"|"toggle"
---@alias stl.view.treeview.NodeType "container"|"leaf"|"location"
---@alias stl.view.treeview.ViewType "tree"|"list"

---@class stl.view.treeview.IBaseStatus
---@field public nodetype               stl.view.treeview.NodeType
---@field public tick_visible           integer

---@class stl.view.treeview.INodeStatus : stl.view.treeview.IBaseStatus
---@field public nodetype               "container"|"leaf"
---@field public collapsed              boolean
---@field public tick_visible           integer
---@field public tick_matched           integer
---@field public tick_selected          integer
---@field public tick_selected_maximum  integer   -- 子树最大选中 tick（用于快速过滤）
---@field public locations              stl.view.treeview.ILocationStatus[]|nil  -- leaf 节点的 location 列表
---@field public cache_listview         stl.view.treeview.INodeRenderCache|nil
---@field public cache_treeview         stl.view.treeview.INodeRenderCache|nil

---@class stl.view.treeview.ILocationStatus : stl.view.treeview.IBaseStatus
---@field public nodetype               "location"
---@field public leafuuid               string
---@field public locationuuid           string
---@field public tick_visible           integer
---@field public data                   unknown|nil

---@class stl.view.treeview.INodeRenderCache
---@field public tick                   integer
---@field public text                   string
---@field public highlights             stl.t.IHighlightInline[]

---@class stl.view.treeview.INodeRenderResult
---@field public text                   string
---@field public highlights             stl.t.IHighlightInline[]|nil

---@class stl.view.treeview.INavigation
---@field public parent_lnum            integer[]     -- lnum -> parent_lnum
---@field public firstchild_lnum        integer[]     -- lnum -> firstchild_lnum
---@field public lastchild_lnum         integer[]     -- lnum -> lastchild_lnum
---@field public prev_sibling_lnum      integer[]     -- lnum -> prev_sibling_lnum
---@field public next_sibling_lnum      integer[]     -- lnum -> next_sibling_lnum

---@class stl.view.treeview.IRenderResult
---@field public lines                  string[]
---@field public highlights             stl.t.IHighlightInline[][]
---@field public indents                string[]
---@field public lnum2uuid              string[]
---@field public uuid2lnum              table<string, integer>
---@field public childline              integer[]
---@field public navigation             stl.view.treeview.INavigation

---@class stl.view.treeview.IRenderContext
---@field public tree                   stl.c.IReadonlyTree
---@field public treeview               stl.view.Treeview
---@field public rootnode               stl.c.ITreeNode
---@field public indent                 string
---@field public depth                  integer

---@alias stl.view.treeview.IContainerRenderer
---| fun(ctx: stl.view.treeview.IRenderContext, node: stl.c.ITreeNode, status: stl.view.treeview.INodeStatus, is_lastchild: boolean, folded_depth: integer): stl.view.treeview.INodeRenderResult

---@alias stl.view.treeview.ILeafRenderer
---| fun(ctx: stl.view.treeview.IRenderContext, node: stl.c.ITreeNode, status: stl.view.treeview.INodeStatus, is_lastchild: boolean): stl.view.treeview.INodeRenderResult

---@alias stl.view.treeview.ILocationRenderer
---| fun(ctx: stl.view.treeview.IRenderContext, node: stl.c.ITreeNode, status: stl.view.treeview.INodeStatus, location: stl.view.treeview.ILocationStatus): stl.view.treeview.INodeRenderResult

---@class stl.view.treeview.IRenderListviewParams
---@field public bufnr                  integer
---@field public orders                 string[]|nil
---@field public only_visible           boolean
---@field public only_matched           boolean
---@field public only_selected          boolean
---@field public render_leaf            stl.view.treeview.ILeafRenderer
---@field public render_location        stl.view.treeview.ILocationRenderer|nil

---@class stl.view.treeview.IRenderTreeviewParams
---@field public bufnr                  integer
---@field public foldempty              boolean
---@field public only_expanded          boolean
---@field public only_visible           boolean
---@field public only_matched           boolean
---@field public only_selected          boolean
---@field public render_container       stl.view.treeview.IContainerRenderer
---@field public render_leaf            stl.view.treeview.ILeafRenderer
---@field public render_location        stl.view.treeview.ILocationRenderer|nil

----------------------------------------------------------------------------------------------------
-- Treeview Class
----------------------------------------------------------------------------------------------------

---@class stl.view.treeview.IProps
---@field public name                   string
---@field public tree                   stl.c.ITree

---@class stl.view.Treeview
---@field public fullname               string
---@field protected _disposed           boolean
---@field protected _tree               stl.c.ITree
---@field protected _superroot          string
---@field protected _root               string
---@field protected _root_history       string[]
---@field protected _statusmap          table<string, stl.view.treeview.IBaseStatus>
---@field protected _tick_visible       integer
---@field protected _tick_matched       integer
---@field protected _tick_selected      integer
---@field protected _tick_render_listview integer
---@field protected _tick_render_treeview integer
local M = {}
M.__index = M

---@param props                         stl.view.treeview.IProps
---@return stl.view.Treeview
function M.new(props)
  local name = props.name ---@type string
  local fullname = string.format("%s@%s", __module_name__, name) ---@type string
  local tree = props.tree ---@type stl.c.ITree

  local self = setmetatable({}, M)
  self.fullname = fullname
  self._disposed = false
  self._tree = tree
  self._superroot = tree.root
  self._root = tree.root
  self._root_history = {}
  self._statusmap = {}
  self._tick_visible = 1
  self._tick_matched = 0
  self._tick_selected = 1
  self._tick_render_listview = 0
  self._tick_render_treeview = 0
  return self
end

---@return nil
function M:dispose()
  if self._disposed then
    return nil
  end
  self._disposed = true

  self._tree = nil
  self._statusmap = nil
  self._root_history = nil
end

---@return boolean
function M:isdisposed()
  return self._disposed
end

----------------------------------------------------------------------------------------------------
-- Root Management (attach/detach)
----------------------------------------------------------------------------------------------------

---@return string
function M:root()
  return self._root
end

---@return string
function M:superroot()
  return self._superroot
end

---@param uuid                          string
---@return stl.view.Treeview
function M:attach(uuid)
  self:__health__()

  if not self._tree:isexistent(uuid) then
    stl.reporter.warn({
      from = self.fullname,
      subject = "attach",
      message = string.format("Node '%s' does not exist.", uuid),
    })
    return self
  end

  self._root_history[#self._root_history + 1] = self._root
  self._root = uuid
  return self
end

---@return stl.view.Treeview
function M:detach()
  self:__health__()

  if #self._root_history > 0 then
    self._root = table.remove(self._root_history)
  end
  return self
end

---@return stl.view.Treeview
function M:reset_root()
  self:__health__()

  self._root = self._superroot
  self._root_history = {}
  return self
end

----------------------------------------------------------------------------------------------------
-- Status Management
----------------------------------------------------------------------------------------------------

---@param uuid                          string
---@param nodetype                      stl.view.treeview.NodeType
---@return stl.view.treeview.INodeStatus
function M:ensure_status(uuid, nodetype)
  self:__health__()

  ---@diagnostic disable-next-line: assign-type-mismatch
  local status = self._statusmap[uuid] ---@type stl.view.treeview.INodeStatus|nil
  if status == nil then
    ---@type stl.view.treeview.INodeStatus
    status = {
      nodetype = nodetype,
      collapsed = nodetype == "container",
      tick_visible = 0,
      tick_matched = 0,
      tick_selected = 0,
      tick_selected_maximum = 0,
      cache_listview = nil,
      cache_treeview = nil,
    }
    self._statusmap[uuid] = status
  end
  return status
end

---@param uuid                          string
---@return stl.view.treeview.INodeStatus|stl.view.treeview.ILocationStatus|nil
function M:retrieve_status(uuid)
  self:__health__()
  return self._statusmap[uuid]
end

---@param uuid                          string
---@return stl.view.treeview.INodeStatus|nil
function M:retrieve_node_status(uuid)
  self:__health__()
  local status = self._statusmap[uuid]
  if status == nil or status.nodetype == "location" then
    return nil
  end
  ---@cast status                       stl.view.treeview.INodeStatus
  return status
end

---@param uuid                          string
---@return nil
function M:remove_status(uuid)
  self:__health__()
  self._statusmap[uuid] = nil
end

---@return nil
function M:clear_statusmap()
  self:__health__()
  self._statusmap = {}
end

----------------------------------------------------------------------------------------------------
-- Visibility State
----------------------------------------------------------------------------------------------------

---@param uuid                          string
---@return boolean
function M:is_visible(uuid)
  local status = self._statusmap[uuid]
  if status == nil then
    return true
  end
  return status.tick_visible ~= self._tick_visible
end

---@param uuid                          string
---@return nil
function M:mark_invisible(uuid)
  self:__health__()

  local status = self._statusmap[uuid]
  if status ~= nil then
    status.tick_visible = self._tick_visible
  end

  -- 级联标记子孙节点
  self._tree:quick_traverse(uuid, function(_, node)
    local s = self._statusmap[node.uuid]
    if s ~= nil then
      s.tick_visible = self._tick_visible
    end
  end)
end

---@return nil
function M:reset_visibility()
  self:__health__()
  self._tick_visible = self._tick_visible + 1
end

----------------------------------------------------------------------------------------------------
-- Match State
----------------------------------------------------------------------------------------------------

---@param uuid                          string
---@return boolean
function M:is_matched(uuid)
  local status = self._statusmap[uuid]
  if status == nil then
    return false
  end
  return status.tick_matched == self._tick_matched
end

---@param uuid                          string
---@return nil
function M:mark_matched(uuid)
  self:__health__()

  local status = self._statusmap[uuid]
  if status ~= nil then
    status.tick_matched = self._tick_matched
  end
end

---@return nil
function M:reset_match()
  self:__health__()
  self._tick_matched = self._tick_matched + 1
end

----------------------------------------------------------------------------------------------------
-- Selection State
----------------------------------------------------------------------------------------------------

---@param uuid                          string
---@return boolean
function M:is_selected(uuid)
  local status = self._statusmap[uuid]
  if status == nil then
    return false
  end
  return status.tick_selected == self._tick_selected
end

---@param uuid                          string
---@param selected                      boolean
---@param recursive                     boolean
---@return nil
function M:set_selected(uuid, selected, recursive)
  self:__health__()

  local tick = selected and self._tick_selected or 0 ---@type integer

  if recursive then
    self._tree:quick_traverse(uuid, function(_, node)
      local status = self._statusmap[node.uuid]
      if status ~= nil then
        status.tick_selected = tick
        status.cache_listview = nil
        status.cache_treeview = nil
      end
    end)
  else
    local status = self._statusmap[uuid]
    if status ~= nil then
      status.tick_selected = tick
      status.cache_listview = nil
      status.cache_treeview = nil
    end
  end
end

---@param uuid                          string
---@param recursive                     boolean
---@return nil
function M:toggle_selected(uuid, recursive)
  local selected = not self:is_selected(uuid)
  self:set_selected(uuid, selected, recursive)
end

---@return nil
function M:reset_selection()
  self:__health__()
  self._tick_selected = self._tick_selected + 1
end

---@return nil
function M:refresh_selected_maximum()
  self:__health__()

  local tree = self._tree ---@type stl.c.ITree
  ---@diagnostic disable-next-line: assign-type-mismatch
  local statusmap = self._statusmap ---@type table<string, stl.view.treeview.INodeStatus>
  local _tick_selected = self._tick_selected ---@type integer

  ---@param node stl.c.ITreeNode
  ---@return integer
  local function recursive(node)
    local status = statusmap[node.uuid]
    if status == nil then
      return 0
    end

    local tick = status.tick_selected ---@type integer
    for _, childuuid in ipairs(node.children) do
      local childnode = tree:retrieve(childuuid)
      if childnode ~= nil then
        local t = recursive(childnode)
        tick = tick < t and t or tick
      end
    end
    status.tick_selected_maximum = tick
    return tick
  end

  local rootnode = tree:retrieve(self._root)
  if rootnode ~= nil then
    recursive(rootnode)
  end
end

----------------------------------------------------------------------------------------------------
-- Collapse State
----------------------------------------------------------------------------------------------------

---@param uuid                          string
---@return boolean
function M:is_collapsed(uuid)
  local status = self._statusmap[uuid]
  if status == nil then
    return true
  end
  return status.collapsed
end

---@param uuid                          string
---@param action                        stl.view.treeview.CollapseAction
---@param recursive                     boolean
---@return nil
function M:collapse(uuid, action, recursive)
  self:__health__()

  local status = self._statusmap[uuid]
  if status == nil then
    return
  end

  local collapsed = status.collapsed ---@type boolean
  if action == "toggle" then
    collapsed = not collapsed
  elseif action == "collapse" then
    collapsed = true
  elseif action == "expand" then
    collapsed = false
  end

  if recursive then
    self._tree:quick_traverse(uuid, function(_, node)
      local s = self._statusmap[node.uuid]
      if s ~= nil and s.collapsed ~= collapsed then
        s.collapsed = collapsed
        s.cache_listview = nil
        s.cache_treeview = nil
      end
    end)
  else
    if status.collapsed ~= collapsed then
      status.collapsed = collapsed
      status.cache_listview = nil
      status.cache_treeview = nil
    end
  end
end

----------------------------------------------------------------------------------------------------
-- Cache Management
----------------------------------------------------------------------------------------------------

---@return nil
function M:mark_cache_listview_dirty()
  self:__health__()
  self._tick_render_listview = self._tick_render_listview + 1
end

---@return nil
function M:mark_cache_treeview_dirty()
  self:__health__()
  self._tick_render_treeview = self._tick_render_treeview + 1
end

---@return nil
function M:mark_cache_all_dirty()
  self:mark_cache_listview_dirty()
  self:mark_cache_treeview_dirty()
end

----------------------------------------------------------------------------------------------------
-- Location Management
----------------------------------------------------------------------------------------------------

---@param leafuuid                      string
---@param locations                     stl.view.treeview.ILocationStatus[]
---@return nil
function M:set_locations(leafuuid, locations)
  self:__health__()

  local statusmap = self._statusmap ---@type table<string, stl.view.treeview.INodeStatus|stl.view.treeview.ILocationStatus>
  ---@diagnostic disable-next-line: assign-type-mismatch
  local status = statusmap[leafuuid] ---@type stl.view.treeview.INodeStatus|nil

  -- 先删除旧的 locations
  if status ~= nil and status.locations ~= nil then
    for _, loc in ipairs(status.locations) do
      statusmap[loc.locationuuid] = nil
    end
  end

  -- 设置新的 locations
  if status ~= nil then
    status.locations = locations
    for _, loc in ipairs(locations) do
      statusmap[loc.locationuuid] = loc
    end
  end
end

---@param leafuuid                      string
---@return stl.view.treeview.ILocationStatus[]|nil
function M:get_locations(leafuuid)
  ---@diagnostic disable-next-line: assign-type-mismatch
  local status = self._statusmap[leafuuid] ---@type stl.view.treeview.INodeStatus|nil
  if status == nil then
    return nil
  end
  return status.locations
end

----------------------------------------------------------------------------------------------------
-- Render: Listview
----------------------------------------------------------------------------------------------------

---@param params                        stl.view.treeview.IRenderListviewParams
---@return stl.view.treeview.IRenderResult
function M:render_listview(params)
  self:__health__()

  local statusmap = self._statusmap ---@type table<string, stl.view.treeview.INodeStatus|stl.view.treeview.ILocationStatus>
  local tree = self._tree ---@type stl.c.ITree
  local root = self._root ---@type string

  local orders = params.orders ---@type string[]|nil
  local only_visible = params.only_visible ---@type boolean
  local only_matched = params.only_matched ---@type boolean
  local only_selected = params.only_selected ---@type boolean
  local render_leaf = params.render_leaf ---@type stl.view.treeview.ILeafRenderer
  local render_location = params.render_location ---@type stl.view.treeview.ILocationRenderer|nil

  local tick_visible = only_visible and self._tick_visible or -1 ---@type integer
  local tick_matched = self._tick_matched ---@type integer
  local tick_selected = self._tick_selected ---@type integer
  local tick_render = self._tick_render_listview ---@type integer

  local rootnode = tree:retrieve(root) ---@type stl.c.ITreeNode|nil
  if rootnode == nil then
    return M.__empty_render_result__()
  end

  ---@diagnostic disable-next-line: assign-type-mismatch
  local rootstatus = statusmap[root] ---@type stl.view.treeview.INodeStatus|nil
  if rootstatus ~= nil and rootstatus.tick_visible == tick_visible then
    return M.__empty_render_result__()
  end

  if only_selected then
    self:refresh_selected_maximum()
  end

  ---@type stl.view.treeview.IRenderContext
  local ctx = {
    tree = tree,
    treeview = self,
    rootnode = rootnode,
    indent = "",
    depth = 0,
  }

  -- Results
  local lines = {} ---@type string[]
  local highlights = {} ---@type stl.t.IHighlightInline[][]
  local indents = {} ---@type string[]
  local lnum2uuid = {} ---@type string[]
  local uuid2lnum = {} ---@type table<string, integer>
  local childline = {} ---@type integer[]

  -- Navigation
  local parent_lnum = {} ---@type integer[]
  local firstchild_lnum = {} ---@type integer[]
  local lastchild_lnum = {} ---@type integer[]
  local prev_sibling_lnum = {} ---@type integer[]
  local next_sibling_lnum = {} ---@type integer[]

  -- Parent tracking for sibling navigation
  local parent_children = {} ---@type table<string, integer[]>

  local lnum = 0 ---@type integer

  ---@param leafnode stl.c.ITreeNode
  ---@param leafstatus stl.view.treeview.INodeStatus
  local function process_leaf(leafnode, leafstatus)
    lnum = lnum + 1 ---@type integer
    local lnum_leaf = lnum ---@type integer

    -- Use cache if available
    local cache = leafstatus.cache_listview ---@type stl.view.treeview.INodeRenderCache|nil
    if cache == nil or cache.tick ~= tick_render then
      local result = render_leaf(ctx, leafnode, leafstatus, false)
      ---@type stl.view.treeview.INodeRenderCache
      cache = {
        tick = tick_render,
        text = result.text,
        highlights = result.highlights or {},
      }
      leafstatus.cache_listview = cache
    end

    lines[lnum] = cache.text
    highlights[lnum] = cache.highlights
    indents[lnum] = ""
    lnum2uuid[lnum] = leafnode.uuid
    uuid2lnum[leafnode.uuid] = lnum
    childline[lnum] = lnum

    -- Track for parent navigation
    local parentuuid = leafnode.parent ---@type string|nil
    if parentuuid ~= nil then
      local siblings = parent_children[parentuuid]
      if siblings == nil then
        siblings = {}
        parent_children[parentuuid] = siblings
      end
      siblings[#siblings + 1] = lnum
    end

    -- Render locations
    if render_location ~= nil and leafstatus.locations ~= nil then
      local locs = leafstatus.locations ---@type stl.view.treeview.ILocationStatus[]
      local location_lnums = {} ---@type integer[]

      for _, loc in ipairs(locs) do
        if loc.tick_visible ~= tick_visible then
          lnum = lnum + 1
          local result = render_location(ctx, leafnode, leafstatus, loc)

          lines[lnum] = "  " .. result.text
          highlights[lnum] = result.highlights or {}
          indents[lnum] = "  "
          lnum2uuid[lnum] = loc.locationuuid
          uuid2lnum[loc.locationuuid] = lnum
          location_lnums[#location_lnums + 1] = lnum

          -- Location's parent is the leaf
          parent_lnum[lnum] = lnum_leaf
        end
      end

      -- Update childline for leaf with locations
      if #location_lnums > 0 then
        childline[lnum_leaf] = location_lnums[#location_lnums]
        firstchild_lnum[lnum_leaf] = location_lnums[1]
        lastchild_lnum[lnum_leaf] = location_lnums[#location_lnums]

        -- Sibling navigation for locations
        for i, loc_lnum in ipairs(location_lnums) do
          if i > 1 then
            prev_sibling_lnum[loc_lnum] = location_lnums[i - 1]
          end
          if i < #location_lnums then
            next_sibling_lnum[loc_lnum] = location_lnums[i + 1]
          end
        end
      end
    end
  end

  ---@param node stl.c.ITreeNode
  ---@return boolean
  local function should_process(node)
    ---@diagnostic disable-next-line: assign-type-mismatch
    local status = statusmap[node.uuid] ---@type stl.view.treeview.INodeStatus|nil
    if status == nil then
      return false
    end
    if status.nodetype ~= "leaf" then
      return false
    end
    if status.tick_visible == tick_visible then
      return false
    end
    if only_matched and status.tick_matched ~= tick_matched then
      return false
    end
    if only_selected and status.tick_selected ~= tick_selected then
      return false
    end
    return true
  end

  if orders ~= nil then
    -- Use provided order
    for _, uuid in ipairs(orders) do
      local node = tree:retrieve(uuid)
      ---@diagnostic disable-next-line: assign-type-mismatch
      local status = statusmap[uuid] ---@type stl.view.treeview.INodeStatus|nil
      if node ~= nil and status ~= nil and should_process(node) then
        process_leaf(node, status)
      end
    end
  else
    -- Traverse tree
    ---@type stl.c.ITreeTraverseConditional
    local conditional = function(_, node)
      local status = statusmap[node.uuid] ---@type stl.view.treeview.INodeStatus|nil
      if status == nil or status.tick_visible == tick_visible then
        return "badroot"
      end
      if only_matched and status.tick_matched ~= tick_matched then
        return "badroot"
      end
      if only_selected and status.tick_selected_maximum ~= tick_selected then
        return "badroot"
      end
      return "goodroot"
    end

    ---@type stl.c.ITreeTraverseHandler
    local traverse = function(_, node)
      local status = statusmap[node.uuid] ---@type stl.view.treeview.INodeStatus|nil
      if status ~= nil and should_process(node) then
        process_leaf(node, status)
      end
    end

    tree:traverse(root, traverse, conditional)
  end

  -- Build sibling navigation for leaves
  for _, siblings in pairs(parent_children) do
    for i, sibling_lnum in ipairs(siblings) do
      if i > 1 then
        prev_sibling_lnum[sibling_lnum] = siblings[i - 1]
      end
      if i < #siblings then
        next_sibling_lnum[sibling_lnum] = siblings[i + 1]
      end
    end
  end

  ---@type stl.view.treeview.INavigation
  local navigation = {
    parent_lnum = parent_lnum,
    firstchild_lnum = firstchild_lnum,
    lastchild_lnum = lastchild_lnum,
    prev_sibling_lnum = prev_sibling_lnum,
    next_sibling_lnum = next_sibling_lnum,
  }

  ---@type stl.view.treeview.IRenderResult
  return {
    lines = lines,
    highlights = highlights,
    indents = indents,
    lnum2uuid = lnum2uuid,
    uuid2lnum = uuid2lnum,
    childline = childline,
    navigation = navigation,
  }
end

----------------------------------------------------------------------------------------------------
-- Render: Treeview
----------------------------------------------------------------------------------------------------

---@param params                        stl.view.treeview.IRenderTreeviewParams
---@return stl.view.treeview.IRenderResult
function M:render_treeview(params)
  self:__health__()

  local statusmap = self._statusmap ---@type table<string, stl.view.treeview.INodeStatus|stl.view.treeview.ILocationStatus>
  local tree = self._tree ---@type stl.c.ITree
  local root = self._root ---@type string

  local foldempty = params.foldempty == true ---@type boolean
  local only_expanded = params.only_expanded ---@type boolean
  local only_visible = params.only_visible ---@type boolean
  local only_matched = params.only_matched ---@type boolean
  local only_selected = params.only_selected ---@type boolean
  local render_container = params.render_container ---@type stl.view.treeview.IContainerRenderer
  local render_leaf = params.render_leaf ---@type stl.view.treeview.ILeafRenderer
  local render_location = params.render_location ---@type stl.view.treeview.ILocationRenderer|nil

  local tick_visible = only_visible and self._tick_visible or -1 ---@type integer
  local tick_matched = self._tick_matched ---@type integer
  local tick_selected = self._tick_selected ---@type integer
  local tick_render = self._tick_render_treeview ---@type integer

  local rootnode = tree:retrieve(root) ---@type stl.c.ITreeNode|nil
  if rootnode == nil then
    return M.__empty_render_result__()
  end

  ---@diagnostic disable-next-line: assign-type-mismatch
  local rootstatus = statusmap[root] ---@type stl.view.treeview.INodeStatus|nil
  if rootstatus ~= nil and rootstatus.tick_visible == tick_visible then
    return M.__empty_render_result__()
  end

  if only_selected then
    self:refresh_selected_maximum()
  end

  ---@type stl.view.treeview.IRenderContext
  local ctx = {
    tree = tree,
    treeview = self,
    rootnode = rootnode,
    indent = "",
    depth = 0,
  }

  -- Results
  local lines = {} ---@type string[]
  local highlights = {} ---@type stl.t.IHighlightInline[][]
  local indents = {} ---@type string[]
  local lnum2uuid = {} ---@type string[]
  local uuid2lnum = {} ---@type table<string, integer>
  local childline = {} ---@type integer[]

  -- Navigation
  local parent_lnum = {} ---@type integer[]
  local firstchild_lnum = {} ---@type integer[]
  local lastchild_lnum = {} ---@type integer[]
  local prev_sibling_lnum = {} ---@type integer[]
  local next_sibling_lnum = {} ---@type integer[]

  -- State tracking
  local lnum = 0 ---@type integer
  local last_cur = 0 ---@type integer
  local folded_depth = 0 ---@type integer
  local folded_indent = "" ---@type string
  local stack_indent = {} ---@type string[]
  local stack_depth = {} ---@type integer[]
  local stack_lnum_roots = {} ---@type integer[]
  local stack_children = {} ---@type integer[][] -- track children lnums for each depth

  ---@param containernode stl.c.ITreeNode
  ---@param containerstatus stl.view.treeview.INodeStatus
  ---@param is_lastchild boolean
  ---@param cur integer
  ---@param dry boolean
  ---@return integer
  local function process_container(containernode, containerstatus, is_lastchild, cur, dry)
    local depth = cur == 1 and 1 or (stack_depth[cur - 1] + 1) ---@type integer
    local indent = "" ---@type string
    local child_indent = "" ---@type string

    if cur > 1 then
      local last_stack_indent = stack_indent[cur - 1] ---@type string
      if foldempty and folded_depth > 0 then
        indent = last_stack_indent
        child_indent = last_stack_indent
      else
        indent = last_stack_indent .. (is_lastchild and "╰─" or "├─")
        child_indent = last_stack_indent .. (is_lastchild and "  " or "│ ")
        if foldempty then
          folded_indent = indent
        end
      end
    end

    last_cur = cur
    stack_depth[cur] = depth
    stack_indent[cur] = child_indent
    stack_lnum_roots[cur] = lnum + 1
    stack_children[cur] = {}

    if dry then
      uuid2lnum[containernode.uuid] = lnum
      return lnum
    end

    lnum = lnum + 1 ---@type integer
    local lnum_container = lnum ---@type integer

    -- Use cache if not folded
    local result ---@type stl.view.treeview.INodeRenderResult
    if foldempty and folded_depth > 0 then
      result = render_container(ctx, containernode, containerstatus, is_lastchild, folded_depth)
    else
      local cache = containerstatus.cache_treeview ---@type stl.view.treeview.INodeRenderCache|nil
      if cache == nil or cache.tick ~= tick_render then
        result = render_container(ctx, containernode, containerstatus, is_lastchild, 0)
        ---@type stl.view.treeview.INodeRenderCache
        cache = {
          tick = tick_render,
          text = result.text,
          highlights = result.highlights or {},
        }
        containerstatus.cache_treeview = cache
      else
        result = { text = cache.text, highlights = cache.highlights }
      end
    end

    local final_indent = (foldempty and folded_depth > 0) and folded_indent or indent ---@type string
    lines[lnum] = final_indent .. result.text
    highlights[lnum] = result.highlights or {}
    indents[lnum] = final_indent
    lnum2uuid[lnum] = containernode.uuid
    uuid2lnum[containernode.uuid] = lnum

    -- Track as child of parent
    if cur > 1 and stack_children[cur - 1] ~= nil then
      local parent_children = stack_children[cur - 1]
      parent_children[#parent_children + 1] = lnum_container
    end

    return lnum
  end

  ---@param leafnode stl.c.ITreeNode
  ---@param leafstatus stl.view.treeview.INodeStatus
  ---@param is_lastchild boolean
  ---@param cur integer
  ---@return integer
  local function process_leaf(leafnode, leafstatus, is_lastchild, cur)
    local depth = cur == 1 and 1 or (stack_depth[cur - 1] + 1) ---@type integer
    local indent = "" ---@type string
    local child_indent = "" ---@type string

    if cur > 1 then
      local last_stack_indent = stack_indent[cur - 1] ---@type string
      indent = last_stack_indent .. (is_lastchild and "╰─" or "├─")
      child_indent = last_stack_indent .. (is_lastchild and "  " or "│ ")
    end

    last_cur = cur
    stack_depth[cur] = depth
    stack_indent[cur] = child_indent
    stack_lnum_roots[cur] = lnum + 1
    stack_children[cur] = {}

    lnum = lnum + 1 ---@type integer
    local lnum_leaf = lnum ---@type integer

    -- Use cache
    local cache = leafstatus.cache_treeview ---@type stl.view.treeview.INodeRenderCache|nil
    if cache == nil or cache.tick ~= tick_render then
      local result = render_leaf(ctx, leafnode, leafstatus, is_lastchild)
      ---@type stl.view.treeview.INodeRenderCache
      cache = {
        tick = tick_render,
        text = result.text,
        highlights = result.highlights or {},
      }
      leafstatus.cache_treeview = cache
    end

    lines[lnum] = indent .. cache.text
    highlights[lnum] = cache.highlights
    indents[lnum] = indent
    lnum2uuid[lnum] = leafnode.uuid
    uuid2lnum[leafnode.uuid] = lnum
    childline[lnum_leaf] = lnum

    -- Track as child of parent
    if cur > 1 and stack_children[cur - 1] ~= nil then
      local parent_children_list = stack_children[cur - 1]
      parent_children_list[#parent_children_list + 1] = lnum_leaf
    end

    -- Render locations
    if render_location ~= nil and leafstatus.locations ~= nil then
      local should_render_locations = not (leafstatus.collapsed and only_expanded) ---@type boolean
      if should_render_locations then
        local locs = leafstatus.locations ---@type stl.view.treeview.ILocationStatus[]
        local location_lnums = {} ---@type integer[]
        local N = #locs ---@type integer
        local last_visible_index = 0 ---@type integer

        -- Find last visible location
        for i = N, 1, -1 do
          if locs[i].tick_visible ~= tick_visible then
            last_visible_index = i
            break
          end
        end

        if last_visible_index > 0 then
          for i = 1, N do
            local loc = locs[i] ---@type stl.view.treeview.ILocationStatus
            if loc.tick_visible ~= tick_visible then
              lnum = lnum + 1
              local loc_indent = child_indent .. (i == last_visible_index and "╰─" or "├─") ---@type string
              local result = render_location(ctx, leafnode, leafstatus, loc)

              lines[lnum] = loc_indent .. result.text
              highlights[lnum] = result.highlights or {}
              indents[lnum] = loc_indent
              lnum2uuid[lnum] = loc.locationuuid
              uuid2lnum[loc.locationuuid] = lnum
              location_lnums[#location_lnums + 1] = lnum

              -- Location's parent is the leaf
              parent_lnum[lnum] = lnum_leaf
            end
          end

          if #location_lnums > 0 then
            childline[lnum_leaf] = location_lnums[#location_lnums]
            firstchild_lnum[lnum_leaf] = location_lnums[1]
            lastchild_lnum[lnum_leaf] = location_lnums[#location_lnums]

            -- Sibling navigation for locations
            for i, loc_lnum in ipairs(location_lnums) do
              if i > 1 then
                prev_sibling_lnum[loc_lnum] = location_lnums[i - 1]
              end
              if i < #location_lnums then
                next_sibling_lnum[loc_lnum] = location_lnums[i + 1]
              end
            end
          end
        end
      end
    end

    return lnum
  end

  -- Build conditional
  ---@type stl.c.ITreeTraverseConditional
  local conditional
  if only_expanded then
    conditional = function(_, node)
      local status = statusmap[node.uuid] ---@type stl.view.treeview.INodeStatus|nil
      if status == nil or status.tick_visible == tick_visible then
        return "badroot"
      end
      if only_matched and status.tick_matched ~= tick_matched then
        return "badroot"
      end
      if only_selected and status.tick_selected_maximum ~= tick_selected then
        return "badroot"
      end
      return status.collapsed and "goodnode" or "goodroot"
    end
  else
    conditional = function(_, node)
      local status = statusmap[node.uuid] ---@type stl.view.treeview.INodeStatus|nil
      if status == nil or status.tick_visible == tick_visible then
        return "badroot"
      end
      if only_matched and status.tick_matched ~= tick_matched then
        return "badroot"
      end
      if only_selected and status.tick_selected_maximum ~= tick_selected then
        return "badroot"
      end
      return "goodroot"
    end
  end

  -- Build traverse handler
  ---@type stl.c.ITreeTraverseHandler
  local traverse
  if foldempty then
    traverse = function(_, node, cur, is_lastchild, onlychild)
      -- Update childline for previous level
      if cur < last_cur then
        for index = cur, last_cur do
          local lnum_root = stack_lnum_roots[index] ---@type integer
          childline[lnum_root] = lnum

          -- Build navigation for children at this level
          local children = stack_children[index]
          if children ~= nil and #children > 0 then
            firstchild_lnum[lnum_root] = children[1]
            lastchild_lnum[lnum_root] = children[#children]
            for i, child_lnum in ipairs(children) do
              parent_lnum[child_lnum] = lnum_root
              if i > 1 then
                prev_sibling_lnum[child_lnum] = children[i - 1]
              end
              if i < #children then
                next_sibling_lnum[child_lnum] = children[i + 1]
              end
            end
          end
        end
      end

      local status = statusmap[node.uuid] ---@type stl.view.treeview.INodeStatus|nil
      if status == nil then
        return
      end

      -- Check if should fold (only child is a container)
      if onlychild ~= nil then
        local onlychild_status = statusmap[onlychild] ---@type stl.view.treeview.INodeStatus|nil
        if onlychild_status ~= nil and onlychild_status.nodetype == "container" then
          process_container(node, status, is_lastchild, cur, true)
          folded_depth = folded_depth + 1
          return
        end
      end

      if status.nodetype == "leaf" then
        folded_depth = 0
        return process_leaf(node, status, is_lastchild, cur)
      end

      if status.nodetype == "container" then
        local result = process_container(node, status, is_lastchild, cur, false)
        folded_depth = 0
        return result
      end
    end
  else
    traverse = function(_, node, cur, is_lastchild)
      -- Update childline for previous level
      if cur < last_cur then
        for index = cur, last_cur do
          local lnum_root = stack_lnum_roots[index] ---@type integer
          childline[lnum_root] = lnum

          -- Build navigation for children at this level
          local children = stack_children[index]
          if children ~= nil and #children > 0 then
            firstchild_lnum[lnum_root] = children[1]
            lastchild_lnum[lnum_root] = children[#children]
            for i, child_lnum in ipairs(children) do
              parent_lnum[child_lnum] = lnum_root
              if i > 1 then
                prev_sibling_lnum[child_lnum] = children[i - 1]
              end
              if i < #children then
                next_sibling_lnum[child_lnum] = children[i + 1]
              end
            end
          end
        end
      end

      local status = statusmap[node.uuid] ---@type stl.view.treeview.INodeStatus|nil
      if status == nil then
        return
      end

      if status.nodetype == "leaf" then
        return process_leaf(node, status, is_lastchild, cur)
      end

      if status.nodetype == "container" then
        return process_container(node, status, is_lastchild, cur, false)
      end
    end
  end

  -- Execute traverse
  tree:traverse(root, traverse, conditional)

  -- Finalize childline and navigation for remaining levels
  for index = 1, last_cur do
    local lnum_root = stack_lnum_roots[index] ---@type integer
    if lnum_root ~= nil then
      childline[lnum_root] = lnum

      local children = stack_children[index]
      if children ~= nil and #children > 0 then
        firstchild_lnum[lnum_root] = children[1]
        lastchild_lnum[lnum_root] = children[#children]
        for i, child_lnum in ipairs(children) do
          parent_lnum[child_lnum] = lnum_root
          if i > 1 then
            prev_sibling_lnum[child_lnum] = children[i - 1]
          end
          if i < #children then
            next_sibling_lnum[child_lnum] = children[i + 1]
          end
        end
      end
    end
  end

  ---@type stl.view.treeview.INavigation
  local navigation = {
    parent_lnum = parent_lnum,
    firstchild_lnum = firstchild_lnum,
    lastchild_lnum = lastchild_lnum,
    prev_sibling_lnum = prev_sibling_lnum,
    next_sibling_lnum = next_sibling_lnum,
  }

  ---@type stl.view.treeview.IRenderResult
  return {
    lines = lines,
    highlights = highlights,
    indents = indents,
    lnum2uuid = lnum2uuid,
    uuid2lnum = uuid2lnum,
    childline = childline,
    navigation = navigation,
  }
end

----------------------------------------------------------------------------------------------------
-- Navigation Helpers
----------------------------------------------------------------------------------------------------

---@param navigation                    stl.view.treeview.INavigation
---@param lnum                          integer
---@return integer|nil
function M.nav_parent(navigation, lnum)
  return navigation.parent_lnum[lnum]
end

---@param navigation                    stl.view.treeview.INavigation
---@param lnum                          integer
---@return integer|nil
function M.nav_firstchild(navigation, lnum)
  return navigation.firstchild_lnum[lnum]
end

---@param navigation                    stl.view.treeview.INavigation
---@param lnum                          integer
---@return integer|nil
function M.nav_lastchild(navigation, lnum)
  return navigation.lastchild_lnum[lnum]
end

---@param navigation                    stl.view.treeview.INavigation
---@param lnum                          integer
---@return integer|nil
function M.nav_prev_sibling(navigation, lnum)
  return navigation.prev_sibling_lnum[lnum]
end

---@param navigation                    stl.view.treeview.INavigation
---@param lnum                          integer
---@return integer|nil
function M.nav_next_sibling(navigation, lnum)
  return navigation.next_sibling_lnum[lnum]
end

----------------------------------------------------------------------------------------------------
-- Collection Helpers
----------------------------------------------------------------------------------------------------

---@param root                          string|nil
---@return string[]
function M:collect_leafs(root)
  self:__health__()

  local statusmap = self._statusmap ---@type table<string, stl.view.treeview.INodeStatus|stl.view.treeview.ILocationStatus>
  local uuids = {} ---@type string[]

  self._tree:quick_traverse(root or self._root, function(_, node)
    local status = statusmap[node.uuid] ---@type stl.view.treeview.INodeStatus|nil
    if status ~= nil and status.nodetype == "leaf" then
      uuids[#uuids + 1] = node.uuid
    end
  end)
  return uuids
end

---@param root                          string|nil
---@return table<string, true>
function M:collect_selected(root)
  self:__health__()

  local statusmap = self._statusmap ---@type table<string, stl.view.treeview.INodeStatus|stl.view.treeview.ILocationStatus>
  local tick_selected = self._tick_selected ---@type integer
  local selected_set = {} ---@type table<string, true>

  self._tree:quick_traverse(root or self._root, function(_, node)
    local status = statusmap[node.uuid] ---@type stl.view.treeview.INodeStatus|nil
    if status ~= nil and status.tick_selected == tick_selected then
      selected_set[node.uuid] = true
    end
  end)
  return selected_set
end

---@param root                          string|nil
---@return string[]
function M:collect_matched(root)
  self:__health__()

  local statusmap = self._statusmap ---@type table<string, stl.view.treeview.INodeStatus|stl.view.treeview.ILocationStatus>
  local tick_matched = self._tick_matched ---@type integer
  local uuids = {} ---@type string[]

  self._tree:quick_traverse(root or self._root, function(_, node)
    local status = statusmap[node.uuid] ---@type stl.view.treeview.INodeStatus|nil
    if status ~= nil and status.tick_matched == tick_matched then
      uuids[#uuids + 1] = node.uuid
    end
  end)
  return uuids
end

---@param root                          string|nil
---@return string[]
function M:collect_visible(root)
  self:__health__()

  local statusmap = self._statusmap ---@type table<string, stl.view.treeview.INodeStatus|stl.view.treeview.ILocationStatus>
  local tick_visible = self._tick_visible ---@type integer
  local uuids = {} ---@type string[]

  self._tree:quick_traverse(root or self._root, function(_, node)
    local status = statusmap[node.uuid] ---@type stl.view.treeview.INodeStatus|nil
    if status ~= nil and status.tick_visible ~= tick_visible then
      uuids[#uuids + 1] = node.uuid
    end
  end)
  return uuids
end

----------------------------------------------------------------------------------------------------
-- Internal
----------------------------------------------------------------------------------------------------

---@private
---@return stl.view.treeview.IRenderResult
function M.__empty_render_result__()
  ---@type stl.view.treeview.IRenderResult
  return {
    lines = {},
    highlights = {},
    indents = {},
    lnum2uuid = {},
    uuid2lnum = {},
    childline = {},
    navigation = {
      parent_lnum = {},
      firstchild_lnum = {},
      lastchild_lnum = {},
      prev_sibling_lnum = {},
      next_sibling_lnum = {},
    },
  }
end

---@protected
---@return nil
function M:__health__()
  if self._disposed then
    local message = string.format("%s has been disposed.", self.fullname) ---@type string
    error(message)
  end
end

return M
