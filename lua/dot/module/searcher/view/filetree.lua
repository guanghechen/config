---@diagnostic disable: invisible
local __module_name__ = "dot.module.searcher.view.filetree" ---@type string

---@alias dot.module.searcher.view.filetree.INodeState
---| dot.module.searcher.view.filetree.IDirectoryNodeState
---| dot.module.searcher.view.filetree.IFileNodeState
---| dot.module.searcher.view.filetree.ILeafLocationState

---@alias dot.module.searcher.view.filetree.IListviewFileRenderer
---| fun(ctx: dot.module.searcher.view.filetree.IListviewRendererContext, node: stl.c.IFiletreeNode, nodestate: dot.module.searcher.view.filetree.IFileNodeState, lnum: integer): stl.view.tree.INodeRenderResult

---@alias dot.module.searcher.view.filetree.IListviewLocationRenderer
---| fun(ctx: dot.module.searcher.view.filetree.IListviewRendererContext, node: stl.c.IFiletreeNode, nodestate: dot.module.searcher.view.filetree.IFileNodeState, locationstate: dot.module.searcher.view.filetree.ILeafLocationState, lnum: integer): stl.view.tree.INodeRenderResult

---@alias dot.module.searcher.view.filetree.ITreeviewDirectoryRenderer
---| fun(ctx: dot.module.searcher.view.filetree.ITreeviewRendererContext, node: stl.c.IFiletreeNode, nodestate: dot.module.searcher.view.filetree.IDirectoryNodeState, lnum: integer, folded_depth: integer): stl.view.tree.INodeRenderResult

---@alias dot.module.searcher.view.filetree.ITreeviewFileRenderer
---| fun(ctx: dot.module.searcher.view.filetree.ITreeviewRendererContext, node: stl.c.IFiletreeNode, nodestate: dot.module.searcher.view.filetree.IFileNodeState, lnum: integer): stl.view.tree.INodeRenderResult

---@alias dot.module.searcher.view.filetree.ITreeviewLocationRenderer
---| fun(ctx: dot.module.searcher.view.filetree.ITreeviewRendererContext, node: stl.c.IFiletreeNode, nodestate: dot.module.searcher.view.filetree.IFileNodeState, locationstate: dot.module.searcher.view.filetree.ILeafLocationState, lnum: integer): stl.view.tree.INodeRenderResult

---@class dot.module.searcher.view.filetree.IDirectoryNodeState : stl.view.tree.IContainerNodeState

---@class dot.module.searcher.view.filetree.IFileNodeState : stl.view.tree.ILeafNodeState
---@field public locations              dot.module.searcher.view.filetree.ILeafLocationState|nil
---@field public filematch              dot.module.searcher.view.filetree.IResolvedFileMatch|nil

---@class dot.module.searcher.view.filetree.ILeafLocationState : stl.view.tree.ILeafLocationState
---@field public lnum                   integer
---@field public col                    ?integer
---@field public col_end                ?integer
---@field public text                   ?string
---@field public highlights             ?stl.t.IHighlightInline[]
---
---@field public match                  dot.module.searcher.view.filetree.ISearchedItem

---@class dot.module.searcher.view.filetree.IResolvedFileMatch
---@field public filepath               string
---@field public relative               string
---@field public matches                yoz.search.ITextMatch[]

---@class dot.module.searcher.view.filetree.IListviewRendererContext : stl.view.tree.IListviewRendererContext
---@field public rootnode               stl.c.IFiletreeNode
---@field public rootstate              dot.module.searcher.view.filetree.IDirectoryNodeState
---@field public tree                   stl.c.IReadonlyFiletree
---@field public view                   dot.module.searcher.FiletreeView

---@class dot.module.searcher.view.filetree.ITreeviewRendererContext : stl.view.tree.IListviewRendererContext
---@field public rootnode               stl.c.IFiletreeNode
---@field public rootstate              dot.module.searcher.view.filetree.IDirectoryNodeState
---@field public tree                   stl.c.IReadonlyFiletree
---@field public view                   dot.module.searcher.FiletreeView

