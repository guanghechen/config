---@diagnostic disable: invisible
local __module_name__ = "eve.ux.picker-file" ---@type string

---@alias eve.ux.picker_file.NodetypeEnum
---| "directory"
---| "file"

---@alias eve.ux.picker_file.IOnClosed
---| fun(self: eve.ux.FilePicker): nil

---@alias eve.ux.picker_file.IOnDisposed
---| fun(): nil

---@alias eve.ux.picker_file.IOnFocused
---| fun(self: eve.ux.FilePicker): nil

---@alias eve.ux.picker_file.IOnHidden
---| fun(self: eve.ux.FilePicker): nil
---
---@alias eve.ux.picker_file.IOnRefresh
---| fun(self: eve.ux.FilePicker, force: boolean): nil

---@class eve.ux.file_picker.ITreeNodeData
---@field public uuid                   string
---@field public basename               string
---@field public filepath               string
---@field public filepath_lower         string
---@field public nodetype               eve.ux.picker_file.NodetypeEnum

---@type eve.ux.view.treeview.INodeRenderer
local default_treeview_node_renderer = function(treeview, node, _, folded_depth)
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

    local o = node
    for index = folded_depth, 1, -1 do
      local parent_uuid = o.parent ---@type string
      local parent = treeview:retrieve_by_uuid(parent_uuid) ---@type eve.ux.view.treeview.INode|nil
      ---@cast parent eve.ux.view.treeview.INode

      local parent_data = parent.data ---@type eve.ux.file_picker.ITreeNodeData
      basenames[index] = parent_data.basename ---@type string
      o = parent
    end

    text = string.format("%s %s", icon, basenames[1]) ---@type string
    highlights[#highlights + 1] = { coll = #icon + 1, colr = #text, hlname = "f_utw_dirname" }

    for index = 2, #basenames, 1 do
      local basename = basenames[index] ---@type string
      local offset = #text ---@type integer
      text = text .. string.format("/%s", basename)
      highlights[#highlights + 1] = { coll = offset, colr = offset + 1, hlname = "f_utw_pathsep" }
      highlights[#highlights + 1] = { coll = offset + 1, colr = #text, hlname = "f_utw_dirname" }
    end
  end

  return { text = text, highlights = highlights }
end

---@type eve.ux.view.treeview.INodeFlatRenderer
local default_treeview_node_flat_renderer = function(_, node, root)
  local data = node.data ---@type eve.ux.file_picker.ITreeNodeData
  local icon, icon_hln = eve.fn.fileicon(data.basename) ---@type string, string

  local filepath = #root.data.filepath < 2 and data.filepath or data.filepath:sub(#root.data.filepath + 2) ---@type string
  local text = string.format("%s %s", icon, filepath) ---@type string
  local highlights = { { coll = 0, colr = #icon + 1, hlname = icon_hln } } ---@type eve.t.IHighlightInline[]

  ---@type eve.ux.view.treeview.INodeRenderResult
  local result = { text = text, highlights = highlights }
  return result
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
---@field public preview                ?boolean
---@field public title                  string
---@field public height                 ?number
---@field public width                  ?number
---
---@field public foldempty              ?boolean
---@field public node_flat_renderer     ?eve.ux.view.treeview.INodeFlatRenderer
---@field public node_renderer          ?eve.ux.view.treeview.INodeRenderer
---@field public node_sorter            ?eve.ux.view.treeview.INodeSorter
---
---@field public flag_fuzzy             eve.std.collection.IObservable
---@field public flag_regex             eve.std.collection.IObservable
---@field public flag_sensitive         eve.std.collection.IObservable
---@field public flag_viewtype          eve.std.collection.IObservable
---@field public flags_append           eve.ux.picker.IFlagItem[]|nil
---@field public flags_prepend          eve.ux.picker.IFlagItem[]|nil
---@field public flags_start_index      ?0|1
---
---@field public finder_input           eve.std.collection.IObservable
---@field public finder_multiline       ?boolean
---
---@field public on_closed              ?eve.ux.picker_file.IOnClosed
---@field public on_disposed            ?eve.ux.picker_file.IOnDisposed
---@field public on_focused             ?eve.ux.picker_file.IOnFocused
---@field public on_hidden              ?eve.ux.picker_file.IOnHidden
---@field public on_refresh             ?eve.ux.picker_file.IOnRefresh

---@class eve.ux.FilePicker
---@field public uuid                   ?string
---@field public name                   string
---@field public title                  string
---
---@field public flag_fuzzy             eve.std.collection.IObservable
---@field public flag_regex             eve.std.collection.IObservable
---@field public flag_sensitive         eve.std.collection.IObservable
---@field public flag_viewtype          eve.std.collection.IObservable
---
---@field protected _disposed           boolean
---@field protected _picker             eve.ux.Picker
---@field protected _plainfile          eve.ux.view.Plainfile
---@field protected _retriever          eve.std.collection.BufRetriever
---@field protected _scheduler_match    eve.std.collection.Scheduler|nil
---@field protected _treeview           eve.ux.view.Treeview
---
---@field protected _last_input         string
---@field protected _last_matches       eve.t.IScoredMatch[]|nil
---@field protected _last_matched_uuids table<string, boolean>|nil
---@field protected _uuid_root          string|nil
---@field protected _uuids_leaf         string[]
---
---@field protected _on_disposed         eve.ux.picker_file.IOnDisposed
local M = {}
M.__index = M

---@param props                         eve.ux.IFilePickerProps
---@return eve.ux.FilePicker
function M.new(props)
  local name = props.name ---@type string
  local uuid = props.uuid or eve.oxi.uuid() ---@type string
  local permanent = props.permanent ---@type boolean
  local preview = props.preview ~= false ---@type boolean
  local title = props.title ---@type string
  local height = props.height ---@type number|nil
  local width = props.width ---@type number|nil
  local foldempty = props.foldempty ---@type boolean|nil
  local node_flat_renderer = props.node_flat_renderer or default_treeview_node_flat_renderer ---@type eve.ux.view.treeview.INodeFlatRenderer
  local node_renderer = props.node_renderer or default_treeview_node_renderer ---@type eve.ux.view.treeview.INodeRenderer
  local node_sorter = props.node_sorter or default_treeview_node_sorter ---@type eve.ux.view.treeview.INodeSorter

  local finder_input = props.finder_input ---@type eve.std.collection.IObservable
  local finder_multiline = props.finder_multiline ---@type boolean|nil

  local on_closed = props.on_closed or eve.std.fn.noop ---@type eve.ux.picker_file.IOnClosed
  local on_disposed = props.on_disposed or eve.std.fn.noop ---@type eve.ux.picker_file.IOnDisposed
  local on_focused = props.on_focused or eve.std.fn.noop ---@type eve.ux.picker_file.IOnFocused
  local on_hidden = props.on_hidden or eve.std.fn.noop ---@type eve.ux.picker_file.IOnHidden
  local on_refresh = props.on_refresh ---@type eve.ux.picker_file.IOnRefresh|nil

  local self = setmetatable({}, M)

  ---@type eve.std.collection.BufRetriever
  local retriever = eve.std.BufRetriever.new({
    name = name,
  })

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
    node_flat_renderer = node_flat_renderer,
    node_renderer = node_renderer,
    node_sorter = node_sorter,
  })

  local scheduler_match = eve.std.Scheduler.new({
    name = string.format("%s#match", name),
    mode = "debounce",
    delay = 256,
    timeout = 0,
    silent = eve.std.fn.falsy,
    value = eve.std.Observable.from_value(true),
    task = function()
      local input = finder_input:snapshot() ---@type string
      self:__match__(input)
      treeview:mark_treeview_node_cache_dirty()
      self:mark_result_dirty()
    end,
  })

  ---@param picker                      eve.ux.Picker
  ---@return eve.ux.view.treeview.INode|nil
  ---@return integer
  local function retrieve(picker)
    local lnum = picker:get_result_lnum() ---@type integer
    local node_uuid = retriever:retrieve_uuid(lnum) ---@type string|nil
    if node_uuid == nil then
      return node_uuid, lnum
    end
    local node = treeview:retrieve_by_uuid(node_uuid) ---@type eve.ux.view.treeview.INode|nil
    return node, lnum
  end

  local flag_fuzzy = props.flag_fuzzy ---@type eve.std.collection.IObservable
  local flag_regex = props.flag_regex ---@type eve.std.collection.IObservable
  local flag_sensitive = props.flag_sensitive ---@type eve.std.collection.IObservable
  local flag_viewtype = props.flag_viewtype ---@type eve.std.collection.IObservable
  local flags_append = props.flags_append ---@type eve.ux.picker.IFlagItem[]|nil
  local flags_prepend = props.flags_prepend ---@type eve.ux.picker.IFlagItem[]|nil
  local flags_start_index = props.flags_start_index ---@type 0|1|nil

  local flags = {} ---@type eve.ux.picker.IFlagItem[]
  if flags_prepend ~= nil then
    for _, flag in ipairs(flags_prepend) do
      flags[#flags + 1] = {
        desc = string.format("%s: %s", name, flag.desc),
        callback = flag.callback,
        snapshot = flag.snapshot,
      }
    end
  end
  flags[#flags + 1] = {
    desc = string.format("%s: viewtype", name),
    callback = function()
      local viewtype = flag_viewtype:snapshot() ---@type eve.ux.view.treeview.ViewtypeEnum
      local next_viewtype = viewtype == "tree" and "list" or "tree" ---@type eve.ux.view.treeview.ViewtypeEnum
      flag_viewtype:next(next_viewtype)
    end,
    snapshot = function()
      local viewtype = flag_viewtype:snapshot() ---@type eve.ux.view.treeview.ViewtypeEnum
      if viewtype == "tree" then
        return eve.icon.symbols.flag_tree, "picker_flag_aqua"
      end
      if viewtype == "list" then
        return eve.icon.symbols.flag_list, "picker_flag_aqua"
      end

      local message = string.format("[%s#%s] Unknown viewtype: %s", __module_name__, name, viewtype)
      error(message)
    end,
  }
  flags[#flags + 1] = {
    desc = string.format("%s: fuzzy", name),
    callback = function()
      local enabled = flag_fuzzy:snapshot() ---@type boolean
      flag_fuzzy:next(not enabled)
    end,
    snapshot = function()
      local enabled = flag_fuzzy:snapshot() ---@type boolean
      return eve.icon.symbols.flag_fuzzy, enabled and "picker_flag_blue" or "picker_flag_grey"
    end,
  }
  flags[#flags + 1] = {
    desc = string.format("%s: sensitive", name),
    callback = function()
      local enabled = flag_sensitive:snapshot() ---@type boolean
      flag_sensitive:next(not enabled)
    end,
    snapshot = function()
      local enabled = flag_sensitive:snapshot() ---@type boolean
      return eve.icon.symbols.flag_case_sensitive, enabled and "picker_flag_blue" or "picker_flag_grey"
    end,
  }
  flags[#flags + 1] = {
    desc = string.format("%s: fold empty path", name),
    disabled = function()
      local viewtype = flag_viewtype:snapshot() ---@type eve.ux.view.treeview.ViewtypeEnum
      return viewtype ~= "tree"
    end,
    callback = function(picker)
      local enabled = treeview:isfoldempty() ---@type boolean
      treeview:set_foldempty(not enabled)
      picker:mark_result_dirty()
    end,
    snapshot = function()
      local enabled = treeview:isfoldempty() ---@type boolean
      return eve.icon.symbols.flag_fold_empty_path, enabled and "picker_flag_blue" or "picker_flag_grey"
    end,
  }
  if flags_append ~= nil then
    for _, flag in ipairs(flags_append) do
      flags[#flags + 1] = {
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
      aliases = { "<enter>" },
      desc = "filetree: open",
      callback = function(picker)
        local node = retrieve(picker) ---@type  eve.ux.view.treeview.INode|nil, integer
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
        local node = retrieve(picker) ---@type  eve.ux.view.treeview.INode|nil, integer
        if node == nil then
          return
        end

        local data = node.data ---@type eve.ux.file_picker.ITreeNodeData
        if data.nodetype == "directory" and not node.collapsed then
          treeview:collapse(node.uuid, "collapsed", false)
          picker:mark_result_dirty()
        else
          local lnum_parent = retriever:retrieve_lnum(node.parent) ---@type integer|nil
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
        local node = retrieve(picker) ---@type  eve.ux.view.treeview.INode|nil, integer
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
          local node = retrieve(picker) ---@type  eve.ux.view.treeview.INode|nil, integer
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
        local node = retrieve(picker) ---@type  eve.ux.view.treeview.INode|nil, integer
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
        local node = retrieve(picker) ---@type  eve.ux.view.treeview.INode|nil, integer
        if node == nil then
          return
        end

        local data = node.data ---@type eve.ux.file_picker.ITreeNodeData
        if data.nodetype == "directory" and not node.collapsed then
          treeview:collapse(node.uuid, "collapsed", false)
          picker:mark_result_dirty()
        else
          local lnum_parent = retriever:retrieve_lnum(node.parent) ---@type integer|nil
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
    height = height,
    width = width,

    finder_title = title,
    finder_keymaps = finder_keymaps,
    finder_input = finder_input,
    finder_multiline = finder_multiline,

    result_keymaps = result_keymaps,

    on_closed = function()
      on_closed(self)
    end,
    on_disposed = function()
      self:dispose()
    end,
    on_focused = function()
      on_focused(self)
    end,
    on_hidden = function()
      on_hidden(self)
    end,
    on_refresh = on_refresh ~= nil and function(_, force)
      on_refresh(self, force)
    end or nil,

    result_render = function(_, bufnr)
      local viewtype = flag_viewtype:snapshot() ---@type eve.ux.view.treeview.ViewtypeEnum
      local result = treeview:render(bufnr, viewtype, self._uuid_root, self._last_matched_uuids) ---@type eve.ux.view.treeview.IRenderResult
      local uuids = result.uuids ---@type string[]
      retriever:attach(bufnr, uuids)
    end,
    preview_render = preview
        and function(picker, bufnr)
          local node, lnum = retrieve(picker) ---@type  eve.ux.view.treeview.INode|nil, integer
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

          local root = treeview:retrieve_by_uuid(self._uuid_root) ---@type eve.ux.view.treeview.INode|nil
          if root == nil then
            return data.filepath
          end
          return eve.path.relative(root.data.filepath or eve.path.cwd(), data.filepath, false)
        end
      or nil,
  })

  self.uuid = uuid
  self.name = name

  self.flag_fuzzy = flag_fuzzy
  self.flag_regex = flag_regex
  self.flag_sensitive = flag_sensitive

  self._disposed = false
  self._picker = picker
  self._plainfile = plainfile
  self._retriever = retriever
  self._scheduler_match = scheduler_match
  self._treeview = treeview

  self._last_input = ""
  self._last_matches = nil
  self._last_matched_uuids = nil
  self._uuid_root = nil
  self._uuids_leaf = {}

  self._on_disposed = on_disposed

  finder_input:subscribe(eve.std.Subscriber.new({
    on_next = function()
      scheduler_match:schedule()
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

  local on_dispose = self._on_disposed ---@type eve.ux.picker.IOnDisposed
  self._plainfile:dispose()
  self._retriever:dispose()
  self._scheduler_match:dispose()
  self._treeview:dispose()
  self._picker:dispose()

  self.flag_fuzzy = nil
  self.flag_regex = nil
  self.flag_sensitive = nil

  self._picker = nil
  self._plainfile = nil
  self._retriever = nil
  self._scheduler_match = nil
  self._treeview = nil

  self._last_input = nil
  self._last_matches = nil
  self._last_matched_uuids = nil
  self._uuid_root = nil
  self._uuids_leaf = nil

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

---@param uuid                          string
---@return eve.ux.FilePicker
function M:attach(uuid)
  self:__health__()
  if self._uuid_root == uuid then
    return self
  end

  local node = self._treeview:retrieve_by_uuid(uuid) ---@type eve.ux.view.treeview.INode|nil
  if node == nil then
    eve.reporter.error({
      from = __module_name__,
      subject = "attach",
      message = string.format("Cannot find node by the given uuid: %s", uuid),
    })
    return self
  end

  self._uuid_root = uuid
  self._last_input = ""
  self._last_matches = nil
  self._last_matched_uuids = nil
  self._scheduler_match:schedule()
  return self
end

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
    filepath_lower = "",
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
        filepath_lower = filepath:lower(),
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

    local filepath = cwd ---@type string
    local uuid = cwd_uuid ---@type string
    local uuid_parent = cwd_uuid ---@type string

    local pieces = eve.path.split(p) ---@type string[]
    local N = #pieces - 1 ---@type integer
    for index = 1, N, 1 do
      local basename = pieces[index] ---@type string
      filepath = filepath .. eve.env.PATH_SEP .. basename ---@type string
      uuid = uuid .. "/" .. basename ---@type string

      ---@type eve.ux.file_picker.ITreeNodeData
      local data = {
        uuid = uuid,
        basename = basename,
        filepath = filepath,
        filepath_lower = filepath:lower(),
        nodetype = "directory",
      }
      treeview:insert(uuid, uuid_parent, data, false, false)
      uuid_parent = uuid ---@type string
    end

    local basename = pieces[#pieces] ---@type string
    filepath = filepath .. eve.env.PATH_SEP .. basename ---@type string
    uuid = uuid .. "/" .. basename ---@type string

    ---@type eve.ux.file_picker.ITreeNodeData
    local data = {
      uuid = uuid,
      basename = basename,
      filepath = filepath,
      filepath_lower = filepath:lower(),
      nodetype = "file",
    }
    treeview:insert(uuid, uuid_parent, data, true, false)
    ::continue::
  end

  for _, p in ipairs(absolute_filepaths) do
    local filepath = root.filepath ---@type string
    local uuid = root.uuid ---@type string
    local uuid_parent = root.uuid ---@type string
    local start_index = eve.env.IS_WIN and 1 or 2 ---@type integer

    local pieces = eve.path.split(p) ---@type string[]
    local N = #pieces - 1 ---@type integer
    for index = start_index, N, 1 do
      local basename = pieces[index] ---@type string
      filepath = filepath .. eve.env.PATH_SEP .. basename ---@type string
      uuid = uuid .. "/" .. basename ---@type string

      ---@type eve.ux.file_picker.ITreeNodeData
      local data = {
        uuid = uuid,
        basename = basename,
        filepath = filepath,
        filepath_lower = filepath:lower(),
        nodetype = "directory",
      }
      treeview:insert(uuid, uuid_parent, data, false, false)
      uuid_parent = uuid ---@type string
    end

    local basename = pieces[#pieces] ---@type string
    filepath = filepath .. eve.env.PATH_SEP .. basename ---@type string
    uuid = uuid .. "/" .. basename ---@type string

    ---@type eve.ux.file_picker.ITreeNodeData
    local data = {
      uuid = uuid,
      basename = basename,
      filepath = filepath,
      filepath_lower = filepath:lower(),
      nodetype = "file",
    }
    treeview:insert(uuid, uuid_parent, data, true, false)
  end

  local uuids_leaf = treeview:collect_leaf_uuids(cwd_uuid) ---@type string[]
  self._last_input = ""
  self._last_matches = nil
  self._last_matched_uuids = nil
  self._uuid_root = cwd_uuid
  self._uuids_leaf = uuids_leaf
  self._scheduler_match:schedule()
  return self
end

----------------------------------------------------------------------------------------------------

---@protected
---@return nil
function M:__health__()
  if self._disposed then
    local message = string.format("[%s#%s] already been disposed.", __module_name__, self.name) ---@type string
    error(message)
  end
end

---@protected
---@param input                         string
---@return nil
function M:__match__(input)
  if #input < 1 then
    self._last_input = ""
    self._last_matches = nil
    self._last_matched_uuids = nil
    return
  end

  local treeview = self._treeview ---@type eve.ux.view.Treeview
  local flag_sensitive = self.flag_sensitive:snapshot() ---@type boolean
  local flag_fuzzy = self.flag_fuzzy:snapshot() ---@type boolean
  local flag_regex = self.flag_regex:snapshot() ---@type boolean

  local lines = {} ---@type string[]
  local uuids = {} ---@type string[]

  local root = treeview:retrieve_by_uuid(self._uuid_root) ---@type eve.ux.view.treeview.INode|nil
  local prefix_len = root ~= nil and #root.data.filepath > 2 and #root.data.filepath + 2 or 0 ---@type integer

  local last_input = self._last_input ---@type string
  local last_matches = self._last_matches ---@type eve.t.IScoredMatch[]|nil
  if last_matches ~= nil and not flag_regex and #input > #last_input and input:sub(1, #last_input) == last_input then
    if flag_sensitive then
      for _, match in ipairs(last_matches) do
        local node = treeview:retrieve_by_uuid(match.uuid, false) ---@type eve.ux.view.treeview.INode|nil
        if node ~= nil then
          local data = node.data ---@type eve.ux.file_picker.ITreeNodeData
          local line = data.filepath:sub(prefix_len) ---@type string
          lines[#lines + 1] = line
          uuids[#uuids + 1] = node.uuid
        end
      end
    else
      for _, match in ipairs(last_matches) do
        local node = treeview:retrieve_by_uuid(match.uuid, false) ---@type eve.ux.view.treeview.INode|nil
        if node ~= nil then
          local data = node.data ---@type eve.ux.file_picker.ITreeNodeData
          local line = data.filepath_lower:sub(prefix_len) ---@type string
          lines[#lines + 1] = line
          uuids[#uuids + 1] = node.uuid
        end
      end
    end
  else
    if flag_sensitive then
      for _, uuid in ipairs(self._uuids_leaf) do
        local node = treeview:retrieve_by_uuid(uuid, false) ---@type eve.ux.view.treeview.INode|nil
        if node ~= nil then
          local data = node.data ---@type eve.ux.file_picker.ITreeNodeData
          local line = data.filepath:sub(prefix_len) ---@type string
          lines[#lines + 1] = line
          uuids[#uuids + 1] = node.uuid
        end
      end
    else
      for _, uuid in ipairs(self._uuids_leaf) do
        local node = treeview:retrieve_by_uuid(uuid, false) ---@type eve.ux.view.treeview.INode|nil
        if node ~= nil then
          local data = node.data ---@type eve.ux.file_picker.ITreeNodeData
          local line = data.filepath_lower:sub(prefix_len) ---@type string
          lines[#lines + 1] = line
          uuids[#uuids + 1] = node.uuid
        end
      end
    end
  end

  ---@type eve.builtin.oxi.string.ILineMatch[]|nil
  local oxi_matches = eve.oxi.find_match_points_line_by_line(input, lines, flag_fuzzy, flag_regex)
  if oxi_matches == nil then
    self._last_input = ""
    self._last_matches = nil
    self._last_matched_uuids = nil
    return
  end

  local matches = {} ---@type eve.t.IScoredMatch[]
  local matched_uuids = {} ---@type string[]
  for _, oxi_match in ipairs(oxi_matches) do
    local lnum = oxi_match.lnum ---@type integer

    ---@type eve.t.IScoredMatch
    local match = {
      order = lnum,
      uuid = uuids[lnum],
      score = oxi_match.score,
      matches = oxi_match.matches,
    }
    matches[#matches + 1] = match
    matched_uuids[#matched_uuids + 1] = match.uuid
  end

  self._last_input = input
  self._last_matches = matches
  self._last_matched_uuids = treeview:calc_include_uuid_set(matched_uuids)
end

return M
