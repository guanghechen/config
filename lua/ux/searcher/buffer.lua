---@diagnostic disable: invisible
local __module_name__ = "ux.searcher.buffer" ---@type string
local NSNR_SEARCH = vim.api.nvim_create_namespace("ux.searcher.buffer") ---@type integer
local NSNR_SEARCH_CURRENT = vim.api.nvim_create_namespace("ux.searcher.buffer.current") ---@type integer
local NSNR_REPLACE_PREVIEW = vim.api.nvim_create_namespace("ux.searcher.buffer.replace_preview") ---@type integer

----------------------------------------------------------------------------------------------------

---@param pattern_line_count            integer
---@return integer
local function calculate_dynamic_height(pattern_line_count)
  local base_height = 2 -- 1 line for input + 1 line for winbar reservation
  local extra_lines = math.min(pattern_line_count - 1, 4) -- Max 4 extra lines
  return base_height + extra_lines
end

---@param o_flag_fuzzy                  std.collection.IObservable
---@param o_flag_regex                  std.collection.IObservable
---@param o_flag_case_sensitive         std.collection.IObservable
---@param o_flag_replace                std.collection.IObservable
---@param title                         string
---@return ux.searcher.result.IFlagItem[], ux.searcher.result.IFlagItemRaw[]
local function create_flag_items(o_flag_fuzzy, o_flag_regex, o_flag_case_sensitive, o_flag_replace, title)
  ---@type ux.searcher.result.IFlagItemRaw[]
  local raw_flags = {
    {
      desc = string.format("%s: toggle fuzzy search", title),
      callback = function()
        o_flag_fuzzy:next(not o_flag_fuzzy:snapshot())
      end,
      snapshot = function()
        local enabled = o_flag_fuzzy:snapshot() ---@type boolean
        return std.icon.symbols.flag_fuzzy, enabled and "picker_flag_blue" or "picker_flag_grey"
      end,
    },
    {
      desc = string.format("%s: toggle regex search", title),
      callback = function()
        o_flag_regex:next(not o_flag_regex:snapshot())
      end,
      snapshot = function()
        local enabled = o_flag_regex:snapshot() ---@type boolean
        return std.icon.symbols.flag_regex, enabled and "picker_flag_blue" or "picker_flag_grey"
      end,
    },
    {
      desc = string.format("%s: toggle case sensitive", title),
      callback = function()
        o_flag_case_sensitive:next(not o_flag_case_sensitive:snapshot())
      end,
      snapshot = function()
        local enabled = o_flag_case_sensitive:snapshot() ---@type boolean
        return std.icon.symbols.flag_case_sensitive, enabled and "picker_flag_blue" or "picker_flag_grey"
      end,
    },
    {
      desc = string.format("%s: toggle replace mode", title),
      callback = function()
        o_flag_replace:next(not o_flag_replace:snapshot())
      end,
      snapshot = function()
        local enabled = o_flag_replace:snapshot() ---@type boolean
        return std.icon.symbols.flag_replace, enabled and "picker_flag_blue" or "picker_flag_grey"
      end,
    },
  }

  local flags = {} ---@type ux.searcher.result.IFlagItem[]
  for _, flag in ipairs(raw_flags) do
    flags[#flags + 1] = {
      desc = flag.desc,
      callback = eve.G.register_anonymous_fn(flag.callback) or "eve.G.noop",
      disabled = std.fn.falsy,
      snapshot = flag.snapshot,
    }
  end
  return flags, raw_flags
end

---@param bufnr                         integer
---@param namespace                     integer
---@param hlgroup                       string
---@param match                         yoz.search.ITextMatch
---@return nil
local function highlight_text_match(bufnr, namespace, hlgroup, match)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local line_count = vim.api.nvim_buf_line_count(bufnr) ---@type integer
  if line_count == 0 then
    return
  end

  local start_row = math.max(0, (match.lx or 1) - 1) ---@type integer
  local end_row = math.max(0, (match.ly or match.lx or 1) - 1) ---@type integer
  if start_row >= line_count then
    return
  end
  if end_row >= line_count then
    end_row = line_count - 1
  end

  local function line_length(row)
    if row < 0 or row >= line_count then
      return 0
    end
    local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
    return #line
  end

  local function highlight_range(row, col_start, col_end)
    if row < 0 or row >= line_count then
      return
    end
    col_start = math.max(0, col_start)
    col_end = math.max(col_start, col_end)
    vim.hl.range(bufnr, namespace, hlgroup, { row, col_start }, { row, col_end })
  end

  if start_row == end_row then
    highlight_range(start_row, match.cx or 0, (match.cy or (match.cx or 0)) + 1)
    return
  end

  highlight_range(start_row, match.cx or 0, line_length(start_row))

  for row = start_row + 1, end_row - 1 do
    highlight_range(row, 0, line_length(row))
  end

  highlight_range(end_row, 0, math.min((match.cy or 0) + 1, line_length(end_row)))
end

---@param bufnr                         integer
---@return string[]
---@return string
local function collect_buffer_content(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false) ---@type string[]
  return lines, table.concat(lines, "\n")
end

---@class ux.searcher.buffer.ISearcherProps
---@field public o_flag_fuzzy?          std.collection.IObservable
---@field public o_flag_regex?          std.collection.IObservable
---@field public o_flag_replace?        std.collection.IObservable
---@field public o_flag_case_sensitive? std.collection.IObservable
---@field public o_search_pattern?      std.collection.IObservable
---@field public o_search_pattern_history? std.collection.IHistory
---@field public o_replace_pattern?     std.collection.IObservable
---@field public o_replace_pattern_history? std.collection.IHistory

---@class ux.searcher.buffer.Searcher
---@field public title                  string
---@field public o_flag_fuzzy           std.collection.IObservable
---@field public o_flag_regex           std.collection.IObservable
---@field public o_flag_replace         std.collection.IObservable
---@field public o_flag_case_sensitive  std.collection.IObservable
---@field public o_search_pattern       std.collection.IObservable
---@field public o_search_pattern_linecount std.collection.IObservable
---@field public o_replace_pattern      std.collection.IObservable
---@field public o_match_index          std.collection.IObservable
---@field public o_match_total          std.collection.IObservable
---@field protected _winnr_finder       integer|nil
---@field protected _bufnr_finder       integer|nil
---@field protected _winnr_replacer     integer|nil
---@field protected _bufnr_replacer     integer|nil
---@field protected _winnr_source       integer|nil
---@field protected _bufnr_source       integer|nil
---@field protected _matches            yoz.search.ITextMatch[]|nil
---@field protected _scheduler_search   std.collection.Scheduler
---@field protected _nvimbar            ux.nvimbar.Nvimbar
---@field protected _finder_keymaps     std.t.IKeymap[]
---@field protected _replacer_keymaps   std.t.IKeymap[]
---@field protected _preserve_match_index integer|nil
---@field protected _last_focused_window "finder"|"replacer"
---@field protected _last_search_pattern string|nil
---@field protected _last_bufnr_source  integer|nil
local M = {}
M.__index = M

