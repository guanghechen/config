---@diagnostic disable: invisible
local __module_name__ = "eve.ux.searcher.view.filetree" ---@type string

---@alias eve.ux.searcher.view.filetree.INodeState
---| eve.ux.searcher.view.filetree.IDirectoryNodeState
---| eve.ux.searcher.view.filetree.IFileNodeState
---| eve.ux.searcher.view.filetree.ILeafLocationState

---@alias eve.ux.searcher.view.filetree.IListviewFileRenderer
---| fun(ctx: eve.ux.searcher.view.filetree.IListviewRendererContext, node: std.collection.filetree.INode, nodestate: eve.ux.searcher.view.filetree.IFileNodeState, lnum: integer): eve.ux.view.tree.INodeRenderResult

---@alias eve.ux.searcher.view.filetree.IListviewLocationRenderer
---| fun(ctx: eve.ux.searcher.view.filetree.IListviewRendererContext, node: std.collection.filetree.INode, nodestate: eve.ux.searcher.view.filetree.IFileNodeState, locationstate: eve.ux.searcher.view.filetree.ILeafLocationState, lnum: integer): eve.ux.view.tree.INodeRenderResult

---@alias eve.ux.searcher.view.filetree.ITreeviewDirectoryRenderer
---| fun(ctx: eve.ux.searcher.view.filetree.ITreeviewRendererContext, node: std.collection.filetree.INode, nodestate: eve.ux.searcher.view.filetree.IDirectoryNodeState, lnum: integer, folded_depth: integer): eve.ux.view.tree.INodeRenderResult

---@alias eve.ux.searcher.view.filetree.ITreeviewFileRenderer
---| fun(ctx: eve.ux.searcher.view.filetree.ITreeviewRendererContext, node: std.collection.filetree.INode, nodestate: eve.ux.searcher.view.filetree.IFileNodeState, lnum: integer): eve.ux.view.tree.INodeRenderResult

---@alias eve.ux.searcher.view.filetree.ITreeviewLocationRenderer
---| fun(ctx: eve.ux.searcher.view.filetree.ITreeviewRendererContext, node: std.collection.filetree.INode, nodestate: eve.ux.searcher.view.filetree.IFileNodeState, locationstate: eve.ux.searcher.view.filetree.ILeafLocationState, lnum: integer): eve.ux.view.tree.INodeRenderResult

---@class eve.ux.searcher.view.filetree.IDirectoryNodeState : eve.ux.view.tree.IContainerNodeState

---@class eve.ux.searcher.view.filetree.IFileNodeState : eve.ux.view.tree.ILeafNodeState
---@field public locations              eve.ux.searcher.view.filetree.ILeafLocationState|nil
---@field public filematch              oxi.searcher.IFileMatch|nil

---@class eve.ux.searcher.view.filetree.ILeafLocationState : eve.ux.view.tree.ILeafLocationState
---@field public lnum                   integer
---@field public col                    ?integer
---@field public col_end                ?integer
---@field public text                   ?string
---@field public highlights             ?std.t.IHighlightInline[]
---
---@field public match                  eve.ux.searcher.view.filetree.ISearchedItem

---@class eve.ux.searcher.view.filetree.IListviewRendererContext : eve.ux.view.tree.IListviewRendererContext
---@field public rootnode               std.collection.filetree.INode
---@field public rootstate              eve.ux.searcher.view.filetree.IDirectoryNodeState
---@field public tree                   std.collection.IReadonlyFiletree
---@field public view                   eve.ux.searcher.FiletreeView

---@class eve.ux.searcher.view.filetree.ITreeviewRendererContext : eve.ux.view.tree.IListviewRendererContext
---@field public rootnode               std.collection.filetree.INode
---@field public rootstate              eve.ux.searcher.view.filetree.IDirectoryNodeState
---@field public tree                   std.collection.IReadonlyFiletree
---@field public view                   eve.ux.searcher.FiletreeView

---@class eve.ux.searcher.view.filetree.ISearchParams
---@field public flag_case_sensitive    boolean
---@field public flag_exclude           boolean
---@field public flag_gitignore         boolean
---@field public flag_regex             boolean
---@field public flag_replace           boolean
---@field public max_filesize           string
---@field public max_matches            integer
---
---@field public excludes               string[]
---@field public includes               string[]
---
---@field public cwd                    string
---@field public specified_filepath     string|nil
---@field public search_pattern         string
---@field public replace_pattern        string|nil

---@class eve.ux.searcher.view.filetree.ISearchResult
---@field public items                  eve.ux.searcher.view.filetree.ISearchedItem[]
---@field public filematch_map          table<string, oxi.searcher.IFileMatch>

