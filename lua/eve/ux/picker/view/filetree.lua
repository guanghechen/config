---@diagnostic disable: invisible
local __module_name__ = "eve.ux.picker.view.filetree" ---@type string

---@alias eve.ux.picker.view.filetree.INodeState
---| eve.ux.picker.view.filetree.IDirectoryNodeState
---| eve.ux.picker.view.filetree.IFileNodeState
---| eve.ux.picker.view.filetree.ILocationNodeState

---@alias eve.ux.picker.view.filetree.IListviewFileRenderer
---| fun(ctx: eve.ux.picker.view.filetree.IListviewRendererContext, node: std.collection.filetree.INode, nodestate: eve.ux.picker.view.filetree.IFileNodeState, lnum: integer): eve.ux.view.tree.INodeRenderResult

---@alias eve.ux.picker.view.filetree.IListviewLocationRenderer
---| fun(ctx: eve.ux.picker.view.filetree.IListviewRendererContext, node: std.collection.filetree.INode, nodestate: eve.ux.picker.view.filetree.IFileNodeState, locationstate: eve.ux.picker.view.filetree.ILocationNodeState, lnum: integer): eve.ux.view.tree.INodeRenderResult

---@alias eve.ux.picker.view.filetree.ITreeviewDirectoryRenderer
---| fun(ctx: eve.ux.picker.view.filetree.ITreeviewRendererContext, node: std.collection.filetree.INode, nodestate: eve.ux.picker.view.filetree.IDirectoryNodeState, lnum: integer, folded_depth: integer): eve.ux.view.tree.INodeRenderResult

---@alias eve.ux.picker.view.filetree.ITreeviewFileRenderer
---| fun(ctx: eve.ux.picker.view.filetree.ITreeviewRendererContext, node: std.collection.filetree.INode, nodestate: eve.ux.picker.view.filetree.IFileNodeState, lnum: integer): eve.ux.view.tree.INodeRenderResult

---@alias eve.ux.picker.view.filetree.ITreeviewLocationRenderer
---| fun(ctx: eve.ux.picker.view.filetree.ITreeviewRendererContext, node: std.collection.filetree.INode, nodestate: eve.ux.picker.view.filetree.IFileNodeState, locationstate: eve.ux.picker.view.filetree.ILocationNodeState, lnum: integer): eve.ux.view.tree.INodeRenderResult

---@class eve.ux.picker.view.filetree.IDirectoryNodeState : eve.ux.view.tree.IContainerNodeState

---@class eve.ux.picker.view.filetree.IFileNodeState : eve.ux.view.tree.ILeafNodeState
---@field public locations              eve.ux.picker.view.filetree.ILocationNodeState|nil
---@field public cache_match            eve.ux.picker.view.filetree.INodeMatchResultCache|nil

---@class eve.ux.picker.view.filetree.ILocationNodeState : eve.ux.view.tree.ILeafLocationState
---@field public lnum                   integer
---@field public col                    ?integer
---@field public col_end                ?integer
---@field public text                   ?string
---@field public highlights             ?std.t.IHighlightInline[]

---@class eve.ux.picker.view.filetree.IListviewRendererContext : eve.ux.view.tree.IListviewRendererContext
---@field public rootnode               std.collection.filetree.INode
---@field public rootstate              eve.ux.picker.view.filetree.IDirectoryNodeState
---@field public tree                   std.collection.IReadonlyFiletree
---@field public view                   eve.ux.picker.FiletreeView

---@class eve.ux.picker.view.filetree.ITreeviewRendererContext : eve.ux.view.tree.IListviewRendererContext
---@field public rootnode               std.collection.filetree.INode
---@field public rootstate              eve.ux.picker.view.filetree.IDirectoryNodeState
---@field public tree                   std.collection.IReadonlyFiletree
---@field public view                   eve.ux.picker.FiletreeView

---@class eve.ux.picker.view.filetree.INodeMatchContext
---@field public rootuuid               string
---@field public pattern                string
---@field public case_sensitive         boolean
---@field public fuzzy                  boolean
---@field public regex                  boolean

---@class eve.ux.picker.view.filetree.INodeMatchResult
---@field public context                eve.ux.picker.view.filetree.INodeMatchContext
---@field public uuids                  string[]

