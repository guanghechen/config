---@diagnostic disable: invisible
local __module_name__ = "eve.ux.searcher.buffer" ---@type string
local NSNR_SEARCH = vim.api.nvim_create_namespace("eve.ux.searcher.buffer") ---@type integer
local NSNR_SEARCH_CURRENT = vim.api.nvim_create_namespace("eve.ux.searcher.buffer.current") ---@type integer

---@param pattern_line_count            integer
---@return integer
local function calculate_dynamic_height(pattern_line_count)
  local base_height = 2 -- 1 line for input + 1 line for winbar reservation
  local extra_lines = math.min(pattern_line_count - 1, 4) -- Max 4 extra lines
  return base_height + extra_lines
end

---@param bufnr                         integer
---@param namespace                     integer
---@param hlgroup                       string
---@param lnum                          integer
---@param point                         std.t.IMatchPoint
---@return nil
local function highlight_match_point(bufnr, namespace, hlgroup, lnum, point)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  -- Get the current line content to check if match extends beyond it
  local current_line = vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)[1] or ""
  local line_length = #current_line
  local row = lnum - 1 -- Convert to 0-based indexing

  -- Single line match - point.r is within current line bounds
  if point.r <= line_length then
    vim.hl.range(bufnr, namespace, hlgroup, { row, point.l }, { row, point.r })
    return
  end

  -- Multiline match - need to handle across multiple lines
  local remaining_chars = point.r - point.l -- Total characters to highlight
  local current_pos = point.l -- Current position within the match
  local current_row = row -- Current line being processed

  while remaining_chars > 0 and current_row < vim.api.nvim_buf_line_count(bufnr) do
    -- Get current line content
    local line = vim.api.nvim_buf_get_lines(bufnr, current_row, current_row + 1, false)[1] or ""
    local line_len = #line

    -- Calculate start position on current line
    local line_start = current_pos
    if current_row > row then
      line_start = 0 -- Start from beginning of subsequent lines
    end

    -- Calculate end position on current line
    local chars_available = line_len - line_start
    local chars_to_highlight = math.min(remaining_chars, chars_available)
    local line_end = line_start + chars_to_highlight

    -- Apply highlighting to current line segment
    if chars_to_highlight > 0 then
      vim.hl.range(bufnr, namespace, hlgroup, { current_row, line_start }, { current_row, line_end })
    end

    -- Update for next iteration
    remaining_chars = remaining_chars - chars_to_highlight - 1 -- -1 for newline character
    current_pos = 0 -- Reset position for next line
    current_row = current_row + 1
  end
end

---@class eve.ux.searcher.buffer.ISearcherProps
---@field public o_flag_fuzzy?           std.collection.IObservable
---@field public o_flag_regex?           std.collection.IObservable
---@field public o_flag_replace?         std.collection.IObservable
---@field public o_flag_case_sensitive?  std.collection.IObservable
---@field public o_search_pattern?       std.collection.IObservable
---@field public o_replace_pattern?      std.collection.IObservable

---@class eve.ux.searcher.buffer.Searcher
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
---@field protected _matches            oxi.string.ILineMatch[]|nil
---@field protected _scheduler_search   std.collection.Scheduler
---@field protected _nvimbar            eve.ux.nvimbar.Nvimbar
---@field protected _finder_keymaps     std.t.IKeymap[]
---@field protected _replacer_keymaps   std.t.IKeymap[]
local M = {}
M.__index = M

