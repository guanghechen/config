---@class eve.builtin.fn
local M = {}

---@generic T
---@param fn                            T
---@param delay                         ?integer
---@return T
function M.debounce(fn, delay)
  local timer = assert(vim.uv.new_timer()) ---@type uv.uv_timer_t
  local duration = delay or 20 ---@type integer
  return function()
    timer:start(duration, 0, vim.schedule_wrap(fn))
  end
end

local spinners = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" } ---@type string[]

---@return string
function M.spinner()
  local index = math.floor(vim.uv.hrtime() / (1e6 * 80)) % #spinners + 1 ---@type integer
  return spinners[index]
end

----------------------------------------------------------------------------------------------------

---@param value                         unknown
---@return boolean
function M.is_dict(value)
  return type(value) == "table" and (vim.tbl_isempty(value) or not value[1])
end

---@param value                         unknown
---@return boolean
function M.is_dict_like(value)
  return type(value) == "table" and (vim.tbl_isempty(value) or not vim.islist(value))
end

---@param value                         unknown
---@return boolean
function M.is_disposable(value)
  return type(value) == "table" and type(value.isDisposable) == "function" and type(value.dispose) == "function"
end

---@param value                         unknown
---@return boolean
function M.is_observable(value)
  return type(value) == "table"
    and type(value.snapshot) == "function"
    and type(value.next) == "function"
    and type(value.subscribe) == "function"
end

----------------------------------------------------------------------------------------------------

---@param text                          string
---@return string
function M.escape_url_component(text)
  return (text:gsub("([^%w%.%-])", function(c)
    return string.format("%%%02X", string.byte(c))
  end))
end

---@param text                          string
---@return string
function M.remove_last_slash(text)
  if #text > 1 then
    local last_character = string.sub(text, -1, -1)
    if last_character == "/" or last_character == "\\" then
      return string.sub(text, 1, -2)
    end
  end
  return text
end

----------------------------------------------------------------------------------------------------

---@param current                       integer  current index
---@param step                          integer  moving step
---@param total                         integer  total index.
---@return integer
function M.navigate_circular(current, step, total)
  local candidate = (current + step - 1) % total

  while candidate < 0 do
    candidate = candidate + total
  end

  while candidate >= total do
    candidate = candidate - total
  end

  return candidate + 1
end

---@param current                       integer  current index
---@param step                          integer  moving step
---@param total                         integer  total index.
---@return integer
function M.navigate_limit(current, step, total)
  local candidate = current + step

  if candidate < 1 then
    return 1
  end

  if candidate > total then
    return total
  end

  return candidate
end

----------------------------------------------------------------------------------------------------

---@param str                           string
---@param data                          table<string, string>
---@param opts                          ?{ prefix?: string, indent?: boolean, offset?: number[] }
function M.tpl(str, data, opts)
  opts = opts or {}
  local ret = (
    str:gsub(
      "(" .. vim.pesc(opts.prefix or "") .. "%b{}" .. ")",
      ---@param w                       string
      ---@return string
      function(w)
        local inner = w:sub(2 + #(opts.prefix or ""), -2)
        local key, default = inner:match("^(.-):(.*)$")
        local ret = data[key or inner]
        if ret == "" and default then
          return default
        end
        return ret or w
      end
    )
  )
  if opts.indent then
    local lines = vim.split(ret:gsub("\t", "  "), "\n", { plain = true })
    local indent = 1000
    for _, line in ipairs(lines) do
      indent = math.min(indent, line:find("%S") or 1000)
    end
    for l, line in ipairs(lines) do
      lines[l] = line:sub(indent)
    end
  end
  return ret
end

----------------------------------------------------------------------------------------------------

---@param timestamp                     integer
---@return string
function M.time_ago(timestamp)
  local current_time = os.time()
  local diff = current_time - timestamp

  local seconds_in_minute = 60
  local seconds_in_hour = 3600
  local seconds_in_day = 86400
  local seconds_in_month = 2592000 -- Approximation
  local seconds_in_year = 31536000 -- Approximation

  if diff < seconds_in_minute then
    return string.format("%d seconds ago", diff)
  elseif diff < seconds_in_hour then
    return string.format("%d minutes ago", math.floor(diff / seconds_in_minute))
  elseif diff < seconds_in_day then
    return string.format("%d hours ago", math.floor(diff / seconds_in_hour))
  elseif diff < seconds_in_month then
    return string.format("%d days ago", math.floor(diff / seconds_in_day))
  elseif diff < seconds_in_year then
    return string.format("%d months ago", math.floor(diff / seconds_in_month))
  else
    return string.format("%d years ago", math.floor(diff / seconds_in_year))
  end
end

----------------------------------------------------------------------------------------------------

---@return table<string, integer>
function M.filepath2bufnr()
  local bufnrs = vim.api.nvim_list_bufs() ---@type integer[]
  local filepath2bufnr = {} ---@type table<string, integer>

  for _, bufnr in ipairs(bufnrs) do
    local filepath = vim.api.nvim_buf_get_name(bufnr)
    if filepath ~= nil and #filepath > 0 then
      filepath2bufnr[filepath] = bufnr
    end
  end
  return filepath2bufnr
end

---@param hlname                        string
---@return string
function M.make_bg_transparency(hlname)
  local fg = vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID(hlname)), "fg#")
  local new_hlname = "_t_" .. hlname
  vim.schedule(function()
    vim.api.nvim_set_hl(0, new_hlname, { fg = fg, bg = "none" })
  end)
  return new_hlname
end

--- Merges the values similar to vim.tbl_deep_extend with the **force** behavior,
--- but the values can be any type
---@generic T
---@param ... T
---@return T
function M.merge_config(...)
  local ret = select(1, ...)
  for i = 2, select("#", ...) do
    local value = select(i, ...)
    if M.is_dict_like(ret) and M.is_dict(value) then
      for k, v in pairs(value) do
        ret[k] = M.merge_config(ret[k], v)
      end
    elseif value ~= nil then
      ret = value
    end
  end
  return ret
end

---@param hlgroups                      string[]
---@param field                         "fg"|"bg"|"sp"
---@return string|nil
function M.pick_color(hlgroups, field)
  for _, hlgroup in ipairs(hlgroups) do
    local hl = vim.api.nvim_get_hl(0, { name = hlgroup, link = false })
    if hl[field] then
      return string.format("#%06x", hl[field])
    end
  end
  return nil
end

return M
