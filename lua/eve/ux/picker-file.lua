---@diagnostic disable: invisible
local __module_name__ = "eve.ux.picker-file" ---@type string

---@alias eve.ux.picker_file.IOnAttach
---| fun(self: eve.ux.FilePicker, rootpath: string): nil

---@alias eve.ux.picker_file.IOnClosed
---| fun(self: eve.ux.FilePicker): nil

---@alias eve.ux.picker_file.IOnConfirm
---| fun(self: eve.ux.FilePicker, selected_filepaths: string[]|nil): nil

---@alias eve.ux.picker_file.IOnDisposed
---| fun(): nil

---@alias eve.ux.picker_file.IOnFocused
---| fun(self: eve.ux.FilePicker): nil

---@alias eve.ux.picker_file.IOnHidden
---| fun(self: eve.ux.FilePicker): nil
---
---@alias eve.ux.picker_file.IOnRefresh
---| fun(self: eve.ux.FilePicker, force: boolean): nil

---@class eve.ux.picker_file.ISelectedItemLocation
---@field public lnum                   integer
---@field public col                    integer|nil

---@class eve.ux.picker_file.actions
---@field public on_filetree_open       fun(): nil
---@field public on_filetree_toggle     fun(): nil
---@field public on_filetree_toggle_recursively fun(): nil
---@field public on_toggle_selection    fun(): nil

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
---@field public flag_foldempty         std.collection.IObservable
---@field public flag_fuzzy             std.collection.IObservable
---@field public flag_regex             std.collection.IObservable
---@field public flag_sensitive         std.collection.IObservable
---@field public flag_selected          std.collection.IObservable
---@field public flag_viewtype          std.collection.IObservable
---@field public flags_append           eve.ux.picker.result.IFlagItemRaw[]|nil
---@field public flags_prepend          eve.ux.picker.result.IFlagItemRaw[]|nil
---@field public flags_start_index      ?0|1
---
---@field public frecency               ?std.collection.IFrecency
---
---@field public finder_input           std.collection.IObservable
---@field public finder_input_history   ?std.collection.IHistory
---@field public finder_multiline       ?boolean
---
---@field public on_attach              ?eve.ux.picker_file.IOnAttach
---@field public on_closed              ?eve.ux.picker_file.IOnClosed
---@field public on_confirm             ?eve.ux.picker_file.IOnConfirm
---@field public on_disposed            ?eve.ux.picker_file.IOnDisposed
---@field public on_focused             ?eve.ux.picker_file.IOnFocused
---@field public on_hidden              ?eve.ux.picker_file.IOnHidden
---@field public on_refresh             ?eve.ux.picker_file.IOnRefresh

---@class eve.ux.FilePicker
---@field public uuid                   string
---@field public fullname               string
---@field public title                  string
---
---@field public finder                 eve.ux.PickerFinder
---@field public result                 eve.ux.PickerResult
---@field public preview                eve.ux.PickerPreview
---
---@field public flag_foldempty         std.collection.IObservable
---@field public flag_fuzzy             std.collection.IObservable
---@field public flag_regex             std.collection.IObservable
---@field public flag_sensitive         std.collection.IObservable
---@field public flag_selected          std.collection.IObservable
---@field public flag_viewtype          std.collection.IObservable
---
---@field protected _disposed           boolean
---@field protected _filetree           std.collection.Filetree
---@field protected _frecency           std.collection.IFrecency|nil
---@field protected _picker             eve.ux.PickerComposer
---@field protected _plainfile          eve.ux.view.Plainfile
---@field protected _retriever          eve.ux.view.TreeRetriever
---@field protected _scheduler_match    std.collection.Scheduler|nil
---@field protected _treeview           eve.ux.view.Filetree
---
---@field protected _last_preview_filepath  string|nil
---@field protected _uuid_root          string|nil
---@field protected _uuid_current       string|nil
---@field protected _uuids_file         string[]
---@field protected _uuids_order        string[]
---
---@field protected _on_confirm         eve.ux.picker_file.IOnConfirm|nil
---@field protected _on_disposed        eve.ux.picker_file.IOnDisposed
local M = {}
M.__index = M

