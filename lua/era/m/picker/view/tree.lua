---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.picker.view.tree" ---@type string

---@alias era.m.picker.view.tree.INodeState
---| era.m.picker.view.tree.IContainerNodeState
---| era.m.picker.view.tree.ILeafNodeState
---| era.m.picker.view.tree.ILeafLocationState

---@alias era.m.picker.view.tree.IListviewLeafNodeRenderer
---| fun(ctx: era.m.picker.view.tree.IListviewRendererContext, node: stl.c.ITreeNode, nodestate: era.m.picker.view.tree.ILeafNodeState, lnum: integer): era.view.tree.INodeRenderResult

---@alias era.m.picker.view.tree.IListviewLeafLocationRenderer
---| fun(ctx: era.m.picker.view.tree.IListviewRendererContext, node: stl.c.ITreeNode, nodestate: era.m.picker.view.tree.ILeafNodeState, location: era.m.picker.view.tree.ILeafLocationState, lnum: integer): era.view.tree.INodeRenderResult

---@alias era.m.picker.view.tree.ITreeviewContainerNodeRenderer
---| fun(ctx: era.m.picker.view.tree.ITreeviewRendererContext, node: stl.c.ITreeNode, nodestate: era.m.picker.view.tree.IContainerNodeState, lnum: integer, folded_depth: integer): era.view.tree.INodeRenderResult

---@alias era.m.picker.view.tree.ITreeviewLeafNodeRenderer
---| fun(ctx: era.m.picker.view.tree.ITreeviewRendererContext, node: stl.c.ITreeNode, nodestate: era.m.picker.view.tree.ILeafNodeState, lnum: integer): era.view.tree.INodeRenderResult

---@alias era.m.picker.view.tree.ITreeviewLeafLocationRenderer
---| fun(ctx: era.m.picker.view.tree.ITreeviewRendererContext, node: stl.c.ITreeNode, nodestate: era.m.picker.view.tree.ILeafNodeState, location: era.m.picker.view.tree.ILeafLocationState, lnum: integer): era.view.tree.INodeRenderResult

---@class era.m.picker.view.tree.IContainerNodeState : era.view.tree.IContainerNodeState

---@class era.m.picker.view.tree.ILeafNodeState : era.view.tree.ILeafNodeState
---@field public text                   string|nil
---@field public text_lower             string|nil
---@field public cache_match            era.m.picker.view.tree.INodeMatchResultCache|nil

---@class era.m.picker.view.tree.ILeafLocationState : era.view.tree.ILeafLocationState

---@class era.m.picker.view.tree.IListviewRendererContext : era.view.tree.IListviewRendererContext
---@field public rootnode               stl.c.ITreeNode
---@field public rootstate              era.m.picker.view.tree.IContainerNodeState
---@field public tree                   stl.c.IReadonlyTree
---@field public view                   era.m.picker.TreeView

---@class era.m.picker.view.tree.ITreeviewRendererContext : era.view.tree.ITreeviewRendererContext
---@field public rootnode               stl.c.ITreeNode
---@field public rootstate              era.m.picker.view.tree.IContainerNodeState
---@field public tree                   stl.c.IReadonlyTree
---@field public view                   era.m.picker.TreeView

---@class era.m.picker.view.tree.INodeMatchContext
---@field public rootuuid               string
---@field public pattern                string
---@field public case_sensitive         boolean
---@field public fuzzy                  boolean
---@field public regex                  boolean

---@class era.m.picker.view.tree.INodeMatchResult
---@field public context                era.m.picker.view.tree.INodeMatchContext
---@field public uuids                  string[]

---@class era.m.picker.view.tree.INodeMatchResultCache
---@field public score                  integer
---@field public matches                dot.t.IMatchPoint[]

---@class era.m.picker.view.tree.IMatchParams
---@field public rootuuid               string|nil
---@field public pattern                string
---@field public case_sensitive         boolean
---@field public fuzzy                  boolean
---@field public regex                  boolean

----------------------------------------------------------------------------------------------------

---@class era.m.picker.view.ITreeProps
---@field public name                   string
---@field public indent                 ?string
---@field public indent_hln             ?string
---@field public tree                   stl.c.IReadonlyTree
---@field public render_listview_leaf   era.m.picker.view.tree.IListviewLeafNodeRenderer
---@field public render_listview_location   era.m.picker.view.tree.IListviewLeafLocationRenderer
---@field public render_treeview_container  era.m.picker.view.tree.ITreeviewContainerNodeRenderer
---@field public render_treeview_leaf   era.m.picker.view.tree.ITreeviewLeafNodeRenderer
---@field public render_treeview_location   era.m.picker.view.tree.ITreeviewLeafLocationRenderer

