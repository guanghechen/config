---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.searcher.view.filetree" ---@type string

local tree_cache = require("era.view.tree.cache")
local tree_collapse = require("era.view.tree.collapse")
local tree_lifecycle = require("era.view.tree.lifecycle")
local tree_selection = require("era.view.tree.selection")
local tree_store = require("era.view.tree.store")
local tree_traversal = require("era.view.tree.traversal")
local tree_visibility = require("era.view.tree.visibility")

---@alias era.m.searcher.view.filetree.INodeState
---| era.m.searcher.view.filetree.IDirectoryNodeState
---| era.m.searcher.view.filetree.IFileNodeState
---| era.m.searcher.view.filetree.ILeafLocationState

---@alias era.m.searcher.view.filetree.IListviewFileRenderer
---| fun(ctx: era.m.searcher.view.filetree.IListviewRendererContext, uuid: string, data: stl.c.IFiletreeNodeData, nodestate: era.m.searcher.view.filetree.IFileNodeState, lnum: integer): string, stl.t.IHighlightInline[]|nil

---@alias era.m.searcher.view.filetree.IListviewLocationRenderer
---| fun(ctx: era.m.searcher.view.filetree.IListviewRendererContext, uuid: string, data: stl.c.IFiletreeNodeData, nodestate: era.m.searcher.view.filetree.IFileNodeState, locationstate: era.m.searcher.view.filetree.ILeafLocationState, lnum: integer): string, stl.t.IHighlightInline[]|nil

---@alias era.m.searcher.view.filetree.ITreeviewDirectoryRenderer
---| fun(ctx: era.m.searcher.view.filetree.ITreeviewRendererContext, uuid: string, data: stl.c.IFiletreeNodeData, nodestate: era.m.searcher.view.filetree.IDirectoryNodeState, lnum: integer, folded_depth: integer): string, stl.t.IHighlightInline[]|nil

---@alias era.m.searcher.view.filetree.ITreeviewFileRenderer
---| fun(ctx: era.m.searcher.view.filetree.ITreeviewRendererContext, uuid: string, data: stl.c.IFiletreeNodeData, nodestate: era.m.searcher.view.filetree.IFileNodeState, lnum: integer): string, stl.t.IHighlightInline[]|nil

---@alias era.m.searcher.view.filetree.ITreeviewLocationRenderer
---| fun(ctx: era.m.searcher.view.filetree.ITreeviewRendererContext, uuid: string, data: stl.c.IFiletreeNodeData, nodestate: era.m.searcher.view.filetree.IFileNodeState, locationstate: era.m.searcher.view.filetree.ILeafLocationState, lnum: integer): string, stl.t.IHighlightInline[]|nil

---@class era.m.searcher.view.filetree.IDirectoryNodeState : era.view.tree.IContainerNodeState

---@class era.m.searcher.view.filetree.IFileNodeState : era.view.tree.ILeafNodeState
---@field public locations              era.m.searcher.view.filetree.ILeafLocationState|nil
---@field public filematch              era.m.searcher.view.filetree.IResolvedFileMatch|nil

---@class era.m.searcher.view.filetree.ILeafLocationState : era.view.tree.ILeafLocationState
---@field public lnum                   integer
---@field public col                    ?integer
---@field public col_end                ?integer
---@field public text                   ?string
---@field public highlights             ?stl.t.IHighlightInline[]
---
---@field public match                  era.m.searcher.view.filetree.ISearchedItem

---@class era.m.searcher.view.filetree.IResolvedFileMatch
---@field public filepath               string
---@field public relative               string
---@field public matches                yoz.search.ITextMatch[]

---@class era.m.searcher.view.filetree.IListviewRendererContext : era.view.tree.IListviewRendererContext
---@field public rootdata               stl.c.IFiletreeNodeData
---@field public rootstate              era.m.searcher.view.filetree.IDirectoryNodeState
---@field public tree                   stl.c.IReadonlyFiletree
---@field public view                   era.m.searcher.FiletreeView

