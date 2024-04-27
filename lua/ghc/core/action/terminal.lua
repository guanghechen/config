---@class ghc.core.action.terminal.util
local util = {
  path = require("ghc.core.util.path"),
}

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

---@class ghc.core.action.terminal
local M = {}

function M.open_terminal_workspace()
  local id = "windows-terminal"
  require("nvchad.term").toggle({
    id = id,
    cmd = "cd " .. '"' .. util.path.workspace() .. '"',
    pos = "float",
  })
  set_term_ft(id)
end

function M.open_terminal_cwd()
  local id = "cwd-terminal"
  require("nvchad.term").toggle({
    id = id,
    cmd = "cd " .. '"' .. util.path.cwd() .. '"',
    pos = "float",
  })
  set_term_ft(id)
end

function M.open_terminal_current()
  local id = "current-terminal"
  require("nvchad.term").create({
    id = id,
    cmd = "cd " .. '"' .. util.path.current() .. '"',
    pos = "float",
  })
  set_term_ft(id)
end

return M
