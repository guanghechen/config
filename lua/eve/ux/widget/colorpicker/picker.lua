local convert = require("eve.ux.widget.colorpicker.convert")

---@class eve.ux.widget.colorpicker.picker
local M = {}

---@param line                          string
---@param cursor_col                    integer
---@return eve.ux.widget.colorpicker.IPickResult|nil
function M.pick_hex(line, cursor_col)
  local init = 1
  while init <= #line do
    local start_col, end_col, hex_part = line:find("#(%x+)", init)
    if not start_col then
      break
    end

    if start_col <= cursor_col and cursor_col <= end_col then
      local r, g, b, a
      local len = #hex_part
      if len == 3 then
        r = tonumber(hex_part:sub(1, 1):rep(2), 16)
        g = tonumber(hex_part:sub(2, 2):rep(2), 16)
        b = tonumber(hex_part:sub(3, 3):rep(2), 16)
      elseif len == 4 then
        r = tonumber(hex_part:sub(1, 1):rep(2), 16)
        g = tonumber(hex_part:sub(2, 2):rep(2), 16)
        b = tonumber(hex_part:sub(3, 3):rep(2), 16)
        a = tonumber(hex_part:sub(4, 4):rep(2), 16)
      elseif len == 6 then
        r = tonumber(hex_part:sub(1, 2), 16)
        g = tonumber(hex_part:sub(3, 4), 16)
        b = tonumber(hex_part:sub(5, 6), 16)
      elseif len == 8 then
        r = tonumber(hex_part:sub(1, 2), 16)
        g = tonumber(hex_part:sub(3, 4), 16)
        b = tonumber(hex_part:sub(5, 6), 16)
        a = tonumber(hex_part:sub(7, 8), 16)
      end

      if r and g and b then
        return {
          start_col = start_col,
          end_col = end_col,
          r = r,
          g = g,
          b = b,
          alpha = a and convert.round(a * 100 / 255) or nil,
          input_mode = "RGB",
          output_mode = "HEX",
        }
      end
    end

    init = end_col + 1
  end

  return nil
end

---@param line                          string
---@param cursor_col                    integer
---@return eve.ux.widget.colorpicker.IPickResult|nil
function M.pick_css_rgb(line, cursor_col)
  local init = 1
  while init <= #line do
    local s, e, inner = line:find("rgb%s*%((.-)%)", init)
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
        local an = nil
        if a then
          an = is_percent and convert.round(tonumber(a) or 0) or convert.round((tonumber(a) or 0) * 100)
        end

        return {
          start_col = s,
          end_col = e,
          r = tonumber(r) or 0,
          g = tonumber(g) or 0,
          b = tonumber(b) or 0,
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
  local init = 1
  while init <= #line do
    local s, e, inner = line:find("hsl%s*%((.-)%)", init)
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
        local hn, sn, ln = tonumber(h) or 0, tonumber(s_pct) or 0, tonumber(l_pct) or 0
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

  return M.pick_hex(line, cursor_col) or M.pick_css_rgb(line, cursor_col) or M.pick_css_hsl(line, cursor_col)
end

return M
