---@class fml.std.nvimbar
local M = {}

---@param num                           integer
---@return string
local function encode_int(num)
  local text = string.format("%o", num) ---@type string
  return text
end

---@param text                          string
---@return integer|nil
local function decode_int(text)
  local num = tonumber(text, 8) ---@type integer|nil
  return num
end

---@param args                          integer[]
---@return string
function M.encode_btn_args(args)
  local result = "" ---@type string
  for i, num in ipairs(args) do
    if i > 1 then
      result = result .. "9"
    end
    result = result .. encode_int(num)
  end
  return result
end

---@param text                          string
---@return integer[]
function M.decode_btn_args(text)
  local argv = vim.split(text, "9") ---@type string[]
  local result = {} ---@type integer[]
  for _, arg in ipairs(argv) do
    local num = decode_int(arg)
    if num ~= nil then
      table.insert(result, num)
    end
  end
  return result
end

---@param text                          string
---@param hlname                        string
---@return string
function M.txt(text, hlname)
  return "%#" .. hlname .. "#" .. text
end

---@param text                          string
---@param callback                      string
---@param args                          ?integer|integer[]
function M.btn(text, callback, args)
  local args_str = args or "" ---@type integer|integer[]|string
  if type(args) == "table" then
    args_str = M.encode_btn_args(args)
  end
  ---@cast args_str integer|string

  if callback.sub(callback, 1, 3) == "fml" then
    return "%" .. args_str .. "@v:lua." .. callback .. "@" .. text .. "%T"
  end
  return "%" .. args_str .. "@v:lua.fml.G." .. callback .. "@" .. text .. "%T"
end

return M
