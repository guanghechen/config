---@class fml.action.clipboard
local M = {}

---@return nil
function M.paste()
  if not eve.clipboard.has_image() then
    return
  end

  local cwd = eve.path.cwd() ---@type string
  local dirpath = cwd ---@type string

  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  if vim.bo[bufnr].buftype == "" then
    local filepath_cur = vim.api.nvim_buf_get_name(bufnr) ---@type string
    dirpath = eve.path.dirname(filepath_cur) ---@type string
  end

  local filepath_default = eve.path.join(dirpath, os.date("%Y-%m-%d") .. ".png") ---@type string
  local placeholder = eve.path.relative(cwd, filepath_default, false) ---@type string

  vim.ui.input({
    prompt = "Save image to",
    default = placeholder,
    relative = "editor",
  }, function(image_path_relative)
    if image_path_relative == nil or image_path_relative == "" then
      return
    end

    local image_path = eve.path.resolve(cwd, image_path_relative) ---@type string
    eve.path.mkdir_if_nonexist(eve.path.dirname(image_path))
    eve.clipboard.paste_image(image_path)

    if eve.editor.is_buf_valid(bufnr) and eve.editor.is_buf_editable(bufnr) then
      local filetype = vim.bo[bufnr].filetype ---@type string
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
  end)
end

return M
