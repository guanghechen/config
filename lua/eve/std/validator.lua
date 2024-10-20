local std_array = require("eve.std.array")

---@class eve.std.validator
local M = {}

---@type table<string, boolean>
local NON_TEXT_EXTNAME_SET = std_array.to_set({
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

local TEXT_FILENAME_SET = std_array.to_set({
  "license",
  "sshd_config",
})

---@param value                         any
---@return boolean
function M.is_disposable(value)
  return type(value) == "table" and type(value.isDisposable) == "function" and type(value.dispose) == "function"
end

---@param value                         any
---@return boolean
function M.is_observable(value)
  return type(value) == "table"
    and type(value.snapshot) == "function"
    and type(value.next) == "function"
    and type(value.subscribe) == "function"
end

---@param filename                      string
---@return boolean
function M.is_printable_file(filename)
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
