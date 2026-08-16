---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.explorer.view" ---@type string

local treeview_layout = require("stl.view.treeview.layout")

local INDENT_BRANCH = "├─" ---@type string
local INDENT_LAST = "╰─" ---@type string
local INDENT_PIPE = "│ " ---@type string
local INDENT_SPACE = "  " ---@type string
local EMPTY_CHILDREN = {} ---@type era.m.explorer.Node[]

-- Virtual text IDs start at 1M to avoid collision with extmark IDs (typically small integers).
-- This ensures clear separation between line-based extmarks and virtual text decorations.
local VIRT_TEXT_ID_OFFSET = 1000000 ---@type integer

---@class era.m.explorer.View
---@field protected _cached_filepaths   string[]
---@field protected _file_icon_nsnr     integer
---@field protected _indent_hln         string
---@field protected _nsnr               integer
---@field protected _tick_structure     integer
local M = {}
M.__index = M

---@return integer
function M:get_namespace()
  return self._nsnr
end

---@param name                          string
---@return era.m.explorer.View
function M.new(name)
  local fullname = string.format("%s@%s", __module_name__, name) ---@type string

  local self = setmetatable({}, M)
  self._cached_filepaths = {}
  self._file_icon_nsnr = vim.api.nvim_create_namespace(fullname .. ".file-icons")
  self._indent_hln = "m_ex_indent"
  self._nsnr = vim.api.nvim_create_namespace(fullname)
  self._tick_structure = -1
  return self
end

