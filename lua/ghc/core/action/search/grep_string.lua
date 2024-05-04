---@class ghc.core.action.search.grep_string
local util = {
  selection = require("guanghechen.util.selection"),
}

---@class ghc.core.search.grep_string
local M = {}

---@param opts? {search?:string}
function M.grep_string(opts)
  opts = opts

  local word
  local visual = vim.fn.mode() == "v"

  if visual == true then
    word = util.selection.get_selected_text()
    vim.notify(vim.inspect(word))
  end
end

return M