---@class era.m.searcher.view.filetree.ITreeviewRendererContext : era.view.tree.IListviewRendererContext
---@field public rootdata               stl.c.IFiletreeNodeData
---@field public rootstate              era.m.searcher.view.filetree.IDirectoryNodeState
---@field public tree                   stl.c.IReadonlyFiletree
---@field public view                   era.m.searcher.FiletreeView

---@class era.m.searcher.view.filetree.ISearchParams
---@field public flag_case_sensitive    boolean
---@field public flag_exclude           boolean
---@field public flag_gitignore         boolean
---@field public flag_regex             boolean
---@field public flag_replace           boolean
---@field public max_filesize           string
---@field public max_matches            integer|nil
---
---@field public excludes               string[]
---@field public includes               string[]
---
---@field public cwd                    string
---@field public specified_filepath     string|nil
---@field public search_pattern         string
---@field public replace_pattern        string|nil

---@class era.m.searcher.view.filetree.ISearchResult
---@field public items                  era.m.searcher.view.filetree.ISearchedItem[]
---@field public filematch_map          table<string, era.m.searcher.view.filetree.IResolvedFileMatch>
---@field public limit_reached          boolean

---@class era.m.searcher.view.filetree.ISearchedPreviewItem
---@field public offset                 integer
---@field public lnum                   integer
---@field public col                    integer
---@field public content                string

---@class era.m.searcher.view.filetree.ISearchedItem
---@field public filepath               string
---@field public uuid                   string
---
---@field public lnum                   integer
---@field public col                    integer
---@field public text                   string
---@field public highlights             stl.t.IHighlightInline[]
---
---@field public preview                era.m.searcher.view.filetree.ISearchedPreviewItem

local function decode_preview_text(text)
  return text:gsub(stl.icon.listchars.eol, "\n")
end

local function encode_preview_text(text)
  local sanitized = text:gsub("\r\n", "\n"):gsub("\r", "\n")
  return sanitized:gsub("\n", stl.icon.listchars.eol)
end

----------------------------------------------------------------------------------------------------

---@class era.m.searcher.view.IFiletreeProps
---@field public name                   string
---@field public tree                   stl.c.IFiletree
---@field public indent                 ?string
---@field public indent_hln             ?string
---
---@field public render_listview_leaf   ?era.m.searcher.view.filetree.IListviewFileRenderer
---@field public render_listview_location   ?era.m.searcher.view.filetree.IListviewLocationRenderer
---@field public render_treeview_container  ?era.m.searcher.view.filetree.ITreeviewDirectoryRenderer
---@field public render_treeview_leaf   ?era.m.searcher.view.filetree.ITreeviewFileRenderer
---@field public render_treeview_location   ?era.m.searcher.view.filetree.ITreeviewLocationRenderer

local tree_render = era.view.TreeRenderer ---@type era.view.TreeRenderer

---@class era.m.searcher.FiletreeView
---@field protected _tree               stl.c.IFiletree
---@field public statemap               table<string, era.m.searcher.view.filetree.INodeState>
---@field public insert                 fun(self: era.m.searcher.FiletreeView, uuid: string, state: era.view.tree.INodeState): era.m.searcher.FiletreeView
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
M.render_listview = tree_render.render_listview
M.render_treeview = tree_render.render_treeview

---@param props                         era.m.searcher.view.IFiletreeProps
---@return era.m.searcher.FiletreeView
function M.new(props)
  local name = props.name ---@type string
  local fullname = string.format("%s -> %s", name, __module_name__) ---@type string
  local indent = props.indent ---@type string|nil
  local indent_hln = props.indent_hln ---@type string|nil
  local tree = props.tree ---@type stl.c.IFiletree

  local render_listview_leaf = props.render_listview_leaf or M.default_render_listview_leaf ---@type era.m.searcher.view.filetree.IListviewFileRenderer
  local render_listview_location = props.render_listview_location or M.default_render_listview_location ---@type era.m.searcher.view.filetree.IListviewLocationRenderer
  local render_treeview_container = props.render_treeview_container or M.default_render_treeview_container ---@type era.m.searcher.view.filetree.ITreeviewDirectoryRenderer
  local render_treeview_leaf = props.render_treeview_leaf or M.default_render_treeview_leaf ---@type era.m.searcher.view.filetree.ITreeviewFileRenderer
  local render_treeview_location = props.render_treeview_location or M.default_render_treeview_location ---@type era.m.searcher.view.filetree.ITreeviewLocationRenderer

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
  ---@cast self                         era.m.searcher.FiletreeView

  return self
