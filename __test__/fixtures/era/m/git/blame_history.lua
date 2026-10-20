---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.fixtures.era.m.git.blame_history" ---@type string

local git = require("__test__.support.git")

local M = {}

---A balanced merge tree attributes every line to a leaf commit without quadratic blob history.
---@param root                          string Fresh, caller-owned temporary directory
---@param leaf_count                    integer
---@param lines_per_leaf                integer
---@return string                       Final tracked file contents
function M.build(root, leaf_count, lines_per_leaf)
  assert(leaf_count > 0 and lines_per_leaf > 0)
  assert(vim.uv.fs_stat(root .. "/.git") == nil, "fixture requires a fresh directory")
  git.run(root, { "init", "-q", "--initial-branch=fixture" })
  git.run(root, { "config", "core.autocrlf", "false" })
  git.run(root, { "config", "core.fsmonitor", "false" })
  local stream, nodes = {}, {}
  local mark = 0

  ---@param text                        string
  ---@param summary                     string
  ---@param left                        ?integer
  ---@param right                       ?integer
  ---@return { mark: integer, text: string }
  local function commit(text, summary, left, right)
    mark = mark + 1
    if not left then
      stream[#stream + 1] = "reset refs/heads/fixture\n\n"
    end
    stream[#stream + 1] = string.format(
      "commit refs/heads/fixture\nmark :%d\ncommitter Fixture <fixture@example.invalid> 1 +0000\ndata %d\n%s\n",
      mark,
      #summary,
      summary
    )
    if left then
      stream[#stream + 1] = string.format("from :%d\nmerge :%d\n", left, assert(right))
    end
    stream[#stream + 1] = string.format("M 100644 inline file\ndata %d\n%s\n", #text, text)
    return { mark = mark, text = text }
  end

  for leaf = 1, leaf_count do
    local lines = {}
    for line = 1, lines_per_leaf do
      lines[#lines + 1] = string.format("leaf %05d line %05d\n", leaf, line)
    end
    nodes[#nodes + 1] = commit(table.concat(lines), "leaf " .. leaf)
  end
  while #nodes > 1 do
    local parents = {}
    for index = 1, #nodes, 2 do
      local left, right = nodes[index], nodes[index + 1]
      parents[#parents + 1] = right and commit(left.text .. right.text, "merge", left.mark, right.mark) or left
    end
    nodes = parents
  end
  git.run(root, { "fast-import", "--quiet" }, table.concat(stream))
  git.run(root, { "read-tree", "HEAD" })
  local file = assert(io.open(root .. "/file", "wb"))
  local written, err = file:write(nodes[1].text)
  file:close()
  assert(written, err)
  return nodes[1].text
end

return M
