---@diagnostic disable: invisible
local __module_name__ = "eve.ux.searcher.buffer" ---@type string
local NSNR_SEARCH = vim.api.nvim_create_namespace("eve.ux.searcher.buffer") ---@type integer

---@class eve.ux.searcher.buffer.Searcher
---@field public title                  string
---@field public o_flag_fuzzy           std.collection.IObservable
---@field public o_flag_regex           std.collection.IObservable
---@field public o_flag_replace         std.collection.IObservable
---@field public o_flag_case_sensitive  std.collection.IObservable
---@field public o_search_pattern       std.collection.IObservable
---@field public o_replace_pattern      std.collection.IObservable
---@field public o_match_index          std.collection.IObservable
---@field public o_match_total          std.collection.IObservable
---@field protected _winnr_popup        integer|nil
---@field protected _bufnr_popup        integer|nil
---@field protected _bufnr_source       integer|nil
---@field protected _matches            oxi.string.ILineMatch[]|nil
---@field protected _scheduler_search   std.collection.Scheduler
---@field protected _nvimbar            eve.ux.nvimbar.Nvimbar
---@field protected _keymaps            std.t.IKeymap[]
local M = {}
M.__index = M

---@return eve.ux.searcher.buffer.Searcher
function M.new()
  local o_flag_fuzzy = std.Observable.from_value(false)
  local o_flag_regex = std.Observable.from_value(false)
  local o_flag_replace = std.Observable.from_value(false)
  local o_flag_case_sensitive = std.Observable.from_value(false)
  local o_search_pattern = std.Observable.from_value("")
  local o_replace_pattern = std.Observable.from_value("")
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
  local keymaps = {
    {
      modes = { "n" },
      key = "q",
      desc = "search_buffer: close",
      callback = function()
        self:close_popup()
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
  }
  for index, flag in ipairs(raw_flags) do
    keymaps[#keymaps + 1] = {
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
        local winnr = self._winnr_popup ---@type integer|nil
        if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
          local width = vim.api.nvim_win_get_width(winnr) ---@type integer
          return width - 2
        end
        return 0
      end,
      get_preset_context = function()
        local winnr = self._winnr_popup ---@type integer|nil
        if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
          return { winnr = winnr }
        end
        return {}
      end,
      is_active = function()
        local winnr = self._winnr_popup ---@type integer|nil
        return winnr ~= nil and vim.api.nvim_win_is_valid(winnr)
      end,
      on_fulfilled = function(result)
        local winnr = self._winnr_popup ---@type integer|nil
        if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
          vim.wo[winnr].winbar = result
        end
      end,
      validate = function()
        local winnr = self._winnr_popup ---@type integer|nil
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

  self.title = "Search in Buffer"
  self.o_flag_fuzzy = o_flag_fuzzy
  self.o_flag_regex = o_flag_regex
  self.o_flag_replace = o_flag_replace
  self.o_flag_case_sensitive = o_flag_case_sensitive
  self.o_search_pattern = o_search_pattern
  self.o_replace_pattern = o_replace_pattern
  self.o_match_index = o_match_index
  self.o_match_total = o_match_total
  self._winnr_popup = nil
  self._bufnr_popup = nil
  self._bufnr_source = nil
  self._matches = nil
  self._nvimbar = nvimbar
  self._scheduler_search = scheduler_search
  self._keymaps = keymaps

  -- Add observers to re-render winbar when flags or match info change
  std.fn.observe({
    self.o_flag_fuzzy,
    self.o_flag_regex,
    self.o_flag_case_sensitive,
    self.o_flag_replace,
    self.o_match_index,
    self.o_match_total,
  }, function()
    self._nvimbar:render()
  end, true)

  -- Add observers to trigger search when search-affecting flags change
  std.fn.observe({
    self.o_flag_fuzzy,
    self.o_flag_regex,
    self.o_flag_case_sensitive,
    self.o_search_pattern,
  }, function()
    scheduler_search:schedule()
  end, true)

  return self
end

---@return nil
function M:goto_prev_match()
  local bufnr = self._bufnr_source ---@type integer|nil
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local matches = self._matches ---@type oxi.string.ILineMatch[]|nil
  if matches == nil then
    return
  end

  local N = #matches ---@type integer
  if N < 1 then
    return
  end

  local index = math.min(N, self.o_match_index:snapshot() or 2) ---@type integer
  index = index <= 1 and N or (index - 1) ---@type integer

  local match_prev = matches[index] ---@type oxi.string.ILineMatch
  if match_prev and match_prev.matches and #match_prev.matches > 0 then
    local target_win = vim.api.nvim_get_current_win() ---@type integer
    if vim.api.nvim_win_is_valid(target_win) then
      self.o_match_index:next(index)
      vim.api.nvim_win_set_cursor(target_win, { match_prev.lnum, match_prev.matches[1].l })
    end
  end
end

---@return nil
function M:goto_next_match()
  local bufnr = self._bufnr_source ---@type integer|nil
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local matches = self._matches ---@type oxi.string.ILineMatch[]|nil
  if matches == nil then
    return
  end

  local N = #matches ---@type integer
  if N < 1 then
    return
  end

  local index = math.max(0, self.o_match_index:snapshot() or 0) ---@type integer
  index = index >= N and 1 or (index + 1) ---@type integer

  local match_next = matches[index] ---@type oxi.string.ILineMatch
  if match_next and match_next.matches and #match_next.matches > 0 then
    local target_win = vim.api.nvim_get_current_win() ---@type integer
    if vim.api.nvim_win_is_valid(target_win) then
      self.o_match_index:next(index)
      vim.api.nvim_win_set_cursor(target_win, { match_next.lnum, match_next.matches[1].l })
    end
  end
end

---@return nil
function M:clear_highlight()
  local bufnr = self._bufnr_source ---@type integer|nil
  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_clear_namespace(bufnr, NSNR_SEARCH, 0, -1)
  end
end

---@return nil
function M:refresh_highlight()
  local bufnr = self._bufnr_source ---@type integer|nil
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  vim.api.nvim_buf_clear_namespace(bufnr, NSNR_SEARCH, 0, -1)

  local matches = self._matches ---@type oxi.string.ILineMatch[]|nil
  if matches == nil or #matches < 1 then
    return
  end

  for _, match in ipairs(matches) do
    local row = match.lnum - 1 ---@type integer
    for _, point in ipairs(match.matches) do
      vim.hl.range(bufnr, NSNR_SEARCH, "Search", { row, point.l }, { row, point.r })
    end
  end
end

---@return nil
function M:close_popup()
  local winnr_popup = self._winnr_popup ---@type integer|nil
  local bufnr_popup = self._bufnr_popup ---@type integer|nil
  local bufnr_source = self._bufnr_source ---@type integer|nil

  self._winnr_popup = nil
  if winnr_popup ~= nil and vim.api.nvim_win_is_valid(winnr_popup) then
    vim.api.nvim_win_close(winnr_popup, true)
  end

  self._bufnr_popup = nil
  if bufnr_popup ~= nil and vim.api.nvim_buf_is_valid(bufnr_popup) then
    vim.api.nvim_buf_delete(bufnr_popup, { force = true })
  end

  self._bufnr_source = nil
  if bufnr_source ~= nil and vim.api.nvim_buf_is_valid(bufnr_source) then
    vim.api.nvim_buf_clear_namespace(bufnr_source, NSNR_SEARCH, 0, -1)
  end

  self._scheduler_search:cancel()
end

---@return integer, boolean
function M:create_popup_buffer_as_needed()
  local bufnr = self._bufnr_popup ---@type integer|nil
  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    return bufnr, false
  end

  bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  self._bufnr_popup = bufnr

  vim.b[bufnr].miniindentscope_disable = true
  vim.b[bufnr].miniai_disable = true
  vim.b[bufnr].minihipatterns_disable = true
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].swapfile = false

  -- Use keymaps created in constructor
  eve.nvim.bindkeys(self._keymaps, { bufnr = bufnr, noremap = true, silent = true })

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
      self:set_prompt()
    end,
  })

  return bufnr, true
