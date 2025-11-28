local convert = require("eve.ux.widget.colorpicker.convert")

---@class eve.ux.widget.colorpicker.picker
local M = {}

local HEX_PATTERNS = {
  [=[\\v%(^|[^[:keyword:]])\\zs#(\\x\\x)(\\x\\x)(\\x\\x)>]=],
  [=[\\v%(^|[^[:keyword:]])\\zs#(\\x\\x)(\\x\\x)(\\x\\x)(\\x\\x)>]=],
  [=[\\v%(^|[^[:keyword:]])\\zs#(\\x)(\\x)(\\x)>]=],
  [=[\\v%(^|[^[:keyword:]])\\zs#(\\x)(\\x)(\\x)(\\x)>]=],
}

---@param hex_str                       string
---@return integer|nil
local function parse_hex_component(hex_str)
  if not hex_str or #hex_str == 0 then
    return nil
  end
  return tonumber(hex_str, 16)
end

---@param line                          string
---@param cursor_col                    integer
---@return eve.ux.widget.colorpicker.IPickResult|nil
function M.pick_hex(line, cursor_col)
  local init = 1
  while init <= #line - 3 do
    local best_start, best_end, best_r, best_g, best_b, best_a

    for _, pattern in ipairs(HEX_PATTERNS) do
      local result = vim.fn.matchstrpos(line, pattern, init - 1)
      if result[2] >= 0 then
        local matched = result[1]
        local start_col = result[2] + 1
        local end_col = result[3]

        if not best_start or start_col < best_start then
          local hex_part = matched:match("#(%x+)")
          if hex_part then
            local r, g, b, a
            if #hex_part == 3 then
              r = hex_part:sub(1, 1):rep(2)
              g = hex_part:sub(2, 2):rep(2)
              b = hex_part:sub(3, 3):rep(2)
            elseif #hex_part == 4 then
              r = hex_part:sub(1, 1):rep(2)
              g = hex_part:sub(2, 2):rep(2)
              b = hex_part:sub(3, 3):rep(2)
              a = hex_part:sub(4, 4):rep(2)
            elseif #hex_part == 6 then
              r = hex_part:sub(1, 2)
              g = hex_part:sub(3, 4)
              b = hex_part:sub(5, 6)
            elseif #hex_part == 8 then
              r = hex_part:sub(1, 2)
              g = hex_part:sub(3, 4)
              b = hex_part:sub(5, 6)
              a = hex_part:sub(7, 8)
            end

            if r and g and b then
              best_start = start_col
              best_end = end_col
              best_r = r
              best_g = g
              best_b = b
              best_a = a
            end
          end
        end
      end
    end

    if not best_start then
      break
    end

    if best_start <= cursor_col and cursor_col <= best_end then
      local r = parse_hex_component(best_r or "")
      local g = parse_hex_component(best_g or "")
      local b = parse_hex_component(best_b or "")
      local a = parse_hex_component(best_a or "")

      if r and g and b then
        return {
          start_col = best_start,
          end_col = best_end,
          r = r,
          g = g,
          b = b,
          alpha = a and convert.round(a * 100 / 255) or nil,
          input_mode = "RGB",
          output_mode = "HEX",
        }
      end
    end

    init = best_end + 1
  end

  return nil
end

---@param line                          string
---@param cursor_col                    integer
---@return eve.ux.widget.colorpicker.IPickResult|nil
function M.pick_css_rgb(line, cursor_col)
  local pattern = "rgb%s*%((.-)%)"
  local init = 1

  while init <= #line do
    local s, e, inner = line:find(pattern, init)
    if not s then
      break
    end

    if s <= cursor_col and cursor_col <= e then
      local r, g, b, a, is_percent
      local inner_str = inner or ""

      local r1, g1, b1, a1 = inner_str:match("^%s*(%d+)%s+(%d+)%s+(%d+)%s*/%s*([%d%.]+)%%%s*$")
      if r1 then
        r, g, b, a, is_percent = r1, g1, b1, a1, true
      else
        r1, g1, b1, a1 = inner_str:match("^%s*(%d+)%s+(%d+)%s+(%d+)%s*/%s*([%d%.]+)%s*$")
        if r1 then
          r, g, b, a, is_percent = r1, g1, b1, a1, false
        else
          r, g, b = inner_str:match("^%s*(%d+)%s+(%d+)%s+(%d+)%s*$")
          if not r then
            r, g, b = inner_str:match("^%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*$")
          end
        end
      end

      if r and g and b then
        local rn = tonumber(r) or 0
        local gn = tonumber(g) or 0
        local bn = tonumber(b) or 0
        local an = nil
        if a then
          an = is_percent and convert.round(tonumber(a) or 0) or convert.round((tonumber(a) or 0) * 100)
        end

        return {
          start_col = s,
          end_col = e,
          r = rn,
          g = gn,
          b = bn,
          alpha = an,
          input_mode = "RGB",
          output_mode = "RGB",
        }
      end
    end

    init = e + 1
  end

  return nil
end

---@param line                          string
---@param cursor_col                    integer
---@return eve.ux.widget.colorpicker.IPickResult|nil
function M.pick_css_hsl(line, cursor_col)
  local pattern = "hsl%s*%((.-)%)"
  local init = 1

  while init <= #line do
    local s, e, inner = line:find(pattern, init)
    if not s then
      break
    end

    if s <= cursor_col and cursor_col <= e then
      local h, s_pct, l_pct, a, is_percent
      local inner_str = inner or ""

      local h1, s1, l1, a1 = inner_str:match("^%s*(%d+)%s+(%d+)%%%s+(%d+)%%%s*/%s*([%d%.]+)%%%s*$")
      if h1 then
        h, s_pct, l_pct, a, is_percent = h1, s1, l1, a1, true
      else
        h1, s1, l1, a1 = inner_str:match("^%s*(%d+)%s+(%d+)%%%s+(%d+)%%%s*/%s*([%d%.]+)%s*$")
        if h1 then
          h, s_pct, l_pct, a, is_percent = h1, s1, l1, a1, false
        else
          h, s_pct, l_pct = inner_str:match("^%s*(%d+)%s+(%d+)%%%s+(%d+)%%%s*$")
          if not h then
            h, s_pct, l_pct = inner_str:match("^%s*(%d+)%s*,%s*(%d+)%%%s*,%s*(%d+)%%%s*$")
          end
        end
      end

      if h and s_pct and l_pct then
        local hn = tonumber(h) or 0
        local sn = tonumber(s_pct) or 0
        local ln = tonumber(l_pct) or 0
        local an = nil
        if a then
          an = is_percent and convert.round(tonumber(a) or 0) or convert.round((tonumber(a) or 0) * 100)
        end

        local r, g, b = convert.hsl2rgb(hn, sn, ln)

        return {
          start_col = s,
          end_col = e,
          r = r,
          g = g,
          b = b,
          alpha = an,
          input_mode = "HSL",
          output_mode = "HSL",
        }
      end
    end

    init = e + 1
  end

  return nil
end

---@return eve.ux.widget.colorpicker.IPickResult|nil
function M.pick()
  local winnr = vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_win_get_buf(winnr)
  local row, cursor_col = unpack(vim.api.nvim_win_get_cursor(winnr))
  local lines = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)
  local line = lines[1] or ""
  cursor_col = cursor_col + 1

  local result = M.pick_hex(line, cursor_col)
  if result then
    return result
  end

  result = M.pick_css_rgb(line, cursor_col)
  if result then
    return result
  end

  result = M.pick_css_hsl(line, cursor_col)
  if result then
    return result
  end

  return nil
end

return M