---@param props                         ux.searcher.buffer.ISearcherProps|nil
---@return ux.searcher.buffer.Searcher
function M.new(props)
  props = props or {}
  local o_flag_fuzzy = props.o_flag_fuzzy or std.Observable.from_value(false)
  local o_flag_regex = props.o_flag_regex or std.Observable.from_value(false)
  local o_flag_replace = props.o_flag_replace or std.Observable.from_value(false)
  local o_flag_case_sensitive = props.o_flag_case_sensitive or std.Observable.from_value(true)
  local o_search_pattern = props.o_search_pattern or std.Observable.from_value("")
  local o_replace_pattern = props.o_replace_pattern or std.Observable.from_value("")
  local o_search_pattern_linecount = std.Observable.from_value(1)
  local o_match_index = std.Observable.from_value(0)
  local o_match_total = std.Observable.from_value(0)

  local self = setmetatable({}, M)
  self.title = "Search in Buffer"
  self.o_flag_replace = o_flag_replace

  local flags, raw_flags =
    create_flag_items(o_flag_fuzzy, o_flag_regex, o_flag_case_sensitive, o_flag_replace, self.title)

  local finder_keymaps = self:__create_keymaps__(raw_flags, "finder")
  local replacer_keymaps = self:__create_keymaps__(raw_flags, "replacer")

  local nvimbar = self:__create_nvimbar__(o_match_index, o_match_total, flags)

  local scheduler_search = std.Scheduler.new({
    name = string.format("%s#search", __module_name__),
    mode = "debounce",
    delay = 64,
    timeout = 0,
    silent = std.fn.falsy,
    value = std.Observable.from_value(true),
    task = function()
      self:__search__()
    end,
  })

  self:__setup_observers__(
    o_search_pattern,
    o_search_pattern_linecount,
    o_flag_fuzzy,
    o_flag_regex,
    o_flag_case_sensitive,
    o_flag_replace,
    o_match_index,
    o_match_total,
    o_replace_pattern,
    nvimbar,
    scheduler_search
  )
  self.o_flag_fuzzy = o_flag_fuzzy
  self.o_flag_regex = o_flag_regex
  self.o_flag_case_sensitive = o_flag_case_sensitive
  self.o_search_pattern = o_search_pattern
  self.o_search_pattern_linecount = o_search_pattern_linecount
  self.o_replace_pattern = o_replace_pattern
  self.o_match_index = o_match_index
  self.o_match_total = o_match_total
  self._winnr_finder = nil
  self._bufnr_finder = nil
  self._winnr_replacer = nil
  self._bufnr_replacer = nil
  self._winnr_source = nil
  self._bufnr_source = nil
  self._matches = nil
  self._nvimbar = nvimbar
  self._scheduler_search = scheduler_search
  self._finder_keymaps = finder_keymaps
  self._replacer_keymaps = replacer_keymaps
  self._preserve_match_index = nil
  self._last_focused_window = "finder"
  self._last_search_pattern = nil
  self._last_bufnr_source = nil
  return self
end

---@param winnr_source                  integer
function M:attach(winnr_source)
  if not vim.api.nvim_win_is_valid(winnr_source) then
    return
  end

  self:__clear__()

  local bufnr_source = vim.api.nvim_win_get_buf(winnr_source) ---@type integer
  self._winnr_source = winnr_source
  self._bufnr_source = bufnr_source
  self._matches = {}

  -- Set up n and N keymaps on source buffer
  self:__setup_source_keymaps__(bufnr_source)

  if winnr_source == vim.api.nvim_get_current_win() then
    local mode = vim.fn.mode() ---@type string
    if mode == "v" or mode == "V" or mode == "\22" then -- visual, visual-line, visual-block
      local selected_text = eve.buf.retrieve_selected_text() ---@type string|nil
      if selected_text ~= nil and selected_text ~= "" then
        self.o_search_pattern:next(selected_text)
      end
    end
  end

  local winnr_finder = self:__create_finder_window_as_needed__() ---@type integer

  -- Create replacer window if replace mode is enabled
  local flag_replace = self.o_flag_replace:snapshot() ---@type boolean
  if flag_replace then
    self:__create_replacer_window_as_needed__()
  end

  vim.api.nvim_set_current_win(winnr_finder)

  self._scheduler_search:schedule()
  self._nvimbar:render()

  -- Ensure replace preview is shown after windows are fully set up
  self:__update_replace_preview__()
end

---@return nil
function M:close()
  local winnr_finder = self._winnr_finder ---@type integer|nil
  local bufnr_finder = self._bufnr_finder ---@type integer|nil
  local winnr_replacer = self._winnr_replacer ---@type integer|nil
  local bufnr_replacer = self._bufnr_replacer ---@type integer|nil
  local bufnr_source = self._bufnr_source ---@type integer|nil

  self._winnr_finder = nil
  if winnr_finder ~= nil and vim.api.nvim_win_is_valid(winnr_finder) then
    vim.api.nvim_win_close(winnr_finder, true)
  end

  self._bufnr_finder = nil
  if bufnr_finder ~= nil and vim.api.nvim_buf_is_valid(bufnr_finder) then
    vim.api.nvim_buf_delete(bufnr_finder, { force = true })
  end

  self._winnr_replacer = nil
  if winnr_replacer ~= nil and vim.api.nvim_win_is_valid(winnr_replacer) then
    vim.api.nvim_win_close(winnr_replacer, true)
  end

  self._bufnr_replacer = nil
  if bufnr_replacer ~= nil and vim.api.nvim_buf_is_valid(bufnr_replacer) then
    vim.api.nvim_buf_delete(bufnr_replacer, { force = true })
  end

  self._winnr_source = nil
  self._bufnr_source = nil
  self._matches = {}
  self._preserve_match_index = nil
  if bufnr_source ~= nil and vim.api.nvim_buf_is_valid(bufnr_source) then
    vim.api.nvim_buf_clear_namespace(bufnr_source, NSNR_SEARCH, 0, -1)
    vim.api.nvim_buf_clear_namespace(bufnr_source, NSNR_SEARCH_CURRENT, 0, -1)
    vim.api.nvim_buf_clear_namespace(bufnr_source, NSNR_REPLACE_PREVIEW, 0, -1)
    -- Clean up source buffer keymaps
    self:__cleanup_source_keymaps__(bufnr_source)
  end
  self._scheduler_search:cancel()
