---@diagnostic disable: invisible
local __module_name__ = "eve.ux.picker-file" ---@type string

---@alias eve.ux.picker_file.NodetypeEnum
---| "directory"
---| "file"

---@alias eve.ux.picker_file.IOnDispose
---| fun(): nil

---@alias eve.ux.picker_file.IOnFocus
---| fun(self: eve.ux.FilePicker): nil

---@alias eve.ux.picker_file.IOnHide
---| fun(self: eve.ux.FilePicker): nil

---@class eve.ux.file_picker.ITreeNodeData
---@field public uuid                   string
---@field public basename               string
---@field public filepath               string
---@field public nodetype               eve.ux.picker_file.NodetypeEnum

---@type eve.ux.view.treeview.INodeRenderer
local default_treeview_node_renderer = function(treeview, node, folded_depth)
  local data = node.data ---@type eve.ux.file_picker.ITreeNodeData
  local icon, icon_hln ---@type string, string

  if data.nodetype == "directory" then
    icon, icon_hln = eve.fn.diricon(data.basename)
    if not node.collapsed then
      if #node.children < 1 then
        icon = eve.icon.filetype.FolderEmptyOpen
      else
        icon = eve.icon.filetype.FolderOpen
      end
    end
  else
    icon, icon_hln = eve.fn.fileicon(data.basename)
  end

  local text ---@type string
  local highlights = { { coll = 0, colr = #icon + 1, hlname = icon_hln } } ---@type eve.t.IHighlightInline[]

  if folded_depth < 1 then
    text = string.format("%s %s", icon, data.basename) ---@type string
    local hln_basename = data.nodetype == "directory" and "f_utw_dirname" or "f_utw_filename" ---@type string
    highlights[#highlights + 1] = { coll = #icon + 1, colr = #text, hlname = hln_basename }
  else
    local basenames = {} ---@type string[]
    basenames[folded_depth + 1] = data.basename ---@type string
    for index = folded_depth, 1, -1 do
      local parent_uuid = node.parent ---@type string
      local parent = treeview:retrieve_by_uuid(parent_uuid) ---@type eve.ux.view.treeview.INode|nil
      ---@cast parent eve.ux.view.treeview.INode

      local parent_data = parent.data ---@type eve.ux.file_picker.ITreeNodeData
      basenames[index] = parent_data.basename ---@type string
    end

    text = string.format("%s %s", icon, basenames[1]) ---@type string
    highlights[#highlights + 1] = { coll = #icon + 1, colr = #text, hlname = "f_utw_dirname" }

    for index = 2, #basenames, 1 do
      local basename = basenames[index] ---@type string
      local offset = #text ---@type integer
      text = text .. string.format("/%s", basename)
      highlights[#highlights + 1] = { coll = offset + 1, colr = offset + 2, hlname = "f_utw_pathsep" }
      highlights[#highlights + 1] = { coll = offset + 2, colr = #text, hlname = "f_utw_dirname" }
    end
  end

  return { text = text, highlights = highlights }
end

---@type eve.ux.view.treeview.INodeSorter
local default_treeview_node_sorter = function(left, right)
  if left.leaf ~= right.leaf then
    return right.leaf
  end
  return left.data.basename < right.data.basename
end

----------------------------------------------------------------------------------------------------

---@class eve.ux.IFilePickerProps
---@field public uuid                   ?string
---@field public name                   string
---@field public permanent              boolean
---@field public title                  string
---
---@field public foldempty              ?boolean
---@field public node_renderer          ?eve.ux.view.treeview.INodeRenderer
---@field public node_sorter            ?eve.ux.view.treeview.INodeSorter
---
---@field public flag_fuzzy             eve.std.collection.IObservable
---@field public flag_regex             eve.std.collection.IObservable
---@field public flag_sensitive         eve.std.collection.IObservable
---@field public flags_append           eve.ux.picker.IFlagItem[]|nil
---@field public flags_prepend          eve.ux.picker.IFlagItem[]|nil
---@field public flags_start_index      ?0|1
---
---@field public finder_input           eve.std.collection.IObservable
---@field public finder_multiline       ?boolean
---
---@field public on_dispose             eve.ux.picker_file.IOnDispose|nil
---@field public on_focus               eve.ux.picker_file.IOnFocus|nil
---@field public on_hide                eve.ux.picker_file.IOnHide|nil

---@class eve.ux.FilePicker
---@field public uuid                   ?string
---@field public name                   string
---@field public title                  string
---
---@field public flag_fuzzy             eve.std.collection.IObservable
---@field public flag_regex             eve.std.collection.IObservable
---@field public flag_sensitive         eve.std.collection.IObservable
---
---@field protected _disposed           boolean
---@field protected _picker             eve.ux.Picker
---@field protected _plainfile          eve.ux.view.Plainfile
---@field protected _treeview           eve.ux.view.Treeview
---@field protected _root_uuid          string|nil
---
---@field protected _on_dispose         eve.ux.picker_file.IOnDispose
---@field protected _on_focus           eve.ux.picker_file.IOnFocus
---@field protected _on_hide            eve.ux.picker_file.IOnHide
local M = {}
M.__index = M

---@param props                         eve.ux.IFilePickerProps
---@return eve.ux.FilePicker
function M.new(props)
  local name = props.name ---@type string
  local uuid = props.uuid or eve.oxi.uuid() ---@type string
  local permanent = props.permanent ---@type boolean
  local title = props.title ---@type string
  local foldempty = props.foldempty ---@type boolean|nil
  local node_renderer = props.node_renderer or default_treeview_node_renderer ---@type eve.ux.view.treeview.INodeRenderer
  local node_sorter = props.node_sorter or default_treeview_node_sorter ---@type eve.ux.view.treeview.INodeSorter

  local finder_input = props.finder_input ---@type eve.std.collection.IObservable
  local finder_multiline = props.finder_multiline ---@type boolean|nil

  local on_dispose = props.on_dispose or eve.std.fn.noop ---@type eve.ux.picker_file.IOnDispose
  local on_focus = props.on_focus or eve.std.fn.noop ---@type eve.ux.picker_file.IOnFocus
  local on_hide = props.on_hide or eve.std.fn.noop ---@type eve.ux.picker_file.IOnHide

  local self = setmetatable({}, M)

  ---@type eve.ux.view.Plainfile
  local plainfile = eve.ux.view.Plainfile.new({
    name = name,
  })

  ---@type eve.ux.view.Treeview
  local treeview = eve.ux.view.Treeview.new({
    name = name,
    foldempty = foldempty,
    indent = "",
    indent_hln = "f_utw_indent_float",
    node_renderer = node_renderer,
    node_sorter = node_sorter,
  })

  local flag_fuzzy = props.flag_fuzzy ---@type eve.std.collection.IObservable
  local flag_regex = props.flag_regex ---@type eve.std.collection.IObservable
  local flag_sensitive = props.flag_sensitive ---@type eve.std.collection.IObservable
  local flags_append = props.flags_append ---@type eve.ux.picker.IFlagItem[]|nil
  local flags_prepend = props.flags_prepend ---@type eve.ux.picker.IFlagItem[]|nil
  local flags_start_index = props.flags_start_index ---@type 0|1|nil

  local flags = {} ---@type eve.ux.picker.IFlagItem[]
  if flags_prepend ~= nil then
    for _, flag in ipairs(flags_prepend) do
      flags[#flags + 1] = {
        type = flag.type,
        desc = string.format("%s: %s", name, flag.desc),
        callback = flag.callback,
        snapshot = flag.snapshot,
      }
    end
  end
  flags[#flags + 1] = {
    type = "boolean",
    desc = string.format("%s: fuzzy", name),
    callback = function()
      local enabled = flag_fuzzy:snapshot() ---@type boolean
      flag_fuzzy:next(not enabled)
    end,
    snapshot = function()
      local enabled = flag_fuzzy:snapshot() ---@type boolean
      return enabled, eve.icon.symbols.flag_fuzzy
    end,
  }
  flags[#flags + 1] = {
    type = "boolean",
    desc = string.format("%s: sensitive", name),
    callback = function()
      local enabled = flag_sensitive:snapshot() ---@type boolean
      flag_sensitive:next(not enabled)
    end,
    snapshot = function()
      local enabled = flag_sensitive:snapshot() ---@type boolean
      return enabled, eve.icon.symbols.flag_case_sensitive
    end,
  }
  flags[#flags + 1] = {
    type = "boolean",
    desc = string.format("%s: fold empty path", name),
    callback = function(picker)
      local enabled = treeview:isfoldempty() ---@type boolean
      treeview:set_foldempty(not enabled)
      picker:mark_result_dirty()
    end,
    snapshot = function()
      local enabled = treeview:isfoldempty() ---@type boolean
      return enabled, eve.icon.symbols.flag_fold_empty_path
    end,
  }
  if flags_append ~= nil then
    for _, flag in ipairs(flags_append) do
      flags[#flags + 1] = {
        type = flag.type,
        desc = string.format("%s: %s", name, flag.desc),
        callback = flag.callback,
        snapshot = flag.snapshot,
      }
    end
  end

  ---@type eve.ux.picker.IKeymap[]
  local finder_keymaps = {
    {
      modes = { "i", "n", "v" },
      key = "<C-l>",
      desc = "filetree: open",
      callback = function(picker)
        local lnum = picker:get_result_lnum() ---@type integer
        local node = treeview:retrieve_by_lnum(lnum, false) ---@type eve.ux.view.treeview.INode|nil
        if node == nil then
          return
        end

        local data = node.data ---@type eve.ux.file_picker.ITreeNodeData
        if data.nodetype == "directory" then
          treeview:collapse(node.uuid, "expanded", false)
          picker:mark_result_dirty()
        else
          local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
          local winnr_sourcefile = eve.tab.retrieve_winnr_sourcefile(tabnr) ---@type integer|nil
          if winnr_sourcefile ~= nil and vim.api.nvim_win_is_valid(winnr_sourcefile) then
            vim.api.nvim_tabpage_set_win(tabnr, winnr_sourcefile)
          end

          picker:close()
          local filepath = data.filepath ---@type string
          eve.win.open_filepath(winnr_sourcefile, filepath)
        end
      end,
    },
    {
      modes = { "i", "n", "v" },
      key = "<C-h>",
      desc = "filetree: close",
      callback = function(picker)
        local lnum = picker:get_result_lnum() ---@type integer
        local node = treeview:retrieve_by_lnum(lnum, false) ---@type eve.ux.view.treeview.INode|nil
        if node == nil then
          return
        end

        local data = node.data ---@type eve.ux.file_picker.ITreeNodeData
        if data.nodetype == "directory" and not node.collapsed then
          treeview:collapse(node.uuid, "collapsed", false)
          picker:mark_result_dirty()
        else
          local lnum_parent = treeview:retrieve_lnum(node.parent) ---@type integer|nil
          treeview:collapse(node.parent, "collapsed", false)
          picker:mark_result_dirty()
          if lnum_parent ~= nil then
            picker:set_result_lnum(lnum_parent)
          end
        end
      end,
    },
  }

  ---@type eve.ux.picker.IKeymap[]
  local result_keymaps = {
    {
      modes = { "n" },
      key = "z",
      desc = "filetree: toggle collapsed (recursively)",
      callback = function(picker)
        local lnum = picker:get_result_lnum() ---@type integer
        local node = treeview:retrieve_by_lnum(lnum, true) ---@type eve.ux.view.treeview.INode|nil
        if node == nil then
          return
        end

        local data = node.data ---@type eve.ux.file_picker.ITreeNodeData
        if data.nodetype == "directory" then
          treeview:collapse(node.uuid, "toggle", true)
          picker:mark_result_dirty()
        else
          local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
          local winnr_sourcefile = eve.tab.retrieve_winnr_sourcefile(tabnr) ---@type integer|nil
          if winnr_sourcefile ~= nil and vim.api.nvim_win_is_valid(winnr_sourcefile) then
            vim.api.nvim_tabpage_set_win(tabnr, winnr_sourcefile)
          end

          picker:close()
          local filepath = data.filepath ---@type string
          eve.win.open_filepath(winnr_sourcefile, filepath)
        end
      end,
    },
    {
      modes = { "n" },
      key = "<2-LeftMouse>",
      desc = "filetree: toggle",
      callback = function(picker)
        local result_winnr = picker:get_result_winnr() ---@type integer|nil
        if result_winnr == nil then
          return
        end

        local cursor = vim.fn.getmousepos()
        if cursor.winid == result_winnr then
          local lnum = cursor.line ---@type integer
          local node = treeview:retrieve_by_lnum(lnum, true) ---@type eve.ux.view.treeview.INode|nil
          if node == nil then
            return
          end

          local data = node.data ---@type eve.ux.file_picker.ITreeNodeData
          if data.nodetype == "directory" then
            treeview:collapse(node.uuid, "toggle", false)
            picker:mark_result_dirty()
          else
            local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
            local winnr_sourcefile = eve.tab.retrieve_winnr_sourcefile(tabnr) ---@type integer|nil
            if winnr_sourcefile ~= nil and vim.api.nvim_win_is_valid(winnr_sourcefile) then
              vim.api.nvim_tabpage_set_win(tabnr, winnr_sourcefile)
            end

            picker:close()
            local filepath = data.filepath ---@type string
            eve.win.open_filepath(winnr_sourcefile, filepath)
          end
        end
      end,
    },
    {
      modes = { "i", "n", "v" },
      key = "<CR>",
      aliases = { "<Right>", "l", "o" },
      desc = "filetree: open",
      callback = function(picker)
        local lnum = picker:get_result_lnum() ---@type integer
        local node = treeview:retrieve_by_lnum(lnum, false) ---@type eve.ux.view.treeview.INode|nil
        if node == nil then
          return
        end

        local data = node.data ---@type eve.ux.file_picker.ITreeNodeData
        if data.nodetype == "directory" then
          treeview:collapse(node.uuid, "expanded", false)
          picker:mark_result_dirty()
        else
          local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
          local winnr_sourcefile = eve.tab.retrieve_winnr_sourcefile(tabnr) ---@type integer|nil
          if winnr_sourcefile ~= nil and vim.api.nvim_win_is_valid(winnr_sourcefile) then
            vim.api.nvim_tabpage_set_win(tabnr, winnr_sourcefile)
          end

          picker:close()
          local filepath = data.filepath ---@type string
          eve.win.open_filepath(winnr_sourcefile, filepath)
        end
      end,
    },
    {
      modes = { "i", "n", "v" },
      key = "<Backspace>",
      aliases = { "<Left>", "h", "c" },
      desc = "filetree: close",
      callback = function(picker)
        local lnum = picker:get_result_lnum() ---@type integer
        local node = treeview:retrieve_by_lnum(lnum, false) ---@type eve.ux.view.treeview.INode|nil
        if node == nil then
          return
        end

        local data = node.data ---@type eve.ux.file_picker.ITreeNodeData
        if data.nodetype == "directory" and not node.collapsed then
          treeview:collapse(node.uuid, "collapsed", false)
          picker:mark_result_dirty()
        else
          local lnum_parent = treeview:retrieve_lnum(node.parent) ---@type integer|nil
          treeview:collapse(node.parent, "collapsed", false)
          picker:mark_result_dirty()
          if lnum_parent ~= nil then
            picker:set_result_lnum(lnum_parent)
          end
        end
      end,
    },
  }

  local picker = eve.ux.Picker.new({
    uuid = uuid,
    name = name,
    permanent = permanent,
    flags = flags,
    flags_start_index = flags_start_index,

    finder_title = title,
    finder_keymaps = finder_keymaps,
    finder_input = finder_input,
    finder_multiline = finder_multiline,

    result_keymaps = result_keymaps,

    on_disposed = function()
      self:dispose()
    end,
    on_focused = function()
      on_focus(self)
    end,
    on_hidden = function()
      on_hide(self)
    end,
    result_render = function(_, bufnr)
      treeview:render(bufnr, self._root_uuid)
    end,
    preview_render = function(picker, bufnr)
      local lnum = picker:get_result_lnum() ---@type integer
      local node = treeview:retrieve_by_lnum(lnum, true) ---@type eve.ux.view.treeview.INode|nil
      if node == nil then
        ---@type string[]
        local lines = {
          string.format("Error: cannot retrieve node by the given lnum: %d", lnum),
        }
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
        return string.format("Unknown lnum(%d)", lnum)
      end

      local data = node.data ---@type eve.ux.file_picker.ITreeNodeData
      if data.nodetype == "directory" then
        ---@type string[]
        local lines = {
          string.format("Directory: %s", data.filepath),
        }
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
        return data.filepath
      end

      plainfile:render(bufnr, data.filepath, false)
      return data.filepath
    end,
  })

  self.uuid = uuid
  self.name = name

  self.flag_fuzzy = flag_fuzzy
  self.flag_regex = flag_regex
  self.flag_sensitive = flag_sensitive

  self._disposed = false
  self._picker = picker
  self._treeview = treeview
  self._root_uuid = nil

  self._on_dispose = on_dispose
  self._on_focus = on_focus
  self._on_hide = on_hide

  finder_input:subscribe(eve.std.Subscriber.new({
    on_next = function(input)
      self:mark_result_dirty()
    end,
  }))

  return self
end

---@return nil
function M:dispose()
  if self._disposed then
    return
  end
  self._disposed = true

  local on_dispose = self._on_dispose ---@type eve.ux.picker.IOnDisposed
  self._plainfile:dispose()
  self._treeview:dispose()
  self._picker:dispose()

  self.flag_fuzzy = nil
  self.flag_regex = nil
  self.flag_sensitive = nil

  self._plainfile = nil
  self._treeview = nil
  self._picker = nil
  self._root_uuid = nil

  vim.schedule(function()
    pcall(on_dispose)
  end)
end

---@return boolean
function M:isdisposed()
  return self._disposed
end

---@return boolean
function M:isfocused()
  return self._picker:isfocused()
end

---@return boolean
function M:isvisible()
  return self._picker:isvisible()
end

---@return nil
function M:close()
  self._picker:close()
end

---@return nil
function M:focus()
  self._picker:focus()
end

---@return nil
function M:hide()
  self._picker:hide()
end

---@return nil
function M:resize()
  self._picker:resize()
end

----------------------------------------------------------------------------------------------------

---@return nil
function M:mark_result_dirty()
  self:__health__()
  self._picker:mark_result_dirty()
  return self
end

---@return nil
function M:mark_result_flags_dirty()
  self:__health__()
  self._picker:mark_result_flags_dirty()
  return self
end

---@param filepaths                 string[]
---@return eve.ux.FilePicker
function M:reset_filepaths(filepaths)
  self:__health__()
  local treeview = self._treeview ---@type eve.ux.view.Treeview
  treeview:clear()

  ---@type eve.ux.file_picker.ITreeNodeData
  local root = {
    uuid = "uuid:",
    basename = "",
    filepath = "",
    nodetype = "directory",
  }
  treeview:insert(root.uuid, root.uuid, root, false, false)

  local cwd = eve.path.cwd() ---@type string
  local cwd_with_slash = cwd .. eve.env.PATH_SEP ---@type string
  local cwd_length = #cwd_with_slash ---@type integer
  local cwd_uuid ---@type string
  do
    local pieces = eve.path.split(cwd) ---@type string[]
    local N = #pieces ---@type integer

    local filepath = root.filepath ---@type string
    local uuid = root.uuid ---@type string
    local uuid_parent = root.uuid ---@type string
    local start_index = eve.env.IS_WIN and 1 or 2 ---@type integer
    for index = start_index, N, 1 do
      local basename = pieces[index] ---@type string
      filepath = index == 1 and basename or (filepath .. eve.env.PATH_SEP .. basename) ---@type string
      uuid = uuid .. "/" .. basename ---@type string

      ---@type eve.ux.file_picker.ITreeNodeData
      local data = {
        uuid = uuid,
        basename = basename,
        filepath = filepath,
        nodetype = "directory",
      }
      treeview:insert(uuid, uuid_parent, data, false, false)
      uuid_parent = uuid
    end
    cwd_uuid = uuid
  end

  local absolute_filepaths = {} ---@type string[]
  for _, p in ipairs(filepaths) do
    if eve.path.is_absolute(p) then
      if p:sub(1, cwd_length) ~= cwd_with_slash then
        absolute_filepaths[#absolute_filepaths + 1] = p
        goto continue
      end
      p = p:sub(cwd_length + 1) ---@type string
    end

    local pieces = eve.path.split(p) ---@type string[]
    local N = #pieces ---@type integer

    local filepath = cwd ---@type string
    local uuid = cwd_uuid ---@type string
    local uuid_parent = cwd_uuid ---@type string
    for index = 1, N, 1 do
      local basename = pieces[index] ---@type string
      local nodetype = index == N and "file" or "directory" ---@type eve.ux.picker_file.NodetypeEnum
      filepath = filepath .. eve.env.PATH_SEP .. basename ---@type string
      uuid = uuid .. "/" .. basename ---@type string

      ---@type eve.ux.file_picker.ITreeNodeData
      local data = {
        uuid = uuid,
        basename = basename,
        filepath = filepath,
        nodetype = nodetype,
      }
      treeview:insert(uuid, uuid_parent, data, index == N, false)
      uuid_parent = uuid ---@type string
    end
    ::continue::
  end

  for _, p in ipairs(absolute_filepaths) do
    local pieces = eve.path.split(p) ---@type string[]
    local N = #pieces ---@type integer

    local filepath = root.filepath ---@type string
    local uuid = root.uuid ---@type string
    local uuid_parent = root.uuid ---@type string
    local start_index = eve.env.IS_WIN and 1 or 2 ---@type integer
    for index = start_index, N, 1 do
      local basename = pieces[index] ---@type string
      local nodetype = index == N and "file" or "directory" ---@type eve.ux.picker_file.NodetypeEnum
      filepath = index == 1 and basename or (filepath .. eve.env.PATH_SEP .. basename) ---@type string
      uuid = uuid .. "/" .. basename ---@type string

      ---@type eve.ux.file_picker.ITreeNodeData
      local data = {
        uuid = uuid,
        basename = basename,
        filepath = filepath,
        nodetype = nodetype,
      }
      treeview:insert(uuid, uuid_parent, data, index == N, false)
      uuid_parent = uuid
    end
    cwd_uuid = uuid
  end

  self._root_uuid = cwd_uuid
  return self
end

----------------------------------------------------------------------------------------------------

---@protected
---@param input                         string
---@param old_matches                   eve.t.IScoredMatch[]
---@return eve.t.IScoredMatch[]
function M:find_matched_items(input, old_matches)
  local flag_sensitive = self.flag_sensitive:snapshot() ---@type boolean
  local flag_fuzzy = self.flag_fuzzy:snapshot() ---@type boolean
  local flag_regex = self.flag_regex:snapshot() ---@type boolean
  local item_map = {} --self._item_map ---@type table<string, eve.ux.select.IItem>

  local lines = {} ---@type string[]
  if flag_sensitive then
    for _, match in ipairs(old_matches) do
      local uuid = match.uuid ---@type string
      local text = item_map[uuid].text ---@type string
      table.insert(lines, text)
    end
  else
    input = input:lower()
    for _, match in ipairs(old_matches) do
      local uuid = match.uuid ---@type string
      local item = item_map[uuid] ---@type eve.ux.select.IItem|nil
      if item ~= nil then
        item.text_lower = item.text_lower or item.text:lower()
        table.insert(lines, item.text_lower)
      end
    end
  end

  ---@type eve.builtin.oxi.string.ILineMatch[]|nil
  local oxi_matches = eve.oxi.find_match_points_line_by_line(input, lines, flag_fuzzy, flag_regex)
  if oxi_matches == nil then
    return old_matches
  end

  local matches = {} ---@type eve.t.IScoredMatch[]
  for _, oxi_match in ipairs(oxi_matches) do
    local old_match = old_matches[oxi_match.lnum] ---@type eve.t.IScoredMatch

    ---@type eve.t.IScoredMatch
    local match = {
      order = old_match.order,
      uuid = old_match.uuid,
      score = oxi_match.score,
      matches = oxi_match.matches,
    }
    table.insert(matches, match)
  end
  return matches
end

---@protected
---@return nil
function M:__health__()
  if self._disposed then
    local message = string.format("[%s#%s] already been disposed.", __module_name__, self.name) ---@type string
    error(message)
  end
end

return M
