local __module_name__ = "guanghechen.action.nvim-treesitter" ---@type string

local reporter = require("eve.builtin.reporter")

local function find_conditional_node(node)
  local node_type = node:type() ---@type string
  if node_type == "ternary_expression" or node_type == "if_statement" then
    return node
  end

  local parent = node:parent()
  return parent and find_conditional_node(parent)
end

---@class guanghechen.action.nvim_treesitter
local M = {}

---@param context                       eve.command.IContext
---@return nil
function M.swap_conditional_branches(context)
  local bufnr = context.bufnr ---@type integer

  local ts_parsers = require("nvim-treesitter.parsers")
  local lang = ts_parsers.get_buf_lang(bufnr) ---@return string
  if not ts_parsers.has_parser(lang) then
    reporter.error({
      from = __module_name__,
      subject = "swap conditional branches",
      message = "No treesitter parser for current language",
    })
    return
  end

  local ts_utils = require("nvim-treesitter.ts_utils")
  local node = ts_utils.get_node_at_cursor(0)
  local conditional_node = node and find_conditional_node(node)
  if not conditional_node then
    return
  end

  local consequence = conditional_node:field("consequence")[1]
  local alternate = conditional_node:field("alternative")[1]
  if consequence == nil or alternate == nil then
    return
  end

  if consequence:type() == "statement_block" then
    consequence = consequence:child(1) or consequence
  end
  if alternate:type() == "else_clause" or alternate:type() == "else_statement" then
    alternate = alternate:child(1) or alternate
  end
  if alternate:type() == "statement_block" then
    alternate = alternate:child(1) or alternate
  end

  local csr, csc, cer, cec = consequence:range() ---@type integer, integer, integer, integer
  local asr, asc, aer, aec = alternate:range() ---@type integer, integer, integer, integer

  ---@type string
  local consequence_text = table.concat(vim.api.nvim_buf_get_text(bufnr, csr, csc, cer, cec, {}), "\n")

  ---@type string
  local alternate_text = table.concat(vim.api.nvim_buf_get_text(bufnr, asr, asc, aer, aec, {}), "\n")

  ---@type string
  local middle_text = table.concat(vim.api.nvim_buf_get_text(bufnr, cer, cec, asr, asc, {}), "\n")

  local text = alternate_text .. middle_text .. consequence_text ---@type string
  local lines = vim.split(text, "\n", { plain = true }) ---@type string[]
  vim.api.nvim_buf_set_text(bufnr, csr, csc, aer, aec, lines)
end

return M
