---@diagnostic disable: invisible
local __module_name__ = "eve.ux.picker.composer.tree" ---@type string

---@alias eve.ux.picker.composer.tree.IOnAttached
---| fun(self: eve.ux.picker.TreeComposer, rootuuid: string): nil

---@alias eve.ux.picker.composer.tree.IOnClosed
---| fun(self: eve.ux.picker.TreeComposer): nil

---@alias eve.ux.picker.composer.tree.IOnConfirm
---| fun(self: eve.ux.picker.TreeComposer, uuids: string[]|nil): nil

---@alias eve.ux.picker.composer.tree.IOnDisposed
---| fun(): nil

---@alias eve.ux.picker.composer.tree.IOnFocused
---| fun(self: eve.ux.picker.TreeComposer): nil

---@alias eve.ux.picker.composer.tree.IOnHidden
---| fun(self: eve.ux.picker.TreeComposer): nil
---
---@alias eve.ux.picker.composer.tree.IOnRefresh
---| fun(self: eve.ux.picker.TreeComposer, force: boolean): nil

---@class eve.ux.picker.composer.tree.actions
---@field public on_tree_open       fun(): nil
---@field public on_tree_toggle     fun(): nil
---@field public on_tree_toggle_recursively fun(): nil
---@field public on_toggle_selection    fun(): nil

----------------------------------------------------------------------------------------------------

---@class eve.ux.picker.ITreeComposerProps
---@field public uuid                   ?string
---@field public name                   string
---@field public permanent              boolean
---@field public title                  string
---@field public height                 ?number
---@field public width                  ?number
---@field public node_sorter            std.collection.tree.INodeSorter
---
---@field public keymaps_common         ?std.t.IKeymap[]
---@field public keymaps_finder         ?std.t.IKeymap[]
---@field public keymaps_preview        ?std.t.IKeymap[]
---@field public keymaps_result         ?std.t.IKeymap[]
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
---@field public finder_input           std.collection.IObservable
---@field public finder_input_history   ?std.collection.IHistory
---@field public finder_multiline       ?boolean
---
---@field public render_preview             ?eve.ux.picker.preview.IDraw
---@field public render_listview_leaf       eve.ux.view.tree.IListviewLeafNodeRenderer
---@field public render_listview_location   eve.ux.view.tree.IListviewLeafLocationRenderer
---@field public render_treeview_container  eve.ux.view.tree.ITreeviewContainerNodeRenderer
---@field public render_treeview_leaf       eve.ux.view.tree.ITreeviewLeafNodeRenderer
---@field public render_treeview_location   eve.ux.view.tree.ITreeviewLeafLocationRenderer
---
---@field public on_attached            ?eve.ux.picker.composer.tree.IOnAttached
---@field public on_closed              ?eve.ux.picker.composer.tree.IOnClosed
---@field public on_confirm             ?eve.ux.picker.composer.tree.IOnConfirm
---@field public on_disposed            ?eve.ux.picker.composer.tree.IOnDisposed
---@field public on_focused             ?eve.ux.picker.composer.tree.IOnFocused
---@field public on_hidden              ?eve.ux.picker.composer.tree.IOnHidden
---@field public on_refresh             ?eve.ux.picker.composer.tree.IOnRefresh

---@class eve.ux.picker.TreeComposer
---@field public uuid                   string
---@field public fullname               string
---@field public title                  string
---
---@field public finder                 eve.ux.picker.Finder
---@field public result                 eve.ux.picker.Result
---@field public preview                eve.ux.picker.Preview
---
---@field public flag_foldempty         std.collection.IObservable
---@field public flag_fuzzy             std.collection.IObservable
---@field public flag_regex             std.collection.IObservable
---@field public flag_sensitive         std.collection.IObservable
---@field public flag_selected          std.collection.IObservable
---@field public flag_viewtype          std.collection.IObservable
---
---@field protected _disposed           boolean
---@field protected _tree           std.collection.Tree
---@field protected _composer           eve.ux.picker.BasicComposer
---@field protected _plainfile          eve.ux.view.Plainfile
---@field protected _retriever          eve.ux.picker.TreeRetriever
---@field protected _scheduler_match    std.collection.Scheduler|nil
---@field protected _treeview           eve.ux.view.Tree
---
---@field protected _last_preview_filepath  string|nil
---@field protected _uuid_root          string|nil
---@field protected _uuid_current       string|nil
---@field protected _uuids_file         string[]
---@field protected _uuids_order        string[]
---
---@field protected _on_attached        eve.ux.picker.composer.tree.IOnAttached
---@field protected _on_confirm         eve.ux.picker.composer.tree.IOnConfirm
---@field protected _on_disposed        eve.ux.picker.composer.tree.IOnDisposed
local M = {}
M.__index = M

