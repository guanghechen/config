---@param keys                          string[]
---@return table<string, boolean>
local function build_set(keys)
  local set = {} ---@type table<string, boolean>
  for _, key in ipairs(keys) do
    set[key] = true
  end
  return set
end

---@type table<string, boolean>
local NON_TEXT_EXTNAME_SET = build_set({
  ".class",
  ".dll",
  ".jpeg",
  ".jpg",
  ".gz",
  ".jar",
  ".mkv",
  ".mp3",
  ".mp4",
  ".pdf",
  ".png",
  ".png",
  ".so",
  ".tar",
  ".xz",
  ".zip",
})

local TEXT_FILENAME_SET = build_set({
  "license",
  "sshd_config",
})

---@class eve.std.is
local M = {}

---@param value                         any
---@return boolean
function M.array(value)
  if type(value) ~= "table" then
    return false
  end

  if #value > 0 then
    return true
  end

  for key in pairs(value) do
    if type(key) ~= "number" then
      return false
    end
  end

  return true
end

---@param value                         any
---@return boolean
function M.disposable(value)
  return type(value) == "table" and type(value.isDisposable) == "function" and type(value.dispose) == "function"
end

---@param value                         any
---@return boolean
function M.observable(value)
  return type(value) == "table"
    and type(value.snapshot) == "function"
    and type(value.next) == "function"
    and type(value.subscribe) == "function"
end

---@param filename                      string
---@return boolean
function M.printable_file(filename)
  filename = filename:lower() ---@type string
  local extname = filename:match("%.[^.]+$") or ""
  if NON_TEXT_EXTNAME_SET[extname] then
    return false
  end

  if extname == "" then
    return TEXT_FILENAME_SET[filename]
  end

  return true
end

return M
