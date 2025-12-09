---@class ux.widget.colorpicker.convert
local M = {}

---@param n                             number
---@param min_val                       number
---@param max_val                       number
---@return number
function M.clamp(n, min_val, max_val)
  if n ~= n then
    return min_val
  end
  return math.max(min_val, math.min(max_val, n))
end

---@param float                         number
---@return integer
function M.round(float)
  return math.floor(float + 0.5)
end

---@param r                             integer
---@param g                             integer
---@param b                             integer
---@return integer, integer, integer
function M.rgb2hsl(r, g, b)
  local h, s, l = dot.lib.color.rgb2hsl(r, g, b)
  return M.round(h), M.round(s * 100), M.round(l * 100)
end

---@param h                             integer
---@param s                             integer
---@param l                             integer
---@return integer, integer, integer
function M.hsl2rgb(h, s, l)
  local r, g, b = dot.lib.color.hsl2rgb(h, s / 100, l / 100)
  return M.round(r), M.round(g), M.round(b)
end

---@param r                             integer
---@param g                             integer
---@param b                             integer
---@return integer, integer, integer
function M.rgb2hsv(r, g, b)
  local R, G, B = r / 255, g / 255, b / 255
  local MAX, MIN = math.max(R, G, B), math.min(R, G, B)
  local V = MAX
  local H, S

  if MAX == MIN then
    H, S = 0, 0
  else
    if MAX == R then
      H = (G - B) / (MAX - MIN) * 60
    elseif MAX == G then
      H = (B - R) / (MAX - MIN) * 60 + 120
    else
      H = (R - G) / (MAX - MIN) * 60 + 240
    end
    H = H % 360
    S = V == 0 and 0 or (MAX - MIN) / MAX
  end

  return M.round(H), M.round(S * 100), M.round(V * 100)
end

---@param h                             integer
---@param s                             integer
---@param v                             integer
---@return integer, integer, integer
function M.hsv2rgb(h, s, v)
  local H, S, V = h, s / 100, v / 100
  local MAX = V
  local MIN = MAX - S * MAX

  local function f(x)
    return x / 60 * (MAX - MIN) + MIN
  end

  local R, G, B
  if H < 60 then
    R, G, B = MAX, f(H), MIN
  elseif H < 120 then
    R, G, B = f(120 - H), MAX, MIN
  elseif H < 180 then
    R, G, B = MIN, MAX, f(H - 120)
  elseif H < 240 then
    R, G, B = MIN, f(240 - H), MAX
  elseif H < 300 then
    R, G, B = f(H - 240), MIN, MAX
  else
    R, G, B = MAX, MIN, f(360 - H)
  end

  return M.clamp(M.round(R * 255), 0, 255), M.clamp(M.round(G * 255), 0, 255), M.clamp(M.round(B * 255), 0, 255)
end

---@param hex                           string
---@return integer|nil, integer|nil, integer|nil
function M.hex_parse(hex)
  return dot.lib.color.hex2rgb(hex)
end

---@param r                             integer
---@param g                             integer
---@param b                             integer
---@return string
function M.hex_stringify(r, g, b)
  return dot.lib.color.rgb2hex(r, g, b)
end

return M