---@param props                         eve.ux.IFilePickerProps
---@return eve.ux.FilePicker
function M.new(props)
  local name = props.name ---@type string
  local fullname = string.format("%s -> %s", name, __module_name__) ---@type string
  local picker_uuid = props.uuid or std.fn.uuid() ---@type string
  local permanent = props.permanent ---@type boolean
  local preview = props.preview ~= false ---@type boolean
  local title = props.title ---@type string
  local height = props.height ---@type number|nil
  local width = props.width ---@type number|nil

  local finder_input = props.finder_input ---@type std.collection.IObservable
  local finder_input_history = props.finder_input_history ---@type std.collection.IHistory|nil
  local finder_multiline = props.finder_multiline ---@type boolean|nil

  local flag_fuzzy = props.flag_fuzzy ---@type std.collection.IObservable
  local flag_regex = props.flag_regex ---@type std.collection.IObservable
  local flag_foldempty = props.flag_foldempty ---@type std.collection.IObservable
  local flag_sensitive = props.flag_sensitive ---@type std.collection.IObservable
  local flag_selected = props.flag_selected ---@type std.collection.IObservable
  local flag_viewtype = props.flag_viewtype ---@type std.collection.IObservable
  local flags_append = props.flags_append ---@type eve.ux.picker.result.IFlagItemRaw[]|nil
  local flags_prepend = props.flags_prepend ---@type eve.ux.picker.result.IFlagItemRaw[]|nil
  local flags_start_index = props.flags_start_index ---@type 0|1|nil

  local frecency = props.frecency ---@type std.collection.IFrecency|nil

  local on_attach = props.on_attach or std.fn.noop ---@type eve.ux.picker_file.IOnAttach
  local on_closed = props.on_closed or std.fn.noop ---@type eve.ux.picker_file.IOnClosed
  local on_confirm = props.on_confirm ---@type eve.ux.picker_file.IOnConfirm|nil
  local on_disposed = props.on_disposed or std.fn.noop ---@type eve.ux.picker_file.IOnDisposed
  local on_focused = props.on_focused or std.fn.noop ---@type eve.ux.picker_file.IOnFocused
  local on_hidden = props.on_hidden or std.fn.noop ---@type eve.ux.picker_file.IOnHidden
  local on_refresh = props.on_refresh or std.fn.noop ---@type eve.ux.picker_file.IOnRefresh

  local filetree = std.Filetree.new({ name = fullname })

  local self = setmetatable({}, M)

  ---@type eve.ux.view.TreeRetriever
  local retriever = eve.ux.view.TreeRetriever.new({
    name = fullname,
  })

  ---@type eve.ux.view.Plainfile
  local plainfile = eve.ux.view.Plainfile.new({
    name = fullname,
  })

  ---@type eve.ux.view.Filetree
  local treeview = eve.ux.view.Filetree.new({
    name = fullname,
    tree = filetree,
    flag_foldempty = flag_foldempty,
    indent = "",
    indent_hln = "f_utw_indent_float",
  })

  local scheduler_match = std.Scheduler.new({
    name = string.format("%s#match", fullname),
    mode = "debounce",
    delay = 64,
    timeout = 0,
    silent = std.fn.falsy,
    value = std.Observable.from_value(true),
    task = function()
      local input = finder_input:snapshot() ---@type string
      self:__match__(input)
      treeview:mark_cache_treeview_dirty()
      self:mark_result_dirty()
    end,
  })

  ---@return string|nil
  ---@return integer
  local function retrieve()
    local lnum = self._picker:get_result_lnum() ---@type integer
    local uuid = retriever:retrieve_uuid(lnum) ---@type string|nil
    return uuid, lnum
  end

  local flags = {} ---@type eve.ux.picker.result.IFlagItemRaw[]
  do
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
      desc = string.format("%s: selected only", name),
      callback = function()
        local enabled = flag_selected:snapshot() ---@type boolean
        flag_selected:next(not enabled)
      end,
      snapshot = function()
        local enabled = flag_selected:snapshot() ---@type boolean
        return eve.icon.symbols.flag_selected, enabled and "picker_flag_orange" or "picker_flag_grey"
      end,
    }
    flags[#flags + 1] = {
      desc = string.format("%s: viewtype", name),
      callback = function()
        local viewtype = flag_viewtype:snapshot() ---@type eve.ux.view.tree.ViewtypeEnum
        local next_viewtype = viewtype == "tree" and "list" or "tree" ---@type eve.ux.view.tree.ViewtypeEnum
        flag_viewtype:next(next_viewtype)
      end,
      snapshot = function()
        local viewtype = flag_viewtype:snapshot() ---@type eve.ux.view.tree.ViewtypeEnum
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
      desc = string.format("%s: fold empty path", name),
      disabled = function()
        local viewtype = flag_viewtype:snapshot() ---@type eve.ux.view.tree.ViewtypeEnum
        return viewtype ~= "tree"
      end,
      callback = function()
        local enabled = flag_foldempty:snapshot() ---@type boolean
        flag_foldempty:next(not enabled)
        self._picker:mark_result_dirty()
      end,
      snapshot = function()
        local enabled = flag_foldempty:snapshot() ---@type boolean
        return eve.icon.symbols.flag_fold_empty_path, enabled and "picker_flag_blue" or "picker_flag_grey"
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
      desc = string.format("%s: regex", name),
      callback = function()
        local enabled = flag_regex:snapshot() ---@type boolean
        flag_regex:next(not enabled)
      end,
      snapshot = function()
        local enabled = flag_regex:snapshot() ---@type boolean
        return eve.icon.symbols.flag_regex, enabled and "picker_flag_blue" or "picker_flag_grey"
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
  end

  ---@type eve.ux.picker_file.actions
  local actions = {
    on_filetree_open = function()
      local nodeuuid = retrieve() ---@type string|nil
      if nodeuuid ~= nil then
        if on_confirm == nil then
          self:__open_node__(nodeuuid)
        else
          self:__resolve_confirmation__(nodeuuid)
        end
      end
    end,
    on_filetree_toggle = function()
      local nodeuuid = retrieve() ---@type string|nil
      if nodeuuid ~= nil then
        self:__toggle_node__(nodeuuid, false)
      end
    end,
    on_filetree_attach = function()
      local nodeuuid = retrieve() ---@type string|nil
      if nodeuuid ~= nil then
        local nodestate = treeview:retrieve(nodeuuid) ---@type eve.ux.view.filetree.INodeState|nil
        if nodestate ~= nil and nodestate.nodetype == "container" then
          treeview:mark_cache_listview_dirty()
          self._uuid_root = nodeuuid ---@type string
          self:mark_result_dirty()

          local next_rootnode = filetree:retrieve(nodeuuid)
          if next_rootnode ~= nil then
            on_attach(self, next_rootnode.data.filepath) ---@type eve.ux.picker_file.IOnAttach
          end
        end
      end
    end,
    on_filetree_attach_parent = function()
      local rootuuid = self._uuid_root ---@type string
      local rootnode = filetree:retrieve(rootuuid) ---@type std.collection.filetree.INode|nil
      if rootnode and rootnode.parent ~= rootuuid then
        treeview:mark_cache_listview_dirty()
        self._uuid_root = rootnode.parent ---@type string
        self:mark_result_dirty()

        local next_rootnode = filetree:retrieve(rootnode.parent)
        if next_rootnode ~= nil then
          on_attach(self, next_rootnode.data.filepath) ---@type eve.ux.picker_file.IOnAttach
        end
      end
    end,
    on_filetree_toggle_recursively = function()
      local nodeuuid = retrieve() ---@type string|nil
      if nodeuuid ~= nil then
        self:__toggle_node__(nodeuuid, true)
      end
    end,
    on_toggle_selection = function()
      local nodeuuid = retrieve() ---@type string|nil
      if nodeuuid == nil then
        return
      end

      local nodestate = treeview:retrieve(nodeuuid) ---@type eve.ux.view.filetree.INodeState|nil
      if nodestate == nil then
        return
      end

      local picker = self._picker ---@type eve.ux.PickerComposer
      local lnum = retriever:retrieve_lnum(nodeuuid) ---@type integer|nil
      if lnum == nil or lnum < 0 then
        return
      end

      if nodestate.nodetype == "container" then
        local lastchild_index = retriever:retrieve_lastchild_lnum(lnum) ---@type integer|nil
        if lastchild_index ~= nil and lnum <= lastchild_index then
          local next_selected = not treeview:isselected(nodeuuid) ---@type boolean
          for index = lnum, lastchild_index, 1 do
            local childuuid = retriever:retrieve_uuid(index) ---@type string|nil
            if childuuid ~= nil then
              local childstate = treeview:retrieve(childuuid) ---@type eve.ux.view.filetree.INodeState|nil
              if childstate ~= nil and childstate.nodetype ~= "location" then
                treeview:toggle_select(childuuid, next_selected, true) ---@type boolean
                picker.result:toggle_selected(index, next_selected)
              end
            end
          end
        end
        return
      end

      if nodestate.nodetype == "leaf" then
        local next_selected = not treeview:isselected(nodeuuid) ---@type boolean
        treeview:toggle_select(nodeuuid, next_selected, true) ---@type boolean
        picker.result:toggle_selected(lnum)
        return
      end

      if nodestate.nodetype == "location" then
        nodeuuid = nodestate.leafuuid ---@type string
        lnum = retriever:retrieve_lnum(nodeuuid) or lnum ---@type integer
        local next_selected = not treeview:isselected(nodeuuid) ---@type boolean
        treeview:toggle_select(nodeuuid, next_selected, true) ---@type boolean
        picker.result:toggle_selected(lnum)
        return
      end

      std.reporter.error({
        from = self.fullname,
        subject = "on_toggle_selection",
        message = "Unknown nodetype",
        details = {
          nodeuuid = nodeuuid,
          nodestate = nodestate,
        },
      })
    end,
  }

  ---@type std.t.IKeymap[]
  local finder_keymaps = {
    {
      modes = { "n", "v" },
      key = ".",
      desc = "filetree: change root",
      callback = actions.on_filetree_attach,
    },
    {
      modes = { "n", "v" },
      key = "<Backspace>",
      desc = "filetree: change root to parent",
      callback = actions.on_filetree_attach_parent,
    },
    {
      modes = { "i", "n", "v" },
      key = "<enter>",
      desc = "filetree: open",
      callback = actions.on_filetree_open,
    },
    {
      modes = { "i", "n", "v" },
      key = "<C-h>",
      aliases = { "<C-l>" },
      desc = "filetree: toggle",
      callback = actions.on_filetree_toggle,
    },
    {
      modes = { "n", "v" },
      key = "<Tab>",
      desc = "filetree: toggle selection",
      callback = actions.on_toggle_selection,
    },
  }

  ---@type std.t.IKeymap[]
  local result_keymaps = {
    {
      modes = { "i", "n", "v" },
      key = ".",
      desc = "filetree: change root",
      callback = actions.on_filetree_attach,
    },
    {
      modes = { "n", "v" },
      key = "<Backspace>",
      desc = "filetree: change root to parent",
      callback = actions.on_filetree_attach_parent,
    },
    {
      modes = { "i", "n", "v" },
      key = "<Enter>",
      aliases = { "o", "w" },
      desc = "filetree: open",
      callback = actions.on_filetree_open,
    },
    {
      modes = { "i", "n", "v" },
      key = "<Right>",
      aliases = { "<Left>", "c", "h", "l" },
      desc = "filetree: toggle",
      callback = actions.on_filetree_toggle,
    },
    {
      modes = { "i", "n", "v" },
      key = "<2-LeftMouse>",
      desc = "filetree: toggle",
      callback = function()
        local result_winnr = self._picker.result:get_winnr() ---@type integer|nil
        if result_winnr ~= nil and vim.api.nvim_win_is_valid(result_winnr) then
          local cursor = vim.fn.getmousepos()
          if cursor.winid == result_winnr then
            actions.on_filetree_toggle()
          end
        end
      end,
    },
    {
      modes = { "i", "n", "v" },
      key = "z",
      desc = "filetree: toggle (recursively)",
      callback = actions.on_filetree_toggle_recursively,
    },
    {
      modes = { "i", "n", "v" },
      key = "<Tab>",
      desc = "filetree: toggle selection",
      callback = actions.on_toggle_selection,
    },
  }

  local picker = eve.ux.PickerComposer.new({
    uuid = picker_uuid,
    name = fullname,
    permanent = permanent,

    flags = flags,
    flags_start_index = flags_start_index,
    height = height,
    width = width,

    finder_input = finder_input,
    finder_input_history = finder_input_history,
    finder_keymaps = finder_keymaps,
    finder_multiline = finder_multiline,
    finder_title = title,

    result_keymaps = result_keymaps,
    ---@type eve.ux.picker.result.IDraw
    result_render = function(bufnr)
      local viewtype = flag_viewtype:snapshot() ---@type eve.ux.view.tree.ViewtypeEnum
      local result ---@type eve.ux.view.tree.IRenderResult
      local only_matched = finder_input:snapshot() ~= "" ---@type boolean
      local only_selected = flag_selected:snapshot() ---@type boolean

      if viewtype == "list" then
        result = treeview:render_listview({
          bufnr = bufnr,
          rootuuid = self._uuid_root,
          orders = self._uuids_order,
          only_matched = only_matched,
          only_selected = only_selected,
          only_visible = true,
        })
      elseif viewtype == "tree" then
        local foldempty = flag_foldempty:snapshot() ---@type boolean
        result = treeview:render_treeview({
          bufnr = bufnr,
          rootuuid = self._uuid_root,
          foldempty = foldempty,
          only_expanded = true,
          only_matched = only_matched,
          only_selected = only_selected,
          only_visible = true,
        })
      end

      retriever:attach(bufnr, result.uuids, result.childline)

      local uuid_current = self._uuid_current ---@type string|nil
      local lnums_selected = self:__collect_selected_lnums__() ---@type integer[]
      local lnum_current = uuid_current ~= nil and retriever:retrieve_lnum(uuid_current) or nil ---@type integer|nil
      local ret = { lnum_current = lnum_current, lnums_selected = lnums_selected } ---@type eve.ux.picker.result.IDrawResult
      return ret
    end,

    ---@type eve.ux.picker.preview.IDraw|nil
    preview_render = preview
        and function(bufnr)
          local nodeuuid, lnum = retrieve() ---@type string|nil, integer
          if nodeuuid == nil then
            local lines = { string.format("Error: cannot retrieve node by the given lnum: %d", lnum) } ---@type string[]
            vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
            self._last_preview_filepath = nil

            ---@type eve.ux.picker.preview.IDrawResult
            local result = {
              cursorline = true,
              number = true,
              title = string.format("Unknown lnum(%d)", lnum),
              wrap = true,
              whitespaces = nil,
              lnum = 1,
            }
            return result
          end

          local node, nodestate = self:__retrieve__(nodeuuid)
          local force = node.data.filepath ~= self._last_preview_filepath ---@type boolean
          self._last_preview_filepath = node.data.filepath ---@type string|nil

          local rootnode = filetree:retrieve(self._uuid_root) ---@type std.collection.filetree.INode|nil
          local filepath = node.data.filepath ---@type string
          local relative_filepath = rootnode ~= nil
              and std.path.relative(rootnode.data.filepath or std.path.cwd(), filepath, false)
            or filepath

          if nodestate.nodetype == "container" then
            treeview:render_treeview({
              bufnr = bufnr,
              rootuuid = nodeuuid,
              foldempty = flag_foldempty:snapshot(),
              only_expanded = false,
              only_matched = false,
              only_selected = false,
              only_visible = false,
            })

            ---@cast nodestate          eve.ux.view.filetree.IDirectoryNodeState
            ---@type eve.ux.picker.preview.IDrawResult
            local result = {
              cursorline = true,
              number = true,
              title = relative_filepath,
              whitespaces = false,
              wrap = false,
              lnum = 1,
            }
            return result
          end

          if nodestate.nodetype == "leaf" then
            ---@cast nodestate          eve.ux.view.filetree.IFileNodeState
            if nodestate.locations ~= nil and #nodestate.locations > 0 then
              ---@diagnostic disable-next-line: cast-local-type
              nodestate = nodestate.locations[1]
            end
          end
          ---@cast nodestate          eve.ux.view.filetree.IFileNodeState|eve.ux.view.filetree.ILocationNodeState

          plainfile:render(bufnr, filepath, force)

          ---@type eve.ux.picker.preview.IDrawResult
          local result = {
            cursorline = true,
            number = true,
            title = relative_filepath,
            whitespaces = true,
            wrap = false,
            lnum = nodestate.lnum,
            col = nodestate.col,
          }
          return result
        end
      or nil,

    on_cancel = function()
      if on_confirm ~= nil then
        on_confirm(self, nil)
      end
    end,
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
    on_refresh = function(picker, force)
      on_refresh(self, force)

      picker:mark_preview_dirty()
      picker:mark_result_flags_dirty()
      picker:mark_result_dirty()
    end,
  })

  self.uuid = picker_uuid
  self.fullname = fullname

  self.finder = picker.finder
  self.result = picker.result
  self.preview = picker.preview

  self.flag_foldempty = flag_foldempty
  self.flag_fuzzy = flag_fuzzy
  self.flag_regex = flag_regex
  self.flag_sensitive = flag_sensitive
  self.flag_selected = flag_selected

  self._disposed = false
  self._filetree = filetree
  self._frecency = frecency
  self._picker = picker
  self._plainfile = plainfile
  self._retriever = retriever
  self._scheduler_match = scheduler_match
  self._treeview = treeview

  self._last_preview_filepath = nil
  self._uuid_root = nil
  self._uuids_file = {}
  self._uuids_order = {}

  self._on_confirm = on_confirm
  self._on_disposed = on_disposed

  std.fn.observe(
    { finder_input, flag_foldempty, flag_fuzzy, flag_regex, flag_sensitive, flag_selected, flag_viewtype },
    function()
      picker:mark_result_flags_dirty()
    end,
    true
  )
  std.fn.observe({ flag_selected, flag_viewtype }, function()
    picker:mark_result_dirty()
  end, true)
  std.fn.observe({ finder_input, flag_fuzzy, flag_regex, flag_sensitive }, function()
    scheduler_match:schedule()
  end)
  std.fn.observe({ picker.result.lnum_current }, function()
    local lnum = picker.result.lnum_current:snapshot() ---@type integer
    local uuid = retriever:retrieve_uuid(lnum) ---@type string|nil
    if uuid ~= nil then
      self._uuid_current = uuid
    end
  end)

  return self
end

---@return nil
function M:dispose()
  if self._disposed then
    return
  end
  self._disposed = true

  local fullname = self.fullname
  local on_dispose = self._on_disposed ---@type eve.ux.picker.composer.IOnDisposed
  local picker = self._picker ---@type eve.ux.PickerComposer
  local plainfile = self._plainfile ---@type eve.ux.view.Plainfile
  local scheduler_match = self._scheduler_match ---@type std.collection.Scheduler
  local treeview = self._treeview ---@type eve.ux.view.Filetree

  vim.schedule(function()
    local ok1, error1 = pcall(scheduler_match.dispose, scheduler_match)
    local ok2, error2 = pcall(treeview.dispose, treeview)
    local ok3, error3 = pcall(picker.dispose, picker)
    local ok4, error4 = pcall(plainfile.dispose, plainfile)
    local ok5, error5 = pcall(on_dispose)

    if not (ok1 and ok2 and ok3 and ok4 and ok5) then
      std.reporter.error({
        from = fullname,
        subject = "dispose",
        message = "Failed to dispose",
        details = {
          error1 = not ok1 and error1 or nil,
          error2 = not ok2 and error2 or nil,
          error3 = not ok3 and error3 or nil,
          error4 = not ok4 and error4 or nil,
          error5 = not ok5 and error5 or nil,
        },
      })
    end
  end)

  self._retriever:dispose()

  self.finder = nil
  self.result = nil
  self.preview = nil

  self.flag_foldempty = nil
  self.flag_fuzzy = nil
  self.flag_regex = nil
  self.flag_sensitive = nil
  self.flag_selected = nil

  self._frecency = nil
  self._picker = nil
  self._plainfile = nil
  self._retriever = nil
  self._scheduler_match = nil
  self._treeview = nil

  self._last_preview_filepath = nil
  self._uuid_root = nil
  self._uuids_file = nil
  self._uuids_order = nil

  self._on_confirm = nil
  self._on_disposed = nil
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

  local node = self._filetree:retrieve(uuid) ---@type std.collection.filetree.INode|nil
  if node == nil then
    std.reporter.error({
      from = __module_name__,
      subject = "attach",
      message = string.format("Cannot find node by the given uuid: %s", uuid),
    })
    return self
  end

  self._treeview:mark_cache_listview_dirty()
  self._uuid_root = uuid
  self._scheduler_match:schedule()
  return self
end

---@return eve.ux.FilePicker
function M:clear_locations()
  self:__health__()
  self._treeview:clear_locations()
  return self
end

---@param fileuuid                     string
---@param lnum                          integer
---@param col                           integer|nil
---@param data                          unknown|nil
---@return eve.ux.FilePicker
function M:insert_location(fileuuid, lnum, col, data)
  self:__health__()
  self._treeview:insert_location(fileuuid, lnum, col, data)
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

  local frecency = self._frecency ---@type std.collection.IFrecency|nil
  local treeview = self._treeview ---@type eve.ux.view.Filetree

  cwd = std.path.normalize(cwd) ---@type string
  treeview:reset_filepaths(cwd, filepaths, with_positions)

  local uuid_cwd = std.Filetree.uuid(cwd) ---@type string
  local uuids_file = self._treeview:collect_file_uuids(uuid_cwd) ---@type string[]
  local uuids_order = vim.list_slice(uuids_file) ---@type string[]

  if frecency ~= nil then
    table.sort(uuids_order, function(a, b)
      local sa = frecency:score(a) or 0 ---@type integer
      local sb = frecency:score(b) or 0 ---@type integer
      return sa > sb
    end)
  end

  self._last_preview_filepath = nil
  self._uuid_root = uuid_cwd
  self._uuids_file = uuids_file
  self._uuids_order = uuids_order
  self._scheduler_match:schedule()
  return self
end

----------------------------------------------------------------------------------------------------

---@protected
---@return integer[]
function M:__collect_selected_lnums__()
  self:__health__()

  local retriever = self._retriever ---@type eve.ux.view.TreeRetriever
  local treeview = self._treeview ---@type eve.ux.view.Filetree

  local linecount = retriever:linecount() ---@type integer
  if linecount < 1 then
    return {}
  end

  local lnums = {} ---@type integer[]
  for lnum = 1, linecount, 1 do
    local uuid = retriever:retrieve_uuid(lnum) ---@type string|nil
    if uuid ~= nil then
      local isselected = treeview:isselected(uuid) ---@type boolean
      if isselected then
        lnums[#lnums + 1] = lnum
      end
    end
  end
  return lnums
end

---@protected
---@return string[]
function M:__collect_selected_uuids__()
  self:__health__()

  local retriever = self._retriever ---@type eve.ux.view.TreeRetriever
  if retriever:linecount() < 1 then
    return {}
  end

  local treeview = self._treeview ---@type eve.ux.view.Filetree
  local lastchild_lnum = retriever:retrieve_lastchild_lnum(1)

  local uuids = {} ---@type string[]
  for lnum = 1, lastchild_lnum, 1 do
    local uuid = retriever:retrieve_uuid(lnum) ---@type string|nil
    if uuid ~= nil then
      local isselected = treeview:isselected(uuid) ---@type boolean
      if isselected then
        uuids[#uuids + 1] = uuid
      end
    end
  end
  return uuids
end

---@protected
---@return boolean
function M:__has_selected_node__()
  self:__health__()

  local retriever = self._retriever ---@type eve.ux.view.TreeRetriever
  if retriever:linecount() < 1 then
    return false
  end

  local treeview = self._treeview ---@type eve.ux.view.Filetree
  local lastchild_lnum = retriever:retrieve_lastchild_lnum(1)

  for lnum = 1, lastchild_lnum, 1 do
    local uuid = retriever:retrieve_uuid(lnum) ---@type string|nil
    if uuid ~= nil then
      local isselected = treeview:isselected(uuid) ---@type boolean
      if isselected then
        return true
      end
    end
  end
  return false
end

---@protected
---@return nil
function M:__health__()
  if self._disposed then
    local message = string.format("[%s#%s] already been disposed.", __module_name__, self.fullname) ---@type string
    error(message)
  end
end

---@protected
---@param input                         string
---@return nil
function M:__match__(input)
  local frecency = self._frecency ---@type std.collection.IFrecency|nil
  local treeview = self._treeview ---@type eve.ux.view.Filetree

  if #input < 1 then
    local uuids_order = vim.list_slice(self._uuids_file) ---@type string[]
    self._uuids_order = uuids_order
    if frecency ~= nil then
      table.sort(uuids_order, function(a, b)
        local sa = frecency:score(a) or 0 ---@type integer
        local sb = frecency:score(b) or 0 ---@type integer
        return sa > sb
      end)
    end
    return
  end

  ---@type string[]
  local uuids_order = treeview:match({
    rootuuid = self._uuid_root,
    pattern = input,
    case_sensitive = self.flag_sensitive:snapshot(),
    fuzzy = self.flag_fuzzy:snapshot(),
    regex = self.flag_regex:snapshot(),
  })

  if frecency ~= nil then
    table.sort(uuids_order, function(a, b)
      local na = treeview:retrieve(a)
      local nb = treeview:retrieve(b)
      ---@cast na                       eve.ux.view.filetree.IFileNodeState
      ---@cast nb                       eve.ux.view.filetree.IFileNodeState

      local sa = na.cache_match and na.cache_match.score or 0 + (frecency:score(a) or 0) ---@type integer
      local sb = nb.cache_match and nb.cache_match.score or 0 + (frecency:score(b) or 0) ---@type integer
      return sa > sb
    end)
  else
    table.sort(uuids_order, function(a, b)
      local na = treeview:retrieve(a)
      local nb = treeview:retrieve(b)
      ---@cast na                       eve.ux.view.filetree.IFileNodeState
      ---@cast nb                       eve.ux.view.filetree.IFileNodeState

      local sa = na.cache_match and na.cache_match.score or 0 ---@type integer
      local sb = nb.cache_match and nb.cache_match.score or 0 ---@type integer
      return sa > sb
    end)
  end

  self._uuids_order = uuids_order
end

---@param nodeuuid                      string
---@return nil
function M:__open_node__(nodeuuid)
  local node, nodestate = self:__retrieve__(nodeuuid)

  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local winnr_sourcefile = eve.tab.retrieve_winnr_sourcefile(tabnr) ---@type integer|nil
  if winnr_sourcefile ~= nil and vim.api.nvim_win_is_valid(winnr_sourcefile) then
    vim.api.nvim_tabpage_set_win(tabnr, winnr_sourcefile)
  else
    winnr_sourcefile = nil
  end

  local filetree = self._filetree ---@type std.collection.Filetree
  local picker = self._picker ---@type eve.ux.PickerComposer
  local treeview = self._treeview ---@type eve.ux.view.Filetree

  if self:__has_selected_node__() then
    local last_nodestate = nil ---@type eve.ux.view.filetree.IFileNodeState|nil
    local filepaths = {} ---@type string[]

    local uuids_selected = self:__collect_selected_uuids__() ---@type string[]
    local N = #uuids_selected ---@type integer
    for index = 1, N, 1 do
      local uuid = uuids_selected[index] ---@type string
      local o = filetree:retrieve(uuid) ---@type std.collection.filetree.INode|nil
      if o ~= nil and o.data.filetype == "file" then
        local s = treeview:retrieve(nodeuuid) ---@type eve.ux.view.filetree.INodeState|nil
        if s ~= nil then
          ---@cast s                      eve.ux.view.filetree.IFileNodeState
          last_nodestate = s
          filepaths[#filepaths + 1] = o.data.filepath
        end
      end
    end

    if #filepaths > 0 then
      ---@cast last_nodestate             eve.ux.view.filetree.IFileNodeState
      local locations = last_nodestate.locations
      local first_location = locations ~= nil and locations[1] or nil ---@type eve.ux.view.filetree.ILocationNodeState|nil
      local lnum = first_location and first_location.lnum or nil ---@type integer|nil
      local col = first_location and first_location.col or nil ---@type integer|nil

      picker:close()
      eve.win.open_filepaths(winnr_sourcefile, filepaths, lnum, col)
      return
    end
  end

  if nodestate.nodetype == "container" then
    self._treeview:collapse(node.uuid, "toggle", false)
    picker:mark_result_dirty()
    return
  end

  if nodestate.nodetype == "leaf" and nodestate.collapsed then
    self._treeview:collapse(node.uuid, "expand", false)
    picker:mark_result_dirty()
    return
  end

  ---@cast nodestate                    eve.ux.view.filetree.IFileNodeState
  local locations = nodestate.locations
  local first_location = locations ~= nil and locations[1] or nil ---@type eve.ux.view.filetree.ILocationNodeState|nil
  local lnum = first_location and first_location.lnum or nil ---@type integer|nil
  local col = first_location and first_location.col or nil ---@type integer|nil
  picker:close()
  eve.win.open_filepath(winnr_sourcefile, node.data.filepath, lnum, col)
end

---@param nodeuuid                      string
---@return nil
function M:__resolve_confirmation__(nodeuuid)
  local node, nodestate = self:__retrieve__(nodeuuid)

  local filetree = self._filetree ---@type std.collection.Filetree
  local picker = self._picker ---@type eve.ux.PickerComposer
  local treeview = self._treeview ---@type eve.ux.view.Filetree

  local rootnode = filetree:retrieve(self._uuid_root) ---@type std.collection.filetree.INode|nil
  local rootpath = rootnode and rootnode.data.filepath or std.path.cwd() --@type string

  if self:__has_selected_node__() then
    local filepaths = {} ---@type string[]

    local uuids_selected = self:__collect_selected_uuids__() ---@type string[]
    local N = #uuids_selected ---@type integer
    for index = 1, N, 1 do
      local uuid = uuids_selected[index] ---@type string
      local o = filetree:retrieve(uuid) ---@type std.collection.filetree.INode|nil
      if o ~= nil and o.data.filetype == "file" then
        local filepath = std.path.relative(rootpath, o.data.filepath, false) ---@type string
        filepaths[#filepaths + 1] = filepath
      end
    end

    if #filepaths > 0 then
      picker:close()
      self._on_confirm(self, filepaths)
      return
    end
  end

  if nodestate.nodetype == "container" then
    treeview:collapse(node.uuid, "toggle", false)
    picker:mark_result_dirty()
    return
  end

  if nodestate.nodetype == "leaf" and nodestate.collapsed then
    treeview:collapse(node.uuid, "expand", false)
    picker:mark_result_dirty()
    return
  end

  local filepath = rootnode ~= nil and std.path.relative(rootnode.data.filepath, node.data.filepath, false)
    or node.data.filepath
  picker:close()
  self._on_confirm(self, { filepath })
end

---@param nodeuuid                      string
---@return std.collection.filetree.INode
---@return eve.ux.view.filetree.INodeState
function M:__retrieve__(nodeuuid)
  ---@type eve.ux.view.filetree.INodeState|nil
  local nodestate = self._treeview:retrieve(nodeuuid)
  if nodestate == nil then
    error(string.format("Cannot retrieve nodestate by the given uuid(%s)", nodeuuid))
  end

  ---@type std.collection.filetree.INode|nil
  local node = self._filetree:retrieve(nodestate.nodetype == "location" and nodestate.leafuuid or nodeuuid)
  if node == nil then
    error(string.format("Cannot retrieve node by the given uuid(%s), nodetype(%s)", nodeuuid, nodestate.nodetype))
  end

  return node, nodestate
end

---@param nodeuuid                      string
---@param recursively                   boolean
---@return nil
function M:__toggle_node__(nodeuuid, recursively)
  local node, nodestate = self:__retrieve__(nodeuuid)

  local treeview = self._treeview ---@type eve.ux.view.Filetree
  local picker = self._picker ---@type eve.ux.PickerComposer
  if nodestate.nodetype == "container" then
    treeview:collapse(node.uuid, "toggle", recursively)
    picker:mark_result_dirty()
    return
  end

  if nodestate.nodetype == "leaf" and #node.children > 0 then
    treeview:collapse(node.uuid, "toggle", false)
    picker:mark_result_dirty()
    return
  end

  if self._on_confirm == nil then
    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    local winnr_sourcefile = eve.tab.retrieve_winnr_sourcefile(tabnr) ---@type integer|nil
    if winnr_sourcefile ~= nil and vim.api.nvim_win_is_valid(winnr_sourcefile) then
      vim.api.nvim_tabpage_set_win(tabnr, winnr_sourcefile)
    else
      winnr_sourcefile = nil
    end

    picker:close()
    eve.win.open_filepath(winnr_sourcefile, node.data.filepath, nodestate.lnum, nodestate.col)
  end
end

return M