---@param bufnr                         integer
---@param tree                          era.m.explorer.Tree
---@param root                          era.m.explorer.Node
---@param options                       ?era.m.explorer.view.IRenderOptions
---@return era.m.explorer.view.IRenderResult
function M:render(bufnr, tree, root, options)
  options = options or {} ---@type era.m.explorer.view.IRenderOptions

  local diag_counts = {} ---@type table<string, era.m.explorer.view.IDiagCounts>
  local deferred_file_icons = {} ---@type era.m.explorer.view.IFileIconInfo[]

  local root_filepath = root.filepath ---@type string

  ---@type era.m.explorer.view.IRenderContext
  local ctx = {
    tree = tree,
    root = root,
    root_filepath = root_filepath,
    resource_manager = options.resource_manager,
    defer_file_icons = options.defer_file_icons == true,
    deferred_file_icons = deferred_file_icons,
    foldempty = options.foldempty ~= false,
    only_selected = options.only_selected == true,
    pending_transfer = options.pending_transfer,
    show_diagnostics = options.show_diagnostics ~= false,
    show_git_status = options.show_git_status ~= false,
    show_icons = options.show_icons ~= false,
    diag_counts = diag_counts,
  }

  self:__precompute__(root, ctx)

  local lines = {} ---@type string[]
  local highlights = {} ---@type stl.t.IHighlight[]
  local diagnostic_info_list = {} ---@type era.m.explorer.view.IDiagnosticInfo[]
  local git_status_list = {} ---@type era.m.explorer.view.IGitStatusInfo[]
  local sign_info_list = {} ---@type era.m.explorer.view.ISignInfo[]
  local indent_hln = self._indent_hln ---@type string
  local only_selected = ctx.only_selected ---@type boolean

  local root_is_selected = tree:is_selected(root_filepath) ---@type boolean
  local pending_transfer = ctx.pending_transfer ---@type era.m.explorer.IPendingTransfer|nil
  local root_transfer_mode = pending_transfer ~= nil
      and (root_is_selected or pending_transfer.source_filepaths[root_filepath])
      and pending_transfer.mode
    or nil ---@type era.m.explorer.TransferModeEnum|nil

  local node_by_filepath = {} ---@type table<string, era.m.explorer.Node>
  local inherited_selected_by_node = only_selected and { [root] = root_is_selected } or nil ---@type table<era.m.explorer.Node, boolean>|nil

  ---@param node                        era.m.explorer.Node
  ---@return era.m.explorer.Node[]
  local function children(node)
    if node.nodetype ~= "D" or not node.expanded then
      return EMPTY_CHILDREN
    end

    if not node.loaded and ctx.resource_manager ~= nil then
      ctx.tree:load_node(node, false)
    end

    local source = node.children ---@type era.m.explorer.Node[]
    if not only_selected then
      return source
    end

    local current_selected = inherited_selected_by_node[node] or node.selected ---@type boolean
    if current_selected then
      for _, child in ipairs(source) do
        inherited_selected_by_node[child] = true
      end
      return source
    end

    local projected = {} ---@type era.m.explorer.Node[]
    for _, child in ipairs(source) do
      if child.selected or (child.nodetype == "D" and child.has_selected) then
        projected[#projected + 1] = child
        inherited_selected_by_node[child] = false
      end
    end
    return projected
  end

  local roots = children(root) ---@type era.m.explorer.Node[]
  local layout = treeview_layout.layout({
    roots = roots,
    id = function(node)
      node_by_filepath[node.filepath] = node
      return node.filepath
    end,
    children = children,
    can_fold = ctx.foldempty and function(parent, child)
      return child.nodetype == "D"
        and #parent.children == 1
        and not parent.selected
        and (pending_transfer == nil or not pending_transfer.source_filepaths[parent.filepath])
    end or nil,
  })

  local prefixes = { [0] = "" } ---@type table<integer, string>
  local selected_by_lnum = {} ---@type table<integer, boolean>
  local transfer_mode_by_lnum = {} ---@type table<integer, era.m.explorer.TransferModeEnum>

  for lnum = 1, layout:len() do
    local filepath = layout:id(lnum) ---@type string
    local node = node_by_filepath[filepath] ---@type era.m.explorer.Node
    local depth = layout:depth(lnum) ---@type integer
    local visible_parent_lnum = layout:parent_lnum(lnum) ---@type integer|nil
    local inherited_selected = visible_parent_lnum ~= nil and selected_by_lnum[visible_parent_lnum] or root_is_selected ---@type boolean
    local is_selected = inherited_selected or node.selected ---@type boolean
    selected_by_lnum[lnum] = is_selected

    local transfer_mode = visible_parent_lnum ~= nil and transfer_mode_by_lnum[visible_parent_lnum]
      or root_transfer_mode ---@type era.m.explorer.TransferModeEnum|nil
    if
      transfer_mode == nil
      and pending_transfer ~= nil
      and (is_selected or pending_transfer.source_filepaths[node.filepath])
    then
      transfer_mode = pending_transfer.mode
    end
    transfer_mode_by_lnum[lnum] = transfer_mode

    local folded_ids = layout:folded_ids(lnum) ---@type string[]|nil
    local source_node = folded_ids ~= nil and node_by_filepath[folded_ids[1]] or node ---@type era.m.explorer.Node
    local prefix = prefixes[depth] ---@type string
    local is_last = layout:is_last(lnum) ---@type boolean
    if only_selected then
      is_last = source_node.parent.children[#source_node.parent.children] == source_node
    end
    local indent = prefix .. (is_last and INDENT_LAST or INDENT_BRANCH) ---@type string
    prefixes[depth + 1] = prefix .. (is_last and INDENT_SPACE or INDENT_PIPE)

    local display_name = nil ---@type string|nil
    if folded_ids ~= nil then
      local names = {} ---@type string[]
      for index, folded_id in ipairs(folded_ids) do
        local folded_node = node_by_filepath[folded_id] ---@type era.m.explorer.Node
        names[index] = folded_node.nodename
      end
      display_name = table.concat(names, "/")
    end

    local line, line_highlights, git_info, diag_info =
      self:__render_node__(ctx, node, indent, lnum, display_name, node.expanded, is_selected)

    lines[lnum] = line

    highlights[#highlights + 1] = {
      lnum = lnum,
      coll = 0,
      colr = #indent,
      hlname = indent_hln,
    }
    for _, hl in ipairs(line_highlights) do
      highlights[#highlights + 1] = hl
    end

    if git_info ~= nil then
      git_status_list[#git_status_list + 1] = git_info
    end
    if diag_info ~= nil then
      diagnostic_info_list[#diagnostic_info_list + 1] = diag_info
    end

    if transfer_mode ~= nil or is_selected then
      local sign_text ---@type string
      local sign_hl_group ---@type string
      if transfer_mode == "move" then
        sign_text = stl.icon.symbols.selection_cut
        sign_hl_group = "m_ex_cut"
      elseif transfer_mode == "copy" then
        sign_text = stl.icon.symbols.selection_copy
        sign_hl_group = "m_ex_copy"
      else
        sign_text = stl.icon.symbols.selection
        sign_hl_group = "m_ex_selected"
      end
      sign_info_list[#sign_info_list + 1] = {
        lnum = lnum,
        sign_text = sign_text,
        sign_hl_group = sign_hl_group,
      }
    end
  end

  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })

  vim.api.nvim_buf_clear_namespace(bufnr, self._nsnr, 0, -1)
  vim.api.nvim_buf_clear_namespace(bufnr, self._file_icon_nsnr, 0, -1)
  local deferred_icon_highlights = {} ---@type table<stl.t.IHighlight, boolean>
  for _, info in ipairs(deferred_file_icons) do
    deferred_icon_highlights[info.highlight] = true
  end
  for _, hl in ipairs(highlights) do
    local row = hl.lnum - 1 ---@type integer
    local nsnr = deferred_icon_highlights[hl] and self._file_icon_nsnr or self._nsnr ---@type integer
    vim.api.nvim_buf_set_extmark(bufnr, nsnr, row, hl.coll, {
      end_row = row,
      end_col = hl.colr,
      hl_group = hl.hlname,
      priority = 10,
      strict = false,
    })
  end

  local diag_by_lnum = {} ---@type table<integer, era.m.explorer.view.IDiagnosticInfo>
  for _, diag_info in ipairs(diagnostic_info_list) do
    diag_by_lnum[diag_info.lnum] = diag_info
  end

  local git_by_lnum = {} ---@type table<integer, era.m.explorer.view.IGitStatusInfo>
  for _, git_info in ipairs(git_status_list) do
    git_by_lnum[git_info.lnum] = git_info
  end

  local sign_by_lnum = {} ---@type table<integer, era.m.explorer.view.ISignInfo>
  for _, sign_info in ipairs(sign_info_list) do
    sign_by_lnum[sign_info.lnum] = sign_info
  end

  local total_lines = #lines ---@type integer
  for lnum_key = 1, total_lines do
    local virt_text = {} ---@type string[][]

    local diag_info = diag_by_lnum[lnum_key] ---@type era.m.explorer.view.IDiagnosticInfo|nil
    if diag_info ~= nil then
      for _, hl in ipairs(diag_info.highlights) do
        local text = diag_info.text:sub(hl.coll + 1, hl.colr) ---@type string
        virt_text[#virt_text + 1] = { text, hl.hlname }
      end
    end

    local git_info = git_by_lnum[lnum_key] ---@type era.m.explorer.view.IGitStatusInfo|nil
    if git_info ~= nil then
      for _, hl in ipairs(git_info.highlights) do
        local text = git_info.text:sub(hl.coll + 1, hl.colr) ---@type string
        virt_text[#virt_text + 1] = { text, hl.hlname }
      end
    end

    local sign_info = sign_by_lnum[lnum_key] ---@type era.m.explorer.view.ISignInfo|nil
    if sign_info ~= nil then
      virt_text[#virt_text + 1] = { " " .. sign_info.sign_text, sign_info.sign_hl_group }
    else
      virt_text[#virt_text + 1] = { "  " }
    end

    vim.api.nvim_buf_set_extmark(bufnr, self._nsnr, lnum_key - 1, 0, {
      id = VIRT_TEXT_ID_OFFSET + lnum_key,
      virt_text = virt_text,
      virt_text_pos = "right_align",
      priority = 10,
    })
  end

  ---@type era.m.explorer.view.IRenderResult
  return {
    deferred_file_icons = deferred_file_icons,
    lines = lines,
    highlights = highlights,
    diagnostic_info_list = diagnostic_info_list,
    git_status_list = git_status_list,
    sign_info_list = sign_info_list,
    layout = layout,
    diag_by_lnum = diag_by_lnum,
    git_by_lnum = git_by_lnum,
    sign_by_lnum = sign_by_lnum,
  }
end

---@param bufnr                         integer
---@param render_result                 era.m.explorer.view.IRenderResult
---@param index_start                   integer
---@param index_end                     integer
---@return nil
function M:update_file_icons(bufnr, render_result, index_start, index_end)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local infos = render_result.deferred_file_icons ---@type era.m.explorer.view.IFileIconInfo[]
  local updates = {} ---@type table[]
  for index = index_start, math.min(index_end, #infos) do
    local info = infos[index] ---@type era.m.explorer.view.IFileIconInfo
    local icon, hlname = stl.fileicon.get_file_icon(info.nodename) ---@type string, string
    if info.is_ignored then
      hlname = "m_ex_ignored"
    end
    if icon ~= info.icon or hlname ~= info.highlight.hlname then
      updates[#updates + 1] = { info = info, icon = icon, hlname = hlname }
    end
  end

  if #updates == 0 then
    return
  end

  local was_modifiable = vim.api.nvim_get_option_value("modifiable", { buf = bufnr }) ---@type boolean
  if not was_modifiable then
    vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
  end

  local ok, err = pcall(function()
    for _, update in ipairs(updates) do
      local info = update.info ---@type era.m.explorer.view.IFileIconInfo
      local icon = update.icon ---@type string
      local hlname = update.hlname ---@type string
      local lnum = info.lnum ---@type integer
      local row = lnum - 1 ---@type integer
      local coll = info.highlight.coll ---@type integer
      local old_colr = coll + #info.icon ---@type integer
      local delta = #icon - #info.icon ---@type integer

      vim.api.nvim_buf_set_text(bufnr, row, coll, row, old_colr, { icon })
      local line = render_result.lines[lnum] ---@type string
      render_result.lines[lnum] = line:sub(1, coll) .. icon .. line:sub(old_colr + 1)

      info.icon = icon
      info.highlight.colr = info.highlight.colr + delta
      info.highlight.hlname = hlname
      info.name_highlight.coll = info.name_highlight.coll + delta
      info.name_highlight.colr = info.name_highlight.colr + delta

      vim.api.nvim_buf_clear_namespace(bufnr, self._file_icon_nsnr, row, row + 1)
      vim.api.nvim_buf_set_extmark(bufnr, self._file_icon_nsnr, row, coll, {
        end_row = row,
        end_col = info.highlight.colr,
        hl_group = hlname,
        priority = 10,
        strict = false,
      })
    end
  end)

  if not was_modifiable and vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
  end
  if not ok then
    error(err, 0)
  end
end

---@param bufnr                         integer
---@param render_result                 era.m.explorer.view.IRenderResult
---@param lnum                          integer
---@param cursorline_hlgroup            ?string
---@return nil
function M:update_virt_text(bufnr, render_result, lnum, cursorline_hlgroup)
  if lnum < 1 or lnum > #render_result.lines then
    return
  end

  local diag_info = render_result.diag_by_lnum[lnum] ---@type era.m.explorer.view.IDiagnosticInfo|nil
  local git_info = render_result.git_by_lnum[lnum] ---@type era.m.explorer.view.IGitStatusInfo|nil
  local sign_info = render_result.sign_by_lnum[lnum] ---@type era.m.explorer.view.ISignInfo|nil

  local is_focused = cursorline_hlgroup == "m_ex_cursorline" ---@type boolean
  local hl_suffix = is_focused and "_cl" or "_clb" ---@type string

  local virt_text = {} ---@type string[][]

  if diag_info ~= nil then
    for _, hl in ipairs(diag_info.highlights) do
      local text = diag_info.text:sub(hl.coll + 1, hl.colr) ---@type string
      local hlname = cursorline_hlgroup and (hl.hlname .. hl_suffix) or hl.hlname ---@type string
      virt_text[#virt_text + 1] = { text, hlname }
    end
  end

  if git_info ~= nil then
    for _, hl in ipairs(git_info.highlights) do
      local text = git_info.text:sub(hl.coll + 1, hl.colr) ---@type string
      local hlname = cursorline_hlgroup and (hl.hlname .. hl_suffix) or hl.hlname ---@type string
      virt_text[#virt_text + 1] = { text, hlname }
    end
  end

  if sign_info ~= nil then
    local hlname = cursorline_hlgroup and (sign_info.sign_hl_group .. hl_suffix) or sign_info.sign_hl_group ---@type string
    virt_text[#virt_text + 1] = { " " .. sign_info.sign_text, hlname }
  else
    virt_text[#virt_text + 1] = { "  ", cursorline_hlgroup }
  end

  vim.api.nvim_buf_set_extmark(bufnr, self._nsnr, lnum - 1, 0, {
    id = VIRT_TEXT_ID_OFFSET + lnum,
    virt_text = virt_text,
    virt_text_pos = "right_align",
    priority = 10,
  })
end

---@protected
---@param ctx                           era.m.explorer.view.IRenderContext
---@param node                          era.m.explorer.Node
---@param lnum                          integer
---@return era.m.explorer.view.IDiagnosticInfo|nil
function M:__get_diagnostic_info__(ctx, node, lnum)
  local counts = ctx.diag_counts[node.filepath] ---@type era.m.explorer.view.IDiagCounts|nil
  if counts == nil then
    return nil
  end

  local count_error = counts.error ---@type integer
  local count_warn = counts.warn ---@type integer
  local count_hint = counts.hint ---@type integer
  local count_info = counts.info ---@type integer

  if count_error == 0 and count_warn == 0 and count_hint == 0 and count_info == 0 then
    return nil
  end

  local text = "" ---@type string
  local highlights = {} ---@type stl.t.IHighlightInline[]
  local col = 0 ---@type integer
  local slots = 0 ---@type integer

  if count_error > 0 then
    local part = " " .. stl.icon.diagnostic.Error_alt .. " " .. count_error ---@type string
    text = text .. part
    highlights[#highlights + 1] = { coll = col, colr = col + #part, hlname = "f_lsp_diagnostic_error" }
    col = col + #part
    slots = slots + 1
  end

  if count_warn > 0 then
    local part = " " .. stl.icon.diagnostic.Warning_alt .. " " .. count_warn ---@type string
    text = text .. part
    highlights[#highlights + 1] = { coll = col, colr = col + #part, hlname = "f_lsp_diagnostic_warn" }
    col = col + #part
    slots = slots + 1
  end

  if count_hint > 0 and slots < 2 then
    local part = " " .. stl.icon.diagnostic.Hint_alt .. " " .. count_hint ---@type string
    text = text .. part
    highlights[#highlights + 1] = { coll = col, colr = col + #part, hlname = "f_lsp_diagnostic_hint" }
    col = col + #part
    slots = slots + 1
  end

  if count_info > 0 and slots < 2 then
    local part = " " .. stl.icon.diagnostic.Information_alt .. " " .. count_info ---@type string
    text = text .. part
    highlights[#highlights + 1] = { coll = col, colr = col + #part, hlname = "f_lsp_diagnostic_info" }
    col = col + #part
    slots = slots + 1
  end

  if #text < 1 then
    return nil
  end

  return {
    lnum = lnum,
    text = text,
    highlights = highlights,
  }
end

---@protected
---@param node                          era.m.explorer.Node
---@param lnum                          integer
---@return era.m.explorer.view.IGitStatusInfo|nil
---@return string|nil
function M:__get_git_status_info__(node, lnum)
  local filepath = node.filepath ---@type string
  if filepath == "" then
    return nil, nil
  end

  local filetype = node.nodetype == "D" and "directory" or "file" ---@type string
  local highlights = {} ---@type stl.t.IHighlightInline[]

  local git_text, git_hl = era.m.git.status.calc_info(filepath, filetype, 0, highlights)

  if git_text == nil or #git_text < 1 then
    return nil, git_hl
  end

  return {
    lnum = lnum,
    text = git_text,
    highlights = highlights,
  }, git_hl
end

---@protected
---@param node                          era.m.explorer.Node
---@param is_ignored                    boolean
---@param is_expanded                   boolean
---@param defer_file_icon               boolean
---@return string
---@return string
function M:__get_node_icon__(node, is_ignored, is_expanded, defer_file_icon)
  if node.nodetype == "D" then
    local icon, icon_hl ---@type string, string
    if is_expanded then
      local is_loaded = node.loaded ---@type boolean
      local is_empty = is_loaded and #node.children == 0 ---@type boolean
      if is_empty then
        icon = stl.icon.filetype.FolderEmptyOpen
        icon_hl = "m_ft_dirname"
      else
        icon = stl.icon.filetype.FolderOpen
        icon_hl = "m_ft_dirname"
      end
    else
      local dir_icon, dir_hl, is_fallback = stl.fileicon.get_directory_icon(node.nodename) ---@type string, string, boolean
      if not is_fallback then
        icon = dir_icon
        icon_hl = dir_hl
      else
        icon = stl.icon.filetype.Folder
        icon_hl = "m_ft_dirname"
      end
    end
    if is_ignored then
      icon_hl = "m_ex_ignored"
    end
    return icon, icon_hl
  end

  local filetype = defer_file_icon and "" or nil ---@type string|nil
  local icon, icon_hl = stl.fileicon.get_file_icon(node.nodename, filetype) ---@type string, string
  if is_ignored then
    icon_hl = "m_ex_ignored"
  end
  return icon, icon_hl
end

---@protected
---@param ctx                           era.m.explorer.view.IRenderContext
---@param node                          era.m.explorer.Node
---@param is_ignored                    boolean
---@param is_selected                   boolean
---@param git_hl                        string|nil
---@return string
function M:__get_node_name_highlight__(ctx, node, is_ignored, is_selected, git_hl)
  if is_selected then
    return "m_ex_selected"
  end

  if is_ignored then
    return "m_ex_ignored"
  end

  local counts = ctx.diag_counts[node.filepath] ---@type era.m.explorer.view.IDiagCounts|nil
  if counts ~= nil then
    if counts.error > 0 then
      return "f_lsp_diagnostic_error"
    end
    if counts.warn > 0 then
      return "f_lsp_diagnostic_warn"
    end
  end

  if git_hl ~= nil then
    return git_hl
  end

  if node.nodetype == "D" then
    return "m_ft_dirname"
  end

  return "m_ft_filename"
end

---@protected
---@param node                          era.m.explorer.Node
---@return boolean
function M:__is_ignored__(node)
  local filepath = node.filepath ---@type string
  if filepath == "" then
    return false
  end
  return era.m.git.state.is_ignored(filepath)
end

---@protected
---@param root                          era.m.explorer.Node
---@param ctx                           era.m.explorer.view.IRenderContext
---@return nil
function M:__precompute__(root, ctx)
  local tree = ctx.tree ---@type era.m.explorer.Tree
  local ticks = tree.ticks ---@type era.m.explorer.ITreeTicks
  local diag_counts = ctx.diag_counts ---@type table<string, era.m.explorer.view.IDiagCounts>
  local show_diagnostics = ctx.show_diagnostics ---@type boolean
  local bufnr_counts = {} ---@type table<integer, era.m.explorer.view.IDiagCounts>

  local loaded_bufnrs = show_diagnostics and stl.nvim.buf.get_loaded_bufnrs() or {} ---@type table<string, integer>

  local filepaths ---@type string[]
  if self._tick_structure == ticks.structure then
    filepaths = self._cached_filepaths
  else
    filepaths = {}

    if root.expanded then
      if not root.loaded and ctx.resource_manager ~= nil then
        ctx.tree:load_node(root, false)
      end

      local stack_children = { root.children } ---@type era.m.explorer.Node[][]
      local stack_indexes = { 1 } ---@type integer[]
      local stack_size = 1 ---@type integer
      while stack_size > 0 do
        local children = stack_children[stack_size] ---@type era.m.explorer.Node[]
        local index = stack_indexes[stack_size] ---@type integer
        if index > #children then
          stack_children[stack_size] = nil
          stack_indexes[stack_size] = nil
          stack_size = stack_size - 1
        else
          stack_indexes[stack_size] = index + 1
          local node = children[index] ---@type era.m.explorer.Node
          if node.filepath ~= "" then
            filepaths[#filepaths + 1] = node.filepath
          end
          if node.nodetype == "D" and node.expanded then
            if not node.loaded and ctx.resource_manager ~= nil then
              ctx.tree:load_node(node, false)
            end
            if #node.children > 0 then
              stack_size = stack_size + 1
              stack_children[stack_size] = node.children
              stack_indexes[stack_size] = 1
            end
          end
        end
      end
    end

    self._cached_filepaths = filepaths
    self._tick_structure = ticks.structure
  end

  if show_diagnostics then
    if root.expanded then
      local stack_nodes = { root } ---@type era.m.explorer.Node[]
      local stack_indexes = { 0 } ---@type integer[]
      local stack_size = 1 ---@type integer
      while stack_size > 0 do
        local node = stack_nodes[stack_size] ---@type era.m.explorer.Node
        local index = stack_indexes[stack_size] ---@type integer
        local children = node.children ---@type era.m.explorer.Node[]
        if node.nodetype == "D" and node.expanded and index < #children then
          index = index + 1
          stack_indexes[stack_size] = index
          stack_size = stack_size + 1
          stack_nodes[stack_size] = children[index]
          stack_indexes[stack_size] = 0
        else
          local counts = { error = 0, warn = 0, hint = 0, info = 0 } ---@type era.m.explorer.view.IDiagCounts
          if node.nodetype == "F" and node.filepath ~= "" then
            local bufnr = stl.nvim.buf.lookup_bufnr(loaded_bufnrs, node.filepath) ---@type integer|nil
            if bufnr ~= nil then
              local cached = bufnr_counts[bufnr] ---@type era.m.explorer.view.IDiagCounts|nil
              if cached ~= nil then
                counts = cached
              else
                local diag_data = era.m.lsp.diagnostic.get_by_bufnr(bufnr) ---@type era.m.lsp.diagnostic.IBufferDiagnostics
                counts.error = diag_data.error
                counts.warn = diag_data.warn
                counts.hint = diag_data.hint
                counts.info = diag_data.info
                bufnr_counts[bufnr] = counts
              end
            end
          elseif node.nodetype == "D" and node.expanded then
            for _, child in ipairs(children) do
              local child_counts = diag_counts[child.filepath] ---@type era.m.explorer.view.IDiagCounts
              counts.error = counts.error + child_counts.error
              counts.warn = counts.warn + child_counts.warn
              counts.hint = counts.hint + child_counts.hint
              counts.info = counts.info + child_counts.info
            end
          end
          diag_counts[node.filepath] = counts
          stack_nodes[stack_size] = nil
          stack_indexes[stack_size] = nil
          stack_size = stack_size - 1
        end
      end
    end
  end

  if #filepaths > 0 then
    era.m.git.state.preload_ignored(filepaths)
  end
end

---@protected
---@param ctx                           era.m.explorer.view.IRenderContext
---@param node                          era.m.explorer.Node
---@param indent                        string
---@param lnum                          integer
---@param display_name                  ?string
---@param is_expanded                   boolean
---@param is_selected                   boolean
---@return string
---@return stl.t.IHighlight[]
---@return era.m.explorer.view.IGitStatusInfo|nil
---@return era.m.explorer.view.IDiagnosticInfo|nil
function M:__render_node__(ctx, node, indent, lnum, display_name, is_expanded, is_selected)
  local parts = {} ---@type string[]
  local highlights = {} ---@type stl.t.IHighlight[]
  local col = 0 ---@type integer

  local is_ignored = self:__is_ignored__(node) ---@type boolean

  parts[#parts + 1] = indent
  col = col + #indent

  local defer_file_icon = ctx.defer_file_icons and node.nodetype == "F" ---@type boolean
  local icon = nil ---@type string|nil
  local icon_highlight = nil ---@type stl.t.IHighlight|nil
  if ctx.show_icons then
    local icon_hl ---@type string
    icon, icon_hl = self:__get_node_icon__(node, is_ignored, is_expanded, defer_file_icon)
    parts[#parts + 1] = icon
    parts[#parts + 1] = " "

    icon_highlight = {
      lnum = lnum,
      coll = col,
      colr = col + #icon + 1,
      hlname = icon_hl,
    }
    highlights[#highlights + 1] = icon_highlight
    col = col + #icon + 1
  end

  local git_info ---@type era.m.explorer.view.IGitStatusInfo|nil
  local git_hl ---@type string|nil
  if ctx.show_git_status then
    git_info, git_hl = self:__get_git_status_info__(node, lnum)
  end

  local name = display_name or node.nodename ---@type string
  local name_hl = self:__get_node_name_highlight__(ctx, node, is_ignored, is_selected, git_hl) ---@type string
  parts[#parts + 1] = name

  local name_highlight = {
    lnum = lnum,
    coll = col,
    colr = col + #name,
    hlname = name_hl,
  } ---@type stl.t.IHighlight
  highlights[#highlights + 1] = name_highlight

  if defer_file_icon and icon ~= nil and icon_highlight ~= nil then
    ctx.deferred_file_icons[#ctx.deferred_file_icons + 1] = {
      highlight = icon_highlight,
      icon = icon,
      is_ignored = is_ignored,
      lnum = lnum,
      name_highlight = name_highlight,
      nodename = node.nodename,
    }
  end

  local diag_info ---@type era.m.explorer.view.IDiagnosticInfo|nil
  if ctx.show_diagnostics then
    diag_info = self:__get_diagnostic_info__(ctx, node, lnum)
  end

  local line = table.concat(parts) ---@type string
  return line, highlights, git_info, diag_info
end

return M
