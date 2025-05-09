local btn = eve.nvim.btn
local txt = eve.nvim.txt

---@class eve.ux.nvimbar.component.dir
local M = {}

---@param position                      eve.ux.nvimbar.PositionEnum
---@return eve.ux.nvimbar.IRawComponent
function M.path(position)
  local hln_blur_sep = position .. "_dir_path_blur_sep" ---@type string
  local hln_blur_text = position .. "_dir_path_blur_text" ---@type string
  local hln_focus_sep = position .. "_dir_path_focus_sep" ---@type string
  local hln_focus_text = position .. "_dir_path_focus_text" ---@type string

  local sep = eve.icon.fillchars.foldclose .. " " ---@type string
  local hl_blur_sep = txt(sep, hln_blur_sep) ---@type string
  local hl_focus_sep = txt(sep, hln_focus_sep) ---@type string
  local relpath_pieces = {} ---@type string[]

  ---@type string
  local fn_open_explorer = eve.G.register_anonymous_fn(function(index)
    local dirpath = table.concat(relpath_pieces, eve.env.PATH_SEP, 1, index) ---@type string
    vim.cmd(eve.command.definitions.find.explorer.uuid .. " " .. vim.fn.fnameescape(dirpath))
  end) or ""

  ---@type eve.ux.nvimbar.IRawComponent
  local component = {
    name = "dir:path",
    atomic = true,
    render = function(context)
      local meta = eve.buf.resolve(context.bufnr, false) ---@type eve.builtin.buf.IMeta|nil
      if meta == nil then
        return "", "", true
      end

      relpath_pieces = vim.split(meta.relpath, eve.env.PATH_SEP, { plain = true }) ---@type string[]
      local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
      local winnr_sourcefile = eve.tab.retrieve_winnr_sourcefile(tabnr) ---@type integer|nil
      local hln_text = winnr_sourcefile == context.winnr and hln_focus_text or hln_blur_text ---@type string
      local hl_text_sep = winnr_sourcefile == context.winnr and hl_focus_sep or hl_blur_sep ---@type string

      local text = "" ---@type string
      local hl_text = "" ---@type string
      local N = #relpath_pieces - 1 ---@type integer
      for i = 1, N, 1 do
        local piece = relpath_pieces[i] ---@type string
        local hl_text_piece = btn(txt(piece, hln_text), fn_open_explorer, i) ---@type string

        text = text .. piece .. sep
        hl_text = hl_text .. hl_text_piece .. hl_text_sep
      end
      return text, hl_text, true
    end,
  }
  return component
end

---@param position                      eve.ux.nvimbar.PositionEnum
---@return eve.ux.nvimbar.IRawComponent
function M.path_prominent(position)
  local hln_icon = position .. "_dir_path_prominent_icon" ---@type string
  local hln_text = position .. "_dir_path_prominent_text" ---@type string

  local icon = " " .. eve.icon.os.current .. " " ---@type string
  local sep = eve.env.PATH_SEP ---@type string
  local hl_icon = txt(icon, hln_icon) ---@type string

  local width_icon = vim.api.nvim_strwidth(icon) ---@type integer
  local width_sep = vim.api.nvim_strwidth(sep) ---@type integer

  ---@type eve.ux.nvimbar.IRawComponent
  local component = {
    name = "dir:path_prominent",
    atomic = false,
    condition = function(context)
      local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
      local winnr_sourcefile = eve.tab.retrieve_winnr_sourcefile(tabnr) ---@type integer|nil
      return context.winnr == winnr_sourcefile
    end,
    will_change = function(context, prev_context)
      return prev_context == nil or context.filepath ~= prev_context.filepath
    end,
    render = function(context, remain_width)
      local meta = eve.buf.resolve(context.bufnr, false) ---@type eve.builtin.buf.IMeta|nil
      if meta == nil then
        return "", "", false
      end

      local relpath_pieces = vim.split(meta.relpath, eve.env.PATH_SEP, { plain = true }) ---@type string[]
      local cwd_name = eve.path.basename(context.cwd) ---@type string
      local N = #relpath_pieces - 1 ---@type integer
      if N < 1 then
        local text = cwd_name .. " " ---@type string
        local hl_text = hl_icon .. txt(text, hln_text) ---@type string
        text = icon .. text
        return text, hl_text, true
      end

      local is_absolute = relpath_pieces[1] == "" ---@type boolean
      local left_text = is_absolute and "" or cwd_name ---@type string

      local remain_count = is_absolute and N - 1 or N ---@type integer
      remain_width = remain_width - vim.api.nvim_strwidth(left_text) - width_icon - width_sep - N
      if remain_width < 1 then
        local text = cwd_name .. " " ---@type string
        local hl_text = hl_icon .. txt(text, hln_text) ---@type string
        text = icon .. text
        return text, hl_text, false
      end

      local right_text = "" ---@type string
      local _start_index = is_absolute and 2 or 1 ---@type integer
      for i = N, _start_index, -1 do
        local piece = relpath_pieces[i] ---@type string
        local w = vim.api.nvim_strwidth(piece) + width_sep ---@type integer
        if remain_width <= w then
          break
        end

        if i == N then
          right_text = piece .. " "
        else
          right_text = piece .. sep .. right_text
        end

        remain_width = remain_width - w
        remain_count = remain_count - 1
      end

      if remain_count > 0 then
        local omitter = string.rep(".", remain_count)
        right_text = omitter .. sep .. right_text
      end

      local text = left_text .. sep .. right_text ---@type string
      local hl_text = hl_icon .. txt(text, hln_text)
      text = icon .. text
      return text, hl_text, remain_count < 1
    end,
  }
  return component
end

return M
