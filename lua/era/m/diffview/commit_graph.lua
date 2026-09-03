---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.diffview.commit_graph" ---@type string

---@see https://github.com/jesseduffield/lazygit/tree/master/pkg/gui/presentation/graph
---Pure commit topology renderer adapted from lazygit's pipe-set model.
---@class era.m.diffview.commit_graph
local M = {}

local TERMINATES = 0 ---@type integer
local STARTS = 1 ---@type integer
local CONTINUES = 2 ---@type integer
local EMPTY_TREE_HASH = "4b825dc642cb6eb9a060e54bf8d69288fbee4904" ---@type string
local START_HASH = "__diffview_graph_start__" ---@type string

---@class era.m.diffview.commit_graph.IPipe
---@field public from_hash              string
---@field public to_hash                string
---@field public from_pos               integer
---@field public to_pos                 integer
---@field public kind                   integer

---@class era.m.diffview.commit_graph.ICell
---@field public up                     boolean
---@field public down                   boolean
---@field public left                   boolean
---@field public right                  boolean
---@field public kind                   "connection"|"commit"|"merge"

---@class era.m.diffview.commit_graph.INode
---@field public hash                   string
---@field public parents                string[]|nil

---@param pipe                           era.m.diffview.commit_graph.IPipe
---@return integer
local function left(pipe)
  return math.min(pipe.from_pos, pipe.to_pos)
end

---@param pipe                           era.m.diffview.commit_graph.IPipe
---@return integer
local function right(pipe)
  return math.max(pipe.from_pos, pipe.to_pos)
end

