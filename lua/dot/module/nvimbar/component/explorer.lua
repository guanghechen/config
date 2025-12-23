local btn = ark.nvim.btn
local txt = ark.nvim.txt

---@class dot.module.nvimbar.component.explorer.IFlagItem
---@field public desc                   string
---@field public callback               string
---@field public snapshot               fun(): string, string

---@type { prefix: string, replacement: string }[]
local PATH_PREFIX_MAP = {
  { prefix = ark.env.HOME_USER, replacement = "~" },
}

---@param path                          string
---@return string
local function shorten_path(path)
  for _, item in ipairs(PATH_PREFIX_MAP) do
    if vim.startswith(path, item.prefix) then
      path = item.replacement .. path:sub(#item.prefix + 1)
      break
    end
  end
  return dot.path.shorten(path)
end

---@return integer
local function get_explorer_width()
  if dot.widget.explorer.widget == nil then
    return 0
  end

  local winnr = dot.widget.explorer.widget:get_winnr() ---@type integer|nil
  if winnr == nil or not vim.api.nvim_win_is_valid(winnr) then
    return 0
  end

  return vim.api.nvim_win_get_width(winnr)
end

---@class dot.module.nvimbar.component.explorer
local M = {}

---@param position                      dot.module.nvimbar.PositionEnum
---@param flags                         dot.module.nvimbar.component.explorer.IFlagItem[]
---@return dot.module.nvimbar.IRawComponent
function M.flags(position, flags)
  ---@type dot.module.nvimbar.IRawComponent
  local component = {
    name = "explorer:flags",
    atomic = true,
    condition = function()
      return #flags > 0
    end,
    render = function()
      local text = "" ---@type string
      local hl_text = "" ---@type string
      local index = 1 ---@type integer
      for _, item in ipairs(flags) do
        local flag_text, flag_hln = item.snapshot() ---@type string, string
        if flag_text ~= "" then
          local digit = ark.icon.todigit_supscript(index) ---@type string
          local piece_text = " " .. flag_text .. digit ---@type string
          local piece_hln = string.format("%s_%s", position, flag_hln) ---@type string

          text = text .. piece_text ---@type string
          hl_text = hl_text .. btn(txt(piece_text, piece_hln), item.callback) ---@type string
        end
        index = index + 1
      end
      return text, hl_text, true
    end,
  }
  return component
end

---@param o_root_uri                    ark.c.Observable
---@param position                      dot.module.nvimbar.PositionEnum
---@param flags                         dot.module.nvimbar.component.explorer.IFlagItem[]
---@param get_width                     fun(): integer
---@return dot.module.nvimbar.IRawComponent
function M.winbar(o_root_uri, position, flags, get_width)
  local hln_text = "f_explorer_winbar" ---@type string
  local hln_path = position .. "_explorer_path" ---@type string
  local hln_path_detached = position .. "_explorer_path_detached" ---@type string
  local hln_detached = position .. "_explorer_detached" ---@type string
  local icon_cwd = ark.icon.filetype.FolderWithHeart ---@type string
  local icon_folder = ark.icon.filetype.Folder ---@type string
  local icon_detached = ark.icon.ui.CircleMedium ---@type string

  ---@type dot.module.nvimbar.IRawComponent
  local component = {
    name = "explorer:winbar",
    atomic = true,
    render = function()
      local width = get_width() ---@type integer

      local root_uri = o_root_uri:snapshot() ---@type string
      local root_path = root_uri:sub(8) ---@type string
      if root_path:sub(-1) == "/" then
        root_path = root_path:sub(1, -2)
      end

      local cwd = dot.path.cwd() ---@type string
      local workspace = dot.path.workspace() ---@type string
      local workspace_name = vim.fn.fnamemodify(workspace, ":t") ---@type string
      local is_cwd = root_path == cwd ---@type boolean
      local icon = is_cwd and icon_cwd or icon_folder ---@type string
      local display_path ---@type string

      if is_cwd then
        if cwd == workspace then
          display_path = icon .. " " .. workspace_name
        elseif vim.startswith(cwd, workspace .. "/") then
          display_path = icon .. " " .. cwd:sub(#workspace + 2)
        else
          display_path = icon .. " " .. shorten_path(root_path)
        end
      else
        display_path = icon .. " " .. shorten_path(root_path)
      end

      local detached_text = is_cwd and "" or (" " .. icon_detached) ---@type string
      local path_text = " " .. display_path .. detached_text ---@type string
      local path_hln = is_cwd and hln_path or hln_path_detached ---@type string
      local path_hl_text = txt(" " .. display_path, path_hln) .. txt(detached_text, hln_detached) ---@type string

      local flags_text = "" ---@type string
      local flags_hl_text = "" ---@type string
      local index = 1 ---@type integer
      for _, item in ipairs(flags) do
        local flag_text, flag_hln = item.snapshot() ---@type string, string
        if flag_text ~= "" then
          local digit = ark.icon.todigit_supscript(index) ---@type string
          local piece_text = " " .. flag_text .. digit ---@type string
          local piece_hln = string.format("%s_%s", position, flag_hln) ---@type string
          flags_text = flags_text .. piece_text
          flags_hl_text = flags_hl_text .. btn(txt(piece_text, piece_hln), item.callback)
        end
        index = index + 1
      end
      flags_text = flags_text .. " "
      flags_hl_text = flags_hl_text .. txt(" ", hln_text)

      local path_width = vim.api.nvim_strwidth(path_text) ---@type integer
      local flags_width = vim.api.nvim_strwidth(flags_text) ---@type integer
      local padding_width = math.max(0, width - path_width - flags_width) ---@type integer
      local padding = string.rep(" ", padding_width) ---@type string

      local text = path_text .. padding .. flags_text ---@type string
      local hl_text = path_hl_text .. txt(padding, hln_text) .. flags_hl_text ---@type string
      return text, hl_text, true
    end,
  }
  return component
end

---@param o_root_uri                    ark.c.Observable
---@return dot.module.nvimbar.IRawComponent
function M.path(o_root_uri)
  local hln_path = "f_tl_explorer_path" ---@type string
  local hln_path_detached = "f_tl_explorer_path_detached" ---@type string
  local hln_detached = "f_tl_explorer_detached" ---@type string
  local icon_cwd = ark.icon.filetype.FolderWithHeart ---@type string
  local icon_folder = ark.icon.filetype.Folder ---@type string
  local icon_detached = ark.icon.ui.CircleMedium ---@type string

  ---@type dot.module.nvimbar.IRawComponent
  local component = {
    name = "explorer:path",
    atomic = true,
    render = function()
      local root_uri = o_root_uri:snapshot() ---@type string
      local root_path = root_uri:sub(8) ---@type string
      if root_path:sub(-1) == "/" then
        root_path = root_path:sub(1, -2)
      end

      local cwd = dot.path.cwd() ---@type string
      local workspace = dot.path.workspace() ---@type string
      local workspace_name = vim.fn.fnamemodify(workspace, ":t") ---@type string
      local is_cwd = root_path == cwd ---@type boolean
      local icon = is_cwd and icon_cwd or icon_folder ---@type string
      local display_path ---@type string

      if is_cwd then
        if cwd == workspace then
          display_path = icon .. " " .. workspace_name
        elseif vim.startswith(cwd, workspace .. "/") then
          display_path = icon .. " " .. cwd:sub(#workspace + 2)
        else
          display_path = icon .. " " .. shorten_path(root_path)
        end
      else
        display_path = icon .. " " .. shorten_path(root_path)
      end

      local detached_text = is_cwd and "" or (" " .. icon_detached) ---@type string
      local text = " " .. display_path .. detached_text ---@type string
      local path_hln = is_cwd and hln_path or hln_path_detached ---@type string
      local hl_text = txt(" " .. display_path, path_hln) .. txt(detached_text, hln_detached) ---@type string
      return text, hl_text, true
    end,
  }
  return component
end

---@param position                      dot.module.nvimbar.PositionEnum
---@return dot.module.nvimbar.IRawComponent
function M.tabline(position)
  local hln_blank = position .. "_sidebar_blank" ---@type string
  local hln_split = position .. "_sidebar_split" ---@type string
  local hln_path = position .. "_explorer_path" ---@type string
  local hln_path_detached = position .. "_explorer_path_detached" ---@type string
  local hln_detached = position .. "_explorer_detached" ---@type string
  local icon_cwd = ark.icon.filetype.FolderWithHeart ---@type string
  local icon_folder = ark.icon.filetype.Folder ---@type string
  local icon_detached = ark.icon.ui.CircleMedium ---@type string

  ---@return string, string, boolean
  local function get_path_text()
    local root_path ---@type string

    if dot.widget.explorer.widget ~= nil then
      local state = dot.widget.explorer.widget:get_state() ---@type dot.module.explorer.State
      local root_uri = state.o_root_uri:snapshot() ---@type string
      root_path = root_uri:sub(8) ---@type string
      if root_path:sub(-1) == "/" then
        root_path = root_path:sub(1, -2)
      end
    else
      root_path = dot.path.workspace()
    end

    local cwd = dot.path.cwd() ---@type string
    local workspace = dot.path.workspace() ---@type string
    local workspace_name = vim.fn.fnamemodify(workspace, ":t") ---@type string
    local is_cwd = root_path == cwd ---@type boolean
    local icon = is_cwd and icon_cwd or icon_folder ---@type string
    local path_hln = is_cwd and hln_path or hln_path_detached ---@type string

    if is_cwd then
      if cwd == workspace then
        local display = icon .. " " .. workspace_name ---@type string
        return display, txt(display, path_hln), is_cwd
      elseif vim.startswith(cwd, workspace .. "/") then
        local display = icon .. " " .. cwd:sub(#workspace + 2) ---@type string
        return display, txt(display, path_hln), is_cwd
      end
    end

    local display = icon .. " " .. shorten_path(root_path) ---@type string
    return display, txt(display, path_hln), is_cwd
  end

  ---@return string, string
  local function get_flags_text()
    local show_hidden ---@type boolean
    local toggle_hidden_callback ---@type fun(): nil

    if dot.widget.explorer.widget ~= nil then
      local state = dot.widget.explorer.widget:get_state() ---@type dot.module.explorer.State
      local o_flag_hidden = state.o_flag_hidden ---@type ark.c.Observable
      show_hidden = o_flag_hidden:snapshot()
      toggle_hidden_callback = function()
        o_flag_hidden:next(not o_flag_hidden:snapshot())
      end
    else
      show_hidden = dot.context.explorer.flag_show_hidden:snapshot()
      toggle_hidden_callback = function()
        local current = dot.context.explorer.flag_show_hidden:snapshot()
        dot.context.explorer.flag_show_hidden:next(not current)
      end
    end

    local text = "" ---@type string
    local hl_text = "" ---@type string
    local index = 1 ---@type integer

    local flag_selected = dot.context.explorer.flag_selected:snapshot() ---@type boolean
    local flag_selected_icon = ark.icon.symbols.flag_selected ---@type string
    local flag_selected_hln = flag_selected and "explorer_flag_orange" or "explorer_flag_grey" ---@type string
    local flag_selected_piece_hln = string.format("%s_%s", position, flag_selected_hln) ---@type string
    local flag_selected_callback = dot.G.register_anonymous_fn(function()
      local current = dot.context.explorer.flag_selected:snapshot()
      dot.context.explorer.flag_selected:next(not current)
    end) or "dot.G.noop"
    local flag_selected_digit = ark.icon.todigit_supscript(index) ---@type string
    local flag_selected_piece_text = " " .. flag_selected_icon .. flag_selected_digit ---@type string
    text = text .. flag_selected_piece_text
    hl_text = hl_text .. btn(txt(flag_selected_piece_text, flag_selected_piece_hln), flag_selected_callback)
    index = index + 1

    local flag_viewtype = dot.context.explorer.flag_viewtype:snapshot() ---@type dot.context.explorer.ViewtypeEnum
    local flag_viewtype_icon = flag_viewtype == "tree" and ark.icon.symbols.flag_tree or ark.icon.symbols.flag_list ---@type string
    local flag_viewtype_hln = "explorer_flag_blue" ---@type string
    local flag_viewtype_piece_hln = string.format("%s_%s", position, flag_viewtype_hln) ---@type string
    local flag_viewtype_callback = dot.G.register_anonymous_fn(function()
      local current = dot.context.explorer.flag_viewtype:snapshot() ---@type dot.context.explorer.ViewtypeEnum
      local next_viewtype = current == "tree" and "list" or "tree" ---@type dot.context.explorer.ViewtypeEnum
      dot.context.explorer.flag_viewtype:next(next_viewtype)
    end) or "dot.G.noop"
    local flag_viewtype_digit = ark.icon.todigit_supscript(index) ---@type string
    local flag_viewtype_piece_text = " " .. flag_viewtype_icon .. flag_viewtype_digit ---@type string
    text = text .. flag_viewtype_piece_text
    hl_text = hl_text .. btn(txt(flag_viewtype_piece_text, flag_viewtype_piece_hln), flag_viewtype_callback)
    index = index + 1

    if flag_viewtype == "tree" then
      local flag_foldempty = dot.context.explorer.flag_foldempty:snapshot() ---@type boolean
      local flag_foldempty_icon = ark.icon.symbols.flag_fold_empty_path ---@type string
      local flag_foldempty_hln = flag_foldempty and "explorer_flag_blue" or "explorer_flag_grey" ---@type string
      local flag_foldempty_piece_hln = string.format("%s_%s", position, flag_foldempty_hln) ---@type string
      local flag_foldempty_callback = dot.G.register_anonymous_fn(function()
        local current = dot.context.explorer.flag_foldempty:snapshot()
        dot.context.explorer.flag_foldempty:next(not current)
      end) or "dot.G.noop"
      local flag_foldempty_digit = ark.icon.todigit_supscript(index) ---@type string
      local flag_foldempty_piece_text = " " .. flag_foldempty_icon .. flag_foldempty_digit ---@type string
      text = text .. flag_foldempty_piece_text
      hl_text = hl_text .. btn(txt(flag_foldempty_piece_text, flag_foldempty_piece_hln), flag_foldempty_callback)
    end
    index = index + 1

    local flag_hidden_icon = ark.icon.symbols.flag_hidden ---@type string
    local flag_hidden_hln = show_hidden and "explorer_flag_blue" or "explorer_flag_grey" ---@type string
    local flag_hidden_piece_hln = string.format("%s_%s", position, flag_hidden_hln) ---@type string
    local flag_hidden_callback = dot.G.register_anonymous_fn(toggle_hidden_callback) or "dot.G.noop"
    local flag_hidden_digit = ark.icon.todigit_supscript(index) ---@type string
    local flag_hidden_piece_text = " " .. flag_hidden_icon .. flag_hidden_digit ---@type string
    text = text .. flag_hidden_piece_text
    hl_text = hl_text .. btn(txt(flag_hidden_piece_text, flag_hidden_piece_hln), flag_hidden_callback)

    return text, hl_text
  end

  ---@type dot.module.nvimbar.IRawComponent
  local component = {
    name = "explorer:tabline",
    atomic = true,
    render = function(_, remain_width)
      local width = math.min(remain_width, get_explorer_width()) ---@type integer
      if width < 1 then
        return "", "", true
      end

      local path_text, path_hl_text, is_cwd = get_path_text() ---@type string, string, boolean
      local detached_text = is_cwd and "" or (" " .. icon_detached) ---@type string
      local detached_hl_text = txt(detached_text, hln_detached) ---@type string
      local flags_text, flags_hl_text = get_flags_text() ---@type string, string

      local path_width = vim.api.nvim_strwidth(path_text) + vim.api.nvim_strwidth(detached_text) ---@type integer
      local flags_width = vim.api.nvim_strwidth(flags_text) ---@type integer
      local content_width = path_width + flags_width + 1 ---@type integer

      if width < content_width then
        local available = width - flags_width - vim.api.nvim_strwidth(detached_text) - 1 ---@type integer
        if available > 3 then
          path_text = vim.fn.strcharpart(path_text, 0, available - 1) .. "…"
          path_hl_text = txt(path_text, hln_path)
        else
          path_text = string.rep(" ", math.max(0, available))
          path_hl_text = txt(path_text, hln_path)
        end
        path_width = vim.api.nvim_strwidth(path_text) + vim.api.nvim_strwidth(detached_text)
        content_width = path_width + flags_width + 1
      end

      local padding_width = math.max(0, width - content_width) ---@type integer
      local padding = string.rep(" ", padding_width) ---@type string
      local right_split = " " ---@type string

      local text = path_text .. detached_text .. padding .. flags_text .. right_split ---@type string
      local hl_text = path_hl_text
        .. detached_hl_text
        .. txt(padding, hln_blank)
        .. flags_hl_text
        .. txt(right_split, hln_split)

      return text, hl_text, true
    end,
  }
  return component
end

return M