---@class eve.ux.picker.view.filetree.INodeMatchResultCache
---@field public score                  integer
---@field public matches                std.t.IMatchPoint[]

---@class eve.ux.picker.view.filetree.IMatchParams
---@field public rootuuid               string|nil
---@field public pattern                string
---@field public case_sensitive         boolean
---@field public fuzzy                  boolean
---@field public regex                  boolean

----------------------------------------------------------------------------------------------------

local DEFAULT_NSNR_MATCHES = eve.var.nsnr.view_filetree_matches ---@type integer

---@class eve.ux.picker.view.IFiletreeProps
---@field public name                   string
---@field public tree                   std.collection.IFiletree
---@field public indent                 ?string
---@field public indent_hln             ?string
---
---@field public render_listview_leaf       ?eve.ux.picker.view.filetree.IListviewFileRenderer
---@field public render_listview_location   ?eve.ux.picker.view.filetree.IListviewLocationRenderer
---@field public render_treeview_container  ?eve.ux.picker.view.filetree.ITreeviewDirectoryRenderer
---@field public render_treeview_leaf       ?eve.ux.picker.view.filetree.ITreeviewFileRenderer
---@field public render_treeview_location   ?eve.ux.picker.view.filetree.ITreeviewLocationRenderer

local P = eve.ux.view.Tree ---@type eve.ux.view.Tree

---@class eve.ux.picker.FiletreeView : eve.ux.view.Tree
---@field protected _tree               std.collection.IFiletree
---@field protected _last_match_result  eve.ux.picker.view.filetree.INodeMatchResult
---@field public insert                 fun(self: eve.ux.picker.FiletreeView, uuid: string, state: eve.ux.view.tree.INodeState): eve.ux.picker.FiletreeView
local M = {}
M.__index = M
setmetatable(M, P)

---@param props                         eve.ux.picker.view.IFiletreeProps
---@return eve.ux.picker.FiletreeView
function M.new(props)
  local name = props.name ---@type string
  local fullname = string.format("%s -> %s", name, __module_name__) ---@type string
  local indent = props.indent ---@type string|nil
  local indent_hln = props.indent_hln ---@type string|nil
  local tree = props.tree ---@type std.collection.IFiletree

  local render_listview_leaf = props.render_listview_leaf or M.default_render_listview_leaf ---@type eve.ux.picker.view.filetree.IListviewFileRenderer
  local render_listview_location = props.render_listview_location or M.default_render_listview_location ---@type eve.ux.picker.view.filetree.IListviewLocationRenderer
  local render_treeview_container = props.render_treeview_container or M.default_render_treeview_container ---@type eve.ux.picker.view.filetree.ITreeviewDirectoryRenderer
  local render_treeview_leaf = props.render_treeview_leaf or M.default_render_treeview_leaf ---@type eve.ux.picker.view.filetree.ITreeviewFileRenderer
  local render_treeview_location = props.render_treeview_location or M.default_render_treeview_location ---@type eve.ux.picker.view.filetree.ITreeviewLocationRenderer

  local super = eve.ux.view.Tree.new({
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
  })

  local self = setmetatable(super, M)
  ---@cast self                         eve.ux.picker.FiletreeView

  self._last_match_result = nil
  return self
end

----------------------------------------------------------------------------------------------------

---@return eve.ux.picker.FiletreeView
function M:clear()
  self:__health__()

  P.clear(self)
  self._last_match_result = nil
  return self
end

---@return nil
function M:dispose()
  if self._disposed then
    return nil
  end

  P.dispose(self)
  self._last_match_result = nil
end

---@return eve.ux.picker.FiletreeView
function M:mark_cache_match_dirty()
  self:__health__()
  self._last_match_result = nil ---@type eve.ux.picker.view.filetree.INodeMatchResult|nil
  return self
end

---@param uuid                          string
---@return eve.ux.picker.view.filetree.INodeState|nil
function M:retrieve(uuid)
  self:__health__()

  local statemap = self.statemap ---@type table<string, eve.ux.view.tree.INodeState>
  ---@cast statemap                     table<string, eve.ux.picker.view.filetree.INodeState>

  local nodestate = statemap[uuid] ---@type eve.ux.picker.view.filetree.INodeState|nil
  return nodestate
end

----------------------------------------------------------------------------------------------------