end

----------------------------------------------------------------------------------------------------

---@return era.m.searcher.FiletreeView
function M:clear()
  self:__health__()

  tree_lifecycle.clear(self)
  return self
end

---@return nil
function M:dispose()
  if self._disposed then
    return nil
  end

  tree_lifecycle.dispose(self)
end

---@return era.m.searcher.FiletreeView
function M:mark_cache_match_dirty()
  self:__health__()
  return self
end

---@param uuid                          string
---@return era.m.searcher.view.filetree.INodeState|nil
function M:retrieve(uuid)
  self:__health__()

  local statemap = self.statemap ---@type table<string, era.view.tree.INodeState>
  ---@cast statemap                     table<string, era.m.searcher.view.filetree.INodeState>

  local nodestate = statemap[uuid] ---@type era.m.searcher.view.filetree.INodeState|nil
  return nodestate
end

----------------------------------------------------------------------------------------------------

---@param root                          string|nil
---@return string[]
function M:collect_file_uuids(root)
  return self:collect_leafs(root)
end

---@param params                        era.m.searcher.view.filetree.ISearchParams
---@return yoz.search.ISearchInFilesOptions
function M:build_search_options(params)
  local excludes = params.flag_exclude and params.excludes or {} ---@type string[]
  local specified_filepath = params.specified_filepath ---@type string|nil
  return {
    cwd = yoz.canonical_path.to_os_path(params.cwd),
    flag_case_sensitive = params.flag_case_sensitive,
    flag_gitignore = params.flag_gitignore,
    flag_regex = params.flag_regex,
    max_filesize = params.max_filesize,
    max_matches = params.max_matches,
    search_pattern = params.search_pattern,
    search_paths = "",
    include_patterns = table.concat(params.includes, ","),
    exclude_patterns = table.concat(excludes, ","),
    specified_filepath = specified_filepath and yoz.canonical_path.to_os_path(specified_filepath) or nil,
  }
end

---@param params                        era.m.searcher.view.filetree.ISearchParams
---@return yoz.search.SearchInFilesJob
function M:start_search(params)
  self:__health__()
  return yoz.search.start_search_in_files(self:build_search_options(params))
end

---@param params                        era.m.searcher.view.filetree.ISearchParams
---@return era.m.searcher.view.filetree.ISearchResult|nil
function M:search(params)
  self:__health__()

  ---@type yoz.search.ISearchFileResult|nil, yoz.search.ISearchFailedResult|nil
  local results, err = yoz.search.search_in_files(self:build_search_options(params))
  if results == nil or results.items == nil then
    stl.reporter.error({
      from = self.fullname,
      subject = "search",
      message = "Failed to perform the search action.",
      details = {
        params = params,
        error = err and err.error or err,
      },
    })
    return
  end
  return self:normalize_search_result(params, results)
end

