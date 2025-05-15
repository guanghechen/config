---@diagnostic disable: invisible
local __module_name__ = "eve.ux.picker-file" ---@type string

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
---@field public flag_foldempty         eve.std.collection.IObservable
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
---@field public flag_foldempty         eve.std.collection.IObservable
---@field public flag_fuzzy             eve.std.collection.IObservable
---@field public flag_regex             eve.std.collection.IObservable
---@field public flag_sensitive         eve.std.collection.IObservable
---@field public flag_viewtype          eve.std.collection.IObservable
---
---@field protected _disposed           boolean
---@field protected _filetree           eve.ux.view.Filetree
---@field protected _picker             eve.ux.Picker
---@field protected _plainfile          eve.ux.view.Plainfile
---@field protected _retriever          eve.std.collection.BufRetriever
---@field protected _scheduler_match    eve.std.collection.Scheduler|nil
---
---@field protected _last_input         string
---@field protected _last_offset        integer
---@field protected _last_matches       eve.t.IScoredMatch[]|nil
---@field protected _last_matched_uuids table<string, boolean>|nil
---@field protected _uuid_root          string|nil
---@field protected _uuids_file         string[]
---
---@field protected _on_disposed         eve.ux.picker_file.IOnDisposed
local M = {}
M.__index = M