---@class dot.module.searcher.view.filetree.ISearchParams
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

---@class dot.module.searcher.view.filetree.ISearchResult
---@field public items                  dot.module.searcher.view.filetree.ISearchedItem[]
---@field public filematch_map          table<string, dot.module.searcher.view.filetree.IResolvedFileMatch>

---@class dot.module.searcher.view.filetree.ISearchedPreviewItem
---@field public offset                 integer
---@field public lnum                   integer
---@field public col                    integer
---@field public content                string

---@class dot.module.searcher.view.filetree.ISearchedItem
---@field public filepath               string
---@field public uuid                   string
---
---@field public lnum                   integer
---@field public col                    integer
---@field public text                   string
---@field public highlights             stl.t.IHighlightInline[]
---
---@field public preview                dot.module.searcher.view.filetree.ISearchedPreviewItem

local function decode_preview_text(text)
  return text:gsub(stl.icon.listchars.eol, "\n")
end

local function encode_preview_text(text)
  local sanitized = text:gsub("\r\n", "\n"):gsub("\r", "\n")
  return sanitized:gsub("\n", stl.icon.listchars.eol)
end

----------------------------------------------------------------------------------------------------

---@class dot.module.searcher.view.IFiletreeProps
---@field public name                   string
---@field public tree                   stl.c.IFiletree
---@field public indent                 ?string
---@field public indent_hln             ?string
---
---@field public render_listview_leaf   ?dot.module.searcher.view.filetree.IListviewFileRenderer
---@field public render_listview_location   ?dot.module.searcher.view.filetree.IListviewLocationRenderer
---@field public render_treeview_container  ?dot.module.searcher.view.filetree.ITreeviewDirectoryRenderer
---@field public render_treeview_leaf   ?dot.module.searcher.view.filetree.ITreeviewFileRenderer
---@field public render_treeview_location   ?dot.module.searcher.view.filetree.ITreeviewLocationRenderer

local P = stl.view.Tree ---@type stl.view.Tree

---@class dot.module.searcher.FiletreeView : stl.view.Tree
---@field protected _tree               stl.c.IFiletree
---@field public statemap               table<string, dot.module.searcher.view.filetree.INodeState>
---@field public insert                 fun(self: dot.module.searcher.FiletreeView, uuid: string, state: stl.view.tree.INodeState): dot.module.searcher.FiletreeView
local M = {}
M.__index = M
setmetatable(M, P)