---@param root                          string|nil
---@return string[]
function M:collect_file_uuids(root)
  return self:collect_leafs(root)
end

---@param params                        eve.ux.picker.view.filetree.IMatchParams
---@return string[]
function M:match(params)
  self:__health__()

  local tree = self._tree ---@type std.collection.IReadonlyFiletree
  local statemap = self.statemap ---@type table<string, eve.ux.view.tree.INodeState>
  ---@cast statemap                     table<string, eve.ux.picker.view.filetree.INodeState>

  local root = params.rootuuid or tree.root ---@type string
  local case_sensitive = params.case_sensitive ---@type boolean
  local fuzzy = params.fuzzy ---@type boolean
  local regex = params.regex ---@type boolean
  local pattern = case_sensitive and params.pattern or params.pattern:lower() ---@type string

  ---@type eve.ux.picker.view.filetree.INodeMatchContext
  local context = {
    rootuuid = root,
    pattern = pattern,
    case_sensitive = case_sensitive,
    fuzzy = fuzzy,
    regex = regex,
  }

  local last_match_result = self._last_match_result ---@type eve.ux.picker.view.filetree.INodeMatchResult|nil
  local last_match_context = last_match_result and last_match_result.context or nil ---@type eve.ux.picker.view.filetree.INodeMatchContext|nil
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
  tree:unsafe_traverse(nil, function(ctx)
    local nodemap = ctx.nodemap ---@type table<string, std.collection.filetree.INode>
    if case_sensitive then
      for index, uuid in ipairs(uuids) do
        local node = nodemap[uuid] ---@type std.collection.filetree.INode|nil
        if node ~= nil then
          lines[index] = node.data.filepath ---@type string
        end
      end
    else
      for index, uuid in ipairs(uuids) do
        local node = nodemap[uuid] ---@type std.collection.filetree.INode|nil
        if node ~= nil then
          lines[index] = node.data.filepath_lower ---@type string
        end
      end
    end
  end)

  local oxi_matches = oxi.searcher.search_in_lines({
    pattern = pattern,
    lines = lines,
    flag_fuzzy = fuzzy,
    flag_regex = regex,
    flag_case_sensitive = case_sensitive,
  }) ---@type oxi.string.ILineMatch[]|nil
  if oxi_matches ~= nil then
    for _, oxi_match in ipairs(oxi_matches) do
      local lnum = oxi_match.lnum ---@type integer
      local uuid = uuids[lnum] ---@type string
      local matches = oxi_match.matches ---@type std.t.IMatchPoint[]
      local state = statemap[uuid]
      state.tick_matched = tick_matched ---@type integer
      state.cache_match = { score = oxi_match.score, matches = matches } ---@type eve.ux.picker.view.filetree.INodeMatchResultCache
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

  tree:unsafe_traverse(nil, function(ctx)
    local nodemap = ctx.nodemap ---@type table<string, std.collection.filetree.INode>
    for _, uuid in ipairs(uuids) do
      local o = nodemap[uuid] ---@type std.collection.filetree.INode

      for _ = o.depth - 1, 1, -1 do
        o = nodemap[o.parent] ---@type std.collection.filetree.INode

        local s = statemap[o.uuid]
        if s.tick_matched == tick_matched then
          break
        end

        s.tick_matched = tick_matched
      end
    end
  end)

  ---@type eve.ux.picker.view.filetree.INodeMatchResult
  local match_result = {
    context = context,
    uuids = uuids,
  }
  self._last_match_result = match_result
  self._tick_matched = tick_matched
  return uuids
end

