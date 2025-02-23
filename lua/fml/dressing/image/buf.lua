local config = require("fml.dressing.image.config")
local Placement = require("fml.dressing.image.placement")

---@class fml.dressing.image.buf
local M = {}

---@param bufnr                         integer
---@param opts                          ?fml.dressing.image.Opts|{src?: string}
function M.attach(bufnr, opts)
  local filename = opts and opts.src or vim.api.nvim_buf_get_name(bufnr) ---@type string
  local is_support_terminal = config.is_support_terminal() ---@type boolean
  local is_support_file = config.is_support_file(filename) ---@type boolean

  if not is_support_terminal or not is_support_file then
    local lines = {} ---@type string[]
    lines[#lines + 1] = "# Image viewer"
    lines[#lines + 1] = "- **file**: `" .. filename .. "`"
    if not is_support_file then
      lines[#lines + 1] = "- unsupported image format"
    end
    if not is_support_terminal then
      lines[#lines + 1] = "- terminal does not support the kitty graphics protocol."
    end
    vim.bo[bufnr].modifiable = true
    vim.bo[bufnr].filetype = "markdown"
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(table.concat(lines, "\n"), "\n"))
    vim.bo[bufnr].modifiable = false
    vim.bo[bufnr].modified = false
  else
    vim.bo[bufnr].filetype = "image"
    vim.bo[bufnr].modifiable = false
    vim.bo[bufnr].modified = false
    vim.bo[bufnr].swapfile = false
    return Placement.new(bufnr, filename, opts)
  end
end

return M
