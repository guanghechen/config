local __module_name__ = "era.m.searcher.view.plainfile" ---@type string

---@class era.m.searcher.IPlainfileViewContext
---@field public flag_case_sensitive    stl.c.Observable
---@field public flag_regex             stl.c.Observable
---@field public flag_replace           stl.c.Observable
---@field public search_pattern         stl.c.Observable
---@field public replace_pattern        stl.c.Observable
---
---@field public filepath               string
---@field public filematch              era.m.searcher.view.filetree.IResolvedFileMatch|nil
---@field public offset_current         integer
---@field public match_offsets          integer[]

---@class era.m.searcher.IPlainfileViewHighlight : stl.t.IHighlight
---@field public offset                 integer

---@class era.m.searcher.IPlainfileViewData
---@field public filepath               string
---@field public filetype               string|nil
---@field public lines                  string[]
---@field public highlights             era.m.searcher.IPlainfileViewHighlight[]
---@field public title                  string

---@class era.m.searcher.IPlainfileViewProps
---@field public name                   string

---@class era.m.searcher.PlainfileView
---@field public fullname               string
---@field public nsnr                   integer
---@field protected _disposed           boolean
---@field protected _last_bufnr         integer|nil
---@field protected _last_data          era.m.searcher.IPlainfileViewData|nil
local M = {}
M.__index = M

---@param props                         era.m.searcher.IPlainfileViewProps
---@return era.m.searcher.PlainfileView
function M.new(props)
  local name = props.name ---@type string
  local fullname = string.format("%s -> %s", name, __module_name__) ---@type string

  local self = setmetatable({}, M)

  self.fullname = fullname
  self._disposed = false
  self._last_bufnr = nil
  self._last_data = nil
  return self
end

---@return era.m.searcher.PlainfileView
function M:clear()
  self:__health__()

  self._last_bufnr = nil
  self._last_data = nil
  return self
end

---@return nil
function M:dispose()
  if self._disposed then
    return nil
  end
  self._disposed = true

  self._last_bufnr = nil
  self._last_data = nil
end

---@return boolean
function M:isdisposed()
  return self._disposed
end

----------------------------------------------------------------------------------------------------

