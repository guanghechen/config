---@class fml.action.clipboard
local M = {}

---@return nil
function M.paste()
  if not eve.clipboard.has_image() then
    return
  end

  local cwd = std.path.cwd() ---@type string
  local dirpath = cwd ---@type string

  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  if vim.bo[bufnr].buftype == "" then
    local filepath_cur = vim.api.nvim_buf_get_name(bufnr) ---@type string
    dirpath = std.path.dirname(filepath_cur) ---@type string
  end

  local filename_default = os.date("%Y-%m-%d_%H-%M") .. ".png" ---@type string
  local filepath_default = std.path.join(dirpath, "img" .. std.env.PATH_SEP .. filename_default) ---@type string
  local placeholder = std.path.relative(cwd, filepath_default, false) ---@type string

  vim.ui.input({
    prompt = "Save image to",
    default = placeholder,
    relative = "editor",
  }, function(filepath_target_relative)
    if filepath_target_relative == nil or filepath_target_relative == "" then
      return
    end

    local filepath_target = std.path.resolve(cwd, filepath_target_relative) ---@type string
    std.path.mkdir_if_nonexist(std.path.dirname(filepath_target))
    eve.clipboard.paste_image(filepath_target)
  end)
end

return M