---@param params                        era.m.searcher.view.filetree.ISearchParams
---@param results                       yoz.search.ISearchFileResult
---@return era.m.searcher.view.filetree.ISearchResult
function M:normalize_search_result(params, results)
  self:__health__()
  if type(results) ~= "table" or type(results.items) ~= "table" or type(results.limit_reached) ~= "boolean" then
    error("invalid native search result")
  end

  local flag_case_sensitive = params.flag_case_sensitive ---@type boolean
  local flag_regex = params.flag_regex ---@type boolean
  local flag_replace = params.flag_replace ---@type boolean

  local cwd = yoz.canonical_path.from_os_path(params.cwd, false) ---@type string
  local search_pattern = params.search_pattern ---@type string
  local replace_pattern = params.replace_pattern ---@type string|nil

  local has_replace_preview = flag_replace and replace_pattern ~= nil and replace_pattern ~= ""
  local search_highlight = has_replace_preview and "m_ss_search" or "m_ss_matches"

  local function resolve_filepath(relpath)
    if relpath == "" then
      return cwd
    end
    if yoz.canonical_path.is_absolute(relpath) then
      return relpath
    end
    return yoz.canonical_path.join(cwd, relpath, false)
  end

  local items = {} ---@type era.m.searcher.view.filetree.ISearchedItem[]
  local filematch_map = {} ---@type table<string, era.m.searcher.view.filetree.IResolvedFileMatch>

  for _, filematch in ipairs(results.items) do
    local relpath = filematch.p or "" ---@type string
    if relpath:find("\\", 1, true) ~= nil then
      relpath = yoz.canonical_path.from_os_path(relpath, false)
    end
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

      ---@type era.m.searcher.view.filetree.ISearchedItem
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

  ---@type era.m.searcher.view.filetree.ISearchResult
  local result = {
    items = items,
    filematch_map = filematch_map,
    limit_reached = results.limit_reached,
  }
  return result
end