---@param context                       era.m.searcher.IPlainfileViewContext
---@return era.m.searcher.IPlainfileViewData
function M:calc_preview_data(context)
  local filepath = context.filepath ---@type string
  local filename = yoz.path.basename(filepath) ---@type string
  if not stl.filetype.is_printable_file(filename) then
    local lines = { "  Not a text file, cannot preview." } ---@type string[]

    ---@type era.m.searcher.IPlainfileViewHighlight[]
    local highlights = { { offset = -1, lnum = 1, coll = 0, colr = -1, hlname = "m_sr_error" } }

    ---@type era.m.searcher.IPlainfileViewData
    local result = {
      filepath = context.filepath,
      filetype = nil,
      highlights = highlights,
      lines = lines,
      title = filepath,
    }
    return result
  end

  local filetype = vim.filetype.match({ filename = filename }) ---@type string|nil
  local flag_case_sensitive = context.flag_case_sensitive:snapshot() ---@type boolean
  local flag_regex = context.flag_regex:snapshot() ---@type boolean
  local flag_replace = context.flag_replace:snapshot() ---@type boolean
  local search_pattern = context.search_pattern:snapshot() ---@type string
  local replace_pattern = context.replace_pattern:snapshot() ---@type string
  local match_offsets = context.match_offsets ---@type integer[]
  local lines = {} ---@type string[]
  local highlights = {} ---@type era.m.searcher.IPlainfileViewHighlight[]

  if flag_replace then
    local preview_result, preview_error = yoz.replace.replace_file_preview_by_matches_advance({
      filepath = filepath,
      search_pattern = search_pattern,
      replace_pattern = replace_pattern,
      keep_search_pieces = true,
      flag_regex = flag_regex,
      flag_case_sensitive = flag_case_sensitive,
      match_offsets = match_offsets,
    })

    if preview_result == nil then
      if preview_error ~= nil then
        stl.reporter.error({
          from = __module_name__,
          subject = "replace_file_preview_by_matches_advance",
          message = preview_error,
        })
      end
      local fallback_lines = stl.fs.read_file_as_lines({ filepath = filepath, silent = true }) or {} ---@type string[]
      preview_result = { text = table.concat(fallback_lines, "\n"), matches = {} }
    end

    local preview_text = preview_result.text ---@type string
    local lwidths = yoz.string.calc_linewidths(preview_text) ---@type integer[]
    lines = yoz.string.parse_lines(preview_text, lwidths) ---@type string[]
    highlights = {} ---@type era.m.searcher.IPlainfileViewHighlight[]
    local matches = preview_result.matches ---@type dot.t.IMatchPoint[]

    local lnum0 = 1 ---@type integer
    local k = 1 ---@type integer
    local offset = 0 ---@type integer
    local lwidth = lwidths[1] + 1 ---@type integer

    local offset_delta = 0 ---@type integer
    local match_offset = 0 ---@type integer
    local is_search_match = false ---@type boolean
    for _, match in ipairs(matches) do
      is_search_match = not is_search_match
      if is_search_match then
        match_offset = match.l - offset_delta ---@type integer
      else
        offset_delta = offset_delta + (match.r - match.l)
      end

      local hlname = is_search_match and "m_sr_search" or "m_sr_replace"

      local l = match.l ---@type integer
      local r = match.r ---@type integer
      while l < r do
        while l >= offset + lwidth and k < #lwidths do
          k = k + 1
          offset = offset + lwidth
          lwidth = lwidths[k] + 1
        end

        local lnum = lnum0 + k - 1 ---@type integer
        local col = l - offset ---@type integer
        local col_end = math.min(lwidth, r - offset) ---@type integer
        l = offset + lwidth ---@type integer

        highlights[#highlights + 1] =
          { offset = match_offset, lnum = lnum, coll = col, colr = col_end, hlname = hlname }
      end
    end
  else
    lines = stl.fs.read_file_as_lines({ filepath = filepath, silent = true }) or {} ---@type string[]
    highlights = {} ---@type era.m.searcher.IPlainfileViewHighlight[]

    if context.filematch ~= nil then
      for _, match in ipairs(context.filematch.matches) do
        if vim.list_contains(match_offsets, match.ox) then
          local start_line = match.lx ---@type integer
          local end_line = match.ly ---@type integer

          for lnum = start_line, end_line, 1 do
            local line_text = lines[lnum] or "" ---@type string
            local line_len = #line_text ---@type integer
            local col_start = (lnum == start_line) and match.cx or 0 ---@type integer
            local col_end = (lnum == end_line) and (match.cy + 1) or line_len ---@type integer

            col_start = math.max(0, math.min(col_start, line_len))
            col_end = math.max(col_start, math.min(col_end, line_len))

            highlights[#highlights + 1] = {
              offset = match.ox,
              lnum = lnum,
              coll = col_start,
              colr = col_end,
              hlname = "m_sr_match",
            }
          end
        end
      end
    end
  end

  ---@type era.m.searcher.IPlainfileViewData
  local result = {
    filepath = filepath,
    filetype = filetype,
    highlights = highlights,
    lines = lines,
    title = filepath,
  }
  return result
end

---@return nil
function M:mark_dirty()
  self:__health__()

  self._last_data = nil
  return self
end

---@param context                       era.m.searcher.IPlainfileViewContext
---@param data                          era.m.searcher.IPlainfileViewData
---@return stl.t.IHighlight[]
function M:patch_preview_data(context, data)
  local highlights = {} ---@type stl.t.IHighlight[]
  local flag_replace = context.flag_replace:snapshot() ---@type boolean
  local offset_current = context.offset_current ---@type integer

  if flag_replace then
    local resolved = false ---@type boolean
    for _, hl in ipairs(data.highlights) do
      if offset_current == hl.offset then
        resolved = true
        local is_search_match = hl.hlname == "m_sr_search" ---@type boolean
        local hlname = is_search_match and "m_sr_search_cur" or "m_sr_replace_cur" ---@type string
        local highlight = { lnum = hl.lnum, coll = hl.coll, colr = hl.colr, hlname = hlname } ---@type stl.t.IHighlight
        highlights[#highlights + 1] = highlight
      elseif resolved then
        break
      end
    end
  else
    local resolved = false ---@type boolean
    for _, hl in ipairs(data.highlights) do
      if offset_current == hl.offset then
        resolved = true
        local hlname = "m_sr_match_cur" ---@type string
        local highlight = { lnum = hl.lnum, coll = hl.coll, colr = hl.colr, hlname = hlname } ---@type stl.t.IHighlight
        highlights[#highlights + 1] = highlight
      elseif resolved then
        break
      end
    end
  end

  return highlights
end

---@param context                       era.m.searcher.IPlainfileViewContext
---@param bufnr                         integer
---@param filepath                      string
---@param force                         boolean
---@return era.m.searcher.PlainfileView
function M:render(context, bufnr, filepath, force)
  self:__health__()

  local data = self._last_data ---@type era.m.searcher.IPlainfileViewData|nil
  if force or data == nil or data.filepath ~= filepath then
    data = self:calc_preview_data(context) ---@type era.m.searcher.IPlainfileViewData
    self._last_data = data
    force = true
  end

  if force or self._last_bufnr ~= bufnr then
    self._last_bufnr = bufnr
    local lines = data.lines ---@type string[]
    local filetype = data.filetype ---@type string

    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

    if filetype ~= nil and vim.treesitter ~= nil and vim.treesitter.language ~= nil then
      local lang = vim.treesitter.language.get_lang(filetype) or filetype
      local loaded = vim.treesitter.language.add(lang)
      if loaded then
        vim.treesitter.stop(bufnr)
        vim.treesitter.start(bufnr, lang)
      end
    end

    local nsnr = dot.var.nsnr.searcher_searched ---@type integer
    vim.api.nvim_buf_clear_namespace(bufnr, nsnr, 0, -1)
    for _, hl in ipairs(data.highlights) do
      local row = hl.lnum - 1 ---@type integer
      vim.hl.range(bufnr, nsnr, hl.hlname, { row, hl.coll }, { row, hl.colr })
    end
  end

  do
    local nsnr = dot.var.nsnr.searcher_searched_cur ---@type integer
    local patched_highlights = self:patch_preview_data(context, data) ---@type stl.t.IHighlight[]

    vim.api.nvim_buf_clear_namespace(bufnr, nsnr, 0, -1)
    for _, hl in ipairs(patched_highlights) do
      local row = hl.lnum - 1 ---@type integer
      vim.hl.range(bufnr, nsnr, hl.hlname, { row, hl.coll }, { row, hl.colr })
    end
  end

  return self
end

----------------------------------------------------------------------------------------------------

---@return nil
function M:__health__()
  if self._disposed then
    local message = string.format("[%s] has been disposed.", self.fullname) ---@type string
    error(message)
  end
end

return M
