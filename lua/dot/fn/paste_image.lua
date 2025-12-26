---see https://github.com/hakonharnes/img-clip.nvim/blob/08a02e14c8c0d42fa7a92c30a98fd04d6993b35d/lua/img-clip/init.lua#L1

local BYTE_DOT = 0x2e ---@type integer '.'

---@param alt                           string
---@param src                           string
---@return boolean
local function insert_markup(alt, src)
  local content = src ---@type string
  local filetype = vim.bo.filetype ---@type string

  if filetype == "markdown" or filetype == ark.filetype.NOTEPAD then
    content = string.format("![%s](%s)", alt, src)
  end

  local lines = vim.split(content, "\n", { plain = true }) ---@type string[]
  vim.api.nvim_put(lines, "l", true, true)
  return true
end

---@param filepath_target               string
---@return boolean
local function paste_image(filepath_target)
  local clipboard = require("dot.module.clipboard")
  local ok = clipboard.paste_image_from_clipboard(filepath_target)
  if ok then
    local filetype = vim.bo.filetype ---@type string
    if ark.filetype.is_sourcefile(filetype) then
      local filepath_current = vim.api.nvim_buf_get_name(0) ---@type string
      local src = dot.path.relative(dot.path.dirname(filepath_current), filepath_target, "/") ---@type string
      if #src > 1 then
        if string.byte(src, 1, 1) ~= BYTE_DOT then
          src = "." .. ark.env.PATH_SEP .. src
        end
        local filename = yoz.path.basename(filepath_target) ---@type string
        local alt = vim.fn.fnamemodify(filename, ":r") ---@type string

        vim.schedule(function()
          insert_markup(alt, src)
        end)
      end
    end
  end
  return ok
end

---@return nil
local function paste()
  local clipboard = require("dot.module.clipboard")
  if not clipboard.has_image() then
    return
  end

  local cwd = dot.path.cwd() ---@type string
  local workspace = dot.path.workspace() ---@type string

  local filepath_relative = dot.context.module.paste_image_filepath:snapshot() ---@type string
  local filepath_absolute = dot.path.join(workspace, filepath_relative) ---@type string
  local placeholder = dot.path.relative(cwd, filepath_absolute) ---@type string

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

    local ok = paste_image(filepath_target) ---@type boolean
    if ok then
      local new_filepath_relative = dot.path.relative(workspace, filepath_target) ---@type string
      dot.context.module.paste_image_filepath:next(new_filepath_relative)
    end
  end)
end

return paste
