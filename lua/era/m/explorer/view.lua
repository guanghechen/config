---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.explorer.view" ---@type string

local INDENT_BRANCH = "├─" ---@type string
local INDENT_LAST = "╰─" ---@type string
local INDENT_PIPE = "│ " ---@type string
local INDENT_SPACE = "  " ---@type string

-- Virtual text IDs start at 1M to avoid collision with extmark IDs (typically small integers).
-- This ensures clear separation between line-based extmarks and virtual text decorations.
local VIRT_TEXT_ID_OFFSET = 1000000 ---@type integer

---@class era.m.explorer.View
---@field protected _cached_filepaths   string[]
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

  local root_filepath = root.filepath ---@type string

  ---@type era.m.explorer.view.IRenderContext
  local ctx = {
    tree = tree,
    root = root,
    root_filepath = root_filepath,
    resource_manager = options.resource_manager,
    foldempty = options.foldempty ~= false,
    only_selected = options.only_selected == true,
    show_diagnostics = options.show_diagnostics ~= false,
    show_git_status = options.show_git_status ~= false,
    show_icons = options.show_icons ~= false,
    diag_counts = diag_counts,
    select_mode = options.select_mode or "select",
  }

  self:__precompute__(root, ctx)

  local lines = {} ---@type string[]
  local highlights = {} ---@type stl.t.IHighlight[]
  local diagnostic_info_list = {} ---@type era.m.explorer.view.IDiagnosticInfo[]
  local git_status_list = {} ---@type era.m.explorer.view.IGitStatusInfo[]
  local sign_info_list = {} ---@type era.m.explorer.view.ISignInfo[]
  local lnum_to_filepath = {} ---@type table<integer, string>
  local filepath_to_lnum = {} ---@type table<string, integer>
  local lnum = 0 ---@type integer
  local indent_hln = self._indent_hln ---@type string
  local only_selected = ctx.only_selected ---@type boolean

  ---@param node                        era.m.explorer.Node
  ---@param prefix                      string
  ---@param is_last                     boolean
  ---@param display_name                string|nil
  ---@param inherited_selected          boolean
  ---@return nil
  local function traverse(node, prefix, is_last, display_name, inherited_selected)
    local is_selected = inherited_selected or node.selected ---@type boolean

    if only_selected and not is_selected then
      if node.nodetype == "F" then
        return
      end
      if not node.has_selected then
        return
      end
    end

    lnum = lnum + 1
    local current_lnum = lnum ---@type integer

    local is_expanded = node.expanded ---@type boolean

    local indent ---@type string
    if prefix == "" then
      indent = is_last and INDENT_LAST or INDENT_BRANCH
    else
      indent = prefix .. (is_last and INDENT_LAST or INDENT_BRANCH)
    end

    local line, line_highlights, git_info, diag_info =
      self:__render_node__(ctx, node, indent, current_lnum, display_name, is_expanded, is_selected)

    lines[current_lnum] = line
    lnum_to_filepath[current_lnum] = node.filepath
    filepath_to_lnum[node.filepath] = current_lnum

    if #indent > 0 then
      highlights[#highlights + 1] = {
        lnum = current_lnum,
        coll = 0,
        colr = #indent,
        hlname = indent_hln,
      }
    end

    for _, hl in ipairs(line_highlights) do
      highlights[#highlights + 1] = hl
    end

    if git_info ~= nil then
      git_status_list[#git_status_list + 1] = git_info
    end

    if diag_info ~= nil then
      diagnostic_info_list[#diagnostic_info_list + 1] = diag_info
    end

    if is_selected then
      local sign_text ---@type string
      local sign_hl_group ---@type string
      if ctx.select_mode == "cut" then
        sign_text = stl.icon.symbols.selection_cut
        sign_hl_group = "m_ex_cut"
      elseif ctx.select_mode == "copy" then
        sign_text = stl.icon.symbols.selection_copy
        sign_hl_group = "m_ex_copy"
      else
        sign_text = stl.icon.symbols.selection
        sign_hl_group = "m_ex_selected"
      end
      sign_info_list[#sign_info_list + 1] = {
        lnum = current_lnum,
        sign_text = sign_text,
        sign_hl_group = sign_hl_group,
      }
    end

    if node.nodetype == "D" and is_expanded then
      if not node.loaded and ctx.resource_manager ~= nil then
        ctx.tree:load_node(node, false)
      end

      local children = node.children ---@type era.m.explorer.Node[]
      local N = #children ---@type integer
      local child_prefix = prefix .. (is_last and INDENT_SPACE or INDENT_PIPE) ---@type string
      for i, child in ipairs(children) do
        local child_display_name = nil ---@type string|nil

        if ctx.foldempty and child.nodetype == "D" then
          local folded_node, folded_path = self:__fold_empty_dirs__(child, ctx)
          if folded_node ~= child then
            child = folded_node
            child_display_name = folded_path
          end
        end

        traverse(child, child_prefix, i == N, child_display_name, is_selected)
      end
    end
  end

  local root_is_expanded = root.expanded ---@type boolean
  local root_is_selected = tree:is_selected(root_filepath) ---@type boolean
  if root_is_expanded then
    if not root.loaded and ctx.resource_manager ~= nil then
      ctx.tree:load_node(root, false)
    end

    local children = root.children ---@type era.m.explorer.Node[]
    local N = #children ---@type integer
    for i, child in ipairs(children) do
      local child_display_name = nil ---@type string|nil

      if ctx.foldempty and child.nodetype == "D" then
        local folded_node, folded_path = self:__fold_empty_dirs__(child, ctx)
        if folded_node ~= child then
          child = folded_node
          child_display_name = folded_path
        end
      end

      traverse(child, "", i == N, child_display_name, root_is_selected)
    end
  end

  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })

  vim.api.nvim_buf_clear_namespace(bufnr, self._nsnr, 0, -1)
  for _, hl in ipairs(highlights) do
    vim.hl.range(bufnr, self._nsnr, hl.hlname, { hl.lnum - 1, hl.coll }, { hl.lnum - 1, hl.colr }, { priority = 10 })
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
    lines = lines,
    highlights = highlights,
    diagnostic_info_list = diagnostic_info_list,
    git_status_list = git_status_list,
    sign_info_list = sign_info_list,
    lnum_to_filepath = lnum_to_filepath,
    filepath_to_lnum = filepath_to_lnum,
    diag_by_lnum = diag_by_lnum,
    git_by_lnum = git_by_lnum,
    sign_by_lnum = sign_by_lnum,
  }
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