---@param props                         dot.module.searcher.view.IFiletreeProps
---@return dot.module.searcher.FiletreeView
function M.new(props)
  local name = props.name ---@type string
  local fullname = string.format("%s -> %s", name, __module_name__) ---@type string
  local indent = props.indent ---@type string|nil
  local indent_hln = props.indent_hln ---@type string|nil
  local tree = props.tree ---@type stl.c.IFiletree

  local render_listview_leaf = props.render_listview_leaf or M.default_render_listview_leaf ---@type dot.module.searcher.view.filetree.IListviewFileRenderer
  local render_listview_location = props.render_listview_location or M.default_render_listview_location ---@type dot.module.searcher.view.filetree.IListviewLocationRenderer
  local render_treeview_container = props.render_treeview_container or M.default_render_treeview_container ---@type dot.module.searcher.view.filetree.ITreeviewDirectoryRenderer
  local render_treeview_leaf = props.render_treeview_leaf or M.default_render_treeview_leaf ---@type dot.module.searcher.view.filetree.ITreeviewFileRenderer
  local render_treeview_location = props.render_treeview_location or M.default_render_treeview_location ---@type dot.module.searcher.view.filetree.ITreeviewLocationRenderer

  local super = stl.view.Tree.new({
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
  ---@cast self                         dot.module.searcher.FiletreeView

  return self
end

----------------------------------------------------------------------------------------------------

---@return dot.module.searcher.FiletreeView
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

---@return dot.module.searcher.FiletreeView
function M:mark_cache_match_dirty()
  self:__health__()
  return self
end

---@param uuid                          string
---@return dot.module.searcher.view.filetree.INodeState|nil
function M:retrieve(uuid)
  self:__health__()

  local statemap = self.statemap ---@type table<string, stl.view.tree.INodeState>
  ---@cast statemap                     table<string, dot.module.searcher.view.filetree.INodeState>

  local nodestate = statemap[uuid] ---@type dot.module.searcher.view.filetree.INodeState|nil
  return nodestate
end

----------------------------------------------------------------------------------------------------

---@param root                          string|nil
---@return string[]
function M:collect_file_uuids(root)
  return self:collect_leafs(root)
end

---@param params                        dot.module.searcher.view.filetree.ISearchParams
---@return dot.module.searcher.view.filetree.ISearchResult|nil
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
  local search_pattern = params.search_pattern ---@type string
  local replace_pattern = params.replace_pattern ---@type string|nil

  ---@type yoz.search.ISearchFileResult|nil, yoz.search.ISearchFailedResult|nil
  local results, err = yoz.search.search_in_files({
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

  if results == nil or results.items == nil then
    stl.reporter.error({
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
        error = err and err.error or err,
      },
    })
    return
  end

  local has_replace_preview = flag_replace and replace_pattern ~= nil and replace_pattern ~= ""
  local search_highlight = has_replace_preview and "m_ss_search" or "m_ss_matches"

  local function resolve_filepath(relpath)
    if relpath == nil or relpath == "" then
      return cwd
    end
    if yoz.path.is_absolute(relpath) then
      return relpath
    end
    return dot.path.join(cwd, relpath)
  end

  local items = {} ---@type dot.module.searcher.view.filetree.ISearchedItem[]
  local filematch_map = {} ---@type table<string, dot.module.searcher.view.filetree.IResolvedFileMatch>

  for _, filematch in ipairs(results.items) do
    local relpath = filematch.p or "" ---@type string
    local filepath = resolve_filepath(relpath) ---@type string
    local uuid = stl.c.Filetree.uuid(filepath) ---@type string

    filematch_map[uuid] = {
      filepath = filepath,
      relative = relpath,
      matches = filematch.matches or {},
    }

    for _, match in ipairs(filematch.matches or {}) do
      local preview_text = match.s or "" ---@type string
      local sx = match.sx or 0 ---@type integer
      local sy = match.sy or sx ---@type integer

      local text ---@type string
      local highlights ---@type stl.t.IHighlightInline[]

      if has_replace_preview then
        local prefix = preview_text:sub(1, sy + 1) ---@type string
        local suffix = preview_text:sub(sy + 2) ---@type string
        local match_chunk = preview_text:sub(sx + 1, sy + 1) ---@type string
        local match_real = decode_preview_text(match_chunk) ---@type string
        local replace_pattern_text = replace_pattern or "" ---@type string

        local replacement_real, preview_err = yoz.replace.replace_text_preview({
          text = match_real,
          search_pattern = search_pattern,
          replace_pattern = replace_pattern_text,
          keep_search_pieces = false,
          flag_regex = flag_regex,
          flag_case_sensitive = flag_case_sensitive,
        })

        if type(replacement_real) ~= "string" then
          if preview_err ~= nil then
            stl.reporter.error({
              from = __module_name__,
              subject = "replace_text_preview",
              message = preview_err,
              details = {
                filepath = filepath,
                offset = match.ox,
              },
            })
          end
          replacement_real = match_real
        end

        local replacement_display = encode_preview_text(replacement_real) ---@type string
        text = prefix .. replacement_display .. suffix

        local prefix_len = #prefix ---@type integer
        local replacement_len = #replacement_display ---@type integer

        highlights = {
          { coll = sx, colr = sy + 1, hlname = search_highlight },
        }

        if replacement_len > 0 then
          highlights[#highlights + 1] = {
            coll = prefix_len,
            colr = prefix_len + replacement_len,
            hlname = "m_ss_replace",
          }
        end
      else
        text = preview_text
        highlights = {
          { coll = sx, colr = sy + 1, hlname = search_highlight },
        }
      end

      ---@type dot.module.searcher.view.filetree.ISearchedItem
      local item = {
        filepath = filepath,
        uuid = uuid,
        lnum = match.lx,
        col = match.cx,
        text = text,
        highlights = highlights,
        preview = {
          offset = match.ox,
          lnum = match.lx,
          col = match.cx,
          content = match.s or "",
        },
      }
      items[#items + 1] = item
    end
  end

  table.sort(items, function(a, b)
    if a.filepath ~= b.filepath then
      return a.filepath < b.filepath
    end
    if a.lnum ~= b.lnum then
      return a.lnum < b.lnum
    end
    if a.col ~= b.col then
      return a.col < b.col
    end
    return a.preview.offset < b.preview.offset
  end)

  ---@type dot.module.searcher.view.filetree.ISearchResult
  local result = {
    items = items,
    filematch_map = filematch_map,
  }
  return result
end

---@param cwd                           string
---@param filepaths                     string[]
---@return dot.module.searcher.FiletreeView
function M:reset_filepaths(cwd, filepaths)
  self:__health__()

  local selected_set = self:collect_selected() ---@type table<string, true>
  self:clear()

  local filetree = self._tree ---@type stl.c.IFiletree
  local tick_selected = self._tick_selected ---@type integer
  local statemap = self.statemap ---@type table<string, stl.view.tree.INodeState>
  ---@cast statemap                     table<string, dot.module.searcher.view.filetree.INodeState>

  filetree:reset(cwd, filepaths, false)
  filetree:unsafe_traverse(filetree.root, function(ctx)
    local nodemap = ctx.nodemap ---@type table<string, stl.c.IFiletreeNode>
    local rootnode = ctx.rootnode ---@type stl.c.IFiletreeNode

    ---@param node                      stl.c.IFiletreeNode
    ---@return nil
    local function traverse(node)
      if node.data.filetype == "directory" then
        ---@type dot.module.searcher.view.filetree.IDirectoryNodeState
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
          local childnode = nodemap[uuid] ---@type stl.c.IFiletreeNode|nil
          if childnode ~= nil then
            traverse(childnode)
          end
        end
        return
      end

      if node.data.filetype == "file" then
        ---@type dot.module.searcher.view.filetree.IFileNodeState
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

      stl.reporter.error({
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

---@type dot.module.searcher.view.filetree.IListviewFileRenderer
function M.default_render_listview_leaf(ctx, node)
  local rootnode = ctx.rootnode ---@type stl.c.IFiletreeNode
  local fileicon = node.data.fileicon ---@type string
  local fileicon_hln = node.data.fileicon_hln ---@type string
  local filepath = #rootnode.data.filepath < 2 and node.data.filepath
    or node.data.filepath:sub(#rootnode.data.filepath + 2)
  local text = string.format("%s %s", fileicon, filepath) ---@type string
  local highlights = { { coll = 0, colr = #fileicon + 1, hlname = fileicon_hln } } ---@type stl.t.IHighlightInline[]
  return { text = text, highlights = highlights }
end

---@type dot.module.searcher.view.filetree.IListviewLocationRenderer
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
  return { text = text, highlights = highlights }
end

---@type dot.module.searcher.view.filetree.ITreeviewDirectoryRenderer
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
    return { text = text, highlights = highlights }
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

  return { text = text, highlights = highlights }
end

---@type dot.module.searcher.view.filetree.ITreeviewFileRenderer
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
  return { text = text, highlights = highlights }
end

---@type dot.module.searcher.view.filetree.ITreeviewLocationRenderer
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
  return { text = text, highlights = highlights }
end

return M