---@class eve.ux.searcher.view.filetree.ISearchedPreviewItem
---@field public offset                 integer
---@field public lnum                   integer
---@field public col                    integer
---@field public content                string

---@class eve.ux.searcher.view.filetree.ISearchedItem
---@field public filepath               string
---@field public uuid                   string
---
---@field public lnum                   integer
---@field public col                    integer
---@field public text                   string
---@field public highlights             std.t.IHighlightInline[]
---
---@field public preview                eve.ux.searcher.view.filetree.ISearchedPreviewItem

----------------------------------------------------------------------------------------------------

---@param lwidths                       integer[]
---@param l                             integer
---@param r                             integer
---@return integer
---@return integer
---@return integer
local function calc_same_line_pos(lwidths, l, r)
  local offset = 0 ---@type integer
  local lwidth = lwidths[1] + 1 ---@type integer
  local N, lnum = #lwidths, 1 ---@type integer, integer
  while offset + lwidth <= l and lnum < N do
    lnum = lnum + 1
    offset = offset + lwidth
    lwidth = lwidths[lnum] + 1
  end

  local col = l - offset ---@type integer
  local col_end = r - offset ---@type integer
  return lnum, col, col_end < lwidth and col_end or lwidth
end

----------------------------------------------------------------------------------------------------

---@class eve.ux.searcher.view.IFiletreeProps
---@field public name                   string
---@field public tree                   std.collection.IFiletree
---@field public indent                 ?string
---@field public indent_hln             ?string
---
---@field public render_listview_leaf       ?eve.ux.searcher.view.filetree.IListviewFileRenderer
---@field public render_listview_location   ?eve.ux.searcher.view.filetree.IListviewLocationRenderer
---@field public render_treeview_container  ?eve.ux.searcher.view.filetree.ITreeviewDirectoryRenderer
---@field public render_treeview_leaf       ?eve.ux.searcher.view.filetree.ITreeviewFileRenderer
---@field public render_treeview_location   ?eve.ux.searcher.view.filetree.ITreeviewLocationRenderer

local P = eve.ux.view.Tree ---@type eve.ux.view.Tree

---@class eve.ux.searcher.FiletreeView : eve.ux.view.Tree
---@field protected _tree               std.collection.IFiletree
---@field public statemap               table<string, eve.ux.searcher.view.filetree.INodeState>
---@field public insert                 fun(self: eve.ux.searcher.FiletreeView, uuid: string, state: eve.ux.view.tree.INodeState): eve.ux.searcher.FiletreeView
local M = {}
M.__index = M
setmetatable(M, P)

---@param props                         eve.ux.searcher.view.IFiletreeProps
---@return eve.ux.searcher.FiletreeView
function M.new(props)
  local name = props.name ---@type string
  local fullname = string.format("%s -> %s", name, __module_name__) ---@type string
  local indent = props.indent ---@type string|nil
  local indent_hln = props.indent_hln ---@type string|nil
  local tree = props.tree ---@type std.collection.IFiletree

  local render_listview_leaf = props.render_listview_leaf or M.default_render_listview_leaf ---@type eve.ux.searcher.view.filetree.IListviewFileRenderer
  local render_listview_location = props.render_listview_location or M.default_render_listview_location ---@type eve.ux.searcher.view.filetree.IListviewLocationRenderer
  local render_treeview_container = props.render_treeview_container or M.default_render_treeview_container ---@type eve.ux.searcher.view.filetree.ITreeviewDirectoryRenderer
  local render_treeview_leaf = props.render_treeview_leaf or M.default_render_treeview_leaf ---@type eve.ux.searcher.view.filetree.ITreeviewFileRenderer
  local render_treeview_location = props.render_treeview_location or M.default_render_treeview_location ---@type eve.ux.searcher.view.filetree.ITreeviewLocationRenderer

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
  ---@cast self                         eve.ux.searcher.FiletreeView

  return self
end

----------------------------------------------------------------------------------------------------

---@return eve.ux.searcher.FiletreeView
function M:clear()
  self:__health__()

  P.clear(self)
  return self
end

---@return nil
function M:dispose()
  if self._disposed then
    return nil
  end

  P.dispose(self)
end

---@return eve.ux.searcher.FiletreeView
function M:mark_cache_match_dirty()
  self:__health__()
  return self
end

---@param uuid                          string
---@return eve.ux.searcher.view.filetree.INodeState|nil
function M:retrieve(uuid)
  self:__health__()

  local statemap = self.statemap ---@type table<string, eve.ux.view.tree.INodeState>
  ---@cast statemap                     table<string, eve.ux.searcher.view.filetree.INodeState>

  local nodestate = statemap[uuid] ---@type eve.ux.searcher.view.filetree.INodeState|nil
  return nodestate
end

----------------------------------------------------------------------------------------------------

