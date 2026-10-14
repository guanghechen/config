---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.git_files.diff" ---@type string

local Diff = require("era.m.git.diff")

---@alias era.m.git_files.diff.Kind "context"|"add"|"delete"|"hunk"|"info"

---@class era.m.git_files.diff.IRow
---@field kind                          era.m.git_files.diff.Kind
---@field text                          string
---@field old_lnum                      ?integer
---@field new_lnum                      ?integer
---@field missing_newline               ?boolean
---@field words                         ?era.m.git.WordChange[]

local M = {}

---@param text                          string
---@return era.m.git_files.diff.IRow[]
local function info(text)
  return { { kind = "info", text = text } }
end

---@param lines                         string[] Bounded unified patch output, without the trailing empty split item.
---@param truncated                     boolean Whether the patch was cut at a complete output line.
---@return era.m.git_files.diff.IRow[]
function M.parse(lines, truncated)
  local rows = {} ---@type era.m.git_files.diff.IRow[]
  local removed, added = {}, {} ---@type integer[], integer[]
  local old_lnum, new_lnum, old_left, new_left = 0, 0, 0, 0
  local metadata = {} ---@type era.m.git_files.diff.IRow[]
  local old_mode, new_mode

  ---@return nil
  local function finish_change()
    for index = 1, math.min(#removed, #added) do
      local before, after = rows[removed[index]], rows[added[index]]
      local words = Diff.compute_word_diff(before.text, after.text)
      before.words, after.words = words, words
    end
    removed, added = {}, {}
  end

  for _, line in ipairs(lines) do
    local old_start, old_count, new_start, new_count = line:match("^@@ %-(%d+)(,?%d*) %+(%d+)(,?%d*) @@")
    if old_start then
      if old_left > 0 or new_left > 0 then
        return info("Diff unavailable: incomplete change block.")
      end
      finish_change()
      local before = assert(tonumber(old_start)) ---@type integer
      local after = assert(tonumber(new_start)) ---@type integer
      local removed_count = old_count == "" and 1 or tonumber(old_count:sub(2)) ---@type integer|nil
      local added_count = new_count == "" and 1 or tonumber(new_count:sub(2)) ---@type integer|nil
      if
        not removed_count
        or not added_count
        or removed_count > 0 and before == 0
        or added_count > 0 and after == 0
      then
        return info("Diff unavailable: invalid change block.")
      end
      old_lnum, new_lnum, old_left, new_left = before, after, removed_count, added_count
      rows[#rows + 1] = { kind = "hunk", text = line }
    elseif line:sub(1, 3) == "@@@" or line:match("^diff %-%-c[co]") then
      return info("Unmerged file: resolve conflicts to preview a two-way diff.")
    elseif line == "\\ No newline at end of file" then
      local row = rows[#rows]
      if row and (row.old_lnum or row.new_lnum) then
        row.missing_newline = true
      end
    elseif old_left > 0 or new_left > 0 then
      local prefix, text = line:sub(1, 1), line:sub(2)
      if prefix == " " and old_left > 0 and new_left > 0 then
        finish_change()
        rows[#rows + 1] = { kind = "context", text = text, old_lnum = old_lnum, new_lnum = new_lnum }
        old_lnum, new_lnum, old_left, new_left = old_lnum + 1, new_lnum + 1, old_left - 1, new_left - 1
      elseif prefix == "-" and old_left > 0 then
        rows[#rows + 1] = { kind = "delete", text = text, old_lnum = old_lnum }
        removed[#removed + 1] = #rows
        old_lnum, old_left = old_lnum + 1, old_left - 1
      elseif prefix == "+" and new_left > 0 then
        rows[#rows + 1] = { kind = "add", text = text, new_lnum = new_lnum }
        added[#added + 1] = #rows
        new_lnum, new_left = new_lnum + 1, new_left - 1
      else
        return info("Diff unavailable: invalid change block.")
      end
    elseif line:match("^Binary files ") or line == "GIT binary patch" then
      return info("Binary file changed.")
    elseif line:match("^rename from ") then
      metadata[#metadata + 1] = { kind = "info", text = "Renamed from " .. line:sub(13) }
    elseif line:match("^rename to ") then
      metadata[#metadata + 1] = { kind = "info", text = "Renamed to " .. line:sub(11) }
    elseif line:match("^copy from ") then
      metadata[#metadata + 1] = { kind = "info", text = "Copied from " .. line:sub(11) }
    elseif line:match("^new file mode ") then
      metadata[#metadata + 1] = { kind = "info", text = "New empty file · mode " .. line:sub(15) }
    elseif line:match("^deleted file mode ") then
      metadata[#metadata + 1] = { kind = "info", text = "Empty file deleted · mode " .. line:sub(19) }
    elseif line:match("^old mode ") then
      old_mode = line:sub(10)
    elseif line:match("^new mode ") then
      new_mode = line:sub(10)
    elseif line:sub(1, 2) == "@@" then
      return info("Diff unavailable: unsupported change block.")
    end
  end
  finish_change()
  if truncated then
    rows[#rows + 1] = { kind = "info", text = "Diff preview truncated." }
  elseif old_left > 0 or new_left > 0 then
    return info("Diff unavailable: incomplete change block.")
  end
  if #rows > 0 then
    return rows
  end
  if old_mode and new_mode then
    metadata[#metadata + 1] = { kind = "info", text = "File mode " .. old_mode .. " → " .. new_mode }
  end
  return #metadata > 0 and metadata or info("No textual changes.")
end

return M