local NSNR_PICKER_MATCHES = eve.var.nsnr.picker_matches ---@type integer

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

  local finder_input = props.finder_input ---@type eve.std.collection.IObservable
  local finder_multiline = props.finder_multiline ---@type boolean|nil

  local flag_fuzzy = props.flag_fuzzy ---@type eve.std.collection.IObservable
  local flag_regex = props.flag_regex ---@type eve.std.collection.IObservable
  local flag_foldempty = props.flag_foldempty ---@type eve.std.collection.IObservable
  local flag_sensitive = props.flag_sensitive ---@type eve.std.collection.IObservable
  local flag_viewtype = props.flag_viewtype ---@type eve.std.collection.IObservable
  local flags_append = props.flags_append ---@type eve.ux.picker.IFlagItem[]|nil
  local flags_prepend = props.flags_prepend ---@type eve.ux.picker.IFlagItem[]|nil
  local flags_start_index = props.flags_start_index ---@type 0|1|nil

  local on_closed = props.on_closed or eve.std.fn.noop ---@type eve.ux.picker_file.IOnClosed
  local on_disposed = props.on_disposed or eve.std.fn.noop ---@type eve.ux.picker_file.IOnDisposed
  local on_focused = props.on_focused or eve.std.fn.noop ---@type eve.ux.picker_file.IOnFocused
  local on_hidden = props.on_hidden or eve.std.fn.noop ---@type eve.ux.picker_file.IOnHidden
  local on_refresh = props.on_refresh ---@type eve.ux.picker_file.IOnRefresh|nil

  local indents = {} ---@type string[]

  local self = setmetatable({}, M)

  ---@type eve.std.collection.BufRetriever
  local retriever = eve.std.BufRetriever.new({
    name = name,
  })

  ---@type eve.ux.view.Plainfile
  local plainfile = eve.ux.view.Plainfile.new({
    name = name,
  })

  ---@type eve.ux.view.Filetree
  local filetree = eve.ux.view.Filetree.new({
    name = name,
    flag_foldempty = flag_foldempty,
    indent = "",
    indent_hln = "f_utw_indent_float",
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
      filetree:mark_treeview_node_cache_dirty()
      self:mark_result_dirty()
    end,
  })

  ---@param picker                      eve.ux.Picker
  ---@return eve.ux.view.filetree.INode|nil
  ---@return integer
  local function retrieve(picker)
    local lnum = picker:get_result_lnum() ---@type integer
    local node_uuid = retriever:retrieve_uuid(lnum) ---@type string|nil
    if node_uuid == nil then
      return node_uuid, lnum
    end
    local node = filetree:retrieve_by_uuid(node_uuid) ---@type eve.ux.view.filetree.INode|nil
    return node, lnum
  end

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
      local enabled = flag_foldempty:snapshot() ---@type boolean
      flag_foldempty:next(not enabled)
      picker:mark_result_dirty()
    end,
    snapshot = function()
      local enabled = flag_foldempty:snapshot() ---@type boolean
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
        local node = retrieve(picker) ---@type  eve.ux.view.filetree.INode|nil, integer
        if node == nil then
          return
        end

        if node.type == "container" then
          filetree:collapse(node.uuid, "expand", false)
          picker:mark_result_dirty()
          return
        end

        if node.type == "leaf" and #node.children > 0 then
          filetree:collapse(node.uuid, "expand", false)
          picker:mark_result_dirty()
          return
        end

        local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
        local winnr_sourcefile = eve.tab.retrieve_winnr_sourcefile(tabnr) ---@type integer|nil
        if winnr_sourcefile ~= nil and vim.api.nvim_win_is_valid(winnr_sourcefile) then
          vim.api.nvim_tabpage_set_win(tabnr, winnr_sourcefile)
        end

        local filepath = node.data.filepath ---@type string

        picker:close()
        eve.win.open_filepath(winnr_sourcefile, filepath, node.data.lnum, node.data.col)
      end,
    },
    {
      modes = { "i", "n", "v" },
      key = "<C-h>",
      desc = "filetree: close",
      callback = function(picker)
        local node = retrieve(picker) ---@type  eve.ux.view.filetree.INode|nil, integer
        if node == nil then
          return
        end

        if node.type == "container" then
          filetree:collapse(node.uuid, "collapse", false)
          picker:mark_result_dirty()
          return
        end

        if node.type == "leaf" and #node.children > 0 then
          filetree:collapse(node.uuid, "collapse", false)
          picker:mark_result_dirty()
          return
        end

        local lnum_parent = retriever:retrieve_lnum(node.parent.uuid) ---@type integer|nil
        filetree:collapse(node.parent.uuid, "collapse", false)
        picker:mark_result_dirty()
        if lnum_parent ~= nil then
          picker:set_result_lnum(lnum_parent)
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
        local node = retrieve(picker) ---@type  eve.ux.view.filetree.INode|nil, integer
        if node == nil then
          return
        end

        if node.type == "container" then
          filetree:collapse(node.uuid, "toggle", true)
          picker:mark_result_dirty()
          return
        end

        if node.type == "leaf" and #node.children > 0 then
          filetree:collapse(node.uuid, "toggle", true)
          picker:mark_result_dirty()
          return
        end

        local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
        local winnr_sourcefile = eve.tab.retrieve_winnr_sourcefile(tabnr) ---@type integer|nil
        if winnr_sourcefile ~= nil and vim.api.nvim_win_is_valid(winnr_sourcefile) then
          vim.api.nvim_tabpage_set_win(tabnr, winnr_sourcefile)
        end

        local filepath = node.data.filepath ---@type string

        picker:close()
        eve.win.open_filepath(winnr_sourcefile, filepath, node.data.lnum, node.data.col)
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
          local node = retrieve(picker) ---@type  eve.ux.view.filetree.INode|nil, integer
          if node == nil then
            return
          end

          if node.type == "container" then
            filetree:collapse(node.uuid, "toggle", false)
            picker:mark_result_dirty()
            return
          end

          if node.type == "leaf" and #node.children > 0 then
            filetree:collapse(node.uuid, "toggle", false)
            picker:mark_result_dirty()
            return
          end

          local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
          local winnr_sourcefile = eve.tab.retrieve_winnr_sourcefile(tabnr) ---@type integer|nil
          if winnr_sourcefile ~= nil and vim.api.nvim_win_is_valid(winnr_sourcefile) then
            vim.api.nvim_tabpage_set_win(tabnr, winnr_sourcefile)
          end

          local filepath = node.data.filepath ---@type string

          picker:close()
          eve.win.open_filepath(winnr_sourcefile, filepath, node.data.lnum, node.data.col)
        end
      end,
    },
    {
      modes = { "i", "n", "v" },
      key = "<CR>",
      aliases = { "<Right>", "l", "o" },
      desc = "filetree: open",
      callback = function(picker)
        local node = retrieve(picker) ---@type  eve.ux.view.filetree.INode|nil, integer
        if node == nil then
          return
        end

        if node.type == "container" then
          filetree:collapse(node.uuid, "expand", false)
          picker:mark_result_dirty()
          return
        end

        if node.type == "leaf" and #node.children > 0 then
          filetree:collapse(node.uuid, "expand", false)
          picker:mark_result_dirty()
          return
        end

        local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
        local winnr_sourcefile = eve.tab.retrieve_winnr_sourcefile(tabnr) ---@type integer|nil
        if winnr_sourcefile ~= nil and vim.api.nvim_win_is_valid(winnr_sourcefile) then
          vim.api.nvim_tabpage_set_win(tabnr, winnr_sourcefile)
        end

        local filepath = node.data.filepath ---@type string

        picker:close()
        eve.win.open_filepath(winnr_sourcefile, filepath, node.data.lnum, node.data.col)
      end,
    },
    {
      modes = { "i", "n", "v" },
      key = "<Backspace>",
      aliases = { "<Left>", "h", "c" },
      desc = "filetree: close",
      callback = function(picker)
        local node = retrieve(picker) ---@type  eve.ux.view.filetree.INode|nil, integer
        if node == nil then
          return
        end

        if node.type == "container" then
          filetree:collapse(node.uuid, "collapse", false)
          picker:mark_result_dirty()
          return
        end

        if node.type == "leaf" and #node.children > 0 then
          filetree:collapse(node.uuid, "collapse", false)
          picker:mark_result_dirty()
          return
        end

        local lnum_parent = retriever:retrieve_lnum(node.parent.uuid) ---@type integer|nil
        filetree:collapse(node.parent.uuid, "collapse", false)
        picker:mark_result_dirty()
        if lnum_parent ~= nil then
          picker:set_result_lnum(lnum_parent)
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
    on_result_rendered = function(_, bufnr)
      local last_matches = self._last_matches ---@type eve.t.IScoredMatch[]|nil
      if last_matches == nil or #last_matches < 1 then
        return
      end

      local viewtype = flag_viewtype:snapshot() ---@type eve.ux.view.treeview.ViewtypeEnum
      if viewtype == "tree" then
        for _, search_match in ipairs(last_matches) do
          local node_uuid = search_match.uuid ---@type string
          local lnum = retriever:retrieve_lnum(node_uuid) ---@type integer|nil
          local node = filetree:retrieve_by_uuid(node_uuid) ---@type eve.ux.view.filetree.INode|nil
          if lnum ~= nil and node ~= nil then
            ---@cast node eve.ux.view.filetree.IFileNode

            local row = lnum - 1 ---@type integer
            local text_width = #node.data.basename ---@type integer
            local offset = self._last_offset ---@type integer
            local offset_start = #node.data.filepath - text_width + 1 ---@type integer
            local offset_final = #indents[lnum] + #node.data.icon + 1 ---@type integer
            for _, m in ipairs(search_match.matches) do
              local dl = m.l + offset - offset_start ---@type integer
              local dr = m.r + offset - offset_start ---@type integer
              if dl <= text_width and dr >= 0 then
                dl = dl < 0 and 0 or dl ---@type integer
                dr = dr > text_width and text_width or dr ---@type integer
                vim.hl.range(
                  bufnr,
                  NSNR_PICKER_MATCHES,
                  "f_picker_matches",
                  { row, offset_final + dl },
                  { row, offset_final + dr }
                )
              end
            end
          end
        end
        return
      end

      if viewtype == "list" then
        for _, search_match in ipairs(last_matches) do
          local node_uuid = search_match.uuid ---@type string
          local lnum = retriever:retrieve_lnum(node_uuid) ---@type integer|nil
          local node = filetree:retrieve_by_uuid(node_uuid) ---@type eve.ux.view.filetree.INode|nil
          if lnum ~= nil and node ~= nil then
            ---@cast node eve.ux.view.filetree.IFileNode

            local row = lnum - 1 ---@type integer
            local offset_final = #node.data.icon + 1 ---@type integer
            for _, m in ipairs(search_match.matches) do
              vim.hl.range(
                bufnr,
                NSNR_PICKER_MATCHES,
                "f_picker_matches",
                { row, offset_final + m.l },
                { row, offset_final + m.r }
              )
            end
          end
        end
        return
      end
    end,

    on_refresh = on_refresh ~= nil and function(_, force)
      on_refresh(self, force)
    end or nil,

    result_render = function(_, bufnr)
      local viewtype = flag_viewtype:snapshot() ---@type eve.ux.view.treeview.ViewtypeEnum
      local result = filetree:render(bufnr, viewtype, self._uuid_root, self._last_matched_uuids) ---@type eve.ux.view.treeview.IRenderResult
      local uuids = result.uuids ---@type string[]
      indents = result.indents ---@type string[]
      retriever:attach(bufnr, uuids)
    end,
    ---@type eve.ux.picker.IPreviewRender|nil
    preview_render = preview
        and function(picker, bufnr)
          local node, lnum = retrieve(picker) ---@type  eve.ux.view.filetree.INode|nil, integer
          if node == nil then
            local lines = { string.format("Error: cannot retrieve node by the given lnum: %d", lnum) } ---@type string[]
            vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
            return string.format("Unknown lnum(%d)", lnum)
          end

          if node.type == "container" then
            ---@cast node               eve.ux.view.filetree.IDirectoryNode
            local lines = { string.format("Directory: %s", node.data.filepath) } ---@type string[]
            vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
            return node.data.filepath
          end

          if node.type == "leaf" and #node.children > 0 then
            node = node.children[1] ---@type eve.ux.view.filetree.INode
          end

          local filepath = node.data.filepath ---@type string
          plainfile:render(bufnr, filepath, false)

          local root = filetree:retrieve_by_uuid(self._uuid_root) ---@type eve.ux.view.filetree.INode|nil
          local relative_filepath = root ~= nil
              and eve.path.relative(root.data.filepath or eve.path.cwd(), filepath, false)
            or filepath
          if node.type == "leaf" then
            return filepath
          end

          ---@cast node                 eve.ux.view.filetree.IPositionNode
          return relative_filepath, node.data.lnum, node.data.col
        end
      or nil,
  })

  self.uuid = uuid
  self.name = name

  self.flag_foldempty = flag_foldempty
  self.flag_fuzzy = flag_fuzzy
  self.flag_regex = flag_regex
  self.flag_sensitive = flag_sensitive

  self._disposed = false
  self._filetree = filetree
  self._picker = picker
  self._plainfile = plainfile
  self._retriever = retriever
  self._scheduler_match = scheduler_match

  self._last_input = ""
  self._last_offset = 0
  self._last_matches = nil
  self._last_matched_uuids = nil
  self._uuid_root = nil
  self._uuids_file = {}

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
  self._filetree:dispose()
  self._plainfile:dispose()
  self._retriever:dispose()
  self._scheduler_match:dispose()
  self._picker:dispose()

  self.flag_foldempty = nil
  self.flag_fuzzy = nil
  self.flag_regex = nil
  self.flag_sensitive = nil

  self._filetree = nil
  self._picker = nil
  self._plainfile = nil
  self._retriever = nil
  self._scheduler_match = nil

  self._last_input = nil
  self._last_offset = nil
  self._last_matches = nil
  self._last_matched_uuids = nil
  self._uuid_root = nil
  self._uuids_file = nil

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

  local node = self._filetree:retrieve_by_uuid(uuid) ---@type eve.ux.view.filetree.INode|nil
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
  self._last_offset = nil
  self._last_matches = nil
  self._last_matched_uuids = nil
  self._scheduler_match:schedule()
  return self