---@param cwd                           string
---@param filepaths                     string[]
---@return era.m.searcher.FiletreeView
function M:reset_filepaths(cwd, filepaths)
  self:__health__()

  local selected_set = self:collect_selected() ---@type table<string, true>
  self:clear()

  local filetree = self._tree ---@type stl.c.IFiletree
  local tick_selected = self._tick_selected ---@type integer
  local statemap = self.statemap ---@type table<string, era.view.tree.INodeState>
  ---@cast statemap                     table<string, era.m.searcher.view.filetree.INodeState>

  filetree:reset(cwd, filepaths, false)
  tree_traversal.preorder(filetree, filetree.root, function(uuid)
    local data = filetree:get(uuid) ---@type stl.c.IFiletreeNodeData
    if data.filetype == "directory" then
      ---@type era.m.searcher.view.filetree.IDirectoryNodeState
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
      ---@type era.m.searcher.view.filetree.IFileNodeState
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

  return self
end

---@param result                        era.m.searcher.view.filetree.ISearchResult
---@param uuids                         string[]
---@return era.m.searcher.FiletreeView
function M:publish_search_result(result, uuids)
  self:__health__()
  self:mark_cache_match_dirty()

  local filetree = self._tree ---@type stl.c.IFiletree
  local tick_matched = self._tick_matched ---@type integer
  local statemap = self.statemap ---@type table<string, era.m.searcher.view.filetree.INodeState>
  local items = result.items ---@type era.m.searcher.view.filetree.ISearchedItem[]
  local filematch_map = result.filematch_map ---@type table<string, era.m.searcher.view.filetree.IResolvedFileMatch>

  local N, i, j = #items, 1, 0 ---@type integer, integer, integer
  while i <= N do
    local nodeuuid = items[i].uuid ---@type string
    j = i + 1
    while j <= N and items[j].uuid == nodeuuid do
      j = j + 1
    end

    local leafnode = statemap[nodeuuid] ---@type era.m.searcher.view.filetree.INodeState|nil
    if leafnode == nil then
      stl.reporter.error({
        from = self.fullname,
        subject = "publish_search_result",
        message = string.format("Cannot retrieve node state by the given uuid: %s", nodeuuid),
        details = { nodeuuid = nodeuuid, items = vim.list_slice(items, i, j - 1), N = N },
      })
    else
      leafnode.filematch = filematch_map[nodeuuid]

      local L = 0 ---@type integer
      local locations = leafnode.locations or {} ---@type era.m.searcher.view.filetree.ILeafLocationState[]
      for k = i, j - 1, 1 do
        local item = items[k] ---@type era.m.searcher.view.filetree.ISearchedItem
        local location = {
          nodetype = "location",
          leafuuid = nodeuuid,
          locationuuid = string.format("%s:%d:%d", nodeuuid, item.lnum, item.col),
          tick_invisible = 0,
          lnum = item.lnum,
          col = item.col,
          text = item.text,
          highlights = item.highlights,
          match = item,
        } ---@type era.m.searcher.view.filetree.ILeafLocationState
        statemap[location.locationuuid] = location
        L = L + 1
        locations[L] = location
      end
      stl.table.truncate_inline(locations, L)
      leafnode.locations = locations
      leafnode.tick_matched = tick_matched
    end

    i = j
  end

  for _, uuid in ipairs(uuids) do
    local parentuuid = filetree:parent(uuid) ---@type string|nil
    while parentuuid ~= nil and parentuuid ~= filetree.root do
      local state = statemap[parentuuid]
      if state == nil or state.tick_matched == tick_matched then
        break
      end
      state.tick_matched = tick_matched
      parentuuid = filetree:parent(parentuuid)
    end
  end

  self:mark_cache_treeview_dirty()
  return self
end

---@param leafstate                     era.m.searcher.view.filetree.IFileNodeState
---@return era.m.searcher.FiletreeView
function M:remove_visible_locations(leafstate)
  self:__health__()

  local locations = leafstate.locations ---@type era.m.searcher.view.filetree.ILeafLocationState[]|nil
  if locations == nil then
    return self
  end

  local statemap = self.statemap ---@type table<string, era.m.searcher.view.filetree.INodeState>
  local tick_invisible = self._tick_invisible ---@type integer
  local count = 0 ---@type integer
  for _, location in ipairs(locations) do
    if location.tick_invisible ~= tick_invisible then
      statemap[location.locationuuid] = nil
    else
      count = count + 1
      locations[count] = location
    end
  end
  stl.table.truncate_inline(locations, count)
  return self
end

----------------------------------------------------------------------------------------------------

---@type era.m.searcher.view.filetree.IListviewFileRenderer
function M.default_render_listview_leaf(ctx, _, data)
  local rootdata = ctx.rootdata ---@type stl.c.IFiletreeNodeData
  local fileicon = data.fileicon ---@type string
  local fileicon_hln = data.fileicon_hln ---@type string
  local filepath = #rootdata.filepath < 2 and data.filepath or data.filepath:sub(#rootdata.filepath + 2)
  local text = string.format("%s %s", fileicon, filepath) ---@type string
  local highlights = { { coll = 0, colr = #fileicon + 1, hlname = fileicon_hln } } ---@type stl.t.IHighlightInline[]
  return text, highlights
end

---@type era.m.searcher.view.filetree.IListviewLocationRenderer
function M.default_render_listview_location(_, _, _, _, locationstate)
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

---@type era.m.searcher.view.filetree.ITreeviewDirectoryRenderer
function M.default_render_treeview_container(ctx, uuid, data, nodestate, _, folded_depth)
  local basename = data.basename ---@type string
  local fileicon = data.fileicon ---@type string
  local fileicon_hln = data.fileicon_hln ---@type string
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

  local current_basename = basename ---@type string
  for index = folded_depth, 1, -1 do
    local parentuuid = tree:parent(uuid) ---@type string|nil
    local parentdata = parentuuid ~= nil and tree:get(parentuuid) or nil ---@type stl.c.IFiletreeNodeData|nil
    if parentuuid ~= nil and parentdata ~= nil then
      uuid = parentuuid
      current_basename = parentdata.basename
    end
    basenames[index] = current_basename
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

---@type era.m.searcher.view.filetree.ITreeviewFileRenderer
function M.default_render_treeview_leaf(_, _, data)
  local basename = data.basename ---@type string
  local fileicon = data.fileicon ---@type string
  local fileicon_hln = data.fileicon_hln ---@type string
  local text = string.format("%s %s", fileicon, basename) ---@type string

  ---@type stl.t.IHighlightInline[]
  local highlights = {
    { coll = 0, colr = #fileicon + 1, hlname = fileicon_hln },
    { coll = #fileicon + 1, colr = #text, hlname = "m_ft_filename" },
  }
  return text, highlights
end

---@type era.m.searcher.view.filetree.ITreeviewLocationRenderer
function M.default_render_treeview_location(_, _, _, _, locationstate)
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