end

---@return nil
function M:focus_finder()
  local winnr = self._winnr_finder ---@type integer|nil
  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    vim.api.nvim_set_current_win(winnr)
    self._last_focused_window = "finder"
  end
end

---@return nil
function M:focus_replacer()
  local winnr = self._winnr_replacer ---@type integer|nil
  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    vim.api.nvim_set_current_win(winnr)
    self._last_focused_window = "replacer"
  end
end

---@return nil
function M:focus_source()
  local winnr = self._winnr_source ---@type integer|nil
  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    vim.api.nvim_set_current_win(winnr)
  end
end

---@return nil
function M:focus_last()
  if self._last_focused_window == "replacer" then
    self:focus_replacer()
  else
    self:focus_finder()
  end
end

---@return integer|nil
function M:get_winnr_finder()
  return self._winnr_finder
end

---@return nil
function M:goto_prev_match()
  local matches = self._matches ---@type yoz.search.ITextMatch[]|nil
  if matches == nil then
    return
  end

  local N = #matches ---@type integer
  if N < 1 then
    return
  end

  local winnr = self._winnr_source ---@type integer|nil
  if winnr == nil or not vim.api.nvim_win_is_valid(winnr) then
    return
  end

  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  if bufnr ~= self._bufnr_source then
    return
  end

  local index_current = self.o_match_index:snapshot() ---@type integer
  local index = std.fn.navigate_circular(index_current, -1, N) ---@type integer
  local match_prev = matches[index] ---@type yoz.search.ITextMatch
  if match_prev then
    self.o_match_index:next(index)
    pcall(vim.api.nvim_win_set_cursor, winnr, { match_prev.lx or 1, match_prev.cx or 0 })

    -- Update current match highlight
    vim.api.nvim_buf_clear_namespace(bufnr, NSNR_SEARCH_CURRENT, 0, -1)
    highlight_text_match(bufnr, NSNR_SEARCH_CURRENT, "IncSearch", match_prev)

    -- Update replace preview for the new current match
    self:__update_replace_preview__()
  end
end

---@return nil
function M:goto_next_match()
  local matches = self._matches ---@type yoz.search.ITextMatch[]|nil
  if matches == nil then
    return
  end

  local N = #matches ---@type integer
  if N < 1 then
    return
  end

  local winnr = self._winnr_source ---@type integer|nil
  if winnr == nil or not vim.api.nvim_win_is_valid(winnr) then
    return
  end

  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  if bufnr ~= self._bufnr_source then
    return
  end

  local index_current = self.o_match_index:snapshot() ---@type integer
  local index = std.fn.navigate_circular(index_current, 1, N) ---@type integer
  local match_next = matches[index] ---@type yoz.search.ITextMatch
  if match_next then
    self.o_match_index:next(index)
    pcall(vim.api.nvim_win_set_cursor, winnr, { match_next.lx or 1, match_next.cx or 0 })

    -- Update current match highlight
    vim.api.nvim_buf_clear_namespace(bufnr, NSNR_SEARCH_CURRENT, 0, -1)
    highlight_text_match(bufnr, NSNR_SEARCH_CURRENT, "IncSearch", match_next)

    self:__update_replace_preview__()
  end
end

---@return nil
function M:set_prompt()
  local bufnr = self:__create_finder_buffer_as_needed__() ---@type integer
  local winnr = self._winnr_finder ---@type integer|nil
  local lnum = 1 ---@type integer

  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    lnum = vim.fn.line("w0", winnr)
  end

  local group = eve.var.sign.GROUP_SEARCHER_BUFFER_PROMPT ---@type string
  local sign = eve.var.sign.SEARCHER_BUFFER_PROMPT ---@type string
  pcall(vim.fn.sign_place, 1, group, sign, bufnr, { lnum = lnum, priority = 10 })
end

---@return nil
function M:replace_current_match()
  local bufnr_source = self._bufnr_source ---@type integer|nil
  if bufnr_source == nil or not vim.api.nvim_buf_is_valid(bufnr_source) then
    std.reporter.error({
      from = __module_name__,
      subject = "Replace Current Match",
      message = "Source buffer is not valid",
    })
    return
  end

  local matches = self._matches ---@type yoz.search.ITextMatch[]|nil
  if matches == nil or #matches == 0 then
    std.reporter.error({
      from = __module_name__,
      subject = "Replace Current Match",
      message = "No matches found",
    })
    return
  end

  local flag_replace = self.o_flag_replace:snapshot() ---@type boolean
  if not flag_replace then
    std.reporter.error({
      from = __module_name__,
      subject = "Replace Current Match",
      message = "Replace mode is not enabled",
    })
    return
  end

  local search_pattern = self.o_search_pattern:snapshot() ---@type string
  local replace_pattern = self.o_replace_pattern:snapshot() ---@type string
  if search_pattern == "" then
    std.reporter.error({
      from = __module_name__,
      subject = "Replace Current Match",
      message = "Search pattern is empty",
    })
    return
  end

  local current_match_index = self.o_match_index:snapshot() ---@type integer
  if current_match_index <= 0 or current_match_index > #matches then
    std.reporter.error({
      from = __module_name__,
      subject = "Replace Current Match",
      message = "No current match selected",
    })
    return
  end

  local _, text = collect_buffer_content(bufnr_source) ---@type string[], string
  local current_match = matches[current_match_index] ---@type yoz.search.ITextMatch
  if current_match == nil then
    std.reporter.error({
      from = __module_name__,
      subject = "Replace Current Match",
      message = "Current match is invalid",
    })
    return
  end

  local match_offset = current_match.ox ---@type integer

  local replaced_text, replace_err = yoz.replace.replace_text_preview_by_matches({
    text = text,
    search_pattern = search_pattern,
    replace_pattern = replace_pattern,
    keep_search_pieces = false,
    flag_regex = self.o_flag_regex:snapshot(),
    flag_case_sensitive = self.o_flag_case_sensitive:snapshot(),
    match_offsets = { match_offset },
  })

  if replaced_text == nil then
    std.reporter.error({
      from = __module_name__,
      subject = "Replace Current Match",
      message = replace_err or "Failed to replace match",
    })
    return
  end

  local new_lines = vim.split(replaced_text, "\n", { plain = true }) ---@type string[]
  local ok, set_err = pcall(vim.api.nvim_buf_set_lines, bufnr_source, 0, -1, false, new_lines)
  if ok then
    -- Store the desired match index to preserve after search refresh
    local next_index = current_match_index
    if current_match_index < #matches then
      next_index = current_match_index
    else
      next_index = math.max(1, current_match_index - 1)
    end

    -- Set the preserve index before scheduling search
    self._preserve_match_index = next_index

    -- Schedule search to refresh matches
    self._scheduler_search:schedule()

    std.reporter.info({
      from = __module_name__,
      subject = "Replace Current Match",
      message = "Match replaced successfully",
    })
  else
    std.reporter.error({
      from = __module_name__,
      subject = "Replace Current Match",
      message = string.format("Failed to update buffer: %s", set_err),
    })
  end
