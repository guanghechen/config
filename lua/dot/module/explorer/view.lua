local __module_name__ = "dot.module.explorer.view" ---@type string

---@class dot.module.explorer.view.IRenderContext
---@field public tree                   dot.module.explorer.Tree
---@field public root                   dot.module.explorer.Node
---@field public resource_manager       dot.module.explorer.resource.IManager|nil
---@field public tick_loaded            integer
---@field public foldempty              boolean
---@field public show_diagnostics       boolean
---@field public show_git_status        boolean
---@field public show_icons             boolean
---@field public diag_counts            table<string, dot.module.explorer.view.IDiagCounts>
---@field public select_mode            dot.module.explorer.SelectModeEnum

---@class dot.module.explorer.view.IDiagCounts
---@field public error                  integer
---@field public warn                   integer
---@field public hint                   integer
---@field public info                   integer

---@class dot.module.explorer.view.IGitStatusInfo
---@field public lnum                   integer
---@field public text                   string
---@field public highlights             ark.t.IHighlightInline[]

---@class dot.module.explorer.view.IDiagnosticInfo
---@field public lnum                   integer
---@field public text                   string
---@field public highlights             ark.t.IHighlightInline[]

---@class dot.module.explorer.view.ISignInfo
---@field public lnum                   integer
---@field public sign_text              string
---@field public sign_hl_group          string

---@class dot.module.explorer.view.IRenderResult
---@field public lines                  string[]
---@field public highlights             ark.t.IHighlight[]
---@field public diagnostic_info_list   dot.module.explorer.view.IDiagnosticInfo[]
---@field public git_status_list        dot.module.explorer.view.IGitStatusInfo[]
---@field public sign_info_list         dot.module.explorer.view.ISignInfo[]
---@field public lnum_to_uri            table<integer, string>
---@field public uri_to_lnum            table<string, integer>

---@class dot.module.explorer.view.IRenderOptions
---@field public resource_manager       ?dot.module.explorer.resource.IManager
---@field public foldempty              ?boolean
---@field public show_diagnostics       ?boolean
---@field public show_git_status        ?boolean
---@field public show_icons             ?boolean
---@field public select_mode            ?dot.module.explorer.SelectModeEnum

local INDENT_BRANCH = "├─" ---@type string
local INDENT_LAST = "╰─" ---@type string
local INDENT_PIPE = "│ " ---@type string
local INDENT_SPACE = "  " ---@type string

---@class dot.module.explorer.View
---@field protected _nsnr               integer
---@field protected _indent_hln         string
local M = {}
M.__index = M

---@param name                          string
---@return dot.module.explorer.View
function M.new(name)
  local fullname = string.format("%s@%s", __module_name__, name) ---@type string

  local self = setmetatable({}, M)
  self._nsnr = vim.api.nvim_create_namespace(fullname)
  self._indent_hln = "f_explorer_indent"
  return self
end

