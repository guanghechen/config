---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.support.diffview_pane" ---@type string

local M = {}

---Row fixtures for action tests; native projection is covered by the composed Diffview specs.
---@param items                         fun(bufnr: integer): table[]|nil
---@return table
function M.new(items)
  local pane = {}

  ---@param bufnr                       integer
  ---@return table|nil
  function pane.get_navigation(bufnr)
    local rows = items(bufnr)
    if rows then
      return {
        rows = function(_, first)
          local last, directory = first, rows[first].uuid
          if rows[first].type == "directory" then
            local prefix = directory .. "/"
            for index = first + 1, #rows do
              local item = rows[index]
              local path = item.entry and item.entry.filepath or item.uuid or ""
              if path:sub(1, #prefix) ~= prefix then
                break
              end
              last = index
            end
          end
          return { last_descendants = { last } }
        end,
      }
    end
  end

  ---@param bufnr                       integer
  ---@param entry                       era.m.diffview.IFileEntry
  ---@return integer|nil
  function pane.find_entry_line(bufnr, entry)
    for row, item in ipairs(items(bufnr) or {}) do
      if item.entry and item.entry.filepath == entry.filepath and item.entry.stage_type == entry.stage_type then
        return row
      end
    end
  end

  ---@param bufnr                       integer
  ---@param entry                       era.m.diffview.IFileEntry
  ---@return integer|nil
  function pane.find_entry_anchor(bufnr, entry)
    local exact = pane.find_entry_line(bufnr, entry)
    if exact then
      return exact
    end
    for row, item in ipairs(items(bufnr) or {}) do
      if item.type == "directory" and item.uuid and entry.filepath:sub(1, #item.uuid + 1) == item.uuid .. "/" then
        return row
      end
    end
  end

  ---@param bufnr                       integer
  ---@param lnum                        ?integer
  ---@param direction                   1|-1
  ---@return integer|nil
  ---@return era.m.diffview.IFileEntry|nil
  function pane.find_adjacent_entry(bufnr, lnum, direction)
    local rows = items(bufnr) or {}
    for row = lnum and lnum + direction or (direction == 1 and 1 or #rows), direction == 1 and #rows or 1, direction do
      local item = rows[row]
      if item.type == "file" and item.entry then
        return row, item.entry
      end
    end
  end

  return pane
end

return M