local P = era.view.Tree ---@type era.view.Tree

---@class era.m.picker.TreeView : era.view.Tree
---@field protected _last_match_result  era.m.picker.view.tree.INodeMatchResult
local M = {}
M.__index = M
setmetatable(M, P)

---@param props                         era.m.picker.view.ITreeProps
---@return era.m.picker.TreeView
function M.new(props)
  local name = props.name ---@type string
  local fullname = string.format("%s -> %s", name, __module_name__) ---@type string
  local indent = props.indent ---@type string|nil
  local indent_hln = props.indent_hln ---@type string|nil
  local tree = props.tree ---@type stl.c.IReadonlyTree
  local render_listview_leaf = props.render_listview_leaf ---@type era.m.picker.view.tree.IListviewLeafNodeRenderer
  local render_listview_location = props.render_listview_location ---@type era.m.picker.view.tree.IListviewLeafLocationRenderer
  local render_treeview_container = props.render_treeview_container ---@type era.m.picker.view.tree.ITreeviewContainerNodeRenderer
  local render_treeview_leaf = props.render_treeview_leaf ---@type era.m.picker.view.tree.ITreeviewLeafNodeRenderer
  local render_treeview_location = props.render_treeview_location ---@type era.m.picker.view.tree.ITreeviewLeafLocationRenderer

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
  ---@cast self                         era.m.picker.TreeView

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

---@return era.m.picker.TreeView
function M:mark_cache_match_dirty()
  self:__health__()
  self._last_match_result = nil ---@type era.m.picker.view.tree.INodeMatchResult|nil
  return self
end

---@param uuid                          string
---@return era.m.picker.view.tree.INodeState|nil
function M:retrieve(uuid)
  self:__health__()

  local statemap = self.statemap ---@type table<string, era.view.tree.INodeState>
  ---@cast statemap                     table<string, era.m.picker.view.tree.INodeState>

  local nodestate = statemap[uuid] ---@type era.m.picker.view.tree.INodeState|nil
  return nodestate
end

----------------------------------------------------------------------------------------------------

---@param params                        era.m.picker.view.tree.IMatchParams
---@return string[]
function M:match(params)
  self:__health__()

  local tree = self._tree ---@type stl.c.IReadonlyTree
  local statemap = self.statemap ---@type table<string, era.view.tree.INodeState>
  ---@cast statemap                     table<string, era.m.picker.view.tree.INodeState>

  local root = params.rootuuid or tree.root ---@type string
  local case_sensitive = params.case_sensitive ---@type boolean
  local fuzzy = params.fuzzy ---@type boolean
  local regex = params.regex ---@type boolean
  local pattern = case_sensitive and params.pattern or params.pattern:lower() ---@type string

  ---@type era.m.picker.view.tree.INodeMatchContext
  local context = {
    rootuuid = root,
    pattern = pattern,
    case_sensitive = case_sensitive,
    fuzzy = fuzzy,
    regex = regex,
  }

  local last_match_result = self._last_match_result ---@type era.m.picker.view.tree.INodeMatchResult|nil
  local last_match_context = last_match_result and last_match_result.context or nil ---@type era.m.picker.view.tree.INodeMatchContext|nil
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

    ---@type stl.c.ITreeQuickTraverseHandler
    local collect = function(_, node)
      local state = statemap[node.uuid]
      if state.text ~= nil then
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
      state.cache_match = { score = line_match.score, matches = matches } ---@type era.m.picker.view.tree.INodeMatchResultCache
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
    local o = tree:retrieve(uuid)
    ---@cast o                          stl.c.ITreeNode

    for _ = o.depth - 1, 1, -1 do
      o = tree:retrieve(o.parent)
      ---@cast o                        stl.c.ITreeNode

      local s = statemap[o.uuid]
      if s.tick_matched == tick_matched then
        break
      end

      s.tick_matched = tick_matched
    end
  end

  ---@type era.m.picker.view.tree.INodeMatchResult
  local match_result = {
    context = context,
    uuids = uuids,
  }
  self._last_match_result = match_result
  self._tick_matched = tick_matched
  return uuids
