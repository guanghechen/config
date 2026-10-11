---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.searcher.view.filetree" ---@type string

local Files = require("era.view.result_files")
local Paths = require("era.view.result_paths")

---@class era.m.searcher.view.filetree.IResolvedFileMatch
---@field public filepath               string
---@field public relative               string
---@field public matches                yoz.search.ITextMatch[]

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

---@param text                          string
---@return string
local function decode_preview_text(text)
  return text:gsub(stl.icon.listchars.eol, "\n")
end

---@param text                          string
---@return string
local function encode_preview_text(text)
  local sanitized = text:gsub("\r\n", "\n"):gsub("\r", "\n")
  return sanitized:gsub("\n", stl.icon.listchars.eol)
end

---@class era.m.searcher.FiletreeView : era.view.ResultFiles
local M = setmetatable({}, { __index = Files })
M.__index = M

---@param props                         table
---@return era.m.searcher.FiletreeView
function M.new(props)
  return setmetatable(Files.new(props), M)
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

  ---@param relpath                     string
  ---@return string
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
    local uuid = Paths.key(filepath) ---@type string

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

---@param result                        era.m.searcher.view.filetree.ISearchResult
---@param uuids                         string[]
---@return nil
function M:publish_search_result(result, uuids)
  for key, match in pairs(result.filematch_map) do
    if self.entries[key] then
      self.entries[key].filematch = match
    end
  end
  for _, item in ipairs(result.items) do
    if self.entries[item.uuid] then
      self:add_location(item.uuid, {
        locationuuid = string.format("%s:%d:%d:%d", item.uuid, item.lnum, item.col, item.preview.offset),
        lnum = item.lnum,
        col = item.col,
        text = item.text,
        highlights = item.highlights,
        match = item,
      })
    end
  end
  self:invalidate()
end

---@param leaf                          era.view.result_tree.IEntry
---@return nil
function M:remove_visible_locations(leaf)
  local entry = self.entries[leaf.key]
  if not entry or not entry.locations then
    return
  end
  local remaining = {}
  for _, location in ipairs(entry.locations) do
    if self:isvisible(location.locationuuid) then
      self.entries[location.locationuuid] = nil
    else
      remaining[#remaining + 1] = location
    end
  end
  entry.locations = remaining
  self:invalidate()
end

return M
