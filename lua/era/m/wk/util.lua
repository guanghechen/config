---@class era.m.wk.util
local M = {}

local KEY_ICONS = stl.icon.keycode ---@type table<string, string>

---Check if currently recording or executing a macro
---@return boolean
function M.in_macro()
  return vim.fn.reg_recording() ~= "" or vim.fn.reg_executing() ~= ""
end

---Parse mode string into array
---@param str                            string
---@return era.m.wk.Mode[]
function M.parse_modes(str)
  local modes = {}
  for i = 1, #str do
    modes[#modes + 1] = str:sub(i, i)
  end
  return modes
end

---Parse key sequence into parts
---@param keys                           string
---@return string[]
function M.parse_keys(keys)
  local result = {}
  local i = 1
  while i <= #keys do
    if keys:sub(i, i) == "<" then
      local j = keys:find(">", i)
      if j then
        result[#result + 1] = keys:sub(i, j)
        i = j + 1
      else
        result[#result + 1] = keys:sub(i, i)
        i = i + 1
      end
    else
      result[#result + 1] = keys:sub(i, i)
      i = i + 1
    end
  end
  return result
end

---Format key for display
---@param key                            string
---@return string
function M.format_key(key)
  local inner = key:match("^<(.*)>$")
  if not inner then
    return key
  end

  -- Handle NL -> C-J
  if inner == "NL" then
    inner = "C-J"
  end

  local direct_icon = KEY_ICONS[inner]
  if direct_icon then
    return direct_icon
  end

  local parts = vim.split(inner, "-", { plain = true })
  for i, part in ipairs(parts) do
    -- Only replace if it's a modifier prefix or if it's the last part and not a single char
    if i == 1 or i ~= #parts or not part:match("^%w$") then
      parts[i] = KEY_ICONS[part] or parts[i]
    end
  end
  return table.concat(parts, "")
end

---Get current map mode
---@param mode                           string?
---@return string
function M.get_mapmode(mode)
  mode = mode or vim.api.nvim_get_mode().mode
  mode = mode
    :gsub(vim.api.nvim_replace_termcodes("<C-V>", true, true, true), "v")
    :gsub(vim.api.nvim_replace_termcodes("<C-S>", true, true, true), "s")
    :lower()

  if mode:sub(1, 2) == "no" then
    return "o"
  end
  if mode:sub(1, 1) == "v" then
    return "x"
  end
  return mode:sub(1, 1):match("[ncitsxo]") or "n"
end

---Normalize lhs (convert actual leader key to <leader>)
---@param lhs                            string
---@return string
function M.normalize_lhs(lhs)
  local leader = vim.g.mapleader
  if leader == nil or leader == " " then
    leader = " "
  end
  -- Replace actual leader with <leader> at the beginning
  if lhs:sub(1, #leader) == leader then
    return "<leader>" .. lhs:sub(#leader + 1)
  end
  return vim.fn.keytrans(lhs)
end

return M