---@param props                         eve.ux.searcher.buffer.ISearcherProps|nil
---@return eve.ux.searcher.buffer.Searcher
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

  ---@type eve.ux.searcher.result.IFlagItemRaw[]
  local raw_flags = {
    {
      desc = string.format("%s: toggle fuzzy search", self.title),
      callback = function()
        local enabled = o_flag_fuzzy:snapshot() ---@type boolean
        o_flag_fuzzy:next(not enabled)
      end,
      snapshot = function()
        local enabled = o_flag_fuzzy:snapshot() ---@type boolean
        return eve.icon.symbols.flag_fuzzy, enabled and "picker_flag_blue" or "picker_flag_grey"
      end,
    },
    {
      desc = string.format("%s: toggle regex search", self.title),
      callback = function()
        local enabled = o_flag_regex:snapshot() ---@type boolean
        o_flag_regex:next(not enabled)
      end,
      snapshot = function()
        local enabled = o_flag_regex:snapshot() ---@type boolean
        return eve.icon.symbols.flag_regex, enabled and "picker_flag_blue" or "picker_flag_grey"
      end,
    },
    {
      desc = string.format("%s: toggle case sensitive", self.title),
      callback = function()
        local enabled = o_flag_case_sensitive:snapshot() ---@type boolean
        o_flag_case_sensitive:next(not enabled)
      end,
      snapshot = function()
        local enabled = o_flag_case_sensitive:snapshot() ---@type boolean
        return eve.icon.symbols.flag_case_sensitive, enabled and "picker_flag_blue" or "picker_flag_grey"
      end,
    },
    {
      desc = string.format("%s: toggle replace mode", self.title),
      callback = function()
        local enabled = o_flag_replace:snapshot() ---@type boolean
        o_flag_replace:next(not enabled)
      end,
      snapshot = function()
        local enabled = o_flag_replace:snapshot() ---@type boolean
        return eve.icon.symbols.flag_replace, enabled and "picker_flag_blue" or "picker_flag_grey"
      end,
    },
  }

  local flags = {} ---@type eve.ux.searcher.result.IFlagItem[]
  for _, flag in ipairs(raw_flags) do
    ---@type eve.ux.searcher.result.IFlagItem
    local item = {
      desc = flag.desc,
      callback = eve.G.register_anonymous_fn(flag.callback) or "eve.G.noop",
      disabled = std.fn.falsy,
      snapshot = flag.snapshot,
    }
    flags[#flags + 1] = item
  end

  ---@type std.t.IKeymap[]
  local finder_keymaps = {
    {
      modes = { "n" },
      key = "q",
      desc = "search_buffer: close",
      callback = function()
        self:close()
      end,
    },
    {
      modes = { "i", "n", "v" },
      key = "<C-k>",
      desc = "search_buffer: goto previous match",
      callback = function()
        self:goto_prev_match()
      end,
    },
    {
      modes = { "i", "n", "v" },
      key = "<C-j>",
      desc = "search_buffer: goto next match",
      callback = function()
        self:goto_next_match()
      end,
    },
    {
      modes = { "n", "v" },
      key = "<CR>",
      desc = "search_buffer: goto next match",
      callback = function()
        self:goto_next_match()
      end,
    },
    {
      modes = { "i", "n", "v" },
      key = "<leader>`",
      desc = "search_buffer: focus source window",
      callback = function()
        self:focus_source()
      end,
    },
    {
      modes = { "i", "n", "v" },
      key = "<C-a>j",
      aliases = { "<D-j>", "<M-j>" },
      desc = "search_buffer: focus replacer window",
      callback = function()
        self:focus_replacer()
      end,
    },
    {
      modes = { "i", "n", "v" },
      key = "<C-a>k",
      aliases = { "<D-k>", "<M-k>" },
      desc = "search_buffer: focus finder window",
      callback = function()
        self:focus_replacer()
      end,
    },
  }
  for index, flag in ipairs(raw_flags) do
    finder_keymaps[#finder_keymaps + 1] = {
      modes = { "n", "v" },
      key = string.format("t%d", index),
      desc = flag.desc,
      callback = flag.callback,
    }
  end

  ---@type std.t.IKeymap[]
  local replacer_keymaps = {
    {
      modes = { "n" },
      key = "q",
      desc = "search_buffer: close",
      callback = function()
        self:close()
      end,
    },
    {
      modes = { "i", "n", "v" },
      key = "<C-k>",
      desc = "search_buffer: goto previous match",
      callback = function()
        self:goto_prev_match()
      end,
    },
    {
      modes = { "i", "n", "v" },
      key = "<C-j>",
      desc = "search_buffer: goto next match",
      callback = function()
        self:goto_next_match()
      end,
    },
    {
      modes = { "n", "v" },
      key = "<CR>",
      desc = "search_buffer: goto next match",
      callback = function()
        self:goto_next_match()
      end,
    },
    {
      modes = { "i", "n", "v" },
      key = "<leader>`",
      desc = "search_buffer: focus source window",
      callback = function()
        self:focus_source()
      end,
    },
    {
      modes = { "i", "n", "v" },
      key = "<C-a>j",
      aliases = { "<D-j>", "<M-j>" },
      desc = "search_buffer: focus replacer window",
      callback = function()
        self:focus_finder()
      end,
    },
    {
      modes = { "i", "n", "v" },
      key = "<C-a>k",
      aliases = { "<D-k>", "<M-k>" },
      desc = "search_buffer: focus finder window",
      callback = function()
        self:focus_finder()
      end,
    },
  }
  for index, flag in ipairs(raw_flags) do
    replacer_keymaps[#replacer_keymaps + 1] = {
      modes = { "n", "v" },
      key = string.format("t%d", index),
      desc = flag.desc,
      callback = flag.callback,
    }
  end

  -- Create winbar once at module level
  local position = "f_wl" ---@type eve.ux.nvimbar.PositionEnum
  local c = eve.ux.nvimbar.component

  ---@type eve.ux.nvimbar.Nvimbar
  local nvimbar = eve.ux.nvimbar.Nvimbar
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
          local width = vim.api.nvim_win_get_width(winnr) ---@type integer
          return width - 2
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

  ---@type std.collection.Scheduler
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

  -- Add observer to update line count when search pattern changes
  std.fn.observe({
    o_search_pattern,
  }, function()
    local pattern = self.o_search_pattern:snapshot() ---@type string
    if pattern == nil or pattern == "" then
      o_search_pattern_linecount:next(1)
      return
    end
    local lines = vim.split(pattern, "\n", { plain = true })
    o_search_pattern_linecount:next(#lines)
  end, true)

  -- Add observers to re-render winbar when flags or match info change
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

  -- Add observers to trigger search when search-affecting flags change
  std.fn.observe({
    o_flag_fuzzy,
    o_flag_regex,
    o_flag_case_sensitive,
    o_search_pattern,
  }, function()
    scheduler_search:schedule()
  end, true)

  -- Add observer to resize window when line count changes
  std.fn.observe({
    o_search_pattern_linecount,
  }, function()
    self:__resize__()
  end, true)

  -- Add observer to show/hide replacer window when replace flag changes
  std.fn.observe({
    o_flag_replace,
  }, function()
    local flag_replace = o_flag_replace:snapshot() ---@type boolean

    -- Update finder window border to match new state
    local winnr_finder = self._winnr_finder ---@type integer|nil
    if winnr_finder ~= nil and vim.api.nvim_win_is_valid(winnr_finder) then
      local finder_config = vim.api.nvim_win_get_config(winnr_finder)
      local new_border = flag_replace and { "╭", "─", "╮", "│", "┤", "─", "├", "│" } or "rounded"
      finder_config.border = new_border
      vim.api.nvim_win_set_config(winnr_finder, finder_config)
    end

    if flag_replace then
      self:__create_replacer_window_as_needed__()
    else
      -- Close replacer window if it exists
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
  end, true)

  self.title = "Search in Buffer"
  self.o_flag_fuzzy = o_flag_fuzzy
  self.o_flag_regex = o_flag_regex
  self.o_flag_replace = o_flag_replace
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
  if bufnr_source ~= nil and vim.api.nvim_buf_is_valid(bufnr_source) then
    vim.api.nvim_buf_clear_namespace(bufnr_source, NSNR_SEARCH, 0, -1)
    vim.api.nvim_buf_clear_namespace(bufnr_source, NSNR_SEARCH_CURRENT, 0, -1)
  end
  self._scheduler_search:cancel()
end

---@return nil
function M:focus_finder()
  local winnr = self._winnr_finder ---@type integer|nil
  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    vim.api.nvim_set_current_win(winnr)
  end
end

---@return nil
function M:focus_replacer()
  local winnr = self._winnr_replacer ---@type integer|nil
  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    vim.api.nvim_set_current_win(winnr)
  end
end

---@return nil
function M:focus_source()
  local winnr = self._winnr_source ---@type integer|nil
  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    vim.api.nvim_set_current_win(winnr)
  end
end

---@return integer|nil
function M:get_winnr_finder()
  return self._winnr_finder
end

---@return nil
function M:goto_prev_match()
  local matches = self._matches ---@type oxi.string.ILineMatch[]|nil
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
  local match_prev = matches[index] ---@type oxi.string.ILineMatch
  if match_prev and match_prev.matches and #match_prev.matches > 0 then
    self.o_match_index:next(index)
    pcall(vim.api.nvim_win_set_cursor, winnr, { match_prev.lnum, match_prev.matches[1].l })

    -- Update current match highlight
    vim.api.nvim_buf_clear_namespace(bufnr, NSNR_SEARCH_CURRENT, 0, -1)
    for _, point in ipairs(match_prev.matches) do
      highlight_match_point(bufnr, NSNR_SEARCH_CURRENT, "IncSearch", match_prev.lnum, point)
    end
  end
end

---@return nil
function M:goto_next_match()
  local matches = self._matches ---@type oxi.string.ILineMatch[]|nil
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
  local match_next = matches[index] ---@type oxi.string.ILineMatch
  if match_next and match_next.matches and #match_next.matches > 0 then
    self.o_match_index:next(index)
    pcall(vim.api.nvim_win_set_cursor, winnr, { match_next.lnum, match_next.matches[1].l })

    -- Update current match highlight
    vim.api.nvim_buf_clear_namespace(bufnr, NSNR_SEARCH_CURRENT, 0, -1)
    for _, point in ipairs(match_next.matches) do
      highlight_match_point(bufnr, NSNR_SEARCH_CURRENT, "IncSearch", match_next.lnum, point)
    end
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
  eve.nvim.bindkeys(self._finder_keymaps, { bufnr = bufnr, noremap = true, silent = true })

  local pattern = self.o_search_pattern:snapshot() ---@type string
  local lines = vim.split(pattern, "\n", { plain = true })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  -- Set up search icon sign
  local sign_group = "fml_search_buffer_prompt"
  local sign_name = "SearchBufferPrompt"
  vim.fn.sign_define(sign_name, { text = eve.icon.ui.Search, texthl = "f_pk_finder_prompt" })
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
  eve.nvim.bindkeys(self._replacer_keymaps, { bufnr = bufnr, noremap = true, silent = true })

  local pattern = self.o_replace_pattern:snapshot() ---@type string
  local lines = vim.split(pattern, "\n", { plain = true })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  -- Set up replace icon sign
  local sign_group = "fml_replace_buffer_prompt"
  local sign_name = "ReplaceBufferPrompt"
  vim.fn.sign_define(sign_name, { text = eve.icon.symbols.flag_replace, texthl = "f_pk_finder_prompt" })
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
---@return nil
function M:__clear__()
  local bufnr = self._bufnr_source
  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_clear_namespace(bufnr, NSNR_SEARCH, 0, -1)
    vim.api.nvim_buf_clear_namespace(bufnr, NSNR_SEARCH_CURRENT, 0, -1)
  end
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
    vim.api.nvim_win_set_config(winnr, current_config)
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
    self.o_match_index:next(0)
    self.o_match_total:next(0)
    vim.api.nvim_buf_clear_namespace(bufnr_source, NSNR_SEARCH, 0, -1)
    vim.api.nvim_buf_clear_namespace(bufnr_source, NSNR_SEARCH_CURRENT, 0, -1)
    return
  end

  -- Construct search parameters
  ---@type oxi.searcher.ISearchInBufferParams
  local search_params = {
    bufnr = bufnr_source,
    search_pattern = pattern,
    flag_fuzzy = self.o_flag_fuzzy:snapshot(),
    flag_regex = self.o_flag_regex:snapshot(),
    flag_case_sensitive = self.o_flag_case_sensitive:snapshot(),
    flag_replace = self.o_flag_replace:snapshot(),
  }

  -- Perform the search
  local matches = oxi.searcher.search_in_buffer(search_params)

  -- Check for errors or no matches
  if not matches or #matches < 1 then
    self._matches = {}
    self.o_match_index:next(0)
    self.o_match_total:next(0)
    vim.api.nvim_buf_clear_namespace(bufnr_source, NSNR_SEARCH, 0, -1)
    vim.api.nvim_buf_clear_namespace(bufnr_source, NSNR_SEARCH_CURRENT, 0, -1)
    return
  end

  self._matches = matches
  self.o_match_total:next(#matches)
  self.o_match_index:next(1)
  vim.api.nvim_buf_clear_namespace(bufnr_source, NSNR_SEARCH, 0, -1)
  vim.api.nvim_buf_clear_namespace(bufnr_source, NSNR_SEARCH_CURRENT, 0, -1)
  for _, match in ipairs(matches) do
    for _, point in ipairs(match.matches) do
      highlight_match_point(bufnr_source, NSNR_SEARCH, "Search", match.lnum, point)
    end
  end

  -- Move cursor to first match and highlight it
  local first_match = matches[1]
  if first_match and first_match.matches and #first_match.matches > 0 then
    local target_win = self._winnr_source ---@type integer|nil
    if target_win ~= nil and vim.api.nvim_win_is_valid(target_win) then
      local line_count = vim.api.nvim_buf_line_count(bufnr_source)
      if first_match.lnum > 0 and first_match.lnum <= line_count then
        vim.api.nvim_win_set_cursor(target_win, { first_match.lnum, first_match.matches[1].l })
        -- Highlight current match
        for _, point in ipairs(first_match.matches) do
          highlight_match_point(bufnr_source, NSNR_SEARCH_CURRENT, "IncSearch", first_match.lnum, point)
        end
      end
    end
  end
end

return M
