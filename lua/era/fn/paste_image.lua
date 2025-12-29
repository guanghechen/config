---@see https://github.com/hakonharnes/img-clip.nvim/blob/08a02e14c8c0d42fa7a92c30a98fd04d6993b35d/lua/img-clip/init.lua#L1

local BYTE_DOT = 0x2e ---@type integer '.'

---@param alt                           string
---@param src                           string
---@return boolean
local function insert_markup(alt, src)
  local content = src ---@type string
  local filetype = vim.bo.filetype ---@type string

  if filetype == "markdown" or filetype == stl.filetype.NOTEPAD then
    content = string.format("![%s](%s)", alt, src)
  end

  local lines = vim.split(content, "\n", { plain = true }) ---@type string[]
  vim.api.nvim_put(lines, "l", true, true)
  return true
end

---@param filepath_target               string
---@return boolean
local function paste_image(filepath_target)
  local clipboard = require("era.clipboard")
  local ok = clipboard.paste_image_from_clipboard(filepath_target)
  if ok then
    local filetype = vim.bo.filetype ---@type string
    if stl.filetype.is_sourcefile(filetype) then
      local filepath_current = vim.api.nvim_buf_get_name(0) ---@type string
      local src = dot.path.relative(dot.path.dirname(filepath_current), filepath_target, "/") ---@type string
      if #src > 1 then
        if string.byte(src, 1, 1) ~= BYTE_DOT then
          src = "." .. stl.env.PATH_SEP .. src
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

---@param filepath_target               string
---@param workspace                     string
---@return nil
local function do_paste(filepath_target, workspace)
  stl.env.mkdirs(filepath_target, false)

  local ok = paste_image(filepath_target) ---@type boolean
  if ok then
    local new_filepath_relative = dot.path.relative(workspace, filepath_target) ---@type string
    dot.context.module.paste_image_filepath:next(new_filepath_relative)
  end
end

---@return nil
local function paste()
  local clipboard = require("era.clipboard")
  if not clipboard.has_image() then
    return
  end

  local cwd = dot.path.cwd() ---@type string
  local workspace = dot.path.workspace() ---@type string

  local filepath_relative = dot.context.module.paste_image_filepath:snapshot() ---@type string
  local filepath_absolute = dot.path.join(workspace, filepath_relative) ---@type string
  local placeholder = dot.path.relative(cwd, filepath_absolute) ---@type string

  local input_winnr ---@type integer

  input_winnr = era.view.Input.open({
    prompt = "Save image to",
    default = placeholder,
    relative = "editor",
    block_cancel = true,
    before_confirm = function(filepath_target_relative, confirm, cancel)
      if filepath_target_relative == "" then
        cancel()
        return
      end

      local filepath_target = dot.path.resolve(cwd, filepath_target_relative) ---@type string
      if not vim.uv.fs_stat(filepath_target) then
        confirm()
        return
      end

      local input_cfg = vim.api.nvim_win_get_config(input_winnr) ---@type vim.api.keyset.win_config
      local input_row = input_cfg.row or 3 ---@type integer
      local input_col = input_cfg.col or 0 ---@type integer

      era.view.Select.confirm({
        title = "File exists, overwrite?",
        relative = "editor",
        row = input_row + 3,
        col = input_col,
        yes_text = "Yes, overwrite",
        no_text = "No, rename",
        default_yes = false,
        on_choice = function(confirmed)
          if confirmed then
            confirm()
          else
            cancel()
          end
        end,
      })
    end,
  }, function(filepath_target_relative)
    if filepath_target_relative == nil or filepath_target_relative == "" then
      return
    end

    local filepath_target = dot.path.resolve(cwd, filepath_target_relative) ---@type string
    do_paste(filepath_target, workspace)
  end)
end

return paste