end

---@param params                        era.view.tree.IRenderListviewParams
---@return era.view.tree.IRenderResult
function M:render_listview(params)
  self:__health__()

  local bufnr = params.bufnr ---@type integer
  local only_matched = params.only_matched ---@type boolean
  local result = P.render_listview(self, params)

  if not only_matched then
    return result
  end

  local nsnr = dot.var.nsnr.picker_matches ---@type integer
  local uuids = result.lnum2uuid ---@type string[]
  local N = #uuids ---@type integer

  vim.api.nvim_buf_clear_namespace(bufnr, nsnr, 0, -1)

  if N < 1 then
    return result
  end

  local tree = self._tree ---@type stl.c.IReadonlyTree
  local indents = result.indents ---@type string[]
  local tick_matched = self._tick_matched ---@type integer
  local statemap = self.statemap ---@type table<string, era.view.tree.INodeState>
  ---@cast statemap                     table<string, era.m.picker.view.tree.INodeState>

  for lnum = 1, N, 1 do
    local uuid = uuids[lnum] ---@type string
    local nodestate = statemap[uuid] ---@type era.m.picker.view.tree.INodeState|nil
    if nodestate ~= nil and nodestate.tick_matched == tick_matched and nodestate.cache_match ~= nil then
      local node = tree:retrieve(uuid) ---@type stl.c.ITreeNode|nil
      if node ~= nil then
        local row = lnum - 1 ---@type integer
        local text = nodestate.text or "" ---@type string
        local L = #text ---@type integer
        local cache = nodestate.cache_listview ---@type era.view.tree.INodeListviewResultCache|nil
        local rendered_text = cache and cache.text or "" ---@type string
        local offset_final = #indents[lnum] + #rendered_text - L ---@type integer

        local matches = nodestate.cache_match.matches ---@type dot.t.IMatchPoint[]
        for _, m in ipairs(matches) do
          local l = m.l ---@type integer
          local r = m.r ---@type integer
          if r > 0 and l < L then
            l = l < 0 and 0 or l ---@type integer
            r = r < L and r or L ---@type integer
            vim.hl.range(bufnr, nsnr, "m_pk_matches", { row, offset_final + l }, { row, offset_final + r })
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

  local bufnr = params.bufnr ---@type integer
  local only_matched = params.only_matched ---@type boolean
  local result = P.render_treeview(self, params)

  if not only_matched then
    return result
  end

  local nsnr = dot.var.nsnr.picker_matches ---@type integer
  local uuids = result.lnum2uuid ---@type string[]
  local N = #uuids ---@type integer

  vim.api.nvim_buf_clear_namespace(bufnr, nsnr, 0, -1)

  if N < 1 then
    return result
  end

  local tree = self._tree ---@type stl.c.IReadonlyTree
  local indents = result.indents ---@type string[]
  local tick_matched = self._tick_matched ---@type integer
  local statemap = self.statemap ---@type table<string, era.view.tree.INodeState>
  ---@cast statemap                     table<string, era.m.picker.view.tree.INodeState>

  for lnum = 1, N, 1 do
    local uuid = uuids[lnum] ---@type string
    local nodestate = statemap[uuid] ---@type era.m.picker.view.tree.INodeState|nil
    if nodestate ~= nil and nodestate.tick_matched == tick_matched and nodestate.cache_match ~= nil then
      local node = tree:retrieve(uuid) ---@type stl.c.ITreeNode|nil
      if node ~= nil then
        local row = lnum - 1 ---@type integer
        local text = nodestate.text or "" ---@type string
        local L = #text ---@type integer
        local cache = nodestate.cache_treeview ---@type era.view.tree.INodeTreeviewResultCache|nil
        local rendered_text = cache and cache.text or "" ---@type string
        local offset_final = #indents[lnum] + #rendered_text - L ---@type integer

        local matches = nodestate.cache_match.matches ---@type dot.t.IMatchPoint[]
        for _, m in ipairs(matches) do
          local l = m.l ---@type integer
          local r = m.r ---@type integer
          if r > 0 and l < L then
            l = l < 0 and 0 or l ---@type integer
            r = r < L and r or L ---@type integer
            vim.hl.range(bufnr, nsnr, "m_pk_matches", { row, offset_final + l }, { row, offset_final + r })
          end
        end
      end
    end
  end

  return result
end

return M
