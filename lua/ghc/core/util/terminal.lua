---@class ghc.core.util.terminal.util
local util = {
  table = require("ghc.core.util.table"),
}

---@class ghc.core.util.terminal
local M = {}

---@param id number|string
local function set_term_ft(id)
  local term = nil
  for _, item in pairs(vim.g.nvchad_terms) do
    if item.id == id then
      term = item
      break
    end
  end

  if term ~= nil then
    vim.bo[term.buf].filetype = "term"
  end
end

---@param opts { id: string, cwd: string, cmd?: table }
function M.toggle_terminal(opts)
  local operations = util.table.merge_multiple_array({ "cd " .. '"' .. opts.cwd .. '"' }, opts.cmd or {})

  local id = opts.id
  local cmd = table.concat(operations, " && ")

  require("nvchad.term").toggle({
    id = id,
    cmd = cmd,
    pos = "float",
  })

  set_term_ft(id)
end

return M
