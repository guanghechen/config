---@class fml.action.clipboard
local M = {}

---@return nil
function M.paste()
  local bufnr_sourcefile = eve.state.editor.get_bufnr_sourcefile() ---@type integer|nil
  if bufnr_sourcefile == nil then
    return
  end

  local filepath = vim.api.nvim_buf_get_name(bufnr_sourcefile) ---@type string
  local dirpath = vim.fn.fnamemodify(filepath, ":h") ---@type string

  if eve.clipboard.has_image() then
    local cwd = eve.path.cwd() ---@type string
    local filepath_default = eve.path.join(dirpath, os.date("%Y-%m-%d") .. ".png") ---@type string
    local placeholder = eve.path.relative(filepath_default, cwd, false) ---@type string
    local image_path_relative = vim.fn.input("New image path", placeholder) ---@type string
    local image_path = eve.path.resolve(cwd, image_path_relative) ---@type string

    eve.path.mkdir_if_nonexist(eve.path.dirname(image_path))
    eve.clipboard.paste_image(image_path)

    local filetype = vim.bo[bufnr_sourcefile].filetype ---@type string
    if filetype == "markdown" then
      local row, col = table.unpack(vim.api.nvim_win_get_cursor(0))
      local line = vim.api.nvim_get_current_line()
      local line_before = string.sub(line, 0, col)
      local line_end = string.sub(line, col + 1)
      line = line_before .. "![](./img/" .. image_path .. ".png)" .. line_end
      vim.api.nvim_set_current_line(line)
      vim.api.nvim_win_set_cursor(0, { row, col + 2 })
      vim.cmd.startinsert()
    end
  end
end

return M
