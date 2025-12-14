---@class fml.action.clipboard
local M = {}

---@return nil
function M.paste()
  local clipboard = require("fml.dressing.clipboard")
  if not clipboard.has_image() then
    return
  end

  local cwd = dot.path.cwd() ---@type string
  local dirpath = cwd ---@type string

  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  if vim.bo[bufnr].buftype == "" then
    local filepath_cur = vim.api.nvim_buf_get_name(bufnr) ---@type string
    dirpath = dot.path.dirname(filepath_cur) ---@type string
  end

  local filename_default = os.date("%Y-%m-%d_%H-%M") .. ".png" ---@type string
  local filepath_default = dot.path.join(dirpath, "img" .. ark.env.PATH_SEP .. filename_default) ---@type string
  local placeholder = dot.path.relative(cwd, filepath_default) ---@type string

  vim.ui.input({
    prompt = "Save image to",
    default = placeholder,
    relative = "editor",
  }, function(filepath_target_relative)
    if filepath_target_relative == nil or filepath_target_relative == "" then
      return
    end

    local filepath_target = dot.path.resolve(cwd, filepath_target_relative) ---@type string
    ark.env.mkdirs(filepath_target, false)
    clipboard.paste_image(filepath_target)
  end)
end

return M