---@param props                         eve.ux.picker.ITreeComposerProps
---@return eve.ux.picker.TreeComposer
function M.new(props)
  local name = props.name ---@type string
  local fullname = string.format("%s -> %s", name, __module_name__) ---@type string
  local picker_uuid = props.uuid or std.fn.uuid() ---@type string
  local permanent = props.permanent ---@type boolean
  local title = props.title ---@type string
  local height = props.height ---@type number|nil
  local width = props.width ---@type number|nil
  local node_sorter = props.node_sorter ---@type std.collection.tree.INodeSorter

  local finder_input = props.finder_input ---@type std.collection.IObservable
  local finder_input_history = props.finder_input_history ---@type std.collection.IHistory|nil
  local finder_multiline = props.finder_multiline ---@type boolean|nil

  local keymaps_common = props.keymaps_common ---@type std.t.IKeymap[]|nil
  local keymaps_finder = props.keymaps_finder ---@type std.t.IKeymap[]|nil
  local keymaps_preview = props.keymaps_preview ---@type std.t.IKeymap[]|nil
  local keymaps_result = props.keymaps_result ---@type std.t.IKeymap[]|nil

  local flag_fuzzy = props.flag_fuzzy ---@type std.collection.IObservable
  local flag_regex = props.flag_regex ---@type std.collection.IObservable
  local flag_foldempty = props.flag_foldempty ---@type std.collection.IObservable
  local flag_sensitive = props.flag_sensitive ---@type std.collection.IObservable
  local flag_selected = props.flag_selected ---@type std.collection.IObservable
  local flag_viewtype = props.flag_viewtype ---@type std.collection.IObservable
  local flags_append = props.flags_append ---@type eve.ux.picker.result.IFlagItemRaw[]|nil
  local flags_prepend = props.flags_prepend ---@type eve.ux.picker.result.IFlagItemRaw[]|nil
  local flags_start_index = props.flags_start_index ---@type 0|1|nil

  local render_preview = props.render_preview ---@type eve.ux.picker.preview.IDraw|nil
  local render_listview_leaf = props.render_listview_leaf ---@type eve.ux.view.tree.IListviewLeafNodeRenderer
  local render_listview_location = props.render_listview_location ---@type eve.ux.view.tree.IListviewLeafLocationRenderer
  local render_treeview_container = props.render_treeview_container ---@type eve.ux.view.tree.ITreeviewContainerNodeRenderer
  local render_treeview_leaf = props.render_treeview_leaf ---@type eve.ux.view.tree.ITreeviewLeafNodeRenderer
  local render_treeview_location = props.render_treeview_location ---@type eve.ux.view.tree.ITreeviewLeafLocationRenderer

  local on_attached = props.on_attached or std.fn.noop ---@type eve.ux.picker.composer.tree.IOnAttached
  local on_closed = props.on_closed or std.fn.noop ---@type eve.ux.picker.composer.tree.IOnClosed
  local on_confirm = props.on_confirm or std.fn.noop ---@type eve.ux.picker.composer.tree.IOnConfirm
  local on_disposed = props.on_disposed or std.fn.noop ---@type eve.ux.picker.composer.tree.IOnDisposed
  local on_focused = props.on_focused or std.fn.noop ---@type eve.ux.picker.composer.tree.IOnFocused
  local on_hidden = props.on_hidden or std.fn.noop ---@type eve.ux.picker.composer.tree.IOnHidden
  local on_refresh = props.on_refresh or std.fn.noop ---@type eve.ux.picker.composer.tree.IOnRefresh

  local tree = std.Tree.new({
    name = fullname,
    node_sorter = node_sorter,
  })

  local self = setmetatable({}, M)

  ---@type eve.ux.picker.TreeRetriever
  local retriever = eve.ux.picker.TreeRetriever.new({
    name = fullname,
  })

  ---@type eve.ux.view.Plainfile
  local plainfile = eve.ux.view.Plainfile.new({
    name = fullname,
  })

  ---@type eve.ux.view.Tree
  local treeview = eve.ux.view.Tree.new({
    name = fullname,
    tree = tree,
    flag_foldempty = flag_foldempty,
    indent = "",
    indent_hln = "f_utw_indent_float",
    render_listview_leaf = render_listview_leaf,
    render_listview_location = render_listview_location,
    render_treeview_container = render_treeview_container,
    render_treeview_leaf = render_treeview_leaf,
    render_treeview_location = render_treeview_location,
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
    local lnum = self._composer:get_result_lnum() ---@type integer
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
        self._composer:mark_result_dirty()
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

  ---@type eve.ux.picker.composer.tree.actions
  local actions = {
    on_goto_lnum_parent = function()
      local nodeuuid, lnum = retrieve() ---@type string|nil, integer
      local node = nodeuuid ~= nil and tree:retrieve(nodeuuid) or nil ---@type std.collection.tree.INode|nil
      local lnum_parent = node ~= nil and retriever:retrieve_lnum(node.parent) or nil ---@type integer|nil
      if lnum_parent ~= nil then
        if lnum == lnum_parent then
          lnum_parent = lnum_parent > 1 and lnum_parent - 1 or lnum_parent ---@type integer
        end
        self._composer.result:set_lnum_current(lnum_parent)
      end
    end,
    on_goto_lnum_lastchild = function()
      local nodeuuid, lnum = retrieve() ---@type string|nil, integer
      if nodeuuid ~= nil then
        local lnum_lastchild = retriever:retrieve_lastchild_lnum(lnum) ---@type integer|nil
        if lnum_lastchild ~= nil then
          self._composer.result:set_lnum_current(lnum_lastchild)
        end
      end
    end,
    on_tree_open = function()
      local nodeuuid = retrieve() ---@type string|nil
      if nodeuuid ~= nil then
        self:__resolve_confirmation__(nodeuuid)
      end
    end,
    on_tree_toggle = function()
      local nodeuuid = retrieve() ---@type string|nil
      if nodeuuid ~= nil then
        self:__toggle_node__(nodeuuid, false)
      end
    end,
    on_tree_attach = function()
      local nodeuuid = retrieve() ---@type string|nil
      if nodeuuid ~= nil then
        local nodestate = treeview:retrieve(nodeuuid) ---@type eve.ux.view.tree.INodeState|nil
        if nodestate ~= nil and nodestate.nodetype == "container" then
          treeview:mark_cache_listview_dirty()
          self._uuid_root = nodeuuid ---@type string
          self:mark_result_dirty()

          on_attached(self, nodeuuid) ---@type eve.ux.picker.composer.tree.IOnAttached
        end
      end
    end,
    on_tree_attach_parent = function()
      local rootuuid = self._uuid_root ---@type string
      local rootnode = tree:retrieve(rootuuid) ---@type std.collection.tree.INode|nil
      if rootnode and rootnode.parent ~= rootuuid then
        treeview:mark_cache_listview_dirty()
        self._uuid_root = rootnode.parent ---@type string
        self:mark_result_dirty()

        on_attached(self, rootnode.parent) ---@type eve.ux.picker.composer.tree.IOnAttached
      end
    end,
    on_tree_toggle_recursively = function()
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

      local nodestate = treeview:retrieve(nodeuuid) ---@type eve.ux.view.tree.INodeState|nil
      if nodestate == nil then
        return
      end

      local composer = self._composer ---@type eve.ux.picker.BasicComposer
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
              local childstate = treeview:retrieve(childuuid) ---@type eve.ux.view.tree.INodeState|nil
              if childstate ~= nil and childstate.nodetype ~= "location" then
                treeview:toggle_select(childuuid, next_selected, true) ---@type boolean
              end
            end
          end
        end
        composer.result:refresh_signs()
        return
      end

      if nodestate.nodetype == "leaf" then
        local next_selected = not treeview:isselected(nodeuuid) ---@type boolean
        treeview:toggle_select(nodeuuid, next_selected, true) ---@type boolean
        composer.result:refresh_signs()
        return
      end

      if nodestate.nodetype == "location" then
        nodeuuid = nodestate.leafuuid ---@type string
        lnum = retriever:retrieve_lnum(nodeuuid) or lnum ---@type integer
        local next_selected = not treeview:isselected(nodeuuid) ---@type boolean
        treeview:toggle_select(nodeuuid, next_selected, true) ---@type boolean
        composer.result:refresh_signs()
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
  local preset_keymaps_common = {}

  ---@type std.t.IKeymap[]
  local preset_keymaps_finder = {
    {
      modes = { "n", "v" },
      key = ".",
      desc = "tree: change root",
      callback = actions.on_tree_attach,
    },
    {
      modes = { "n", "v" },
      key = "<Backspace>",
      desc = "tree: change root to parent",
      callback = actions.on_tree_attach_parent,
    },
    {
      modes = { "i", "n", "v" },
      key = "<Enter>",
      desc = "tree: open",
      callback = actions.on_tree_open,
    },
    {
      modes = { "i", "n", "v" },
      key = "<C-h>",
      aliases = { "<C-l>" },
      desc = "tree: toggle",
      callback = actions.on_tree_toggle,
    },
    {
      modes = { "n", "v" },
      key = "<Tab>",
      desc = "tree: toggle selection",
      callback = actions.on_toggle_selection,
    },
    {
      modes = { "n", "v" },
      key = "[i",
      desc = "tree: goto the parent line",
      callback = actions.on_goto_lnum_parent,
    },
    {
      modes = { "n", "v" },
      key = "]i",
      desc = "tree: goto the lastchild line",
      callback = actions.on_goto_lnum_lastchild,
    },
    {
      modes = { "n", "v" },
      key = "z",
      desc = "tree: toggle (recursively)",
      callback = actions.on_tree_toggle_recursively,
    },
  }

  ---@type std.t.IKeymap[]
  local preset_keymaps_result = {
    {
      modes = { "i", "n", "v" },
      key = ".",
      desc = "tree: change root",
      callback = actions.on_tree_attach,
    },
    {
      modes = { "i", "n", "v" },
      key = "<Backspace>",
      desc = "tree: change root to parent",
      callback = actions.on_tree_attach_parent,
    },
    {
      modes = { "i", "n", "v" },
      key = "<Enter>",
      aliases = { "l", "w" },
      desc = "tree: open",
      callback = actions.on_tree_open,
    },
    {
      modes = { "i", "n", "v" },
      key = "<Right>",
      aliases = { "<Left>", "c", "h" },
      desc = "tree: toggle",
      callback = actions.on_tree_toggle,
    },
    {
      modes = { "i", "n", "v" },
      key = "<2-LeftMouse>",
      desc = "tree: toggle",
      callback = function()
        local result_winnr = self._composer.result:get_winnr() ---@type integer|nil
        if result_winnr ~= nil and vim.api.nvim_win_is_valid(result_winnr) then
          local cursor = vim.fn.getmousepos()
          if cursor.winid == result_winnr then
            actions.on_tree_toggle()
          end
        end
      end,
    },
    {
      modes = { "i", "n", "v" },
      key = "<Tab>",
      desc = "tree: toggle selection",
      callback = actions.on_toggle_selection,
    },
    {
      modes = { "i", "n", "v" },
      key = "[i",
      desc = "tree: goto the parent line",
      callback = actions.on_goto_lnum_parent,
    },
    {
      modes = { "i", "n", "v" },
      key = "]i",
      desc = "tree: goto the lastchild line",
      callback = actions.on_goto_lnum_lastchild,
    },
    {
      modes = { "i", "n", "v" },
      key = "z",
      desc = "tree: toggle (recursively)",
      callback = actions.on_tree_toggle_recursively,
    },
  }

  local composer = eve.ux.picker.BasicComposer.new({
    uuid = picker_uuid,
    name = fullname,
    permanent = permanent,

    flags = flags,
    flags_start_index = flags_start_index,
    height = height,
    width = width,

    keymaps_common = keymaps_common and vim.list_extend(preset_keymaps_common, keymaps_common) or preset_keymaps_common,
    keymaps_finder = keymaps_finder and vim.list_extend(preset_keymaps_finder, keymaps_finder) or preset_keymaps_finder,
    keymaps_result = keymaps_result and vim.list_extend(preset_keymaps_result, keymaps_result) or preset_keymaps_result,
    keymaps_preview = keymaps_preview,

    finder_input = finder_input,
    finder_input_history = finder_input_history,
    finder_multiline = finder_multiline,
    finder_title = title,

    result_number = true,

    ---@type eve.ux.picker.result.IIsSelected
    result_isselected = function(_, lnum)
      local uuid = retriever:retrieve_uuid(lnum) ---@type string|nil
      return uuid ~= nil and treeview:isselected(uuid)
    end,

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

      retriever:attach(bufnr, result.lnum2uuid, result.uuid2lnum, result.childline)

      local uuid_current = self._uuid_current ---@type string|nil
      local lnum_current = uuid_current ~= nil and retriever:retrieve_lnum(uuid_current) or nil ---@type integer|nil
      local ret = { lnum_current = lnum_current } ---@type eve.ux.picker.result.IDrawResult
      return ret
    end,

    ---@type eve.ux.picker.preview.IDraw|nil
    preview_render = render_preview,

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

  self.finder = composer.finder
  self.result = composer.result
  self.preview = composer.preview

  self.flag_foldempty = flag_foldempty
  self.flag_fuzzy = flag_fuzzy
  self.flag_regex = flag_regex
  self.flag_sensitive = flag_sensitive
  self.flag_selected = flag_selected

  self._disposed = false
  self._tree = tree
  self._composer = composer
  self._plainfile = plainfile
  self._retriever = retriever
  self._scheduler_match = scheduler_match
  self._treeview = treeview

  self._last_preview_filepath = nil
  self._uuid_root = nil
  self._uuids_file = {}
  self._uuids_order = {}

  self._on_attached = on_attached
  self._on_confirm = on_confirm
  self._on_disposed = on_disposed

  std.fn.observe(
    { finder_input, flag_foldempty, flag_fuzzy, flag_regex, flag_sensitive, flag_selected, flag_viewtype },
    function()
      composer:mark_result_flags_dirty()
    end,
    true
  )
  std.fn.observe({ flag_selected, flag_viewtype }, function()
    composer:mark_result_dirty()
  end, true)
  std.fn.observe({ finder_input, flag_fuzzy, flag_regex, flag_sensitive }, function()
    scheduler_match:schedule()
  end)
  std.fn.observe({ composer.result.lnum_current }, function()
    local lnum = composer.result.lnum_current:snapshot() ---@type integer
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
  local on_dispose = self._on_disposed ---@type eve.ux.picker.composer.tree.IOnDisposed
  local composer = self._composer ---@type eve.ux.picker.BasicComposer
  local plainfile = self._plainfile ---@type eve.ux.view.Plainfile
  local retriever = self._retriever ---@type eve.ux.picker.TreeRetriever
  local scheduler_match = self._scheduler_match ---@type std.collection.Scheduler
  local treeview = self._treeview ---@type eve.ux.view.Tree

  vim.schedule(function()
    local ok1, error1 = pcall(scheduler_match.dispose, scheduler_match)
    local ok2, error2 = pcall(treeview.dispose, treeview)
    local ok3, error3 = pcall(composer.dispose, composer)
    local ok4, error4 = pcall(plainfile.dispose, plainfile)
    local ok5, error5 = pcall(retriever.dispose, retriever)
    local ok6, error6 = pcall(on_dispose)

    if not (ok1 and ok2 and ok3 and ok4 and ok5 and ok6) then
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
          error6 = not ok6 and error6 or nil,
        },
      })
    end
  end)

  self.finder = nil
  self.result = nil
  self.preview = nil

  self.flag_foldempty = nil
  self.flag_fuzzy = nil
  self.flag_regex = nil
  self.flag_sensitive = nil
  self.flag_selected = nil

  self._composer = nil
  self._plainfile = nil
  self._retriever = nil
  self._scheduler_match = nil
  self._treeview = nil

  self._last_preview_filepath = nil
  self._uuid_root = nil
  self._uuids_file = nil
  self._uuids_order = nil

  self._on_attached = nil
  self._on_confirm = nil
  self._on_disposed = nil
end

---@return boolean
function M:isdisposed()
  return self._disposed
end

---@param uuid                          string
---@return boolean
function M:isexistent(uuid)
  return self._tree:isexistent(uuid)
end

---@return boolean
function M:isfocused()
  return self._composer:isfocused()
end

---@return boolean
function M:isvisible()
  return self._composer:isvisible()
end

---@return nil
function M:close()
  self._composer:close()
end

---@return nil
function M:focus()
  self._composer:focus()
end

---@return nil
function M:hide()
  self._composer:hide()
end

---@return nil
function M:resize()
  self._composer:resize()
end

----------------------------------------------------------------------------------------------------

---@param rootuuid                      string
---@return eve.ux.picker.TreeComposer
function M:attach(rootuuid)
  self:__health__()
  if self._uuid_root == rootuuid then
    return self
  end

  local node = self._tree:retrieve(rootuuid) ---@type std.collection.tree.INode|nil
  if node == nil then
    std.reporter.error({
      from = __module_name__,
      subject = "attach",
      message = string.format("Cannot find node by the given uuid: %s", rootuuid),
    })
    return self
  end

  local treeview = self._treeview ---@type eve.ux.view.Tree

  treeview:mark_cache_listview_dirty()
  self._uuid_root = rootuuid
  self._scheduler_match:schedule()

  self._on_attached(self, rootuuid)
  return self
end

---@return eve.ux.picker.TreeComposer
function M:mark_result_dirty()
  self:__health__()
  self._composer:mark_result_dirty()
  return self
end

---@return eve.ux.picker.TreeComposer
function M:mark_result_flags_dirty()
  self:__health__()
  self._composer:mark_result_flags_dirty()
  return self
end

----------------------------------------------------------------------------------------------------

---@protected
---@return string[]
function M:__collect_selected_uuids__()
  self:__health__()

  local retriever = self._retriever ---@type eve.ux.picker.TreeRetriever
  if retriever:linecount() < 1 then
    return {}
  end

  local treeview = self._treeview ---@type eve.ux.view.Tree
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
  local treeview = self._treeview ---@type eve.ux.view.Tree

  if #input < 1 then
    local uuids_order = vim.list_slice(self._uuids_file) ---@type string[]
    self._uuids_order = uuids_order
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
  self._uuids_order = uuids_order
end

---@param nodeuuid                      string
---@return nil
function M:__resolve_confirmation__(nodeuuid)
  local composer = self._composer ---@type eve.ux.picker.BasicComposer

  local uuids = self:__collect_selected_uuids__() ---@type string[]
  if #uuids > 0 then
    composer:close()
    self._on_confirm(self, uuids)
    return
  end

  composer:close()
  self._on_confirm(self, { nodeuuid })
end

---@param nodeuuid                      string
---@return std.collection.tree.INode
---@return eve.ux.view.tree.INodeState
function M:__retrieve__(nodeuuid)
  ---@type eve.ux.view.tree.INodeState|nil
  local nodestate = self._treeview:retrieve(nodeuuid)
  if nodestate == nil then
    error(string.format("Cannot retrieve nodestate by the given uuid(%s)", nodeuuid))
  end

  ---@type std.collection.tree.INode|nil
  local node = self._tree:retrieve(nodestate.nodetype == "location" and nodestate.leafuuid or nodeuuid)
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

  local composer = self._composer ---@type eve.ux.picker.BasicComposer
  local treeview = self._treeview ---@type eve.ux.view.Tree
  if nodestate.nodetype == "container" then
    treeview:collapse(node.uuid, "toggle", recursively)
    composer:mark_result_dirty()
    return
  end

  if nodestate.nodetype == "leaf" and #node.children > 0 then
    treeview:collapse(node.uuid, "toggle", false)
    composer:mark_result_dirty()
    return
  end

  composer:close()
  self._on_confirm(self, { nodeuuid })
end

return M