end

---@return integer, boolean
function M:create_popup_window_as_needed()
  local winnr = self._winnr_popup ---@type integer|nil
  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    return winnr, false
  end

  local winblend = eve.context.theme.get_float_winblend() ---@type integer

  local height = 2 ---@type integer
  local width = math.min(60, math.floor(vim.o.columns * 0.9)) ---@type integer
  local row = 3 ---@type integer
  local col = math.max(0, math.floor((vim.o.columns - width) / 2)) ---@type integer

  -- Create popup window with error handling
  local bufnr = self:create_popup_buffer_as_needed() ---@type integer
  local popup_winnr = vim.api.nvim_open_win(bufnr, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = string.format(" %s ", self.title),
    title_pos = "center",
  })
  self._winnr_popup = popup_winnr

  -- Set window options
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

---@return nil
function M:set_prompt()
  local bufnr = self:create_popup_buffer_as_needed() ---@type integer
  local group = eve.var.sign.GROUP_SEARCHER_BUFFER_PROMPT ---@type string
  local sign = eve.var.sign.SEARCHER_BUFFER_PROMPT ---@type string
  pcall(vim.fn.sign_place, 1, group, sign, bufnr, { lnum = 1, priority = 10 })
end

---@protected
---@return nil
function M:__search__()
  local bufnr_popup = self._bufnr_popup ---@type integer|nil
  if bufnr_popup == nil or not vim.api.nvim_buf_is_valid(bufnr_popup) then
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
    return
  end

  -- Construct search parameters following the filetree pattern
  ---@type oxi.searcher.ISearchInBufferParams
  local search_params = {
    flag_fuzzy = self.o_flag_fuzzy:snapshot(),
    flag_regex = self.o_flag_regex:snapshot(),
    flag_case_sensitive = self.o_flag_case_sensitive:snapshot(),
    flag_replace = self.o_flag_replace:snapshot(),
    search_pattern = pattern,
    replace_pattern = self.o_replace_pattern:snapshot(),
  }

  -- Perform the search
  local matches = oxi.searcher.search_in_buffer(search_params, bufnr_source)
  if not matches or #matches < 1 then
    self._matches = {}
    self.o_match_index:next(0)
    self.o_match_total:next(0)
    vim.api.nvim_buf_clear_namespace(bufnr_source, NSNR_SEARCH, 0, -1)
    return
  end

  self._matches = matches
  self.o_match_total:next(#matches)
  vim.api.nvim_buf_clear_namespace(bufnr_source, NSNR_SEARCH, 0, -1)
  for _, match in ipairs(matches) do
    local row = match.lnum - 1 ---@type integer
    for _, point in ipairs(match.matches) do
      vim.hl.range(bufnr_source, NSNR_SEARCH, "Search", { row, point.l }, { row, point.r })
    end
  end
end

return M