end

---@return eve.ux.FilePicker
function M:clear_positions()
  self:__health__()
  self._filetree:clear_positions()
  return self
end

---@param fileuuid                     string
---@param lnum                          integer
---@param col                           integer|nil
---@param data                          unknown|nil
---@return eve.ux.FilePicker
function M:insert_position(fileuuid, lnum, col, data)
  self:__health__()
  self._filetree:insert_position(fileuuid, lnum, col, data)
  return self
end

---@return eve.ux.FilePicker
function M:mark_result_dirty()
  self:__health__()
  self._picker:mark_result_dirty()
  return self
end

---@return eve.ux.FilePicker
function M:mark_result_flags_dirty()
  self:__health__()
  self._picker:mark_result_flags_dirty()
  return self
end

---@param cwd                           string
---@param filepaths                     string[]
---@param with_positions                boolean
---@return eve.ux.FilePicker
function M:reset_filepaths(cwd, filepaths, with_positions)
  self:__health__()

  cwd = eve.path.normalize(cwd) ---@type string
  self._filetree:reset_filepaths(cwd, filepaths, with_positions)

  local uuid_cwd = self._filetree:retrieve_uuid_by_filepath(cwd) ---@type string|nil
  local uuids_file = self._filetree:collect_file_uuids(uuid_cwd) ---@type string[]

  self._last_input = ""
  self._last_offset = nil
  self._last_matches = nil
  self._last_matched_uuids = nil
  self._uuid_root = uuid_cwd
  self._uuids_file = uuids_file
  self._scheduler_match:schedule()
  return self
