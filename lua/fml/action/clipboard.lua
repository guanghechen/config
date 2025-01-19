local path = require("eve.builtin.path")
local clipboard_img = require("eve.module.clipboar-img")

---@class fml.action.clipboard
local M = {}

---@param context                       eve.command.IContext
function M.paste(context)
  local bufnr = context.bufnr ---@type integer
  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
  local dirpath = vim.fn.fnamemodify(filepath, ":h") ---@type string

  if clipboard_img.has_image() then
    local placeholder = path.join(dirpath, os.date("%Y-%m-%d") .. ".png") ---@type string
    local imagepath = vim.fn.input("New image path", placeholder) ---@type string

    clipboard_img.paste_image(imagepath)

    local filetype = vim.bo[bufnr].filetype ---@type string
    if filetype == "markdown" then
      local row, col = table.unpack(vim.api.nvim_win_get_cursor(0))
      local line = vim.api.nvim_get_current_line()
      local line_before = string.sub(line, 0, col)
      local line_end = string.sub(line, col + 1)
      line = line_before .. "![](./img/" .. imagepath .. ".png)" .. line_end
      vim.api.nvim_set_current_line(line)
      vim.api.nvim_win_set_cursor(0, { row, col + 2 })
      vim.cmd.startinsert()
    end
  end
end

return M