end

---@return nil
function M:replace_all_matches()
  local bufnr_source = self._bufnr_source ---@type integer|nil
  if bufnr_source == nil or not vim.api.nvim_buf_is_valid(bufnr_source) then
    std.reporter.error({
      from = __module_name__,
      subject = "Replace All Matches",
      message = "Source buffer is not valid",
    })
    return
  end

  local matches = self._matches ---@type yoz.search.ITextMatch[]|nil
  if matches == nil or #matches == 0 then
    std.reporter.error({
      from = __module_name__,
      subject = "Replace All Matches",
      message = "No matches found",
    })
    return
  end

  local flag_replace = self.o_flag_replace:snapshot() ---@type boolean
  if not flag_replace then
    std.reporter.error({
      from = __module_name__,
      subject = "Replace All Matches",
      message = "Replace mode is not enabled",
    })
    return
  end

  local search_pattern = self.o_search_pattern:snapshot() ---@type string
  local replace_pattern = self.o_replace_pattern:snapshot() ---@type string
  if search_pattern == "" then
    std.reporter.error({
      from = __module_name__,
      subject = "Replace All Matches",
      message = "Search pattern is empty",
    })
    return
  end

  local _, text = collect_buffer_content(bufnr_source) ---@type string[], string
  local replaced_text, replace_err = yoz.replace.replace_text_preview({
    text = text,
    search_pattern = search_pattern,
    replace_pattern = replace_pattern,
    keep_search_pieces = false,
    flag_regex = self.o_flag_regex:snapshot(),
    flag_case_sensitive = self.o_flag_case_sensitive:snapshot(),
  })

  if replaced_text == nil then
    std.reporter.error({
      from = __module_name__,
      subject = "Replace All Matches",
      message = replace_err or "Failed to replace matches",
    })
    return
  end

  local new_lines = vim.split(replaced_text, "\n", { plain = true }) ---@type string[]
  local ok, set_err = pcall(vim.api.nvim_buf_set_lines, bufnr_source, 0, -1, false, new_lines)

  if ok then
    -- Clear all highlights since all matches are replaced
    vim.api.nvim_buf_clear_namespace(bufnr_source, NSNR_SEARCH, 0, -1)
    vim.api.nvim_buf_clear_namespace(bufnr_source, NSNR_SEARCH_CURRENT, 0, -1)
    vim.api.nvim_buf_clear_namespace(bufnr_source, NSNR_REPLACE_PREVIEW, 0, -1)

    -- Clear matches and update counters
    self._matches = {}
    self.o_match_index:next(0)
    self.o_match_total:next(0)

    std.reporter.info({
      from = __module_name__,
      subject = "Replace All Matches",
      message = string.format("Replaced %d matches successfully", #matches),
    })
  else
    std.reporter.error({
      from = __module_name__,
      subject = "Replace All Matches",
      message = string.format("Failed to update buffer: %s", set_err),
    })
  end
end

----------------------------------------------------------------------------------------------------

---@protected
---@return integer
---@return boolean
function M:__create_finder_buffer_as_needed__()
  local bufnr = self._bufnr_finder ---@type integer|nil
  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    return bufnr, false
  end

  bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  self._bufnr_finder = bufnr

  vim.b[bufnr].miniindentscope_disable = true
  vim.b[bufnr].miniai_disable = true
  vim.b[bufnr].minihipatterns_disable = true
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].swapfile = false

  -- Use finder keymaps
  std.nvim.bindkeys(self._finder_keymaps, { bufnr = bufnr, noremap = true, silent = true })

  local pattern = self.o_search_pattern:snapshot() ---@type string
  local lines = vim.split(pattern, "\n", { plain = true })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  -- Set up search icon sign
  local sign_group = "eve_ux_search_buffer_prompt"
  local sign_name = "SearchBufferPrompt"
  vim.fn.sign_define(sign_name, { text = std.icon.ui.Search, texthl = "f_pk_finder_prompt" })
  vim.fn.sign_place(1, sign_group, sign_name, bufnr, { lnum = 1, priority = 10 })

  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    buffer = bufnr,
    callback = function()
      local raw_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false) ---@type string[]
      local content = table.concat(raw_lines, "\n") ---@type string
      self.o_search_pattern:next(content)
      self.o_search_pattern_linecount:next(#raw_lines)
      self:set_prompt()
    end,
  })

  return bufnr, true
end

---@protected
---@return integer
---@return boolean
function M:__create_replacer_buffer_as_needed__()
  local bufnr = self._bufnr_replacer ---@type integer|nil
  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    return bufnr, false
  end

  bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  self._bufnr_replacer = bufnr

  vim.b[bufnr].miniindentscope_disable = true
  vim.b[bufnr].miniai_disable = true
  vim.b[bufnr].minihipatterns_disable = true
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].swapfile = false

  -- Use replacer keymaps
  std.nvim.bindkeys(self._replacer_keymaps, { bufnr = bufnr, noremap = true, silent = true })

  local pattern = self.o_replace_pattern:snapshot() ---@type string
  local lines = vim.split(pattern, "\n", { plain = true })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  -- Set up replace icon sign
  local sign_group = "eve_ux_replace_buffer_prompt"
  local sign_name = "ReplaceBufferPrompt"
  vim.fn.sign_define(sign_name, { text = std.icon.symbols.flag_replace, texthl = "f_pk_replacer_prompt" })
  vim.fn.sign_place(1, sign_group, sign_name, bufnr, { lnum = 1, priority = 10 })

  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    buffer = bufnr,
    callback = function()
      local raw_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false) ---@type string[]
      local content = table.concat(raw_lines, "\n") ---@type string
      self.o_replace_pattern:next(content)
    end,
  })

  return bufnr, true
end