end

---@param uuid                          string
---@param silent                        boolean|nil
---@return eve.ux.view.filetree.INode|nil
function M:retrieve_by_uuid(uuid, silent)
  self:__health__()
  return self._filetree:retrieve_by_uuid(uuid, silent)
end

---@param filepath                     string
---@return string|nil
function M:retrieve_uuid_by_filepath(filepath)
  self:__health__()
  return self._filetree:retrieve_uuid_by_filepath(filepath)
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
    self._last_offset = 0
    self._last_matches = nil
    self._last_matched_uuids = nil
    return
  end

  local filetree = self._filetree ---@type eve.ux.view.Filetree
  local flag_sensitive = self.flag_sensitive:snapshot() ---@type boolean
  local flag_fuzzy = self.flag_fuzzy:snapshot() ---@type boolean
  local flag_regex = self.flag_regex:snapshot() ---@type boolean

  local lines = {} ---@type string[]
  local uuids = {} ---@type string[]

  local root = filetree:retrieve_by_uuid(self._uuid_root) ---@type eve.ux.view.filetree.INode|nil
  local offset = root ~= nil and #root.data.filepath > 2 and #root.data.filepath + 2 or 0 ---@type integer

  local last_input = self._last_input ---@type string
  local last_matches = self._last_matches ---@type eve.t.IScoredMatch[]|nil
  if last_matches ~= nil and not flag_regex and #input > #last_input and input:sub(1, #last_input) == last_input then
    if flag_sensitive then
      for _, match in ipairs(last_matches) do
        local node = filetree:retrieve_by_uuid(match.uuid, false) ---@type eve.ux.view.filetree.INode|nil
        if node ~= nil then
          local data = node.data ---@type eve.ux.view.filetree.INodeData
          local line = data.filepath:sub(offset) ---@type string
          lines[#lines + 1] = line
          uuids[#uuids + 1] = node.uuid
        end
      end
    else
      for _, match in ipairs(last_matches) do
        local node = filetree:retrieve_by_uuid(match.uuid, false) ---@type eve.ux.view.filetree.INode|nil
        if node ~= nil then
          local data = node.data ---@type eve.ux.view.filetree.INodeData
          local line = data.filepath_lower:sub(offset) ---@type string
          lines[#lines + 1] = line
          uuids[#uuids + 1] = node.uuid
        end
      end
    end
  else
    if flag_sensitive then
      for _, uuid in ipairs(self._uuids_file) do
        local node = filetree:retrieve_by_uuid(uuid, false) ---@type eve.ux.view.filetree.INode|nil
        if node ~= nil then
          local data = node.data ---@type eve.ux.view.filetree.INodeData
          local line = data.filepath:sub(offset) ---@type string
          lines[#lines + 1] = line
          uuids[#uuids + 1] = node.uuid
        end
      end
    else
      for _, uuid in ipairs(self._uuids_file) do
        local node = filetree:retrieve_by_uuid(uuid, false) ---@type eve.ux.view.filetree.INode|nil
        if node ~= nil then
          local data = node.data ---@type eve.ux.view.filetree.INodeData
          local line = data.filepath_lower:sub(offset) ---@type string
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
    self._last_offset = 0
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

  for _, uuid in ipairs(matched_uuids) do
    local node = filetree:retrieve_by_uuid(uuid, false)
    ---@cast node eve.ux.view.filetree.IFileNode
    for _, child in ipairs(node.children) do
      matched_uuids[#matched_uuids + 1] = child.uuid
    end
  end

  self._last_input = input
  self._last_offset = offset
  self._last_matches = matches
  self._last_matched_uuids = filetree:calc_include_uuid_set(matched_uuids)
end

return M
