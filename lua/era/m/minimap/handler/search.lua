---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.minimap.handler.search" ---@type string

local util = require("era.m.minimap.util")

local HIGHLIGHT = "m_mm_search"
local HIGHLIGHT_CURRENT = "m_mm_search_current"
local SYMBOLS = { "⠂", "⠅", "⠇", "⠗", "⠟", "⠿" } ---@type string[]
local SYMBOLS_COUNT = #SYMBOLS ---@type integer
local SEARCH_KEYS = { n = true, N = true, ["&"] = true, ["*"] = true, ["#"] = true } ---@type table<string, boolean>

---@class era.m.minimap.handler.search : era.m.minimap.IHandler
local M = {
  name = "search",
}

---@type table<integer, uv.uv_timer_t>
local search_timers = {}

---@type table<integer, integer>
local on_key_nss = {}

---@type table<integer, integer>
local last_hlsearch_by_winnr = {}

---@class era.m.minimap.handler.search.ICacheElem
---@field public changedtick          integer
---@field public pattern              string
---@field public matches              table<integer, integer>

---@type table<integer, era.m.minimap.handler.search.ICacheElem>
local cache = {}

---@return boolean
local function is_search_mode()
  return vim.o.incsearch
    and vim.o.hlsearch
    and vim.api.nvim_get_mode().mode == "c"
    and vim.tbl_contains({ "/", "?" }, vim.fn.getcmdtype())
end

---@param winnr                       integer
---@param data                        any
---@return nil
local function exec_search_autocmd(winnr, data)
  vim.api.nvim_exec_autocmds("User", { pattern = "Search_" .. tostring(winnr), data = data })
end

---@param pattern                     string
---@return string
local function smartcaseify(pattern)
  if pattern and vim.o.ignorecase and vim.o.smartcase then
    local smartcase = pattern:find("[A-Z]") ~= nil ---@type boolean
    if smartcase and not vim.startswith(pattern, "\\C") then
      return "\\C" .. pattern
    end
  end
  return pattern
end

---@return string
local function get_pattern()
  if is_search_mode() then
    return vim.fn.getcmdline()
  end
  return vim.v.hlsearch == 1 and vim.fn.getreg("/") or ""
end

---@async
---@param bufnr                       integer
---@param pattern                     string|nil
---@return table<integer, integer>
local function update_matches(bufnr, pattern)
  pattern = pattern or get_pattern()
  pattern = smartcaseify(pattern)

  if
    cache[bufnr]
    and cache[bufnr].changedtick == vim.b[bufnr].changedtick
    and (not pattern or cache[bufnr].pattern == pattern)
  then
    return cache[bufnr].matches
  end

  local matches = {} ---@type table<integer, integer>

  if pattern and pattern ~= "" then
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)
    local pred = util.winbuf_pred(bufnr)

    for lnum, line in stl.async.ipairs(lines) do
      if pred() == false then
        return {}
      end
      local count = 1 ---@type integer
      repeat
        local ok, col = pcall(vim.fn.match, line, pattern, 0, count)
        if not ok then
          matches[lnum] = 0
          break
        elseif col ~= -1 then
          matches[lnum] = (matches[lnum] or 0) + 1
        end
        if count >= SYMBOLS_COUNT then
          break
        end
        count = count + 1
      until col == -1
    end
  end

  cache[bufnr] = {
    pattern = pattern,
    changedtick = vim.b[bufnr].changedtick,
    matches = matches,
  }

  return matches
end

---@class era.m.minimap.handler.search.ISearchMark
---@field public count                integer
---@field public highlight            string|nil
---@field public unique               boolean|nil
---@field public symbol               string|nil

