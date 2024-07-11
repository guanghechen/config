local std_os = require("fml.std.os")

local PATH_SEP = std_os.path_sep() ---@type string

---@class fml.std.path
local M = require("fml.std.path.mod")

---@param filepath string
---@return string
function M.basename(filepath)
  local pieces = M.split(filepath)
  return #pieces > 0 and pieces[#pieces] or ""
end

---@param filepath string
---@return string
function M.extname(filepath)
  return filepath:match("^.+(%..+)$") or ""
end

---@param filepath                      string
---@return boolean
function M.is_absolute(filepath)
  if std_os.is_win() then
    return string.match(filepath, "^[%a]:[\\/].*$") ~= nil
  end
  return string.sub(filepath, 1, 1) == PATH_SEP
end

---@param filepath                      string
---@return boolean
function M.is_exist(filepath)
  local stat = vim.uv.fs_stat(filepath)
  return stat ~= nil and not vim.tbl_isempty(stat)
end

---! Check if the `to` path is under the `from` path.
---@param from                          string
---@param to                            string
---@return boolean
function M.is_under(from, to)
  local is_from_absolute = M.is_absolute(from) ---@type boolean
  local is_to_absolute = M.is_absolute(to) ---@type boolean

  if is_from_absolute and not is_to_absolute then
    return true
  end

  if is_to_absolute and not is_from_absolute then
    from = M.resolve(M.cwd(), from)
  end

  local from_pieces = M.split(from) ---@type string[]
  local to_pieces = M.split(to) ---@type string[]

  if #to_pieces < #from_pieces then
    return false
  end

  for i = 1, #from_pieces do
    if to_pieces[i] ~= from_pieces[i] then
      return false
    end
  end
  return true
end

---@param from                          string
---@param to                            string
---@return string
function M.join(from, to)
  return M.normalize(from .. PATH_SEP .. to)
end

function M.mkdir_if_nonexist(dirpath)
  if not M.is_exist(dirpath) then
    vim.fn.mkdir(dirpath, "p")
  end
end

---@param filepath                      string
---@return string
function M.normalize(filepath)
  return table.concat(M.split(filepath), PATH_SEP)
end

---@param from                          string
---@param to                            string
---@return string
function M.relative(from, to)
  local is_from_absolute = M.is_absolute(from) ---@type boolean
  local is_to_absolute = M.is_absolute(to) ---@type boolean

  if is_from_absolute and not is_to_absolute then
    return M.normalize(to)
  end

  if is_to_absolute and not is_from_absolute then
    return M.normalize(to)
  end

  local from_pieces = M.split(from) ---@type string[]
  local to_pieces = M.split(to) ---@type string[]
  local L = #from_pieces < #to_pieces and #from_pieces or #to_pieces

  local i = 1
  while i <= L do
    if from_pieces[i] ~= to_pieces[i] then
      break
    end
    i = i + 1
  end

  local pieces = {} --
  for _ = i, #from_pieces do
    table.insert(pieces, "..")
  end
  for j = i, #to_pieces do
    table.insert(pieces, to_pieces[j])
  end
  return table.concat(pieces, PATH_SEP)
end

---@param cwd                           string
---@param to                            string
function M.resolve(cwd, to)
  return M.is_absolute(to) and M.normalize(to) or M.normalize(cwd .. PATH_SEP .. to)
end

---@param filepath                      string
---@return string[]
function M.split(filepath)
  local pieces = {} ---@type string[]
  local pattern = "([^/\\]+)" ---@type string
  local has_prefix_sep = PATH_SEP == "/" and string.sub(filepath, 1, 1) == PATH_SEP ---@type boolean

  for piece in string.gmatch(filepath, pattern) do
    if #piece > 0 and piece ~= "." then
      if piece == ".." and (has_prefix_sep or #pieces > 0) then
        table.remove(pieces, #pieces)
      else
        table.insert(pieces, piece)
      end
    end
  end
  if has_prefix_sep then
    table.insert(pieces, 1, "")
  end
  return pieces
end

---! Check if the `to` path is under the `from` path.
---@param from_pieces                   string[]
---@param to                            string
---@return string[]
function M.split_prettier(from_pieces, to)
  local to_pieces = M.split(to) ---@type string[]
  local is_under = true ---@type boolean
  for i = 1, #from_pieces do
    if to_pieces[i] ~= from_pieces[i] then
      is_under = false
      break
    end
  end

  if is_under then
    local k = 0 ---@type integer
    local N = #to_pieces ---@type integer
    for i = #from_pieces + 1, N, 1 do
      k = k + 1
      to_pieces[k] = to_pieces[i]
    end
    for i = k + 1, N, 1 do
      to_pieces[i] = nil
    end
  end
  return to_pieces
end
