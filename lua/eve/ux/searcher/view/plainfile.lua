local __module_name__ = "eve.ux.searcher.view.plainfile" ---@type string

---@class eve.ux.searcher.IPlainfileViewContext
---@field public flag_case_sensitive    std.collection.IObservable
---@field public flag_regex             std.collection.IObservable
---@field public flag_replace           std.collection.IObservable
---@field public search_pattern         std.collection.IObservable
---@field public replace_pattern        std.collection.IObservable
---
---@field public filepath               string
---@field public filematch              oxi.searcher.IFileMatch|nil
---@field public offset_current         integer
---@field public match_offsets          integer[]

---@class eve.ux.searcher.IPlainfileViewHighlight : std.t.IHighlight
---@field public offset                 integer

---@class eve.ux.searcher.IPlainfileViewData
---@field public filepath               string
---@field public filetype               string|nil
---@field public lines                  string[]
---@field public highlights             eve.ux.searcher.IPlainfileViewHighlight[]
---@field public title                  string

---@class eve.ux.searcher.IPlainfileViewProps
---@field public name                   string

---@class eve.ux.searcher.PlainfileView
---@field public fullname               string
---@field public nsnr                   integer
---@field protected _disposed           boolean
---@field protected _last_bufnr         integer|nil
---@field protected _last_data          eve.ux.searcher.IPlainfileViewData|nil
local M = {}
M.__index = M

---@param props                         eve.ux.searcher.IPlainfileViewProps
---@return eve.ux.searcher.PlainfileView
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

---@return eve.ux.searcher.PlainfileView
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

---@param context                       eve.ux.searcher.IPlainfileViewContext
---@return eve.ux.searcher.IPlainfileViewData
function M:calc_preview_data(context)
  local filepath = context.filepath ---@type string
  local filename = std.path.basename(filepath) ---@type string
  if not eve.filetype.is_printable_file(filename) then
    local lines = { "  Not a text file, cannot preview." } ---@type string[]

    ---@type eve.ux.searcher.IPlainfileViewHighlight[]
    local highlights = { { offset = -1, lnum = 1, coll = 0, colr = -1, hlname = "f_sr_error" } }

    ---@type eve.ux.searcher.IPlainfileViewData
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
  local highlights = {} ---@type eve.ux.searcher.IPlainfileViewHighlight[]

  if flag_replace then
    ---@type oxi.replacer.replace_file_preview_by_matches_advance.IResult
    local preview_result = oxi.replacer.replace_file_preview_by_matches_advance({
      flag_case_sensitive = flag_case_sensitive,
      flag_regex = flag_regex,
      search_pattern = search_pattern,
      replace_pattern = replace_pattern,
      filepath = filepath,
      keep_search_pieces = true,
      match_offsets = match_offsets,
    })

    lines = preview_result.lines ---@type string[]
    highlights = {} ---@type eve.ux.searcher.IPlainfileViewHighlight[]
    local lwidths = preview_result.lwidths ---@type integer[]
    local matches = preview_result.matches ---@type std.t.IMatchPoint[]

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

      local hlname = is_search_match and "f_sr_search" or "f_sr_replace"

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
    lines = std.fs.read_file_as_lines({ filepath = filepath, silent = true }) ---@type string[]
    highlights = {} ---@type eve.ux.searcher.IPlainfileViewHighlight[]

    if context.filematch ~= nil then
      for _, block_match in ipairs(context.filematch.matches) do
        local lwidths = block_match.lwidths ---@type integer[]
        local lnum0 = block_match.lnum ---@type integer

        local k = 1 ---@type integer
        local offset = 0 ---@type integer
        local lwidth = lwidths[1] + 1 ---@type integer
        for _, search_match in ipairs(block_match.matches) do
          local match_offset = block_match.offset + search_match.l ---@type integer
          if vim.list_contains(match_offsets, match_offset) then
            local hlname = "f_sr_match" ---@type string

            local l = search_match.l ---@type integer
            local r = search_match.r ---@type integer
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
        end
      end
    end
  end

  ---@type eve.ux.searcher.IPlainfileViewData
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

---@param context                       eve.ux.searcher.IPlainfileViewContext
---@param data                          eve.ux.searcher.IPlainfileViewData
---@return std.t.IHighlight[]
function M:patch_preview_data(context, data)
  local highlights = {} ---@type std.t.IHighlight[]
  local flag_replace = context.flag_replace:snapshot() ---@type boolean
  local offset_current = context.offset_current ---@type integer

  if flag_replace then
    local resolved = false ---@type boolean
    for _, hl in ipairs(data.highlights) do
      if offset_current == hl.offset then
        resolved = true
        local is_search_match = hl.hlname == "f_sr_search" ---@type boolean
        local hlname = is_search_match and "f_sr_search_cur" or "f_sr_replace_cur" ---@type string
        local highlight = { lnum = hl.lnum, coll = hl.coll, colr = hl.colr, hlname = hlname } ---@type std.t.IHighlight
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
        local hlname = "f_sr_match_cur" ---@type string
        local highlight = { lnum = hl.lnum, coll = hl.coll, colr = hl.colr, hlname = hlname } ---@type std.t.IHighlight
        highlights[#highlights + 1] = highlight
      elseif resolved then
        break
      end
    end
  end

  return highlights
end

---@param context                       eve.ux.searcher.IPlainfileViewContext
---@param bufnr                         integer
---@param filepath                      string
---@param force                         boolean
---@return eve.ux.searcher.PlainfileView
function M:render(context, bufnr, filepath, force)
  self:__health__()

  local data = self._last_data ---@type eve.ux.searcher.IPlainfileViewData|nil
  if force or data == nil or data.filepath ~= filepath then
    data = self:calc_preview_data(context) ---@type eve.ux.searcher.IPlainfileViewData
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

    local nsnr = eve.var.nsnr.searcher_searched ---@type integer
    vim.api.nvim_buf_clear_namespace(bufnr, nsnr, 0, -1)
    for _, hl in ipairs(data.highlights) do
      local row = hl.lnum - 1 ---@type integer
      vim.hl.range(bufnr, nsnr, hl.hlname, { row, hl.coll }, { row, hl.colr })
    end
  end

  do
    local nsnr = eve.var.nsnr.searcher_searched_cur ---@type integer
    local patched_highlights = self:patch_preview_data(context, data) ---@type std.t.IHighlight[]

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
