---@diagnostic disable: invisible
local __module_name__ = "eve.ux.picker.view.tree" ---@type string

---@alias eve.ux.picker.view.tree.INodeState
---| eve.ux.picker.view.tree.IContainerNodeState
---| eve.ux.picker.view.tree.ILeafNodeState
---| eve.ux.picker.view.tree.ILeafLocationState

---@alias eve.ux.picker.view.tree.IListviewLeafNodeRenderer
---| fun(ctx: eve.ux.picker.view.tree.IListviewRendererContext, node: std.collection.tree.INode, nodestate: eve.ux.picker.view.tree.ILeafNodeState, lnum: integer): eve.ux.view.tree.INodeRenderResult

---@alias eve.ux.picker.view.tree.IListviewLeafLocationRenderer
---| fun(ctx: eve.ux.picker.view.tree.IListviewRendererContext, node: std.collection.tree.INode, nodestate: eve.ux.picker.view.tree.ILeafNodeState, location: eve.ux.picker.view.tree.ILeafLocationState, lnum: integer): eve.ux.view.tree.INodeRenderResult

---@alias eve.ux.picker.view.tree.ITreeviewContainerNodeRenderer
---| fun(ctx: eve.ux.picker.view.tree.ITreeviewRendererContext, node: std.collection.tree.INode, nodestate: eve.ux.picker.view.tree.IContainerNodeState, lnum: integer, folded_depth: integer): eve.ux.view.tree.INodeRenderResult

---@alias eve.ux.picker.view.tree.ITreeviewLeafNodeRenderer
---| fun(ctx: eve.ux.picker.view.tree.ITreeviewRendererContext, node: std.collection.tree.INode, nodestate: eve.ux.picker.view.tree.ILeafNodeState, lnum: integer): eve.ux.view.tree.INodeRenderResult

---@alias eve.ux.picker.view.tree.ITreeviewLeafLocationRenderer
---| fun(ctx: eve.ux.picker.view.tree.ITreeviewRendererContext, node: std.collection.tree.INode, nodestate: eve.ux.picker.view.tree.ILeafNodeState, location: eve.ux.picker.view.tree.ILeafLocationState, lnum: integer): eve.ux.view.tree.INodeRenderResult

---@class eve.ux.picker.view.tree.IContainerNodeState : eve.ux.view.tree.IContainerNodeState

---@class eve.ux.picker.view.tree.ILeafNodeState : eve.ux.view.tree.ILeafNodeState
---@field public text                   string|nil
---@field public text_lower             string|nil
---@field public cache_match            eve.ux.picker.view.tree.INodeMatchResultCache|nil

---@class eve.ux.picker.view.tree.ILeafLocationState : eve.ux.view.tree.ILeafLocationState

---@class eve.ux.picker.view.tree.IListviewRendererContext : eve.ux.view.tree.IListviewRendererContext
---@field public rootnode               std.collection.tree.INode
---@field public rootstate              eve.ux.picker.view.tree.IContainerNodeState
---@field public tree                   std.collection.IReadonlyTree
---@field public view                   eve.ux.picker.TreeView

---@class eve.ux.picker.view.tree.ITreeviewRendererContext : eve.ux.view.tree.ITreeviewRendererContext
---@field public rootnode               std.collection.tree.INode
---@field public rootstate              eve.ux.picker.view.tree.IContainerNodeState
---@field public tree                   std.collection.IReadonlyTree
---@field public view                   eve.ux.picker.TreeView

---@class eve.ux.picker.view.tree.INodeMatchContext
---@field public rootuuid               string
---@field public pattern                string
---@field public case_sensitive         boolean
---@field public fuzzy                  boolean
---@field public regex                  boolean

---@class eve.ux.picker.view.tree.INodeMatchResult
---@field public context                eve.ux.picker.view.tree.INodeMatchContext
---@field public uuids                  string[]