---@param dirpath                       string
---@return eve.ux.picker.FiletreeView
function M:insert_dirpath(dirpath)
  self:__health__()

  local filetree = self._tree ---@type std.collection.IFiletree
  local statemap = self.statemap ---@type table<string, eve.ux.view.tree.INodeState>
  ---@cast statemap                     table<string, eve.ux.picker.view.filetree.INodeState>

  local filenode = filetree:insert_directory_absolute(dirpath)
  local fileuuid = filenode.uuid ---@type string
  local filestate = statemap[fileuuid] ---@type eve.ux.picker.view.filetree.INodeState|nil

  if filestate == nil or filestate.nodetype ~= "container" then
    local node = filetree:retrieve(filenode.parent) ---@type std.collection.filetree.INode|nil
    while node ~= nil and node.uuid ~= node.parent do
      local nodestate = statemap[filenode.uuid] ---@type eve.ux.picker.view.filetree.INodeState|nil
      if nodestate ~= nil and nodestate.nodetype == "container" then
        break
      end

      ---@type eve.ux.picker.view.filetree.IDirectoryNodeState
      nodestate = {
        nodetype = "container",
        collapsed = false,
        tick_invisible = 0,
        tick_matched = 0,
        tick_selected = 0,
        tick_selected_maximum = 0,
      }
      statemap[node.uuid] = nodestate
      node = filetree:retrieve(node.parent) ---@type std.collection.filetree.INode|nil
    end

    ---@type eve.ux.picker.view.filetree.IDirectoryNodeState
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
---@return eve.ux.picker.FiletreeView
function M:insert_filepath(filepath, with_locations)
  self:__health__()

  local filetree = self._tree ---@type std.collection.IFiletree
  local statemap = self.statemap ---@type table<string, eve.ux.view.tree.INodeState>
  ---@cast statemap                     table<string, eve.ux.picker.view.filetree.INodeState>

  local lnum, col, col_end ---@type integer|nil, integer|nil, integer|nil

  if with_locations then
    filepath, lnum, col, col_end = std.string.parse_filepath_with_location(filepath)
  end

  local filenode = filetree:insert_file_absolute(filepath)
  local fileuuid = filenode.uuid ---@type string
  local filestate = statemap[fileuuid] ---@type eve.ux.picker.view.filetree.INodeState|nil

  if filestate == nil or filestate.nodetype ~= "leaf" then
    local node = filetree:retrieve(filenode.parent) ---@type std.collection.filetree.INode|nil
    while node ~= nil and node.uuid ~= node.parent do
      local nodestate = statemap[filenode.uuid] ---@type eve.ux.picker.view.filetree.INodeState|nil
      if nodestate ~= nil and nodestate.nodetype == "container" then
        break
      end

      ---@type eve.ux.picker.view.filetree.IDirectoryNodeState
      nodestate = {
        nodetype = "container",
        collapsed = false,
        tick_invisible = 0,
        tick_matched = 0,
        tick_selected = 0,
        tick_selected_maximum = 0,
      }
      statemap[node.uuid] = nodestate
      node = filetree:retrieve(node.parent) ---@type std.collection.filetree.INode|nil
    end

    ---@type eve.ux.picker.view.filetree.IFileNodeState
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

    ---@type eve.ux.picker.view.filetree.ILocationNodeState
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

    local locations = filestate.locations or {} ---@type eve.ux.picker.view.filetree.ILocationNodeState[]
    locations[#locations + 1] = location ---@type eve.ux.picker.view.filetree.ILocationNodeState
    filestate.locations = locations ---@type eve.ux.picker.view.filetree.ILocationNodeState[]
  end

  return self
end

---@param cwd                           string
---@param filepaths                     string[]
---@param with_locations                boolean
---@return eve.ux.picker.FiletreeView
function M:reset_filepaths(cwd, filepaths, with_locations)
  self:__health__()

  local selected_set = self:collect_selected() ---@type table<string, true>
  self:clear()

  local filetree = self._tree ---@type std.collection.IFiletree
  local tick_selected = self._tick_selected ---@type integer
  local statemap = self.statemap ---@type table<string, eve.ux.view.tree.INodeState>
  ---@cast statemap                     table<string, eve.ux.picker.view.filetree.INodeState>

  filetree:reset(cwd, filepaths, with_locations)
  filetree:unsafe_traverse(filetree.root, function(ctx)
    local nodemap = ctx.nodemap ---@type table<string, std.collection.filetree.INode>
    local rootnode = ctx.rootnode ---@type std.collection.filetree.INode

    ---@param node                      std.collection.filetree.INode
    ---@return nil
    local function traverse(node)
      if node.data.filetype == "directory" then
        ---@type eve.ux.picker.view.filetree.IDirectoryNodeState
        local nodestate = {
          nodetype = "container",
          collapsed = false,
          tick_invisible = 0,
          tick_matched = 0,
          tick_selected = selected_set[node.uuid] and tick_selected or 0,
          tick_selected_maximum = 0,
        }
        statemap[node.uuid] = nodestate

        for _, uuid in ipairs(node.children) do
          local childnode = nodemap[uuid] ---@type std.collection.filetree.INode|nil
          if childnode ~= nil then
            traverse(childnode)
          end
        end
        return
      end

      if node.data.filetype == "file" then
        ---@type eve.ux.picker.view.filetree.IFileNodeState
        local nodestate = {
          nodetype = "leaf",
          collapsed = false,
          tick_invisible = 0,
          tick_matched = 0,
          tick_selected = selected_set[node.uuid] and tick_selected or 0,
        }
        statemap[node.uuid] = nodestate
        return
      end

      std.reporter.error({
        from = self.fullname,
        subject = "reset_filepaths",
        message = "Unexpected filetype",
        details = {
          nodeuuid = node.uuid,
          nodedata = node.data,
        },
      })
    end

    traverse(rootnode)

    if with_locations then
      for _, p in ipairs(filepaths) do
        local filepath, lnum, col, col_end = std.string.parse_filepath_with_location(p) ---@type string, integer|nil, integer|nil
        if lnum ~= nil then
          if not std.path.is_absolute(filepath) then
            filepath = cwd .. std.env.PATH_SEP .. filepath ---@type string
          end

          local fileuuid = std.Filetree.uuid(filepath) ---@type string
          local filenode = nodemap[fileuuid] ---@type std.collection.filetree.INode|nil
          local nodestate = statemap[fileuuid]

          if filenode ~= nil and nodestate ~= nil then
            local locationuuid = string.format("%s:%d:%d", fileuuid, lnum, col or 0) ---@type string

            ---@type eve.ux.picker.view.filetree.ILocationNodeState
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

            local locations = nodestate.locations or {} ---@type eve.ux.picker.view.filetree.ILocationNodeState[]
            locations[#locations + 1] = location ---@type eve.ux.picker.view.filetree.ILocationNodeState
            nodestate.locations = locations ---@type eve.ux.picker.view.filetree.ILocationNodeState[]
          end
        end
      end
    end
  end)

  return self
end

---@param root                          string|nil
---@param handle                        fun(node: std.collection.filetree.INode, nodestate: eve.ux.picker.view.filetree.IFileNodeState): nil
---@return string[]
function M:traverse_filenode(root, handle)
  self:__health__()

  local statemap = self.statemap ---@type table<string, eve.ux.view.tree.INodeState>
  local uuids = {} ---@type string[]

  self._tree:quick_traverse(root, function(_, node)
    local nodestate = statemap[node.uuid] ---@type eve.ux.view.tree.INodeState|nil
    if nodestate ~= nil and nodestate.nodetype == "leaf" then
      ---@cast nodestate                eve.ux.picker.view.filetree.IFileNodeState
      handle(node, nodestate)
    end
  end)
  return uuids
end

----------------------------------------------------------------------------------------------------

---@param params                        eve.ux.view.tree.IRenderListviewParams
---@return eve.ux.view.tree.IRenderResult
function M:render_listview(params)
  self:__health__()

  local nsnr = DEFAULT_NSNR_MATCHES ---@type integer
  local bufnr = params.bufnr ---@type integer
  local only_matched = params.only_matched ---@type boolean

  local result = P.render_listview(self, params)
  local uuids = result.lnum2uuid ---@type string[]
  local N = #uuids ---@type integer

  vim.api.nvim_buf_clear_namespace(bufnr, nsnr, 0, -1)

  if N < 1 then
    return result
  end

  local filetree = self._tree ---@type std.collection.IReadonlyFiletree
  local statemap = self.statemap ---@type table<string, eve.ux.view.tree.INodeState>
  ---@cast statemap                     table<string, eve.ux.picker.view.filetree.INodeState>

  local tick_matched = self._tick_matched ---@type integer

  local rootuuid = params.rootuuid ~= nil and params.rootuuid or filetree.root ---@type string
  local rootnode = filetree:retrieve(rootuuid) ---@type std.collection.filetree.INode|nil
  if rootnode == nil then
    std.reporter.error({
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
      local nodestate = statemap[uuid] ---@type eve.ux.picker.view.filetree.INodeState|nil
      if nodestate ~= nil and nodestate.tick_matched == tick_matched and nodestate.cache_match ~= nil then
        local node = filetree:retrieve(uuid) ---@type std.collection.filetree.INode|nil
        if node ~= nil then
          local row = lnum - 1 ---@type integer
          local offset_final = #indents[lnum] + #node.data.fileicon + 1 ---@type integer
          local rootpath = rootnode.data.filepath ---@type string
          local displayed_filepath = #rootpath < 2 and node.data.filepath or node.data.filepath:sub(#rootpath + 2) ---@type string
          local L = #displayed_filepath ---@type integer
          local offset_filepath = #node.data.filepath - L ---@type integer

          local matches = nodestate.cache_match.matches ---@type std.t.IMatchPoint[]
          for _, m in ipairs(matches) do
            local l = m.l - offset_filepath
            local r = m.r - offset_filepath
            if r > 0 and l < L then
              l = l < 0 and 0 or l ---@type integer
              r = r < L and r or L ---@type integer
              vim.hl.range(bufnr, nsnr, "f_pk_matches", { row, offset_final + l }, { row, offset_final + r })
            end
          end
        end
      end
    end
  end
  return result
end

---@param params                        eve.ux.view.tree.IRenderTreeviewParams
---@return eve.ux.view.tree.IRenderResult
function M:render_treeview(params)
  self:__health__()
  local nsnr = DEFAULT_NSNR_MATCHES ---@type integer
  local bufnr = params.bufnr ---@type integer
  local only_matched = params.only_matched ---@type boolean

  local result = P.render_treeview(self, params)
  local uuids = result.lnum2uuid ---@type string[]
  local N = #uuids ---@type integer

  vim.api.nvim_buf_clear_namespace(bufnr, nsnr, 0, -1)

  if N < 1 then
    return result
  end

  local indents = result.indents ---@type string[]
  local filetree = self._tree ---@type std.collection.IReadonlyFiletree
  local tick_matched = self._tick_matched ---@type integer
  local statemap = self.statemap ---@type table<string, eve.ux.view.tree.INodeState>
  ---@cast statemap                     table<string, eve.ux.picker.view.filetree.INodeState>

  if only_matched then
    for lnum = 1, N, 1 do
      local uuid = uuids[lnum] ---@type string
      local nodestate = statemap[uuid] ---@type eve.ux.picker.view.filetree.INodeState|nil
      if
        nodestate ~= nil
        and nodestate.nodetype == "leaf"
        and nodestate.tick_matched == tick_matched
        and nodestate.cache_match ~= nil
      then
        local node = filetree:retrieve(uuid) ---@type std.collection.filetree.INode|nil
        if node ~= nil then
          local row = lnum - 1 ---@type integer
          local offset_final = #indents[lnum] + #node.data.fileicon + 1 ---@type integer
          local basename = node.data.basename ---@type string
          local L = #basename ---@type integer
          local offset_basename = #node.data.filepath - L ---@type integer

          local matches = nodestate.cache_match.matches ---@type std.t.IMatchPoint[]
          for _, m in ipairs(matches) do
            local l = m.l - offset_basename ---@type integer
            local r = m.r - offset_basename ---@type integer
            if r > 0 and l < L then
              l = l < 0 and 0 or l ---@type integer
              r = r < L and r or L ---@type integer
              vim.hl.range(bufnr, nsnr, "f_pk_matches", { row, offset_final + l }, { row, offset_final + r })
            end
          end
        end
      end
    end
  end

  return result
end

----------------------------------------------------------------------------------------------------

---@type eve.ux.picker.view.filetree.IListviewFileRenderer
function M.default_render_listview_leaf(ctx, node)
  local rootnode = ctx.rootnode ---@type std.collection.filetree.INode
  local fileicon = node.data.fileicon ---@type string
  local fileicon_hln = node.data.fileicon_hln ---@type string
  local filepath = #rootnode.data.filepath < 2 and node.data.filepath
    or node.data.filepath:sub(#rootnode.data.filepath + 2)
  local text = string.format("%s %s", fileicon, filepath) ---@type string

  ---@type std.t.IHighlightInline[]
  local highlights = {
    { coll = 0, colr = #fileicon + 1, hlname = fileicon_hln },
  }

  local diagnostic_text = eve.lsp.calc_diagnostic_info(node.data.filepath, #text, highlights) ---@type string
  text = text .. diagnostic_text ---@type string
  return { text = text, highlights = highlights }
end

---@type eve.ux.picker.view.filetree.IListviewLocationRenderer
function M.default_render_listview_location(_, _, _, locationstate)
  local lnum = locationstate.lnum ---@type integer
  local col = locationstate.col ---@type integer|nil
  local text = col ~= nil and string.format("%4d:%-4d", lnum, col) or string.format("%4d:", lnum) ---@type string
  local offset = #text ---@type integer

  ---@type std.t.IHighlightInline[]
  local highlights = {
    { coll = 0, colr = offset, hlname = "f_ft_position" },
    { coll = offset, colr = -1, hlname = "f_ft_text" },
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
  return { text = text, highlights = highlights }
end

---@type eve.ux.picker.view.filetree.ITreeviewDirectoryRenderer
function M.default_render_treeview_container(ctx, node, nodestate, _, folded_depth)
  local basename = node.data.basename ---@type string
  local fileicon = node.data.fileicon ---@type string
  local fileicon_hln = node.data.fileicon_hln ---@type string
  if not nodestate.collapsed then
    fileicon = eve.icon.filetype.FolderOpen
  end

  if folded_depth < 1 then
    local text = string.format("%s %s", fileicon, basename) ---@type string

    ---@type std.t.IHighlightInline[]
    local highlights = {
      { coll = 0, colr = #fileicon + 1, hlname = fileicon_hln },
      { coll = #fileicon + 1, colr = #text, hlname = "f_ft_dirname" },
    }
    return { text = text, highlights = highlights }
  end

  local tree = ctx.tree ---@type std.collection.IReadonlyFiletree

  local basenames = {} ---@type string[]
  basenames[folded_depth + 1] = basename ---@type string

  local o = node ---@type std.collection.filetree.INode
  for index = folded_depth, 1, -1 do
    local uuid_parent = o.parent ---@type string
    o = tree:retrieve(uuid_parent) or o ---@type std.collection.filetree.INode
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

  ---@type std.t.IHighlightInline[]
  local highlights = {
    { coll = 0, colr = #fileicon + 1, hlname = fileicon_hln },
    { coll = #fileicon + 1, colr = #text, hlname = "f_ft_dirname" },
  }

  for index = start_index + 1, #basenames, 1 do
    local piece = basenames[index] ---@type string
    local offset = #text ---@type integer
    text = text .. string.format("/%s", piece)
    highlights[#highlights + 1] = { coll = offset, colr = offset + 1, hlname = "f_ft_pathsep" }
    highlights[#highlights + 1] = { coll = offset + 1, colr = #text, hlname = "f_ft_dirname" }
  end

  return { text = text, highlights = highlights }
end

---@type eve.ux.picker.view.filetree.ITreeviewFileRenderer
function M.default_render_treeview_leaf(_, node)
  local basename = node.data.basename ---@type string
  local fileicon = node.data.fileicon ---@type string
  local fileicon_hln = node.data.fileicon_hln ---@type string
  local text = string.format("%s %s", fileicon, basename) ---@type string

  ---@type std.t.IHighlightInline[]
  local highlights = {
    { coll = 0, colr = #fileicon + 1, hlname = fileicon_hln },
    { coll = #fileicon + 1, colr = #text, hlname = "f_ft_filename" },
  }

  local diagnostic_text = eve.lsp.calc_diagnostic_info(node.data.filepath, #text, highlights) ---@type string
  text = text .. diagnostic_text ---@type string
  return { text = text, highlights = highlights }
end

---@type eve.ux.picker.view.filetree.ITreeviewLocationRenderer
function M.default_render_treeview_location(_, _, _, locationstate)
  local lnum = locationstate.lnum ---@type integer
  local col = locationstate.col ---@type integer|nil
  local text = col ~= nil and string.format("%4d:%-4d", lnum, col) or string.format("%4d:", lnum) ---@type string
  local offset = #text ---@type integer

  ---@type std.t.IHighlightInline[]
  local highlights = {
    { coll = 0, colr = offset, hlname = "f_ft_position" },
    { coll = offset, colr = -1, hlname = "f_ft_text" },
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
  return { text = text, highlights = highlights }
end

return M