---@param pipes                          era.m.diffview.commit_graph.IPipe[]
---@param commit                         era.m.diffview.commit_graph.INode
---@return era.m.diffview.commit_graph.IPipe[]
local function next_pipes(pipes, commit)
  local max_pos = 0 ---@type integer
  local current = {} ---@type era.m.diffview.commit_graph.IPipe[]
  for _, pipe in ipairs(pipes) do
    max_pos = math.max(max_pos, pipe.to_pos)
    if pipe.kind ~= TERMINATES then
      current[#current + 1] = pipe
    end
  end

  local pos = max_pos + 1 ---@type integer
  for _, pipe in ipairs(current) do
    if pipe.to_hash == commit.hash then
      pos = pipe.to_pos
      break
    end
  end

  local parents = commit.parents or {} ---@type string[]
  local result = {
    {
      from_pos = pos,
      to_pos = pos,
      from_hash = commit.hash,
      to_hash = parents[1] or EMPTY_TREE_HASH,
      kind = STARTS,
    },
  } ---@type era.m.diffview.commit_graph.IPipe[]

  local taken = {} ---@type table<integer, boolean>
  local traversed = {} ---@type table<integer, boolean>
  local continuing_destinations = {} ---@type table<integer, boolean>
  for _, pipe in ipairs(current) do
    if pipe.to_hash ~= commit.hash then
      continuing_destinations[pipe.to_pos] = true
    end
  end

  ---@return integer
  local function next_continuing_pos()
    local candidate = 0 ---@type integer
    while traversed[candidate] do
      candidate = candidate + 1
    end
    return candidate
  end

  ---@return integer
  local function next_new_pos()
    local candidate = 0 ---@type integer
    while taken[candidate] or continuing_destinations[candidate] do
      candidate = candidate + 1
    end
    return candidate
  end

  ---@param from                         integer
  ---@param to                           integer
  local function traverse(from, to)
    local first = math.min(from, to) ---@type integer
    local last = math.max(from, to) ---@type integer
    for index = first, last do
      traversed[index] = true
    end
    taken[to] = true
  end

  for _, pipe in ipairs(current) do
    if pipe.to_hash == commit.hash then
      result[#result + 1] = {
        from_pos = pipe.to_pos,
        to_pos = pos,
        from_hash = pipe.from_hash,
        to_hash = pipe.to_hash,
        kind = TERMINATES,
      }
      traverse(pipe.to_pos, pos)
    elseif pipe.to_pos < pos then
      local available = next_continuing_pos() ---@type integer
      result[#result + 1] = {
        from_pos = pipe.to_pos,
        to_pos = available,
        from_hash = pipe.from_hash,
        to_hash = pipe.to_hash,
        kind = CONTINUES,
      }
      traverse(pipe.to_pos, available)
    end
  end

  for index = 2, #parents do
    local available = next_new_pos() ---@type integer
    result[#result + 1] = {
      from_pos = pos,
      to_pos = available,
      from_hash = commit.hash,
      to_hash = parents[index],
      kind = STARTS,
    }
    taken[available] = true
  end

  for _, pipe in ipairs(current) do
    if pipe.to_hash ~= commit.hash and pipe.to_pos > pos then
      local destination = pipe.to_pos ---@type integer
      for candidate = pipe.to_pos, pos + 1, -1 do
        if taken[candidate] or traversed[candidate] then
          break
        end
        destination = candidate
      end
      result[#result + 1] = {
        from_pos = pipe.to_pos,
        to_pos = destination,
        from_hash = pipe.from_hash,
        to_hash = pipe.to_hash,
        kind = CONTINUES,
      }
      traverse(pipe.to_pos, destination)
    end
  end

  table.sort(result, function(a, b)
    if a.to_pos == b.to_pos then
      return a.kind < b.kind
    end
    return a.to_pos < b.to_pos
  end)
  return result
end

---@param up                             boolean
---@param down                           boolean
---@param leftward                       boolean
---@param rightward                      boolean
---@return string first
---@return string second
local function box_chars(up, down, leftward, rightward)
  if up and down and leftward and rightward then
    return "│", "─"
  elseif up and down and leftward then
    return "│", " "
  elseif up and down and rightward then
    return "│", "─"
  elseif up and down then
    return "│", " "
  elseif up and leftward and rightward then
    return "┴", "─"
  elseif up and leftward then
    return "╯", " "
  elseif up and rightward then
    return "╰", "─"
  elseif up then
    return "╵", " "
  elseif down and leftward and rightward then
    return "┬", "─"
  elseif down and leftward then
    return "╮", " "
  elseif down and rightward then
    return "╭", "─"
  elseif down then
    return "╷", " "
  elseif leftward and rightward then
    return "─", "─"
  elseif leftward then
    return "─", " "
  elseif rightward then
    return "╶", "─"
  end
  return " ", " "
end

---@param pipes                          era.m.diffview.commit_graph.IPipe[]
---@return string
local function render_pipes(pipes)
  local max_pos = 0 ---@type integer
  local commit_pos = 0 ---@type integer
  local starts = 0 ---@type integer
  for _, pipe in ipairs(pipes) do
    if pipe.kind == STARTS then
      starts = starts + 1
      commit_pos = pipe.from_pos
    elseif pipe.kind == TERMINATES then
      commit_pos = pipe.to_pos
    end
    max_pos = math.max(max_pos, right(pipe))
  end

  local cells = {} ---@type era.m.diffview.commit_graph.ICell[]
  for _ = 0, max_pos do
    cells[#cells + 1] = {
      up = false,
      down = false,
      left = false,
      right = false,
      kind = "connection",
    }
  end

  ---@param pipe                         era.m.diffview.commit_graph.IPipe
  local function render_pipe(pipe)
    local first = left(pipe) ---@type integer
    local last = right(pipe) ---@type integer
    if first ~= last then
      for index = first + 1, last - 1 do
        cells[index + 1].left = true
        cells[index + 1].right = true
      end
      cells[first + 1].right = true
      cells[last + 1].left = true
    end
    if pipe.kind == STARTS or pipe.kind == CONTINUES then
      cells[pipe.to_pos + 1].down = true
    end
    if pipe.kind == TERMINATES or pipe.kind == CONTINUES then
      cells[pipe.from_pos + 1].up = true
    end
  end

  for _, pipe in ipairs(pipes) do
    if pipe.kind == STARTS then
      render_pipe(pipe)
    end
  end
  for _, pipe in ipairs(pipes) do
    if
      pipe.kind ~= STARTS
      and not (pipe.kind == TERMINATES and pipe.from_pos == commit_pos and pipe.to_pos == commit_pos)
    then
      render_pipe(pipe)
    end
  end

  cells[commit_pos + 1].kind = starts > 1 and "merge" or "commit"
  local parts = {} ---@type string[]
  for _, cell in ipairs(cells) do
    local first, second = box_chars(cell.up, cell.down, cell.left, cell.right)
    if cell.kind == "commit" then
      first = "○"
    elseif cell.kind == "merge" then
      first = "◎"
    end
    parts[#parts + 1] = first .. second
  end
  return (table.concat(parts):gsub("%s+$", ""))
end

---Render one compact graph row per commit. Commits must be in topological display order.
---@param commits                        era.m.diffview.commit_graph.INode[]
---@return string[]
function M.render(commits)
  if #commits == 0 then
    return {}
  end

  ---@type era.m.diffview.commit_graph.IPipe[]
  local pipes = {
    {
      from_pos = 0,
      to_pos = 0,
      from_hash = START_HASH,
      to_hash = commits[1].hash,
      kind = STARTS,
    },
  }
  ---@type string[]
  local graph_lines = {}
  for _, commit in ipairs(commits) do
    pipes = next_pipes(pipes, commit)
    graph_lines[#graph_lines + 1] = render_pipes(pipes)
  end
  return graph_lines
end

return M