---@param bufnr                         integer
---@param tree                          dot.module.explorer.Tree
---@param root                          dot.module.explorer.Node
---@param options                       dot.module.explorer.view.IRenderOptions|nil
---@return dot.module.explorer.view.IRenderResult
function M:render(bufnr, tree, root, options)
  options = options or {} ---@type dot.module.explorer.view.IRenderOptions

  local diag_counts = {} ---@type table<string, dot.module.explorer.view.IDiagCounts>

  local tick_loaded = tree.state.tick_loaded ---@type integer

  ---@type dot.module.explorer.view.IRenderContext
  local ctx = {
    tree = tree,
    root = root,
    resource_manager = options.resource_manager,
    tick_loaded = tick_loaded,
    foldempty = options.foldempty ~= false,
    show_diagnostics = options.show_diagnostics ~= false,
    show_git_status = options.show_git_status ~= false,
    show_icons = options.show_icons ~= false,
    diag_counts = diag_counts,
    select_mode = options.select_mode or "select",
  }

  self:__precompute__(root, ctx)

  local lines = {} ---@type string[]
  local highlights = {} ---@type ark.t.IHighlight[]
  local diagnostic_info_list = {} ---@type dot.module.explorer.view.IDiagnosticInfo[]
  local git_status_list = {} ---@type dot.module.explorer.view.IGitStatusInfo[]
  local sign_info_list = {} ---@type dot.module.explorer.view.ISignInfo[]
  local lnum_to_uri = {} ---@type table<integer, string>
  local uri_to_lnum = {} ---@type table<string, integer>
  local lnum = 0 ---@type integer
  local indent_hln = self._indent_hln ---@type string

  ---@param node                        dot.module.explorer.Node
  ---@param prefix                      string
  ---@param is_last                     boolean
  ---@param display_name                string|nil
  ---@param rs_tick_expanded_max        integer
  ---@param rs_tick_selected_max        integer
  ---@return nil
  local function traverse(node, prefix, is_last, display_name, rs_tick_expanded_max, rs_tick_selected_max)
    lnum = lnum + 1
    local current_lnum = lnum ---@type integer

    local node_rs_tick_selected_max = math.max(rs_tick_selected_max, node.rs.tick_selected) ---@type integer
    local is_selected = node_rs_tick_selected_max % 2 == 1 ---@type boolean

    local node_rs_tick_expanded_max = math.max(rs_tick_expanded_max, node.rs.tick_expanded) ---@type integer
    local is_expanded = math.max(node_rs_tick_expanded_max, node.ns.tick_expanded) % 2 == 1 ---@type boolean

    local indent ---@type string
    if prefix == "" then
      indent = is_last and INDENT_LAST or INDENT_BRANCH
    else
      indent = prefix .. (is_last and INDENT_LAST or INDENT_BRANCH)
    end

    local line, line_highlights, git_info, diag_info = self:__render_node__(ctx, node, indent, current_lnum, display_name, is_expanded, is_selected)

    lines[current_lnum] = line
    lnum_to_uri[current_lnum] = node.uri
    uri_to_lnum[node.uri] = current_lnum

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
        sign_text = dot.icon.symbols.selection_cut
        sign_hl_group = "f_explorer_cut"
      elseif ctx.select_mode == "copy" then
        sign_text = dot.icon.symbols.selection_copy
        sign_hl_group = "f_explorer_copy"
      else
        sign_text = dot.icon.symbols.selection
        sign_hl_group = "f_explorer_selected"
      end
      sign_info_list[#sign_info_list + 1] = {
        lnum = current_lnum,
        sign_text = sign_text,
        sign_hl_group = sign_hl_group,
      }
    end

    if node.nodetype == "D" and is_expanded then
      if not node:is_loaded(ctx.tick_loaded) and ctx.resource_manager ~= nil then
        ctx.tree:load_node(node, ctx.resource_manager, false)
      end

      local children = node.children ---@type dot.module.explorer.Node[]
      local N = #children ---@type integer
      local child_prefix = prefix == "" and "" or (prefix .. (is_last and INDENT_SPACE or INDENT_PIPE)) ---@type string
      if prefix == "" then
        child_prefix = is_last and INDENT_SPACE or INDENT_PIPE
      end
      for i, child in ipairs(children) do
        local child_display_name = nil ---@type string|nil

        if ctx.foldempty and child.nodetype == "D" then
          local folded_node, folded_path = self:__fold_empty_dirs__(child, ctx)
          if folded_node ~= child then
            child = folded_node
            child_display_name = folded_path
          end
        end

        traverse(child, child_prefix, i == N, child_display_name, node_rs_tick_expanded_max, node_rs_tick_selected_max)
      end
    end
  end

  local root_rs_tick_expanded_max = root.rs.tick_expanded ---@type integer
  local root_rs_tick_selected_max = root.rs.tick_selected ---@type integer
  local root_is_expanded = math.max(root_rs_tick_expanded_max, root.ns.tick_expanded) % 2 == 1 ---@type boolean
  if root_is_expanded then
    if not root:is_loaded(ctx.tick_loaded) and ctx.resource_manager ~= nil then
      ctx.tree:load_node(root, ctx.resource_manager, false)
    end

    local children = root.children ---@type dot.module.explorer.Node[]
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

      traverse(child, "", i == N, child_display_name, root_rs_tick_expanded_max, root_rs_tick_selected_max)
    end
  end

  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].modifiable = false

  vim.api.nvim_buf_clear_namespace(bufnr, self._nsnr, 0, -1)
  for _, hl in ipairs(highlights) do
    vim.hl.range(bufnr, self._nsnr, hl.hlname, { hl.lnum - 1, hl.coll }, { hl.lnum - 1, hl.colr }, { priority = 10 })
  end

  local diag_by_lnum = {} ---@type table<integer, dot.module.explorer.view.IDiagnosticInfo>
  for _, diag_info in ipairs(diagnostic_info_list) do
    diag_by_lnum[diag_info.lnum] = diag_info
  end

  local git_by_lnum = {} ---@type table<integer, dot.module.explorer.view.IGitStatusInfo>
  for _, git_info in ipairs(git_status_list) do
    git_by_lnum[git_info.lnum] = git_info
  end

  local sign_by_lnum = {} ---@type table<integer, dot.module.explorer.view.ISignInfo>
  for _, sign_info in ipairs(sign_info_list) do
    sign_by_lnum[sign_info.lnum] = sign_info
  end

  local total_lines = #lines ---@type integer
  for lnum_key = 1, total_lines do
    local virt_text = {} ---@type string[][]

    local diag_info = diag_by_lnum[lnum_key] ---@type dot.module.explorer.view.IDiagnosticInfo|nil
    if diag_info ~= nil then
      local pos = 0 ---@type integer
      for _, hl in ipairs(diag_info.highlights) do
        local text = diag_info.text:sub(hl.coll - pos + 1, hl.colr - pos) ---@type string
        virt_text[#virt_text + 1] = { text, hl.hlname }
      end
    end

    local git_info = git_by_lnum[lnum_key] ---@type dot.module.explorer.view.IGitStatusInfo|nil
    if git_info ~= nil then
      local pos = 0 ---@type integer
      for _, hl in ipairs(git_info.highlights) do
        local text = git_info.text:sub(hl.coll - pos + 1, hl.colr - pos) ---@type string
        virt_text[#virt_text + 1] = { text, hl.hlname }
      end
    end

    local sign_info = sign_by_lnum[lnum_key] ---@type dot.module.explorer.view.ISignInfo|nil
    if sign_info ~= nil then
      virt_text[#virt_text + 1] = { " " .. sign_info.sign_text, sign_info.sign_hl_group }
    else
      virt_text[#virt_text + 1] = { "  " }
    end

    vim.api.nvim_buf_set_extmark(bufnr, self._nsnr, lnum_key - 1, 0, {
      virt_text = virt_text,
      virt_text_pos = "right_align",
      priority = 10,
    })
  end

  ---@type dot.module.explorer.view.IRenderResult
  return {
    lines = lines,
    highlights = highlights,
    diagnostic_info_list = diagnostic_info_list,
    git_status_list = git_status_list,
    sign_info_list = sign_info_list,
    lnum_to_uri = lnum_to_uri,
    uri_to_lnum = uri_to_lnum,
  }
end

---@return integer
function M:get_namespace()
  return self._nsnr
end

----------------------------------------------------------------------------------------------------

---@protected
---@param ctx                           dot.module.explorer.view.IRenderContext
---@param node                          dot.module.explorer.Node
---@param indent                        string
---@param lnum                          integer
---@param display_name                  string|nil
---@param is_expanded                   boolean
---@param is_selected                   boolean
---@return string
---@return ark.t.IHighlight[]
---@return dot.module.explorer.view.IGitStatusInfo|nil
---@return dot.module.explorer.view.IDiagnosticInfo|nil
function M:__render_node__(ctx, node, indent, lnum, display_name, is_expanded, is_selected)
  local parts = {} ---@type string[]
  local highlights = {} ---@type ark.t.IHighlight[]
  local col = 0 ---@type integer

  local is_ignored = self:__is_ignored__(node) ---@type boolean

  parts[#parts + 1] = indent
  col = col + #indent

  if ctx.show_icons then
    local icon, icon_hl = self:__get_node_icon__(ctx, node, is_ignored, is_expanded) ---@type string, string
    parts[#parts + 1] = icon
    parts[#parts + 1] = " "

    highlights[#highlights + 1] = {
      lnum = lnum,
      coll = col,
      colr = col + #icon,
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

  local git_info ---@type dot.module.explorer.view.IGitStatusInfo|nil
  if ctx.show_git_status then
    git_info = self:__get_git_status_info__(node, lnum)
  end

  local diag_info ---@type dot.module.explorer.view.IDiagnosticInfo|nil
  if ctx.show_diagnostics then
    diag_info = self:__get_diagnostic_info__(ctx, node, lnum)
  end

  local line = table.concat(parts) ---@type string
  return line, highlights, git_info, diag_info
end

---@protected
---@param ctx                           dot.module.explorer.view.IRenderContext
---@param node                          dot.module.explorer.Node
---@param is_ignored                    boolean
---@param is_expanded                   boolean
---@return string
---@return string
function M:__get_node_icon__(ctx, node, is_ignored, is_expanded)
  if node.nodetype == "D" then
    local icon, icon_hl ---@type string, string
    if is_expanded then
      local is_loaded = node:is_loaded(ctx.tick_loaded) ---@type boolean
      local is_empty = is_loaded and #node.children == 0 ---@type boolean
      if is_empty then
        icon = dot.icon.filetype.FolderEmptyOpen
        icon_hl = "f_ft_dirname"
      else
        icon = dot.icon.filetype.FolderOpen
        icon_hl = "f_ft_dirname"
      end
    else
      local dir_icon, dir_hl, is_fallback = dot.fileicon.get_directory_icon(node.nodename) ---@type string, string, boolean
      if not is_fallback then
        icon = dir_icon
        icon_hl = dir_hl
      else
        icon = dot.icon.filetype.Folder
        icon_hl = "f_ft_dirname"
      end
    end
    if is_ignored then
      icon_hl = "f_explorer_ignored"
    end
    return icon, icon_hl
  end

  local icon, icon_hl = dot.fileicon.get_file_icon(node.nodename) ---@type string, string
  if is_ignored then
    icon_hl = "f_explorer_ignored"
  end
  return icon, icon_hl
end

---@protected
---@param ctx                           dot.module.explorer.view.IRenderContext
---@param node                          dot.module.explorer.Node
---@param is_ignored                    boolean
---@param is_selected                   boolean
---@return string
function M:__get_node_name_highlight__(ctx, node, is_ignored, is_selected)
  if is_selected then
    return "f_explorer_selected"
  end

  if is_ignored then
    return "f_explorer_ignored"
  end

  local counts = ctx.diag_counts[node.uri] ---@type dot.module.explorer.view.IDiagCounts|nil
  if counts ~= nil then
    if counts.error > 0 then
      return "f_lsp_diagnostic_error"
    end
    if counts.warn > 0 then
      return "f_lsp_diagnostic_warn"
    end
  end

  if ctx.show_git_status then
    local filepath = self:__uri_to_filepath__(node.uri) ---@type string
    if filepath ~= "" then
      local filetype = node.nodetype == "D" and "directory" or "file" ---@type string
      local _, git_hl = dot.git.status.resolve(filepath, filetype)
      if git_hl ~= nil then
        return git_hl
      end
    end
  end

  if node.nodetype == "D" then
    return "f_ft_dirname"
  end

  return "f_ft_filename"
end

---@protected
---@param node                          dot.module.explorer.Node
---@param lnum                          integer
---@return dot.module.explorer.view.IGitStatusInfo|nil
function M:__get_git_status_info__(node, lnum)
  local filepath = self:__uri_to_filepath__(node.uri) ---@type string
  if filepath == "" then
    return nil
  end

  local filetype = node.nodetype == "D" and "directory" or "file" ---@type string
  local highlights = {} ---@type ark.t.IHighlightInline[]

  local git_text, _ = dot.git.status.calc_info(filepath, filetype, 0, highlights)

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
---@param ctx                           dot.module.explorer.view.IRenderContext
---@param node                          dot.module.explorer.Node
---@param lnum                          integer
---@return dot.module.explorer.view.IDiagnosticInfo|nil
function M:__get_diagnostic_info__(ctx, node, lnum)
  local counts = ctx.diag_counts[node.uri] ---@type dot.module.explorer.view.IDiagCounts|nil
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
  local highlights = {} ---@type ark.t.IHighlightInline[]
  local col = 0 ---@type integer
  local slots = 0 ---@type integer

  if count_error > 0 then
    local part = " " .. dot.icon.diagnostic.Error_alt .. " " .. count_error ---@type string
    text = text .. part
    highlights[#highlights + 1] = { coll = col, colr = col + #part, hlname = "f_lsp_diagnostic_error" }
    col = col + #part
    slots = slots + 1
  end

  if count_warn > 0 then
    local part = " " .. dot.icon.diagnostic.Warning_alt .. " " .. count_warn ---@type string
    text = text .. part
    highlights[#highlights + 1] = { coll = col, colr = col + #part, hlname = "f_lsp_diagnostic_warn" }
    col = col + #part
    slots = slots + 1
  end

  if count_hint > 0 and slots < 2 then
    local part = " " .. dot.icon.diagnostic.Hint_alt .. " " .. count_hint ---@type string
    text = text .. part
    highlights[#highlights + 1] = { coll = col, colr = col + #part, hlname = "f_lsp_diagnostic_hint" }
    col = col + #part
    slots = slots + 1
  end

  if count_info > 0 and slots < 2 then
    local part = " " .. dot.icon.diagnostic.Information_alt .. " " .. count_info ---@type string
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
---@param uri                           string
---@return string
function M:__uri_to_filepath__(uri)
  local prefix = "file://" ---@type string
  if not vim.startswith(uri, prefix) then
    return ""
  end

  local filepath = uri:sub(#prefix + 1) ---@type string
  if filepath:sub(-1) == "/" and #filepath > 1 then
    filepath = filepath:sub(1, -2)
  end

  return filepath
end

---@protected
---@param node                          dot.module.explorer.Node
---@return boolean
function M:__is_ignored__(node)
  local filepath = self:__uri_to_filepath__(node.uri) ---@type string
  if filepath == "" then
    return false
  end
  return dot.git.state.is_ignored(filepath)
end

---@protected
---@param root                          dot.module.explorer.Node
---@param ctx                           dot.module.explorer.view.IRenderContext
---@return nil
function M:__precompute__(root, ctx)
  local filepaths = {} ---@type string[]
  local diag_counts = ctx.diag_counts ---@type table<string, dot.module.explorer.view.IDiagCounts>
  local show_diagnostics = ctx.show_diagnostics ---@type boolean
  local bufnr_counts = {} ---@type table<integer, dot.module.explorer.view.IDiagCounts>

  ---@param node                        dot.module.explorer.Node
  ---@return dot.module.explorer.view.IDiagCounts
  local function traverse(node)
    local filepath = self:__uri_to_filepath__(node.uri) ---@type string
    if filepath ~= "" then
      filepaths[#filepaths + 1] = filepath
    end

    local counts = { error = 0, warn = 0, hint = 0, info = 0 } ---@type dot.module.explorer.view.IDiagCounts

    if node.nodetype == "F" then
      if show_diagnostics and filepath ~= "" then
        local bufnr = vim.fn.bufnr(filepath) ---@type integer
        if bufnr >= 0 then
          local cached = bufnr_counts[bufnr] ---@type dot.module.explorer.view.IDiagCounts|nil
          if cached ~= nil then
            counts = cached
          else
            local diagnostics = vim.diagnostic.get(bufnr) ---@type vim.Diagnostic[]
            for _, diag in ipairs(diagnostics) do
              local severity = diag.severity ---@type vim.diagnostic.Severity
              if severity == vim.diagnostic.severity.ERROR then
                counts.error = counts.error + 1
              elseif severity == vim.diagnostic.severity.WARN then
                counts.warn = counts.warn + 1
              elseif severity == vim.diagnostic.severity.HINT then
                counts.hint = counts.hint + 1
              elseif severity == vim.diagnostic.severity.INFO then
                counts.info = counts.info + 1
              end
            end
            bufnr_counts[bufnr] = counts
          end
        end
      end
    elseif node.nodetype == "D" and node:is_expanded() then
      if not node:is_loaded(ctx.tick_loaded) and ctx.resource_manager ~= nil then
        ctx.tree:load_node(node, ctx.resource_manager, false)
      end
      for _, child in ipairs(node.children) do
        local child_counts = traverse(child) ---@type dot.module.explorer.view.IDiagCounts
        counts.error = counts.error + child_counts.error
        counts.warn = counts.warn + child_counts.warn
        counts.hint = counts.hint + child_counts.hint
        counts.info = counts.info + child_counts.info
      end
    end

    if show_diagnostics then
      diag_counts[node.uri] = counts
    end
    return counts
  end

  if root:is_expanded() then
    if not root:is_loaded(ctx.tick_loaded) and ctx.resource_manager ~= nil then
      ctx.tree:load_node(root, ctx.resource_manager, false)
    end
    local root_counts = { error = 0, warn = 0, hint = 0, info = 0 } ---@type dot.module.explorer.view.IDiagCounts
    for _, child in ipairs(root.children) do
      local child_counts = traverse(child) ---@type dot.module.explorer.view.IDiagCounts
      root_counts.error = root_counts.error + child_counts.error
      root_counts.warn = root_counts.warn + child_counts.warn
      root_counts.hint = root_counts.hint + child_counts.hint
      root_counts.info = root_counts.info + child_counts.info
    end
    if show_diagnostics then
      diag_counts[root.uri] = root_counts
    end
  end

  if #filepaths > 0 then
    dot.git.state.preload_ignored(filepaths)
  end
end

---@protected
---@param node                          dot.module.explorer.Node
---@param ctx                           dot.module.explorer.view.IRenderContext
---@return dot.module.explorer.Node
---@return string
function M:__fold_empty_dirs__(node, ctx)
  local path_parts = { node.nodename } ---@type string[]
  local current = node ---@type dot.module.explorer.Node

  while true do
    if not current:is_expanded() then
      break
    end

    if not current:is_loaded(ctx.tick_loaded) and ctx.resource_manager ~= nil then
      ctx.tree:load_node(current, ctx.resource_manager, false)
    end

    local children = current.children ---@type dot.module.explorer.Node[]
    if #children ~= 1 then
      break
    end

    local child = children[1] ---@type dot.module.explorer.Node
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

return M