---@param root                          string|nil
---@return string[]
function M:collect_file_uuids(root)
  return self:collect_leafs(root)
end

---@param params                        eve.ux.searcher.view.filetree.ISearchParams
---@return eve.ux.searcher.view.filetree.ISearchResult|nil
function M:search(params)
  self:__health__()

  local flag_case_sensitive = params.flag_case_sensitive ---@type boolean
  local flag_exclude = params.flag_exclude ---@type boolean
  local flag_gitignore = params.flag_gitignore ---@type boolean
  local flag_regex = params.flag_regex ---@type boolean
  local flag_replace = params.flag_replace ---@type boolean
  local max_filesize = params.max_filesize ---@type string
  local max_matches = params.max_matches ---@type integer

  local includes = params.includes ---@type string[]
  local excludes = flag_exclude and params.excludes or {} ---@type string[]

  local cwd = params.cwd ---@type string
  local specified_filepath = params.specified_filepath ---@type string|nil
  local search_pattern = flag_case_sensitive and params.search_pattern or params.search_pattern:lower() ---@type string
  local replace_pattern = params.replace_pattern ---@type string|nil

  ---@type oxi.searcher.ISearchInFilesResult|nil
  local results = oxi.searcher.search_in_files({
    cwd = cwd,
    flag_case_sensitive = flag_case_sensitive,
    flag_gitignore = flag_gitignore,
    flag_regex = flag_regex,
    max_filesize = max_filesize,
    max_matches = max_matches,
    search_pattern = search_pattern,
    search_paths = "",
    include_patterns = table.concat(includes, ","),
    exclude_patterns = table.concat(excludes, ","),
    specified_filepath = specified_filepath,
  })

  if results == nil or results.error ~= nil or results.items == nil then
    std.reporter.error({
      from = self.fullname,
      subject = "search",
      message = "Failed to perform the search action.",
      details = {
        flag_case_sensitive = flag_case_sensitive,
        flag_exclude = flag_exclude,
        flag_gitignore = flag_gitignore,
        flag_regex = flag_regex,
        flag_replace = flag_replace,
        max_filesize = max_filesize,
        max_matches = max_matches,
        includes = includes,
        excludes = excludes,
        cwd = cwd,
        specified_filepath = specified_filepath,
        search_pattern = search_pattern,
        replacement = replace_pattern,
        error = results ~= nil and results.error or nil,
      },
    })
    return
  end

  local items = {} ---@type eve.ux.searcher.view.filetree.ISearchedItem[]
  local filematch_map = {} ---@type table<string, oxi.searcher.IFileMatch>

  for _, filepath in ipairs(results.item_orders) do
    local filematch = results.items[filepath] ---@type oxi.searcher.IFileMatch
    filepath = std.path.join(cwd, filepath) ---@type string
    local uuid = std.Filetree.uuid(filepath) ---@type string

    filematch_map[uuid] = filematch ---@type oxi.searcher.IFileMatch

    if flag_replace and replace_pattern ~= nil then
      local lnum_delta = 0 ---@type integer
      for _, block_match in ipairs(filematch.matches) do
        ---@type oxi.replacer.replace_text_preview_advance.IResult
        local preview_result = oxi.replacer.replace_text_preview_advance({
          flag_case_sensitive = flag_case_sensitive,
          flag_regex = flag_regex,
          keep_search_pieces = true,
          search_pattern = search_pattern,
          replace_pattern = replace_pattern,
          text = block_match.text,
        })

        local r_lines = preview_result.lines ---@type string[]
        local r_lwidths = preview_result.lwidths ---@type integer[]
        local r_matches = preview_result.matches ---@type std.t.IMatchPoint[]
        local s_lines = block_match.lines ---@type string[]
        local s_lwidths = block_match.lwidths ---@type integer[]
        local s_matches = block_match.matches ---@type std.t.IMatchPoint[]
        for i = 1, #s_matches, 1 do
          local s_match = s_matches[i] ---@type std.t.IMatchPoint
          local k, col, col_end = calc_same_line_pos(s_lwidths, s_match.l, s_match.r)
          local line = s_lines[k] ---@type string
          local lnum = block_match.lnum + k - 1 ---@type integer

          local search_match = r_matches[i * 2 - 1] ---@type std.t.IMatchPoint
          local s_k, s_col = calc_same_line_pos(r_lwidths, search_match.l, search_match.r)
          local s_lnum = block_match.lnum + s_k - 1 + lnum_delta ---@type integer

          local replace_match = r_matches[i * 2] ---@type std.t.IMatchPoint
          local r_k, r_col, r_col_end = calc_same_line_pos(r_lwidths, replace_match.l, replace_match.r)
          local r_line = r_lines[r_k] ---@type string

          local text ---@type string
          local highlights ---@type std.t.IHighlightInline[]

          if s_k == r_k then
            text = string.sub(line, 1, col_end)
              .. string.sub(r_line, r_col + 1, r_col_end)
              .. string.sub(line, col_end + 1)
              .. eve.icon.listchars.eol

            highlights = {
              { coll = col, colr = col_end, hlname = "f_ss_search" },
              { coll = col_end, colr = col_end + (r_col_end - r_col), hlname = "f_ss_replace" },
            }
          else
            text = line .. eve.icon.listchars.eol
            highlights = {
              { coll = col, colr = col_end, hlname = "f_ss_matches" },
            }
          end

          ---@type eve.ux.searcher.view.filetree.ISearchedItem
          local item = {
            filepath = filepath,
            uuid = uuid,
            lnum = lnum,
            col = col,
            text = text,
            highlights = highlights,
            preview = {
              offset = block_match.offset + s_match.l,
              lnum = s_lnum,
              col = s_col,
              content = s_lines[s_k],
            },
          }
          items[#items + 1] = item
        end

        lnum_delta = lnum_delta + #r_lwidths - #s_lwidths
      end
    else
      for _, block_match in ipairs(filematch.matches) do
        local lines = block_match.lines ---@type string[]
        local lwidths = block_match.lwidths ---@type integer[]
        for _, s_match in ipairs(block_match.matches) do
          local k, col, col_end = calc_same_line_pos(lwidths, s_match.l, s_match.r)
          local lnum = block_match.lnum + k - 1 ---@type integer

          local text = lines[k] .. eve.icon.listchars.eol ---@type string

          ---@type std.t.IHighlightInline[]
          local highlights = {
            { coll = col, colr = col_end, hlname = "f_ss_matches" },
          }

          ---@type eve.ux.searcher.view.filetree.ISearchedItem
          local item = {
            filepath = filepath,
            uuid = uuid,
            lnum = lnum,
            col = col,
            text = text,
            highlights = highlights,
            preview = {
              offset = block_match.offset + s_match.l,
              lnum = lnum,
              col = col,
              content = lines[k],
            },
          }
          items[#items + 1] = item
        end
      end
    end
  end

  ---@type eve.ux.searcher.view.filetree.ISearchResult
  local result = {
    items = items,
    filematch_map = filematch_map,
  }
  return result
end

---@param cwd                           string
---@param filepaths                     string[]
---@return eve.ux.searcher.FiletreeView
function M:reset_filepaths(cwd, filepaths)
  self:__health__()

  local selected_set = self:collect_selected() ---@type table<string, true>
  self:clear()

  local filetree = self._tree ---@type std.collection.IFiletree
  local tick_selected = self._tick_selected ---@type integer
  local statemap = self.statemap ---@type table<string, eve.ux.view.tree.INodeState>
  ---@cast statemap                     table<string, eve.ux.searcher.view.filetree.INodeState>

  filetree:reset(cwd, filepaths, false)
  filetree:unsafe_traverse(filetree.root, function(ctx)
    local nodemap = ctx.nodemap ---@type table<string, std.collection.filetree.INode>
    local rootnode = ctx.rootnode ---@type std.collection.filetree.INode

    ---@param node                      std.collection.filetree.INode
    ---@return nil
    local function traverse(node)
      if node.data.filetype == "directory" then
        ---@type eve.ux.searcher.view.filetree.IDirectoryNodeState
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
        ---@type eve.ux.searcher.view.filetree.IFileNodeState
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
  end)

  return self
end

----------------------------------------------------------------------------------------------------

---@type eve.ux.searcher.view.filetree.IListviewFileRenderer
function M.default_render_listview_leaf(ctx, node)
  local rootnode = ctx.rootnode ---@type std.collection.filetree.INode
  local fileicon = node.data.fileicon ---@type string
  local fileicon_hln = node.data.fileicon_hln ---@type string
  local filepath = #rootnode.data.filepath < 2 and node.data.filepath
    or node.data.filepath:sub(#rootnode.data.filepath + 2)
  local text = string.format("%s %s", fileicon, filepath) ---@type string
  local highlights = { { coll = 0, colr = #fileicon + 1, hlname = fileicon_hln } } ---@type std.t.IHighlightInline[]
  return { text = text, highlights = highlights }
end

---@type eve.ux.searcher.view.filetree.IListviewLocationRenderer
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

---@type eve.ux.searcher.view.filetree.ITreeviewDirectoryRenderer
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

---@type eve.ux.searcher.view.filetree.ITreeviewFileRenderer
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
  return { text = text, highlights = highlights }
end

---@type eve.ux.searcher.view.filetree.ITreeviewLocationRenderer
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