---@class eve.ux.picker.view.tree.INodeMatchResultCache
---@field public score                  integer
---@field public matches                std.t.IMatchPoint[]

---@class eve.ux.picker.view.tree.IMatchParams
---@field public rootuuid               string|nil
---@field public pattern                string
---@field public case_sensitive         boolean
---@field public fuzzy                  boolean
---@field public regex                  boolean

----------------------------------------------------------------------------------------------------

---@class eve.ux.picker.view.ITreeProps
---@field public name                   string
---@field public indent                 ?string
---@field public indent_hln             ?string
---@field public tree                   std.collection.IReadonlyTree
---@field public render_listview_leaf       eve.ux.picker.view.tree.IListviewLeafNodeRenderer
---@field public render_listview_location   eve.ux.picker.view.tree.IListviewLeafLocationRenderer
---@field public render_treeview_container  eve.ux.picker.view.tree.ITreeviewContainerNodeRenderer
---@field public render_treeview_leaf       eve.ux.picker.view.tree.ITreeviewLeafNodeRenderer
---@field public render_treeview_location   eve.ux.picker.view.tree.ITreeviewLeafLocationRenderer

local P = eve.ux.view.Tree ---@type eve.ux.view.Tree

---@class eve.ux.picker.TreeView : eve.ux.view.Tree
---@field protected _last_match_result    eve.ux.picker.view.tree.INodeMatchResult
local M = {}
M.__index = M
setmetatable(M, P)

---@param props                         eve.ux.picker.view.ITreeProps
---@return eve.ux.picker.TreeView
function M.new(props)
  local name = props.name ---@type string
  local fullname = string.format("%s -> %s", name, __module_name__) ---@type string
  local indent = props.indent ---@type string|nil
  local indent_hln = props.indent_hln ---@type string|nil
  local tree = props.tree ---@type std.collection.IReadonlyTree
  local render_listview_leaf = props.render_listview_leaf ---@type eve.ux.picker.view.tree.IListviewLeafNodeRenderer
  local render_listview_location = props.render_listview_location ---@type eve.ux.picker.view.tree.IListviewLeafLocationRenderer
  local render_treeview_container = props.render_treeview_container ---@type eve.ux.picker.view.tree.ITreeviewContainerNodeRenderer
  local render_treeview_leaf = props.render_treeview_leaf ---@type eve.ux.picker.view.tree.ITreeviewLeafNodeRenderer
  local render_treeview_location = props.render_treeview_location ---@type eve.ux.picker.view.tree.ITreeviewLeafLocationRenderer

  local super = P.new({
    name = fullname,
    indent = indent,
    indent_hln = indent_hln,
    tree = tree,
    render_listview_leaf = render_listview_leaf,
    render_listview_location = render_listview_location,
    render_treeview_container = render_treeview_container,
    render_treeview_leaf = render_treeview_leaf,
    render_treeview_location = render_treeview_location,
  })

  local self = setmetatable(super, M)
  ---@cast self                         eve.ux.picker.TreeView

  self._last_match_result = nil
  return self
end

---@return nil
function M:clear()
  self:__health__()

  P.clear(self)
  self._last_match_result = nil
end

---@return nil
function M:dispose()
  if self._disposed then
    return nil
  end

  P.dispose(self)
  self._last_match_result = nil
end

---@return eve.ux.picker.TreeView
function M:mark_cache_match_dirty()
  self:__health__()
  self._last_match_result = nil ---@type eve.ux.picker.view.tree.INodeMatchResult|nil
  return self
end

---@param uuid                          string
---@return eve.ux.picker.view.tree.INodeState|nil
function M:retrieve(uuid)
  self:__health__()

  local statemap = self.statemap ---@type table<string, eve.ux.view.tree.INodeState>
  ---@cast statemap                     table<string, eve.ux.picker.view.tree.INodeState>

  local nodestate = statemap[uuid] ---@type eve.ux.picker.view.tree.INodeState|nil
  return nodestate