---@protected
---@return integer
---@return boolean
function M:__create_finder_window_as_needed__()
  local winnr = self._winnr_finder ---@type integer|nil
  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    return winnr, false
  end

  local winblend = eve.context.theme.get_float_winblend() ---@type integer
  local pattern_line_count = self.o_search_pattern_linecount:snapshot() ---@type integer
  local height = calculate_dynamic_height(pattern_line_count) ---@type integer
  local width = math.min(60, math.floor(vim.o.columns * 0.9)) ---@type integer
  local row = 3 ---@type integer
  local col = math.max(0, math.floor((vim.o.columns - width) / 2)) ---@type integer

  -- Determine border style based on whether replacer is shown
  local flag_replace = self.o_flag_replace:snapshot() ---@type boolean
  local border = flag_replace and { "╭", "─", "╮", "│", "┤", "─", "├", "│" } or "rounded"

  local bufnr = self:__create_finder_buffer_as_needed__() ---@type integer
  local popup_winnr = vim.api.nvim_open_win(bufnr, true, {
    zindex = eve.win.resolve_zindex(),
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = border,
    title = string.format(" %s ", self.title),
    title_pos = "center",
  })
  self._winnr_finder = popup_winnr

  vim.wo[popup_winnr].cursorline = false
  vim.wo[popup_winnr].number = false
  vim.wo[popup_winnr].relativenumber = false
  vim.wo[popup_winnr].signcolumn = "yes"
  vim.wo[popup_winnr].spell = false
  vim.wo[popup_winnr].winblend = winblend
  vim.wo[popup_winnr].winfixbuf = true
  vim.wo[popup_winnr].winhighlight = "Normal:Normal,FloatBorder:FloatBorder"
  vim.wo[popup_winnr].wrap = false

  -- Set nvimbar immediately when finder window is created
  vim.wo[popup_winnr].winbar = self._nvimbar:snapshot()
  self._nvimbar:render()

  return popup_winnr, true
end

---@protected
---@return integer
---@return boolean
function M:__create_replacer_window_as_needed__()
  local winnr = self._winnr_replacer ---@type integer|nil
  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    return winnr, false
  end

  -- Get finder window config to position replacer below it
  local finder_winnr = self._winnr_finder ---@type integer|nil
  if finder_winnr == nil or not vim.api.nvim_win_is_valid(finder_winnr) then
    return -1, false
  end

  local finder_config = vim.api.nvim_win_get_config(finder_winnr)
  local winblend = eve.context.theme.get_float_winblend() ---@type integer
  local width = finder_config.width ---@type integer
  local height = 3 ---@type integer -- Fixed height for replacer
  local row = finder_config.row + finder_config.height + 1 ---@type integer
  local col = finder_config.col ---@type integer

  local bufnr = self:__create_replacer_buffer_as_needed__() ---@type integer
  local popup_winnr = vim.api.nvim_open_win(bufnr, false, {
    zindex = eve.win.resolve_zindex(),
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = { "├", "─", "┤", "│", "╯", "─", "╰", "│" }, -- Connect to finder above
    title = " Replace ",
    title_pos = "center",
  })
  self._winnr_replacer = popup_winnr

  vim.wo[popup_winnr].cursorline = false
  vim.wo[popup_winnr].number = false
  vim.wo[popup_winnr].relativenumber = false
  vim.wo[popup_winnr].signcolumn = "yes"
  vim.wo[popup_winnr].spell = false
  vim.wo[popup_winnr].winblend = winblend
  vim.wo[popup_winnr].winfixbuf = true
  vim.wo[popup_winnr].winhighlight = "Normal:Normal,FloatBorder:FloatBorder"
  vim.wo[popup_winnr].wrap = false

  return popup_winnr, true
end

---@protected
---@param raw_flags                     ux.searcher.result.IFlagItemRaw[]
---@param window_type                   "finder"|"replacer"
---@return std.t.IKeymap[]
function M:__create_keymaps__(raw_flags, window_type)
  local actions = {
    toggle_source_with_searcher = function()
      local current_winnr = vim.api.nvim_get_current_win() ---@type integer
      local winnr_source = self._winnr_source ---@type integer|nil

      -- If we're in the source window, focus back to the searcher
      if current_winnr == winnr_source then
        self:focus_last()
      else
        -- Otherwise, focus the source window
        self:focus_source()
      end
    end,
  }

  ---@type std.t.IKeymap[]
  local base_keymaps = {
    {
      modes = { "n" },
      key = "q",
      desc = "search_buffer: close",
      callback = function()
        self:close()
      end,
    },
    {
      modes = { "n" },
      key = "n",
      desc = "search_buffer: goto next match",
      callback = function()
        self:goto_next_match()
      end,
    },
    {
      modes = { "n" },
      key = "N",
      desc = "search_buffer: goto previous match",
      callback = function()
        self:goto_prev_match()
      end,
    },
    {
      modes = { "i", "n", "x" },
      key = "<C-k>",
      desc = "search_buffer: goto previous match",
      callback = function()
        self:goto_prev_match()
      end,
    },
    {
      modes = { "i", "n", "x" },
      key = "<C-j>",
      desc = "search_buffer: goto next match",
      callback = function()
        self:goto_next_match()
      end,
    },
    {
      modes = { "n", "x" },
      key = "<CR>",
      desc = "search_buffer: goto next match",
      callback = function()
        self:goto_next_match()
      end,
    },
    {
      modes = { "i", "n", "x" },
      key = "<C-a>`",
      aliases = { "<D-`>", "<M-`>" },
      desc = "search_buffer: toggle between searcher and source window",
      callback = actions.toggle_source_with_searcher,
    },
    {
      modes = { "n", "x" },
      key = "<leader>`",
      desc = "search_buffer: toggle between searcher and source window",
      callback = actions.toggle_source_with_searcher,
    },
    {
      modes = { "i", "n", "x" },
      key = "<C-a>j",
      aliases = { "<D-j>", "<M-j>" },
      desc = "search_buffer: focus replacer window (move down)",
      callback = function()
        if window_type == "finder" then
          self:focus_replacer()
        end
      end,
    },
    {
      modes = { "i", "n", "x" },
      key = "<C-a>k",
      aliases = { "<D-k>", "<M-k>" },
      desc = "search_buffer: focus finder window (move up)",
      callback = function()
        if window_type == "replacer" then
          self:focus_finder()
        end
      end,
    },
    {
      modes = { "i", "n", "x" },
      key = "<leader><CR>",
      desc = "search_buffer: replace current match",
      callback = function()
        self:replace_current_match()
      end,
    },
    {
      modes = { "i", "n", "x" },
      key = "<C-a><cr>",
      aliases = { "<D-cr>", "<M-cr>" },
      desc = "search_buffer: replace all matches",
      callback = function()
        self:replace_all_matches()
      end,
    },
    {
      modes = { "i", "n", "x" },
      key = "<C-a>r",
      aliases = { "<D-r>", "<M-r>" },
      desc = "search_buffer: trigger re-search",
      callback = function()
        self._scheduler_search:schedule()
      end,
    },
  }

  if self.o_flag_replace ~= nil then
    base_keymaps[#base_keymaps + 1] = {
      modes = { "n", "x" },
      key = "tr",
      desc = string.format("%s: toggle replace mode", self.title),
      callback = function()
        local flag = self.o_flag_replace ---@type std.collection.IObservable
        flag:next(not flag:snapshot())
      end,
    }
  end

  for index, flag in ipairs(raw_flags) do
    base_keymaps[#base_keymaps + 1] = {
      modes = { "n", "x" },
      key = string.format("t%d", index),
      desc = flag.desc,
      callback = flag.callback,
    }
  end

  return base_keymaps