----------------------------------------------------------------------------------------------------

---@protected
---@param node                          era.m.explorer.Node
---@param ctx                           era.m.explorer.view.IRenderContext
---@return era.m.explorer.Node
---@return string
function M:__fold_empty_dirs__(node, ctx)
  local path_parts = { node.nodename } ---@type string[]
  local current = node ---@type era.m.explorer.Node

  while true do
    if current.selected then
      break
    end

    if not current.expanded then
      break
    end

    if not current.loaded and ctx.resource_manager ~= nil then
      ctx.tree:load_node(current, false)
    end

    local children = current.children ---@type era.m.explorer.Node[]
    if #children ~= 1 then
      break
    end

    local child = children[1] ---@type era.m.explorer.Node
    if child.nodetype ~= "D" then
      break
    end

    path_parts[#path_parts + 1] = child.nodename
    current = child
  end

  if #path_parts == 1 then
    return node, node.nodename
  end

  return current, table.concat(path_parts, "/")
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
function M:__get_git_status_info__(node, lnum)
  local filepath = self:__filepath_to_filepath__(node.filepath) ---@type string
  if filepath == "" then
    return nil
  end

  local filetype = node.nodetype == "D" and "directory" or "file" ---@type string
  local highlights = {} ---@type stl.t.IHighlightInline[]

  local git_text, _ = era.m.git.status.calc_info(filepath, filetype, 0, highlights)

  if git_text == nil or #git_text < 1 then
    return nil
  end

  return {
    lnum = lnum,
    text = git_text,
    highlights = highlights,
  }
end

---@protected
---@param node                          era.m.explorer.Node
---@param is_ignored                    boolean
---@param is_expanded                   boolean
---@return string
---@return string
function M:__get_node_icon__(node, is_ignored, is_expanded)
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

  local icon, icon_hl = stl.fileicon.get_file_icon(node.nodename) ---@type string, string
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
---@return string
function M:__get_node_name_highlight__(ctx, node, is_ignored, is_selected)
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

  if ctx.show_git_status then
    local filepath = self:__filepath_to_filepath__(node.filepath) ---@type string
    if filepath ~= "" then
      local filetype = node.nodetype == "D" and "directory" or "file" ---@type string
      local _, git_hl = era.m.git.status.resolve(filepath, filetype)
      if git_hl ~= nil then
        return git_hl
      end
    end
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
  local filepath = self:__filepath_to_filepath__(node.filepath) ---@type string
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

    ---@param node                      era.m.explorer.Node
    local function collect_filepaths(node)
      local filepath = self:__filepath_to_filepath__(node.filepath) ---@type string
      if filepath ~= "" then
        filepaths[#filepaths + 1] = filepath
      end

      if node.nodetype == "D" and node.expanded then
        if not node.loaded and ctx.resource_manager ~= nil then
          ctx.tree:load_node(node, false)
        end
        for _, child in ipairs(node.children) do
          collect_filepaths(child)
        end
      end
    end

    if root.expanded then
      if not root.loaded and ctx.resource_manager ~= nil then
        ctx.tree:load_node(root, false)
      end
      for _, child in ipairs(root.children) do
        collect_filepaths(child)
      end
    end

    self._cached_filepaths = filepaths
    self._tick_structure = ticks.structure
  end

  if show_diagnostics then
    ---@param node                      era.m.explorer.Node
    ---@return era.m.explorer.view.IDiagCounts
    local function compute_diagnostics(node)
      local counts = { error = 0, warn = 0, hint = 0, info = 0 } ---@type era.m.explorer.view.IDiagCounts

      if node.nodetype == "F" then
        local filepath = self:__filepath_to_filepath__(node.filepath) ---@type string
        if filepath ~= "" then
          local bufnr = stl.nvim.buf.lookup_bufnr(loaded_bufnrs, filepath) ---@type integer|nil
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
        end
      elseif node.nodetype == "D" and node.expanded then
        for _, child in ipairs(node.children) do
          local child_counts = compute_diagnostics(child) ---@type era.m.explorer.view.IDiagCounts
          counts.error = counts.error + child_counts.error
          counts.warn = counts.warn + child_counts.warn
          counts.hint = counts.hint + child_counts.hint
          counts.info = counts.info + child_counts.info
        end
      end

      diag_counts[node.filepath] = counts
      return counts
    end

    if root.expanded then
      local root_counts = { error = 0, warn = 0, hint = 0, info = 0 } ---@type era.m.explorer.view.IDiagCounts
      for _, child in ipairs(root.children) do
        local child_counts = compute_diagnostics(child) ---@type era.m.explorer.view.IDiagCounts
        root_counts.error = root_counts.error + child_counts.error
        root_counts.warn = root_counts.warn + child_counts.warn
        root_counts.hint = root_counts.hint + child_counts.hint
        root_counts.info = root_counts.info + child_counts.info
      end
      diag_counts[root.filepath] = root_counts
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

  if ctx.show_icons then
    local icon, icon_hl = self:__get_node_icon__(node, is_ignored, is_expanded) ---@type string, string
    parts[#parts + 1] = icon
    parts[#parts + 1] = " "

    highlights[#highlights + 1] = {
      lnum = lnum,
      coll = col,
      colr = col + #icon + 1,
      hlname = icon_hl,
    }
    col = col + #icon + 1
  end

  local name = display_name or node.nodename ---@type string
  local name_hl = self:__get_node_name_highlight__(ctx, node, is_ignored, is_selected) ---@type string
  parts[#parts + 1] = name

  highlights[#highlights + 1] = {
    lnum = lnum,
    coll = col,
    colr = col + #name,
    hlname = name_hl,
  }

  local git_info ---@type era.m.explorer.view.IGitStatusInfo|nil
  if ctx.show_git_status then
    git_info = self:__get_git_status_info__(node, lnum)
  end

  local diag_info ---@type era.m.explorer.view.IDiagnosticInfo|nil
  if ctx.show_diagnostics then
    diag_info = self:__get_diagnostic_info__(ctx, node, lnum)
  end

  local line = table.concat(parts) ---@type string
  return line, highlights, git_info, diag_info
end

---@protected
---@param filepath                           string
---@return string
function M:__filepath_to_filepath__(filepath)
  if type(filepath) ~= "string" then
    return ""
  end

  local keep_trailing_slash = filepath:sub(-1) == "/" ---@type boolean
  return dot.path.normalize(filepath, keep_trailing_slash, "/")
end

return M