end

----------------------------------------------------------------------------------------------------

---@param params                        eve.ux.picker.view.tree.IMatchParams
---@return string[]
function M:match(params)
  self:__health__()

  local tree = self._tree ---@type std.collection.IReadonlyTree
  local statemap = self.statemap ---@type table<string, eve.ux.view.tree.INodeState>
  ---@cast statemap                     table<string, eve.ux.picker.view.tree.INodeState>

  local root = params.rootuuid or tree.root ---@type string
  local case_sensitive = params.case_sensitive ---@type boolean
  local fuzzy = params.fuzzy ---@type boolean
  local regex = params.regex ---@type boolean
  local pattern = case_sensitive and params.pattern or params.pattern:lower() ---@type string

  ---@type eve.ux.picker.view.tree.INodeMatchContext
  local context = {
    rootuuid = root,
    pattern = pattern,
    case_sensitive = case_sensitive,
    fuzzy = fuzzy,
    regex = regex,
  }

  local last_match_result = self._last_match_result ---@type eve.ux.picker.view.tree.INodeMatchResult|nil
  local last_match_context = last_match_result and last_match_result.context or nil ---@type eve.ux.picker.view.tree.INodeMatchContext|nil
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
    and std.string.starts_with(pattern, last_match_context.pattern)
  )

  local uuids ---@type string[]
  if is_limit_in_last_matched then
    uuids = last_matched_uuids and vim.list_slice(last_matched_uuids) or {} ---@type string[]
  else
    local k = 0 ---@type integer
    uuids = {} ---@type string[]

    ---@type std.collection.tree.IQuickTraverseHandler
    local collect = function(_, node)
      local state = statemap[node.uuid]
      if state.nodetype == "leaf" then
        k = k + 1
        uuids[k] = node.uuid
      end
    end
    tree:quick_traverse(root, collect)
  end

  local lines = {} ---@type string[]
  if case_sensitive then
    for index, uuid in ipairs(uuids) do
      local state = statemap[uuid]
      lines[index] = state.text ---@type string
    end
  else
    for index, uuid in ipairs(uuids) do
      local state = statemap[uuid]
      lines[index] = state.text_lower ---@type string
    end
  end

  local oxi_matches = oxi.searcher.search_in_lines(pattern, lines, fuzzy, regex) ---@type oxi.string.ILineMatch[]|nil
  if oxi_matches ~= nil then
    for _, oxi_match in ipairs(oxi_matches) do
      local lnum = oxi_match.lnum ---@type integer
      local uuid = uuids[lnum] ---@type string
      local matches = oxi_match.matches ---@type std.t.IMatchPoint[]
      local state = statemap[uuid]
      state.tick_matched = tick_matched ---@type integer
      state.cache_match = { score = oxi_match.score, matches = matches } ---@type eve.ux.picker.view.tree.INodeMatchResultCache
    end

    local N = #oxi_matches ---@type integer
    if N < #uuids then
      for index = 1, N, 1 do
        local oxi_match = oxi_matches[index] ---@type oxi.string.ILineMatch
        local lnum = oxi_match.lnum ---@type integer
        uuids[index] = uuids[lnum] ---@type string
      end
      std.table.truncate_inline(uuids, N)
    end
  end

  for _, uuid in ipairs(uuids) do
    local o = tree:retrieve(uuid)
    ---@cast o                          std.collection.tree.INode

    for _ = o.depth - 1, 1, -1 do
      o = tree:retrieve(o.parent)
      ---@cast o                        std.collection.tree.INode

      local s = statemap[o.uuid]
      if s.tick_matched == tick_matched then
        break
      end

      s.tick_matched = tick_matched
    end
  end

  ---@type eve.ux.picker.view.tree.INodeMatchResult
  local match_result = {
    context = context,
    uuids = uuids,
  }
  self._last_match_result = match_result
  self._tick_matched = tick_matched
  return uuids
end

return M