end

---@protected
---@param o_match_index                 std.collection.IObservable
---@param o_match_total                 std.collection.IObservable
---@param flags                         ux.searcher.result.IFlagItem[]
---@return ux.nvimbar.Nvimbar
function M:__create_nvimbar__(o_match_index, o_match_total, flags)
  local position = "f_wl" ---@type ux.nvimbar.PositionEnum
  local c = ux.nvimbar.component

  return ux.nvimbar.Nvimbar
    .new({
      name = string.format("%s#winbar", __module_name__),
      comp_sep = "",
      comp_sep_hlname = "f_wl_searcher",
      comp_sep_hlname_active = "f_wl_searcher",
      delay = 64,
      silent = std.fn.falsy,
      get_max_width = function()
        local winnr = self._winnr_finder ---@type integer|nil
        if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
          return vim.api.nvim_win_get_width(winnr)
        end
        return 0
      end,
      get_preset_context = function()
        local winnr = self._winnr_finder ---@type integer|nil
        if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
          return { winnr = winnr }
        end
        return {}
      end,
      is_active = function()
        local winnr = self._winnr_finder ---@type integer|nil
        return winnr ~= nil and vim.api.nvim_win_is_valid(winnr)
      end,
      on_fulfilled = function(result)
        local winnr = self._winnr_finder ---@type integer|nil
        if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
          vim.wo[winnr].winbar = result
        end
      end,
      validate = function()
        local winnr = self._winnr_finder ---@type integer|nil
        if winnr == nil or not vim.api.nvim_win_is_valid(winnr) then
          return "The window is not valid, winnr=" .. winnr .. "."
        end
      end,
    })
    :place("left", c.picker.result_pos(position, o_match_index, o_match_total), 100)
    :place("right", c.picker.result_flags(position, flags, 1), 100)
end