---@async
---@param bufnr                       integer
---@param winnr                       integer
---@return era.m.minimap.IMark[]
local function get_marks(bufnr, winnr)
  local matches = update_matches(bufnr)

  if not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_win_is_valid(winnr) then
    return {}
  end

  local cursor_lnum = vim.api.nvim_win_get_cursor(winnr)[1] ---@type integer
  local pred = util.winbuf_pred(bufnr, winnr)

  local marks = {} ---@type era.m.minimap.handler.search.ISearchMark[]

  for lnum, count in stl.async.pairs(matches) do
    if pred() == false then
      return {}
    end
    local pos = util.row_to_barpos(winnr, lnum - 1)

    local count0 = count ---@type integer
    if marks[pos] and marks[pos].count then
      count0 = count0 + marks[pos].count
    end

    if lnum == cursor_lnum then
      marks[pos] = {
        count = count0,
        highlight = HIGHLIGHT_CURRENT,
        unique = true,
      }
    elseif count0 <= SYMBOLS_COUNT then
      marks[pos] = {
        count = count0,
      }
    end
  end

  local ret = {} ---@type era.m.minimap.IMark[]

  for pos, mark in pairs(marks) do
    ret[#ret + 1] = {
      pos = pos,
      unique = mark.unique,
      highlight = mark.highlight or HIGHLIGHT,
      symbol = mark.symbol or SYMBOLS[mark.count] or SYMBOLS[SYMBOLS_COUNT],
    }
  end

  return ret
end

---@param winnr                       integer
---@return nil
local function render(winnr)
  stl.async.run(function()
    local view = require("era.m.minimap.view")
    if not vim.api.nvim_win_is_valid(winnr) or not view.is_attached(winnr) then
      return
    end
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    local marks = get_marks(bufnr, winnr)
    if not vim.api.nvim_win_is_valid(winnr) or not view.is_attached(winnr) then
      return
    end
    if vim.api.nvim_win_get_buf(winnr) ~= bufnr then
      return
    end
    view.render_handler(winnr, M.ns, M.config, marks)
  end)
end

---@param winnr                       integer
---@return nil
function M.attach(winnr)
  local gname = "era_minimap_search_" .. tostring(winnr) ---@type string
  local group = vim.api.nvim_create_augroup(gname, { clear = true })

  local search_timer = assert(vim.uv.new_timer())
  search_timers[winnr] = search_timer
  last_hlsearch_by_winnr[winnr] = vim.v.hlsearch
  local search_interval = math.min(vim.o.updatetime, 1000) ---@type integer
  search_timer:start(0, search_interval, function()
    local last_hlsearch = last_hlsearch_by_winnr[winnr]
    if vim.v.hlsearch ~= last_hlsearch then
      last_hlsearch_by_winnr[winnr] = vim.v.hlsearch
      vim.schedule(function()
        exec_search_autocmd(winnr, { hlsearch = vim.v.hlsearch })
      end)
    end
  end)

  local on_key_ns = vim.on_key(function(key)
    if vim.api.nvim_get_mode().mode == "n" and SEARCH_KEYS[key] then
      exec_search_autocmd(winnr, { key = key })
    end
  end) ---@type integer
  on_key_nss[winnr] = on_key_ns

  vim.api.nvim_create_autocmd({ "CmdlineEnter", "CmdlineChanged", "CmdlineLeave" }, {
    group = group,
    callback = function()
      if is_search_mode() then
        exec_search_autocmd(winnr, { pattern = vim.fn.getcmdline() })
      end
    end,
  })

  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = group,
    callback = function(args)
      if not vim.api.nvim_win_is_valid(winnr) or vim.api.nvim_win_get_buf(winnr) ~= args.buf then
        return
      end
      exec_search_autocmd(winnr, { buf = args.buf })
    end,
  })

  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "Search_" .. tostring(winnr),
    callback = vim.schedule_wrap(function()
      render(winnr)
    end),
  })

  render(winnr)
end

---@param winnr                       integer
---@return nil
function M.detach(winnr)
  local search_timer = search_timers[winnr]
  if search_timer then
    search_timer:stop()
    search_timer:close()
    search_timers[winnr] = nil
  end

  local on_key_ns = on_key_nss[winnr]
  if on_key_ns then
    vim.on_key(nil, on_key_ns)
    on_key_nss[winnr] = nil
  end

  last_hlsearch_by_winnr[winnr] = nil

  local gname = "era_minimap_search_" .. tostring(winnr) ---@type string
  vim.api.nvim_clear_autocmds({ group = gname })
end

return M
