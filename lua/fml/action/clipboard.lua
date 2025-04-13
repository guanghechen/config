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

  local filename_default = os.date("%Y-%m-%d_%H-%M") .. ".png" ---@type string
  local filepath_default = eve.path.join(dirpath, "img" .. eve.env.PATH_SEP .. filename_default) ---@type string
  local placeholder = eve.path.relative(cwd, filepath_default, false) ---@type string

  vim.ui.input({
    prompt = "Save image to",
    default = placeholder,
    relative = "editor",
  }, function(filepath_target_relative)
    if filepath_target_relative == nil or filepath_target_relative == "" then
      return
    end

    local filepath_target = eve.path.resolve(cwd, filepath_target_relative) ---@type string
    eve.path.mkdir_if_nonexist(eve.path.dirname(filepath_target))
    eve.clipboard.paste_image(filepath_target)
  end)
end

return M