---@protected
---@return nil
function M:__setup_observers__(
  o_search_pattern,
  o_search_pattern_linecount,
  o_flag_fuzzy,
  o_flag_regex,
  o_flag_case_sensitive,
  o_flag_replace,
  o_match_index,
  o_match_total,
  o_replace_pattern,
  nvimbar,
  scheduler_search
)
  std.fn.observe({ o_search_pattern }, function()
    local pattern = o_search_pattern:snapshot() ---@type string
    if pattern == nil or pattern == "" then
      o_search_pattern_linecount:next(1)
      return
    end
    local lines = vim.split(pattern, "\n", { plain = true })
    o_search_pattern_linecount:next(#lines)
  end, true)

  std.fn.observe({
    o_flag_fuzzy,
    o_flag_regex,
    o_flag_case_sensitive,
    o_flag_replace,
    o_match_index,
    o_match_total,
  }, function()
    nvimbar:render()
  end, true)

  std.fn.observe({
    o_flag_fuzzy,
    o_flag_regex,
    o_flag_case_sensitive,
    o_search_pattern,
  }, function()
    scheduler_search:schedule()
  end, true)

  std.fn.observe({ o_search_pattern_linecount }, function()
    self:__resize__()
  end, true)

  std.fn.observe({ o_flag_replace }, function()
    self:__toggle_replacer__(o_flag_replace:snapshot())
  end, true)

  std.fn.observe({
    o_flag_fuzzy,
    o_flag_regex,
    o_flag_case_sensitive,
    o_flag_replace,
    o_search_pattern,
    o_replace_pattern,
    o_match_index,
  }, function()
    self:__update_replace_preview__()
  end, true)
end

---@protected
---@param flag_replace                  boolean
---@return nil
function M:__toggle_replacer__(flag_replace)
  local winnr_finder = self._winnr_finder ---@type integer|nil
  if winnr_finder ~= nil and vim.api.nvim_win_is_valid(winnr_finder) then
    local finder_config = vim.api.nvim_win_get_config(winnr_finder)
    finder_config.border = flag_replace and { "╭", "─", "╮", "│", "┤", "─", "├", "│" } or "rounded"
    vim.api.nvim_win_set_config(winnr_finder, finder_config)
  end

  if flag_replace then
    self:__create_replacer_window_as_needed__()
    return
  end

  local winnr_replacer = self._winnr_replacer ---@type integer|nil
  local bufnr_replacer = self._bufnr_replacer ---@type integer|nil

  self._winnr_replacer = nil
  if winnr_replacer ~= nil and vim.api.nvim_win_is_valid(winnr_replacer) then
    vim.api.nvim_win_close(winnr_replacer, true)
  end

  self._bufnr_replacer = nil
  if bufnr_replacer ~= nil and vim.api.nvim_buf_is_valid(bufnr_replacer) then
    vim.api.nvim_buf_delete(bufnr_replacer, { force = true })
  end
end

---@protected
---@return nil
function M:__clear__()
  local bufnr = self._bufnr_source
  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_clear_namespace(bufnr, NSNR_SEARCH, 0, -1)
    vim.api.nvim_buf_clear_namespace(bufnr, NSNR_SEARCH_CURRENT, 0, -1)
    vim.api.nvim_buf_clear_namespace(bufnr, NSNR_REPLACE_PREVIEW, 0, -1)
  end
  self._preserve_match_index = nil
end

---@protected
---@return nil
function M:__resize__()
  local winnr = self._winnr_finder ---@type integer|nil
  if winnr == nil or not vim.api.nvim_win_is_valid(winnr) then
    return
  end

  -- Calculate new dynamic height based on current search pattern
  local pattern_line_count = self.o_search_pattern_linecount:snapshot() ---@type integer
  local new_height = calculate_dynamic_height(pattern_line_count) ---@type integer

  -- Get current window config
  local current_config = vim.api.nvim_win_get_config(winnr)

  -- Only resize if height actually changed
  if current_config.height ~= new_height then
    current_config.height = new_height
    local resize = eve.state.maximized.resolve_resize_config(winnr, current_config) ---@type eve.state.maximized.ResolveResizeResult
    vim.api.nvim_win_set_config(winnr, resize.cfg)
  end
end

---@protected
---@return nil
function M:__search__()
  local bufnr_finder = self._bufnr_finder ---@type integer|nil
  if bufnr_finder == nil or not vim.api.nvim_buf_is_valid(bufnr_finder) then
    return
  end

  local bufnr_source = self._bufnr_source ---@type integer|nil
  if bufnr_source == nil or not vim.api.nvim_buf_is_valid(bufnr_source) then
    return
  end

  local pattern = self.o_search_pattern:snapshot() ---@type string
  if pattern == "" then
    self._matches = {}
    self._last_search_pattern = nil
    self._last_bufnr_source = nil
    self.o_match_index:next(0)
    self.o_match_total:next(0)
    vim.api.nvim_buf_clear_namespace(bufnr_source, NSNR_SEARCH, 0, -1)
    vim.api.nvim_buf_clear_namespace(bufnr_source, NSNR_SEARCH_CURRENT, 0, -1)
    return
  end

  -- Check if pattern or source buffer changed
  local pattern_changed = self._last_search_pattern ~= pattern
  local buffer_changed = self._last_bufnr_source ~= bufnr_source

  -- Construct search parameters
  local flag_fuzzy = self.o_flag_fuzzy:snapshot() ---@type boolean
  local flag_regex = self.o_flag_regex:snapshot() ---@type boolean
  local flag_case_sensitive = self.o_flag_case_sensitive:snapshot() ---@type boolean

  local matches ---@type yoz.search.ITextMatch[]|nil
  local ok_lines, lines = pcall(vim.api.nvim_buf_get_lines, bufnr_source, 0, -1, false)

  if not ok_lines then
    std.reporter.error({
      from = __module_name__,
      subject = "search_in_buffer failed",
      details = {
        error = lines,
        params = {
          bufnr = bufnr_source,
          search_pattern = pattern,
          flag_fuzzy = flag_fuzzy,
          flag_regex = flag_regex,
          flag_case_sensitive = flag_case_sensitive,
        },
      },
    })
  else
    ---@type yoz.search.ISearchInLinesOptions
    local search_params = {
      pattern = pattern,
      lines = lines,
      flag_fuzzy = flag_fuzzy,
      flag_regex = flag_regex,
      flag_case_sensitive = flag_case_sensitive,
    }
    local search_result, search_err = yoz.search.search_in_lines(search_params) ---@type yoz.search.ISearchTextResult|nil, string|nil
    if search_err then
      std.reporter.error({
        from = __module_name__,
        subject = "search_in_lines failed",
        details = {
          error = search_err,
          params = search_params,
        },
      })
      matches = nil
    else
      matches = search_result and search_result.matches or nil
    end
  end

  -- Check for errors or no matches
  if not matches or #matches < 1 then
    self._matches = {}
    self._last_search_pattern = pattern
    self._last_bufnr_source = bufnr_source
    self.o_match_index:next(0)
    self.o_match_total:next(0)
    vim.api.nvim_buf_clear_namespace(bufnr_source, NSNR_SEARCH, 0, -1)
    vim.api.nvim_buf_clear_namespace(bufnr_source, NSNR_SEARCH_CURRENT, 0, -1)
    return
  end

  self._matches = matches
  self._last_search_pattern = pattern
  self._last_bufnr_source = bufnr_source
  self.o_match_total:next(#matches)

  -- Determine match index to use
  local match_index = 1
  if self._preserve_match_index ~= nil then
    -- Use preserved match index (from replace operations)
    local preserved_index = self._preserve_match_index ---@type integer
    match_index = math.min(preserved_index, #matches)
    match_index = math.max(1, match_index)
    self._preserve_match_index = nil -- Clear after use
  elseif not pattern_changed and not buffer_changed then
    -- Pattern and buffer unchanged - preserve current match index
    local current_index = self.o_match_index:snapshot() ---@type integer
    if current_index > 0 then
      match_index = math.min(current_index, #matches)
    end
  end
  self.o_match_index:next(match_index)

  vim.api.nvim_buf_clear_namespace(bufnr_source, NSNR_SEARCH, 0, -1)
  vim.api.nvim_buf_clear_namespace(bufnr_source, NSNR_SEARCH_CURRENT, 0, -1)
  for _, match in ipairs(matches) do
    highlight_text_match(bufnr_source, NSNR_SEARCH, "Search", match)
  end

  -- Move cursor to the selected match (either preserved or first) and highlight it
  local target_match = matches[match_index]
  if target_match then
    local target_win = self._winnr_source ---@type integer|nil
    if target_win ~= nil and vim.api.nvim_win_is_valid(target_win) then
      local line_count = vim.api.nvim_buf_line_count(bufnr_source)
      local target_line = target_match.lx ---@type integer
      if target_line > 0 and target_line <= line_count then
        vim.api.nvim_win_set_cursor(target_win, { target_line, target_match.cx or 0 })
        highlight_text_match(bufnr_source, NSNR_SEARCH_CURRENT, "IncSearch", target_match)
      end
    end
  end

  -- Update replace preview after search is complete to ensure it shows for the current match
  self:__update_replace_preview__()
end

---@protected
---@return nil
function M:__update_replace_preview__()
  local bufnr_source = self._bufnr_source ---@type integer|nil
  if bufnr_source == nil or not vim.api.nvim_buf_is_valid(bufnr_source) then
    return
  end

  -- Clear existing replace preview highlights
  vim.api.nvim_buf_clear_namespace(bufnr_source, NSNR_REPLACE_PREVIEW, 0, -1)

  local flag_replace = self.o_flag_replace:snapshot() ---@type boolean

  -- Only show replace preview if replace mode is enabled
  if not flag_replace then
    return
  end

  -- Ensure replacer window exists if replace mode is enabled
  local winnr_replacer = self._winnr_replacer ---@type integer|nil
  if winnr_replacer == nil or not vim.api.nvim_win_is_valid(winnr_replacer) then
    -- Create replacer window if it doesn't exist and finder window is available
    local winnr_finder = self._winnr_finder ---@type integer|nil
    if winnr_finder ~= nil and vim.api.nvim_win_is_valid(winnr_finder) then
      self:__create_replacer_window_as_needed__()
      winnr_replacer = self._winnr_replacer
    end
  end

  -- Still need a valid replacer window to show preview
  if winnr_replacer == nil or not vim.api.nvim_win_is_valid(winnr_replacer) then
    return
  end

  local search_pattern = self.o_search_pattern:snapshot() ---@type string
  local replace_pattern = self.o_replace_pattern:snapshot() ---@type string

  -- Don't show preview if search pattern is empty
  if search_pattern == "" then
    return
  end

  local matches = self._matches ---@type yoz.search.ITextMatch[]|nil
  if not matches or #matches == 0 then
    return
  end

  local _, text = collect_buffer_content(bufnr_source) ---@type string[], string
  local flag_regex = self.o_flag_regex:snapshot() ---@type boolean
  local flag_case_sensitive = self.o_flag_case_sensitive:snapshot() ---@type boolean
  local replacement_matches = {} ---@type ux.searcher.buffer.IReplacementMatch[]

  local text_len = #text ---@type integer

  for _, text_match in ipairs(matches) do
    local start_offset = text_match.ox ---@type integer
    local end_offset = math.min((text_match.oy or text_match.ox) + 1, text_len) ---@type integer

    if end_offset > start_offset then
      local matched_text = string.sub(text, start_offset + 1, end_offset) ---@type string
      local replacement_text, preview_err = yoz.replace.replace_text_preview({
        text = matched_text,
        search_pattern = search_pattern,
        replace_pattern = replace_pattern,
        keep_search_pieces = false,
        flag_regex = flag_regex,
        flag_case_sensitive = flag_case_sensitive,
      })

      if replacement_text == nil then
        std.reporter.error({
          from = __module_name__,
          subject = "Replace Preview",
          message = preview_err or "Failed to compute replacement preview",
        })
        return
      end

      replacement_matches[#replacement_matches + 1] = {
        l = start_offset,
        r = end_offset,
        text = replacement_text,
      }
    end
  end

  if #replacement_matches > 0 then
    self:__render_replacement_matches__(bufnr_source, replacement_matches)
  end
end

---@class ux.searcher.buffer.IReplacementMatch
---@field public l                      integer
---@field public r                      integer
---@field public text                   string

---@protected
---@param bufnr                         integer
---@param replacement_matches           ux.searcher.buffer.IReplacementMatch[]
---@return nil
function M:__render_replacement_matches__(bufnr, replacement_matches)
  local text = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
  local lines = vim.split(text, "\n", { plain = true })
  local current_match_offset = self:__get_current_match_offset__(lines)

  for _, replacement_match in ipairs(replacement_matches) do
    local lnum = self:__calculate_line_number__(lines, replacement_match.l)
    local line_start_pos = self:__calculate_line_start_pos__(lines, lnum)
    local col_start = replacement_match.l - line_start_pos
    local col_end = replacement_match.r - line_start_pos

    local is_current_match = current_match_offset and replacement_match.l == current_match_offset
    local search_hlgroup = is_current_match and "f_sr_search_cur" or "f_sr_search"
    local replace_hlgroup = is_current_match and "f_sr_replace_cur" or "f_sr_replace"

    if col_start >= 0 and col_end > col_start then
      pcall(vim.hl.range, bufnr, NSNR_REPLACE_PREVIEW, search_hlgroup, { lnum - 1, col_start }, { lnum - 1, col_end })

      local replacement_text = replacement_match.text or ""
      if replacement_text ~= "" then
        pcall(vim.api.nvim_buf_set_extmark, bufnr, NSNR_REPLACE_PREVIEW, lnum - 1, col_end, {
          virt_text = { { replacement_text, replace_hlgroup } },
          virt_text_pos = "inline",
          priority = vim.hl.priorities.user + 1,
        })
      end
    end
  end
end

---@protected
---@param lines                         string[]
---@return integer|nil
---@diagnostic disable-next-line: unused-local
function M:__get_current_match_offset__(lines)
  local current_match_index = self.o_match_index:snapshot() ---@type integer
  local matches = self._matches ---@type yoz.search.ITextMatch[]|nil

  if not matches or current_match_index <= 0 or current_match_index > #matches then
    return nil
  end

  local current_match = matches[current_match_index]
  if not current_match then
    return nil
  end

  return current_match.ox
end

---@protected
---@param lines                         string[]
---@param char_offset                   integer
---@return integer
function M:__calculate_line_number__(lines, char_offset)
  local char_pos = 0
  for i, line in ipairs(lines) do
    local line_end = char_pos + #line
    if char_offset >= char_pos and char_offset < line_end + 1 then
      return i
    end
    char_pos = line_end + 1
  end
  return 1
end

---@protected
---@param lines                         string[]
---@param lnum                          integer
---@return integer
function M:__calculate_line_start_pos__(lines, lnum)
  local line_start_pos = 0
  for i = 1, lnum - 1 do
    line_start_pos = line_start_pos + #lines[i] + 1
  end
  return line_start_pos
end

---@protected
---@param bufnr                         integer
---@return nil
function M:__setup_source_keymaps__(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local keymap_opts = { buffer = bufnr, noremap = true, silent = true }

  vim.keymap.set("n", "n", function()
    local current_win = vim.api.nvim_get_current_win() ---@type integer
    local current_buf = vim.api.nvim_win_get_buf(current_win) ---@type integer
    local finder_winnr = self._winnr_finder ---@type integer|nil

    if
      finder_winnr ~= nil
      and vim.api.nvim_win_is_valid(finder_winnr)
      and current_win == self._winnr_source
      and current_buf == self._bufnr_source
    then
      self:goto_next_match()
    else
      vim.cmd("normal! n")
    end
  end, keymap_opts)

  vim.keymap.set("n", "N", function()
    local current_win = vim.api.nvim_get_current_win() ---@type integer
    local current_buf = vim.api.nvim_win_get_buf(current_win) ---@type integer
    local finder_winnr = self._winnr_finder ---@type integer|nil

    if
      finder_winnr ~= nil
      and vim.api.nvim_win_is_valid(finder_winnr)
      and current_win == self._winnr_source
      and current_buf == self._bufnr_source
    then
      self:goto_prev_match()
    else
      vim.cmd("normal! N")
    end
  end, keymap_opts)
end

---@protected
---@param bufnr                         integer
---@return nil
function M:__cleanup_source_keymaps__(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  pcall(vim.keymap.del, "n", "n", { buffer = bufnr })
  pcall(vim.keymap.del, "n", "N", { buffer = bufnr })
end

return M
