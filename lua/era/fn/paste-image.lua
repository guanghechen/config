---@see https://github.com/hakonharnes/img-clip.nvim/blob/5ff183655ad98b5fc50c55c66540375bbd62438c/lua/img-clip/init.lua#L1

--- MIT License
---
--- Copyright (c) 2023 Håkon Harnes
---
--- Permission is hereby granted, free of charge, to any person obtaining a copy
--- of this software and associated documentation files (the "Software"), to deal
--- in the Software without restriction, including without limitation the rights
--- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
--- copies of the Software, and to permit persons to whom the Software is
--- furnished to do so, subject to the following conditions:
---
--- The above copyright notice and this permission notice shall be included in all
--- copies or substantial portions of the Software.
---
--- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
--- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
--- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
--- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
--- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
--- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
--- SOFTWARE.

---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.fn.paste-image" ---@type string

local BYTE_DOT = 0x2e ---@type integer '.'

---@param bufnr                         integer
---@param alt                           string
---@param src                           string
---@return boolean
local function insert_markup(bufnr, alt, src)
  if
    not vim.api.nvim_buf_is_valid(bufnr)
    or not vim.api.nvim_buf_is_loaded(bufnr)
    or not vim.api.nvim_get_option_value("modifiable", { buf = bufnr })
  then
    return false
  end
  local content = src ---@type string
  local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr }) ---@type string

  if filetype == "markdown" or filetype == stl.filetype.NOTEPAD then
    if stl.env.IS_WIN then
      src = src:gsub("\\", "/")
    end
    src = src:gsub(" ", "%%20")
    content = string.format("![%s](%s)", alt, src)
  end

  local lines = vim.split(content, "\n", { plain = true }) ---@type string[]
  vim.api.nvim_buf_call(bufnr, function()
    vim.api.nvim_put(lines, "l", true, true)
  end)
  return true
end

---@param filepath_target               string
---@param bufnr                         integer
---@return boolean
local function paste_image(filepath_target, bufnr)
  local ok = era.m.clipboard.paste_image_from_clipboard(filepath_target)
  if ok and vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_is_loaded(bufnr) then
    local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr }) ---@type string
    if stl.filetype.is_sourcefile(filetype) then
      local filepath_current = vim.api.nvim_buf_get_name(bufnr) ---@type string
      local src = dot.path.relative(dot.path.dirname(filepath_current), filepath_target, "/") ---@type string
      if #src > 1 then
        if string.byte(src, 1, 1) ~= BYTE_DOT then
          src = "." .. stl.env.PATH_SEP .. src
        end
        local filename = yoz.path.basename(filepath_target) ---@type string
        local alt = vim.fn.fnamemodify(filename, ":r") ---@type string

        vim.schedule(function()
          insert_markup(bufnr, alt, src)
        end)
      end
    end
  end
  return ok
end

---@param filepath_target               string
---@param workspace                     string
---@param bufnr                         integer
---@return nil
local function do_paste(filepath_target, workspace, bufnr)
  stl.env.mkdirs(filepath_target, false)

  local ok = paste_image(filepath_target, bufnr) ---@type boolean
  if ok then
    local new_filepath_relative = dot.path.relative(workspace, filepath_target) ---@type string
    dot.context.module.paste_image_filepath:next(new_filepath_relative)
  end
end

---@return nil
local function paste()
  if not era.m.clipboard.has_image() then
    return
  end

  -- The input callback can run after focus has moved to another buffer.
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local cwd = dot.path.cwd() ---@type string
  local workspace = dot.path.workspace() ---@type string

  local filepath_relative = dot.context.module.paste_image_filepath:snapshot() ---@type string
  local filepath_absolute = dot.path.join(workspace, filepath_relative) ---@type string
  local placeholder = dot.path.relative(cwd, filepath_absolute) ---@type string

  local input_winnr ---@type integer

  input_winnr = era.m.input.open({
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

      era.m.select.confirm({
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
    do_paste(filepath_target, workspace, bufnr)
  end)
end

return paste
