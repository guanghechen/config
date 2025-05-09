local btn = eve.nvim.btn
local txt = eve.nvim.txt

---@class eve.ux.nvimbar.component.plugin
local M = {}

---@param position                      eve.ux.nvimbar.PositionEnum
---@param neotree_position              "left"|"right"|"float"
---@return eve.ux.nvimbar.IRawComponent
function M.neotree(position, neotree_position)
  local filetype = eve.filetype.NEOTREE ---@type string
  local hln_text = position .. "_plugin_neotree_text" ---@type string
  local hln_sep = position .. "_plugin_neotree_sep" ---@type string
  local hln_blank = position .. "_plugin_neotree_blank" ---@type string
  local hln_split = position .. "_plugin_neotree_split" ---@type string
  local hln_active_text = "mf_b_bg0" ---@type string
  local hln_active_sep = "ms_b_none" ---@type string

  local right_split = position == "f_wl" and "" or " " ---@type string -- "│"
  local title_filesystem = string.format("%s Files", eve.icon.filetype.File) ---@type string
  local title_buffers = string.format("%s Buffers", eve.icon.ui.Buffer) ---@type string
  local title_git_status = string.format("%s Git", eve.icon.git.Git) ---@type string

  local sep_left = " " .. eve.icon.symbols.sep_left ---@type string
  local sep_right = eve.icon.symbols.sep_right .. " " ---@type string
  local text_filesystem = sep_left .. title_filesystem .. sep_right ---@type string
  local text_buffers = sep_left .. title_buffers .. sep_right ---@type string
  local text_git_status = sep_left .. title_git_status .. sep_right ---@type string

  local hl_sep_left = txt(sep_left, hln_sep) ---@type string
  local hl_sep_right = txt(sep_right, hln_sep) ---@type string

  local hl_filesystem = hl_sep_left .. txt(title_filesystem, hln_text) .. hl_sep_right ---@type string
  local hl_buffers = hl_sep_left .. txt(title_buffers, hln_text) .. hl_sep_right ---@type string
  local hl_git_status = hl_sep_left .. txt(title_git_status, hln_text) .. hl_sep_right ---@type string

  ---@param context                     eve.ux.nvimbar.INvimbarContext
  ---@return integer
  ---@return integer
  local function locate_neotree_pane(context)
    if position == "f_wl" then
      return vim.api.nvim_win_get_width(context.winnr), context.winnr
    end

    local winnrs = vim.api.nvim_tabpage_list_wins(0) ---@type integer[]
    for _, winnr in ipairs(winnrs) do
      local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
      if vim.bo[bufnr].filetype == filetype then
        if not eve.win.is_float(winnr) then
          return vim.api.nvim_win_get_width(winnr), winnr
        end
      end
    end
    return 0, 0
  end

  local fn_focus_filesystem = eve.G.register_anonymous_fn(function()
    require("neo-tree.command").execute({
      source = "filesystem",
      position = neotree_position,
      action = "focus",
    })
  end)

  local fn_focus_buffers = eve.G.register_anonymous_fn(function()
    require("neo-tree.command").execute({
      source = "buffers",
      position = neotree_position,
      action = "focus",
    })
  end)

  local fn_focus_git = eve.G.register_anonymous_fn(function()
    require("neo-tree.command").execute({
      source = "git_status",
      position = neotree_position,
      action = "focus",
    })
  end)

  ---@type eve.ux.nvimbar.IRawComponent
  local component = {
    name = "sidebar:neotree",
    atomic = true,
    render = function(context, remain_width)
      local width, winnr = locate_neotree_pane(context) ---@type integer, integer
      width = math.min(width, remain_width) ---@type integer
      if width < 1 then
        return "", "", true
      end

      local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
      local source = vim.b[bufnr][eve.var.Names.NEO_TREE_SOURCE] ---@type string

      local hl_sep_active_left = txt(sep_left, hln_active_sep) ---@type string
      local hl_sep_active_right = txt(sep_right, hln_active_sep) ---@type string
      local hl_active_filesystem = hl_sep_active_left .. txt(title_filesystem, hln_active_text) .. hl_sep_active_right ---@type string
      local hl_active_buffers = hl_sep_active_left .. txt(title_buffers, hln_active_text) .. hl_sep_active_right ---@type string
      local hl_active_git_status = hl_sep_active_left .. txt(title_git_status, hln_active_text) .. hl_sep_active_right ---@type string

      local text = "" ---@type string
      local hl_text = "" ---@type string

      text = text .. text_filesystem ---@type string
      hl_text = hl_text .. btn(source == "filesystem" and hl_active_filesystem or hl_filesystem, fn_focus_filesystem) ---@type string

      text = text .. text_buffers ---@type string
      hl_text = hl_text .. btn(source == "buffers" and hl_active_buffers or hl_buffers, fn_focus_buffers) ---@type string

      text = text .. text_git_status ---@type string
      hl_text = hl_text .. btn(source == "git_status" and hl_active_git_status or hl_git_status, fn_focus_git) ---@type string

      local main_width = vim.api.nvim_strwidth(text) ---@type integer
      local width_remain = width - main_width ---@type integer
      local left_width = math.floor(width_remain / 2) ---@type integer
      local right_width = width_remain - left_width - 1 ---@type integer
      local left_blank = string.rep(" ", left_width) ---@type string
      local right_blank = string.rep(" ", right_width) ---@type string

      text = left_blank .. text .. right_blank .. right_split ---@type string
      hl_text = txt(left_blank, hln_blank) .. hl_text .. txt(right_blank, hln_blank) .. txt(right_split, hln_split)
      return text, hl_text, true
    end,
  }
  return component
end

return M
