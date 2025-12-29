---@diagnostic disable: invisible
local __module_name__ = "dot.module.picker.composer.tree" ---@type string

---@alias dot.module.picker.composer.tree.IOnAttached
---| fun(self: dot.module.picker.TreeComposer, rootuuid: string): nil

---@alias dot.module.picker.composer.tree.IOnClosed
---| fun(self: dot.module.picker.TreeComposer): nil

---@alias dot.module.picker.composer.tree.IOnConfirm
---| fun(self: dot.module.picker.TreeComposer, uuids: string[]|nil): nil

---@alias dot.module.picker.composer.tree.IOnDisposed
---| fun(): nil

---@alias dot.module.picker.composer.tree.IOnEnter
---| fun(self: dot.module.picker.TreeComposer, nodeuuid: string): boolean

---@alias dot.module.picker.composer.tree.IOnFocused
---| fun(self: dot.module.picker.TreeComposer): nil

---@alias dot.module.picker.composer.tree.IOnHidden
---| fun(self: dot.module.picker.TreeComposer): nil
---
---@alias dot.module.picker.composer.tree.IOnRefresh
---| fun(self: dot.module.picker.TreeComposer, force: boolean): nil

---@class dot.module.picker.composer.tree.actions
---@field public attach_node            fun(): nil
---@field public attach_parent          fun(): nil
---@field public goto_lnum_lastchild    fun(): nil
---@field public goto_lnum_parent       fun(): nil
---@field public mark_node_invisible    fun(): nil
---@field public mark_subroot_invisible fun(): nil
---@field public open_node              fun(): nil
---@field public collapse_node          fun(): nil
---@field public toggle_node            fun(): nil
---@field public toggle_node_recursively fun(): nil
---@field public toggle_selection       fun(): nil

----------------------------------------------------------------------------------------------------

---@class dot.module.picker.ITreeComposerProps
---@field public uuid                   ?string
---@field public name                   string
---@field public permanent              boolean
---@field public title                  string
---@field public height                 ?number
---@field public width                  ?number
---@field public node_sorter            ark.c.ITreeNodeSorter
---
---@field public keymaps_common         ?ark.t.IKeymap[]
---@field public keymaps_finder         ?ark.t.IKeymap[]
---@field public keymaps_preview        ?ark.t.IKeymap[]
---@field public keymaps_result         ?ark.t.IKeymap[]
---
---@field public flag_foldempty         ark.c.Observable
---@field public flag_fuzzy             ark.c.Observable
---@field public flag_regex             ark.c.Observable
---@field public flag_case_sensitive    ark.c.Observable
---@field public flag_selected          ark.c.Observable
---@field public flag_viewtype          ark.c.Observable
---@field public flags_append           dot.module.picker.result.IFlagItemRaw[]|nil
---@field public flags_prepend          dot.module.picker.result.IFlagItemRaw[]|nil
---@field public flags_start_index      ?0|1
---
---@field public search_pattern         ark.c.Observable
---@field public search_pattern_history ?ark.c.History
---
---@field public render_preview         ?dot.module.picker.preview.IDraw
---@field public render_listview_leaf   dot.module.picker.view.tree.IListviewLeafNodeRenderer
---@field public render_listview_location   dot.module.picker.view.tree.IListviewLeafLocationRenderer
---@field public render_treeview_container  dot.module.picker.view.tree.ITreeviewContainerNodeRenderer
---@field public render_treeview_leaf   dot.module.picker.view.tree.ITreeviewLeafNodeRenderer
---@field public render_treeview_location   dot.module.picker.view.tree.ITreeviewLeafLocationRenderer
---
---@field public on_attached            ?dot.module.picker.composer.tree.IOnAttached
---@field public on_closed              ?dot.module.picker.composer.tree.IOnClosed
---@field public on_confirm             ?dot.module.picker.composer.tree.IOnConfirm
---@field public on_disposed            ?dot.module.picker.composer.tree.IOnDisposed
---@field public on_enter               ?dot.module.picker.composer.tree.IOnEnter
---@field public on_focused             ?dot.module.picker.composer.tree.IOnFocused
---@field public on_hidden              ?dot.module.picker.composer.tree.IOnHidden
---@field public on_refresh             ?dot.module.picker.composer.tree.IOnRefresh

---@class dot.module.picker.TreeComposer
---@field public uuid                   string
---@field public fullname               string
---@field public title                  string
---
---@field public finder                 dot.module.picker.Finder
---@field public result                 dot.module.picker.Result
---@field public preview                dot.module.picker.Preview
---
---@field public flag_foldempty         ark.c.Observable
---@field public flag_fuzzy             ark.c.Observable
---@field public flag_regex             ark.c.Observable
---@field public flag_case_sensitive    ark.c.Observable
---@field public flag_selected          ark.c.Observable
---@field public flag_viewtype          ark.c.Observable
---
---@field protected _disposed           boolean
---@field protected _tree               ark.c.Tree
---@field protected _composer           dot.module.picker.BasicComposer
---@field protected _plainfile          ark.view.Plainfile
---@field protected _retriever          ark.c.TreeRetriever
---@field protected _scheduler_match    ark.c.Scheduler|nil
---@field protected _treeview           dot.module.picker.TreeView
---
---@field protected _uuid_root          string|nil
---@field protected _uuid_current       string|nil
---@field protected _uuids_file         string[]
---@field protected _uuids_order        string[]
---
---@field protected _on_attached        dot.module.picker.composer.tree.IOnAttached
---@field protected _on_confirm         dot.module.picker.composer.tree.IOnConfirm
---@field protected _on_disposed        dot.module.picker.composer.tree.IOnDisposed
---@field protected _on_enter           dot.module.picker.composer.tree.IOnEnter|nil
---@field protected _observer_unsubs    ark.c.IUnsubscribable[]|nil
local M = {}
M.__index = M

---@param props                         dot.module.picker.ITreeComposerProps
---@return dot.module.picker.TreeComposer
function M.new(props)
  local name = props.name ---@type string
  local fullname = string.format("%s -> %s", name, __module_name__) ---@type string
  local picker_uuid = props.uuid or yoz.fn.uuid() ---@type string
  local permanent = props.permanent ---@type boolean
  local title = props.title ---@type string
  local height = props.height ---@type number|nil
  local width = props.width ---@type number|nil
  local node_sorter = props.node_sorter ---@type ark.c.ITreeNodeSorter

  local o_search_pattern = props.search_pattern ---@type ark.c.Observable
  local search_pattern_history = props.search_pattern_history ---@type ark.c.History|nil

  local keymaps_common = props.keymaps_common ---@type ark.t.IKeymap[]|nil
  local keymaps_finder = props.keymaps_finder ---@type ark.t.IKeymap[]|nil
  local keymaps_preview = props.keymaps_preview ---@type ark.t.IKeymap[]|nil
  local keymaps_result = props.keymaps_result ---@type ark.t.IKeymap[]|nil

  local o_flag_fuzzy = props.flag_fuzzy ---@type ark.c.Observable
  local o_flag_regex = props.flag_regex ---@type ark.c.Observable
  local o_flag_foldempty = props.flag_foldempty ---@type ark.c.Observable
  local o_flag_case_sensitive = props.flag_case_sensitive ---@type ark.c.Observable
  local o_flag_selected = props.flag_selected ---@type ark.c.Observable
  local o_flag_viewtype = props.flag_viewtype ---@type ark.c.Observable

  local flags_append = props.flags_append ---@type dot.module.picker.result.IFlagItemRaw[]|nil
  local flags_prepend = props.flags_prepend ---@type dot.module.picker.result.IFlagItemRaw[]|nil
  local flags_start_index = props.flags_start_index ---@type 0|1|nil

  local render_preview = props.render_preview ---@type dot.module.picker.preview.IDraw|nil
  local render_listview_leaf = props.render_listview_leaf ---@type dot.module.picker.view.tree.IListviewLeafNodeRenderer
  local render_listview_location = props.render_listview_location ---@type dot.module.picker.view.tree.IListviewLeafLocationRenderer
  local render_treeview_container = props.render_treeview_container ---@type dot.module.picker.view.tree.ITreeviewContainerNodeRenderer
  local render_treeview_leaf = props.render_treeview_leaf ---@type dot.module.picker.view.tree.ITreeviewLeafNodeRenderer
  local render_treeview_location = props.render_treeview_location ---@type dot.module.picker.view.tree.ITreeviewLeafLocationRenderer

  local on_attached = props.on_attached or stl.fn.noop ---@type dot.module.picker.composer.tree.IOnAttached
  local on_closed = props.on_closed or stl.fn.noop ---@type dot.module.picker.composer.tree.IOnClosed
  local on_confirm = props.on_confirm or stl.fn.noop ---@type dot.module.picker.composer.tree.IOnConfirm
  local on_disposed = props.on_disposed or stl.fn.noop ---@type dot.module.picker.composer.tree.IOnDisposed
  local on_enter = props.on_enter ---@type dot.module.picker.composer.tree.IOnEnter|nil
  local on_focused = props.on_focused or stl.fn.noop ---@type dot.module.picker.composer.tree.IOnFocused
  local on_hidden = props.on_hidden or stl.fn.noop ---@type dot.module.picker.composer.tree.IOnHidden
  local on_refresh = props.on_refresh or stl.fn.noop ---@type dot.module.picker.composer.tree.IOnRefresh

  local tree = ark.c.Tree.new({
    name = fullname,
    node_sorter = node_sorter,
  })

  local self = setmetatable({}, M)

  ---@type ark.c.TreeRetriever
  local retriever = ark.c.TreeRetriever.new({
    name = fullname,
  })

  ---@type ark.view.Plainfile
  local plainfile = ark.view.Plainfile.new({
    name = fullname,
  })

  ---@type dot.module.picker.TreeView
  local treeview = dot.picker.TreeView.new({
    name = fullname,
    tree = tree,
    flag_foldempty = o_flag_foldempty,
    indent = "",
    indent_hln = "f_utw_indent_float",
    render_listview_leaf = render_listview_leaf,
    render_listview_location = render_listview_location,
    render_treeview_container = render_treeview_container,
    render_treeview_leaf = render_treeview_leaf,
    render_treeview_location = render_treeview_location,
  })

  local scheduler_match = ark.c.Scheduler.new({
    name = string.format("%s#match", fullname),
    mode = "debounce",
    delay = 64,
    timeout = 0,
    silent = stl.fn.falsy,
    value = ark.c.Observable.from_value(true),
    task = function()
      local input = o_search_pattern:snapshot() ---@type string
      self:__match__(input)
      treeview:mark_cache_treeview_dirty()
      self:mark_result_dirty()
    end,
  })

  local flags = {} ---@type dot.module.picker.result.IFlagItemRaw[]
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
        local enabled = o_flag_selected:snapshot() ---@type boolean
        o_flag_selected:next(not enabled)
      end,
      snapshot = function()
        local enabled = o_flag_selected:snapshot() ---@type boolean
        return stl.icon.symbols.flag_selected, enabled and "picker_flag_orange" or "picker_flag_grey"
      end,
    }
    flags[#flags + 1] = {
      desc = string.format("%s: viewtype", name),
      callback = function()
        local viewtype = o_flag_viewtype:snapshot() ---@type ark.view.tree.ViewtypeEnum
        local next_viewtype = viewtype == "tree" and "list" or "tree" ---@type ark.view.tree.ViewtypeEnum
        o_flag_viewtype:next(next_viewtype)
      end,
      snapshot = function()
        local viewtype = o_flag_viewtype:snapshot() ---@type ark.view.tree.ViewtypeEnum
        if viewtype == "tree" then
          return stl.icon.symbols.flag_tree, "picker_flag_aqua"
        end
        if viewtype == "list" then
          return stl.icon.symbols.flag_list, "picker_flag_aqua"
        end

        local message = string.format("[%s#%s] Unknown viewtype: %s", __module_name__, name, viewtype)
        error(message)
      end,
    }
    flags[#flags + 1] = {
      desc = string.format("%s: fold empty path", name),
      disabled = function()
        local viewtype = o_flag_viewtype:snapshot() ---@type ark.view.tree.ViewtypeEnum
        return viewtype ~= "tree"
      end,
      callback = function()
        local enabled = o_flag_foldempty:snapshot() ---@type boolean
        o_flag_foldempty:next(not enabled)
        self._composer:mark_result_dirty()
      end,
      snapshot = function()
        local enabled = o_flag_foldempty:snapshot() ---@type boolean
        return stl.icon.symbols.flag_fold_empty_path, enabled and "picker_flag_blue" or "picker_flag_grey"
      end,
    }
    flags[#flags + 1] = {
      desc = string.format("%s: fuzzy", name),
      callback = function()
        local enabled = o_flag_fuzzy:snapshot() ---@type boolean
        o_flag_fuzzy:next(not enabled)
      end,
      snapshot = function()
        local enabled = o_flag_fuzzy:snapshot() ---@type boolean
        return stl.icon.symbols.flag_fuzzy, enabled and "picker_flag_blue" or "picker_flag_grey"
      end,
    }
    flags[#flags + 1] = {
      desc = string.format("%s: sensitive", name),
      callback = function()
        local enabled = o_flag_case_sensitive:snapshot() ---@type boolean
        o_flag_case_sensitive:next(not enabled)
      end,
      snapshot = function()
        local enabled = o_flag_case_sensitive:snapshot() ---@type boolean
        return stl.icon.symbols.flag_case_sensitive, enabled and "picker_flag_blue" or "picker_flag_grey"
      end,
    }
    flags[#flags + 1] = {
      desc = string.format("%s: regex", name),
      callback = function()
        local enabled = o_flag_regex:snapshot() ---@type boolean
        o_flag_regex:next(not enabled)
      end,
      snapshot = function()
        local enabled = o_flag_regex:snapshot() ---@type boolean
        return stl.icon.symbols.flag_regex, enabled and "picker_flag_blue" or "picker_flag_grey"
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

  ---@type dot.module.picker.composer.tree.actions
  local actions = {
    attach_node = function()
      local nodeuuid = self:__retrieve_nodeuuid__() ---@type string|nil
      if nodeuuid ~= nil then
        local nodestate = treeview:retrieve(nodeuuid) ---@type ark.view.tree.INodeState|nil
        if nodestate == nil then
          return
        end

        if nodestate.nodetype == "container" then
          treeview:mark_cache_listview_dirty()
          self._uuid_root = nodeuuid ---@type string
          self:mark_result_dirty()
          on_attached(self, nodeuuid)
          return
        end

        local leafuuid = nodestate.nodetype == "location" and nodestate.leafuuid or nodeuuid ---@type string
        local leafnode = tree:retrieve(leafuuid) ---@type ark.c.ITreeNode|nil
        if leafnode == nil then
          return
        end

        treeview:mark_cache_listview_dirty()
        self._uuid_root = leafuuid ---@type string
        self:mark_result_dirty()
        on_attached(self, leafuuid)
      end
    end,
    attach_parent = function()
      local rootuuid = self._uuid_root ---@type string
      local rootnode = tree:retrieve(rootuuid) ---@type ark.c.ITreeNode|nil
      if rootnode and rootnode.parent ~= rootuuid then
        treeview:mark_cache_listview_dirty()
        self._uuid_root = rootnode.parent ---@type string
        self:mark_result_dirty()

        on_attached(self, rootnode.parent)
      end
    end,
    goto_lnum_lastchild = function()
      local nodeuuid, lnum = self:__retrieve_nodeuuid__() ---@type string|nil, integer
      if nodeuuid ~= nil then
        local lnum_lastchild = retriever:retrieve_lastchild_lnum(lnum) ---@type integer|nil
        if lnum_lastchild ~= nil then
          self._composer.result:set_lnum_current(lnum_lastchild)
        end
      end
    end,
    goto_lnum_parent = function()
      local nodeuuid, lnum = self:__retrieve_nodeuuid__() ---@type string|nil, integer
      local lnum_parent = self:__retrieve_lnum_parent__(nodeuuid) ---@type integer|nil
      if lnum_parent ~= nil then
        if lnum == lnum_parent then
          lnum_parent = lnum_parent > 1 and lnum_parent - 1 or lnum_parent ---@type integer
        end
        self._composer.result:set_lnum_current(lnum_parent)
      end
    end,
    mark_node_invisible = function()
      local lnum_from, lnum_to = self:__retrieve_lnum_range__() ---@type integer, integer
      if lnum_from < 1 then
        return
      end

      local search_pattern = o_search_pattern:snapshot() ---@type string
      for lnum = lnum_from, lnum_to, 1 do
        local nodeuuid = retriever:retrieve_uuid(lnum) ---@type string|nil
        if nodeuuid ~= nil then
          local nodestate = treeview:retrieve(nodeuuid) ---@type ark.view.tree.INodeState|nil
          if nodestate ~= nil and (search_pattern == "" or nodestate.nodetype ~= "container") then
            treeview:mark_node_invisible(nodeuuid)
          end
        end
      end
      self._composer:mark_result_dirty()
    end,
    mark_subroot_invisible = function()
      local lnum_from, lnum_to = self:__retrieve_lnum_range__() ---@type integer, integer
      if lnum_from < 1 then
        return
      end

      for lnum = lnum_from, lnum_to, 1 do
        local nodeuuid = retriever:retrieve_uuid(lnum) ---@type string|nil
        if nodeuuid ~= nil then
          treeview:mark_node_invisible(nodeuuid)
        end
      end
      self._composer:mark_result_dirty()
    end,
    open_node = function()
      local nodeuuid = self:__retrieve_nodeuuid__() ---@type string|nil
      if nodeuuid == nil then
        return
      end

      local nodestate = treeview:retrieve(nodeuuid) ---@type ark.view.tree.INodeState|nil
      if nodestate ~= nil and nodestate.nodetype == "container" then
        if nodestate.collapsed then
          treeview:collapse(nodeuuid, "expand", true)
          treeview:mark_cache_listview_dirty()
          self._composer:mark_result_dirty()
          return
        end
        if on_enter ~= nil and on_enter(self, nodeuuid) then
          return
        end
        return
      end

      self:__resolve_confirmation__(nodeuuid)
    end,
    collapse_node = function()
      local nodeuuid, lnum = self:__retrieve_nodeuuid__() ---@type string|nil, integer
      if nodeuuid == nil then
        return
      end

      local nodestate = treeview:retrieve(nodeuuid) ---@type ark.view.tree.INodeState|nil
      if nodestate ~= nil and nodestate.nodetype == "container" and not nodestate.collapsed then
        treeview:collapse(nodeuuid, "collapse", true)
        treeview:mark_cache_listview_dirty()
        self._composer:mark_result_dirty()
        self._composer.result:set_lnum_current(lnum)
        return
      end

      local lnum_parent, parentuuid = self:__retrieve_lnum_parent__(nodeuuid) ---@type integer|nil, string|nil
      if parentuuid == nil then
        return
      end

      treeview:collapse(parentuuid, "collapse", true)
      treeview:mark_cache_listview_dirty()
      self._composer:mark_result_dirty()
      if lnum_parent ~= nil then
        self._composer.result:set_lnum_current(lnum_parent)
      end
    end,
    toggle_node = function()
      local nodeuuid = self:__retrieve_nodeuuid__() ---@type string|nil
      if nodeuuid ~= nil then
        self:__toggle_node__(nodeuuid, false, false)
      end
    end,
    toggle_node_recursively = function()
      local nodeuuid = self:__retrieve_nodeuuid__() ---@type string|nil
      if nodeuuid ~= nil then
        self:__toggle_node__(nodeuuid, false, true)
      end
    end,
    toggle_selection = function()
      local lnum_from, lnum_to = self:__retrieve_lnum_range__() ---@type integer, integer
      if lnum_from < 1 then
        return
      end

      if lnum_from == lnum_to then
        local nodeuuid = retriever:retrieve_uuid(lnum_from) ---@type string|nil
        if nodeuuid == nil then
          return
        end

        local nodestate = treeview:retrieve(nodeuuid) ---@type ark.view.tree.INodeState|nil
        if nodestate == nil then
          return
        end

        if nodestate.nodetype == "container" then
          local next_selected = not treeview:isselected(nodeuuid) ---@type boolean
          treeview:toggle_select(nodeuuid, next_selected, true)
        elseif nodestate.nodetype == "leaf" then
          local next_selected = not treeview:isselected(nodeuuid) ---@type boolean
          treeview:toggle_select(nodeuuid, next_selected, true)
        elseif nodestate.nodetype == "location" then
          nodeuuid = nodestate.leafuuid ---@type string
          local next_selected = not treeview:isselected(nodeuuid) ---@type boolean
          treeview:toggle_select(nodeuuid, next_selected, true)
        end
        self._composer.result:refresh_signs()
        return
      end

      local next_selected = false ---@type boolean
      for lnum = lnum_from, lnum_to, 1 do
        local nodeuuid = retriever:retrieve_uuid(lnum) ---@type string|nil
        if nodeuuid ~= nil then
          local childstate = treeview:retrieve(nodeuuid) ---@type ark.view.tree.INodeState|nil
          if childstate ~= nil and childstate.nodetype ~= "location" then
            local isselected = treeview:isselected(nodeuuid) ---@type boolean
            if not isselected then
              next_selected = true
              break
            end
          end
        end
      end

      for lnum = lnum_from, lnum_to, 1 do
        local nodeuuid = retriever:retrieve_uuid(lnum) ---@type string|nil
        if nodeuuid ~= nil then
          local childstate = treeview:retrieve(nodeuuid) ---@type ark.view.tree.INodeState|nil
          if childstate ~= nil and childstate.nodetype ~= "location" then
            treeview:set_selected(nodeuuid, next_selected)
          end
        end
      end
      self._composer.result:refresh_signs()
    end,
  }

  ---@type ark.t.IKeymap[]
  local preset_keymaps_common = {}

  ---@type ark.t.IKeymap[]
  local preset_keymaps_finder = {
    {
      modes = { "n", "x" },
      key = ".",
      desc = "tree: change root",
      callback = actions.attach_node,
    },
    {
      modes = { "n", "x" },
      key = "<Backspace>",
      desc = "tree: change root to parent",
      callback = actions.attach_parent,
    },
    {
      modes = { "i", "n", "x" },
      key = "<Enter>",
      desc = "tree: open",
      callback = actions.open_node,
    },
  {
    modes = { "i", "n", "x" },
    key = "<C-h>",
    desc = "tree: collapse",
    callback = actions.collapse_node,
  },
  {
    modes = { "i", "n", "x" },
    key = "<C-l>",
    desc = "tree: open",
    callback = actions.open_node,
  },
    {
      modes = { "n", "x" },
      key = "<Tab>",
      desc = "tree: toggle selection",
      callback = actions.toggle_selection,
    },
    {
      modes = { "n", "x" },
      key = "<leader>D",
      desc = "tree: mark the subroot invisible",
      callback = actions.mark_subroot_invisible,
    },
    {
      modes = { "n", "x" },
      key = "<leader>dd",
      desc = "tree: mark the node invisible",
      callback = actions.mark_node_invisible,
    },
    {
      modes = { "n", "x" },
      key = "[i",
      desc = "tree: goto the parent line",
      callback = actions.goto_lnum_parent,
    },
    {
      modes = { "n", "x" },
      key = "]i",
      desc = "tree: goto the lastchild line",
      callback = actions.goto_lnum_lastchild,
    },
    {
      modes = { "n", "x" },
      key = "oz",
      desc = "tree: toggle (recursively)",
      callback = actions.toggle_node_recursively,
    },
  }

  ---@type ark.t.IKeymap[]
  local preset_keymaps_result = {
    {
      modes = { "i", "n", "x" },
      key = ".",
      desc = "tree: change root",
      callback = actions.attach_node,
    },
    {
      modes = { "i", "n", "x" },
      key = "<Backspace>",
      desc = "tree: change root to parent",
      callback = actions.attach_parent,
    },
    {
      modes = { "i", "n", "x" },
      key = "<Enter>",
      aliases = { "w" },
      desc = "tree: open",
      callback = actions.open_node,
    },
    {
      modes = { "i", "n", "x" },
      key = "<Right>",
      aliases = { "<Left>", "c" },
      desc = "tree: toggle",
      callback = actions.toggle_node,
    },
    {
      modes = { "i", "n" },
      key = "l",
      desc = "tree: open",
      callback = actions.open_node,
    },
    {
      modes = { "i", "n" },
      key = "h",
      desc = "tree: collapse",
      callback = actions.collapse_node,
    },
    {
      modes = { "i", "n", "x" },
      key = "<C-l>",
      desc = "tree: open",
      callback = actions.open_node,
    },
    {
      modes = { "i", "n", "x" },
      key = "<2-LeftMouse>",
      desc = "tree: toggle",
      callback = function()
        local result_winnr = self._composer.result:get_winnr() ---@type integer|nil
        if result_winnr ~= nil and vim.api.nvim_win_is_valid(result_winnr) then
          local cursor = vim.fn.getmousepos()
          if cursor.winid == result_winnr then
            actions.toggle_node()
          end
        end
      end,
    },
    {
      modes = { "i", "n", "x" },
      key = "<Tab>",
      desc = "tree: toggle selection",
      callback = actions.toggle_selection,
    },
    {
      modes = { "i", "n", "x" },
      key = "<leader>D",
      desc = "tree: mark the subroot invisible",
      callback = actions.mark_subroot_invisible,
    },
    {
      modes = { "i", "n", "x" },
      key = "<leader>dd",
      desc = "tree: mark the node invisible",
      callback = actions.mark_node_invisible,
    },
    {
      modes = { "i", "n", "x" },
      key = "[i",
      desc = "tree: goto the parent line",
      callback = actions.goto_lnum_parent,
    },
    {
      modes = { "i", "n", "x" },
      key = "]i",
      desc = "tree: goto the lastchild line",
      callback = actions.goto_lnum_lastchild,
    },
    {
      modes = { "i", "n", "x" },
      key = "oz",
      desc = "tree: toggle (recursively)",
      callback = actions.toggle_node_recursively,
    },
  }

  local composer = dot.picker.BasicComposer.new({
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

    search_pattern = o_search_pattern,
    search_pattern_history = search_pattern_history,
    finder_title = title,

    result_number = true,

    ---@type dot.module.picker.result.IIsSelected
    result_isselected = function(_, lnum)
      local uuid = retriever:retrieve_uuid(lnum) ---@type string|nil
      return uuid ~= nil and treeview:isselected(uuid)
    end,

    ---@type dot.module.picker.result.IDraw
    render_result = function(bufnr)
      local viewtype = o_flag_viewtype:snapshot() ---@type ark.view.tree.ViewtypeEnum
      local result ---@type ark.view.tree.IRenderResult
      local only_matched = o_search_pattern:snapshot() ~= "" ---@type boolean
      local only_selected = o_flag_selected:snapshot() ---@type boolean

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
        local foldempty = o_flag_foldempty:snapshot() ---@type boolean
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
      local ret = { lnum_current = lnum_current } ---@type dot.module.picker.result.IDrawResult
      return ret
    end,

    ---@type dot.module.picker.preview.IDraw|nil
    render_preview = render_preview,

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

  self.flag_foldempty = o_flag_foldempty
  self.flag_fuzzy = o_flag_fuzzy
  self.flag_regex = o_flag_regex
  self.flag_case_sensitive = o_flag_case_sensitive
  self.flag_selected = o_flag_selected
  self.flag_viewtype = o_flag_viewtype

  self._disposed = false
  self._tree = tree
  self._composer = composer
  self._plainfile = plainfile
  self._retriever = retriever
  self._scheduler_match = scheduler_match
  self._treeview = treeview

  self._uuid_root = nil
  self._uuids_file = {}
  self._uuids_order = {}

  self._on_attached = on_attached
  self._on_confirm = on_confirm
  self._on_disposed = on_disposed
  self._on_enter = on_enter
  self._observer_unsubs = nil

  local observer_unsubs = {} ---@type ark.c.IUnsubscribable[]

  observer_unsubs[#observer_unsubs + 1] = stl.fn.observe({
    o_search_pattern,
    o_flag_foldempty,
    o_flag_fuzzy,
    o_flag_regex,
    o_flag_case_sensitive,
    o_flag_selected,
    o_flag_viewtype,
  }, function()
    composer:mark_result_flags_dirty()
  end, true)
  observer_unsubs[#observer_unsubs + 1] = stl.fn.observe({ o_flag_selected, o_flag_viewtype }, function()
    composer:mark_result_dirty()
  end, true)
  observer_unsubs[#observer_unsubs + 1] = stl.fn.observe(
    { o_search_pattern, o_flag_fuzzy, o_flag_regex, o_flag_case_sensitive },
    function()
      scheduler_match:schedule()
    end
  )
  observer_unsubs[#observer_unsubs + 1] = stl.fn.observe({ composer.result.lnum_current }, function()
    local lnum = composer.result.lnum_current:snapshot() ---@type integer
    local uuid = retriever:retrieve_uuid(lnum) ---@type string|nil
    if uuid ~= nil then
      self._uuid_current = uuid
    end
  end)
  self._observer_unsubs = observer_unsubs

  return self
end

---@return nil
function M:dispose()
  if self._disposed then
    return
  end
  self._disposed = true

  local fullname = self.fullname
  local on_dispose = self._on_disposed ---@type dot.module.picker.composer.tree.IOnDisposed
  local composer = self._composer ---@type dot.module.picker.BasicComposer
  local plainfile = self._plainfile ---@type ark.view.Plainfile
  local retriever = self._retriever ---@type ark.c.TreeRetriever
  local scheduler_match = self._scheduler_match ---@type ark.c.Scheduler
  local treeview = self._treeview ---@type dot.module.picker.TreeView
  local observer_unsubs = self._observer_unsubs ---@type ark.c.IUnsubscribable[]|nil
  self._observer_unsubs = nil

  local ok_unsubs = true ---@type boolean
  local error_unsubs = {} ---@type table[]
  if observer_unsubs ~= nil then
    for index, unsub in ipairs(observer_unsubs) do
      local ok, err = pcall(unsub.unsubscribe, unsub)
      if not ok then
        ok_unsubs = false
        error_unsubs[#error_unsubs + 1] = { index = index, error = err }
      end
    end
  end

  vim.schedule(function()
    local ok1, error1 = pcall(scheduler_match.dispose, scheduler_match)
    local ok2, error2 = pcall(treeview.dispose, treeview)
    local ok3, error3 = pcall(composer.dispose, composer)
    local ok4, error4 = pcall(plainfile.dispose, plainfile)
    local ok5, error5 = pcall(retriever.dispose, retriever)
    local ok6, error6 = pcall(on_dispose)

    if not (ok1 and ok2 and ok3 and ok4 and ok5 and ok6) then
      ark.reporter.error({
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
          error_observers = not ok_unsubs and error_unsubs or nil,
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
  self.flag_case_sensitive = nil
  self.flag_selected = nil

  self._composer = nil
  self._plainfile = nil
  self._retriever = nil
  self._scheduler_match = nil
  self._treeview = nil

  self._uuid_root = nil
  self._uuids_file = nil
  self._uuids_order = nil

  self._on_attached = nil
  self._on_confirm = nil
  self._on_disposed = nil
  self._on_enter = nil
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
---@return dot.module.picker.TreeComposer
function M:attach(rootuuid)
  self:__health__()
  if self._uuid_root == rootuuid then
    return self
  end

  local node = self._tree:retrieve(rootuuid) ---@type ark.c.ITreeNode|nil
  if node == nil then
    ark.reporter.error({
      from = __module_name__,
      subject = "attach",
      message = string.format("Cannot find node by the given uuid: %s", rootuuid),
    })
    return self
  end

  local treeview = self._treeview ---@type dot.module.picker.TreeView

  treeview:mark_cache_listview_dirty()
  self._uuid_root = rootuuid
  self._scheduler_match:schedule()

  self._on_attached(self, rootuuid)
  return self
end

---@return dot.module.picker.TreeComposer
function M:mark_result_dirty()
  self:__health__()
  self._composer:mark_result_dirty()
  return self
end

---@return dot.module.picker.TreeComposer
function M:mark_result_flags_dirty()
  self:__health__()
  self._composer:mark_result_flags_dirty()
  return self
end

----------------------------------------------------------------------------------------------------

---@protected
---@return boolean
function M:__has_selected_node__()
  self:__health__()

  local retriever = self._retriever ---@type ark.c.TreeRetriever
  local linecount = retriever:linecount() ---@type integer
  if linecount < 1 then
    return false
  end

  local treeview = self._treeview ---@type dot.module.picker.TreeView

  for lnum = 1, linecount, 1 do
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
  local treeview = self._treeview ---@type dot.module.picker.TreeView

  if #input < 1 then
    local uuids_order = vim.list_slice(self._uuids_file) ---@type string[]
    self._uuids_order = uuids_order
    return
  end

  ---@type string[]
  local uuids_order = treeview:match({
    rootuuid = self._uuid_root,
    pattern = input,
    case_sensitive = self.flag_case_sensitive:snapshot(),
    fuzzy = self.flag_fuzzy:snapshot(),
    regex = self.flag_regex:snapshot(),
  })
  self._uuids_order = uuids_order
end

---@param nodeuuid                      string
---@return nil
function M:__resolve_confirmation__(nodeuuid)
  local composer = self._composer ---@type dot.module.picker.BasicComposer
  local retriever = self._retriever ---@type ark.c.TreeRetriever
  local treeview = self._treeview ---@type dot.module.picker.TreeView

  if self:__has_selected_node__() then
    local linecount = retriever:linecount() ---@type integer
    local uuids = {} ---@type string[]

    for lnum = 1, linecount, 1 do
      local uuid = retriever:retrieve_uuid(lnum) ---@type string|nil
      if uuid ~= nil then
        local isselected = treeview:isselected(uuid) ---@type boolean
        if isselected then
          treeview:set_selected(uuid, false)
          uuids[#uuids + 1] = uuid
        end
      end
    end

    if #uuids > 0 then
      composer:close()
      composer:mark_result_dirty()
      self._on_confirm(self, uuids)
      return
    end
  end

  composer:close()
  composer:mark_result_dirty()
  self._on_confirm(self, { nodeuuid })
end

---@param nodeuuid                      string
---@return ark.c.ITreeNode
---@return ark.view.tree.INodeState
function M:__retrieve__(nodeuuid)
  ---@type ark.view.tree.INodeState|nil
  local nodestate = self._treeview:retrieve(nodeuuid)
  if nodestate == nil then
    error(string.format("Cannot retrieve nodestate by the given uuid(%s)", nodeuuid))
  end

  ---@type ark.c.ITreeNode|nil
  local node = self._tree:retrieve(nodestate.nodetype == "location" and nodestate.leafuuid or nodeuuid)
  if node == nil then
    error(string.format("Cannot retrieve node by the given uuid(%s), nodetype(%s)", nodeuuid, nodestate.nodetype))
  end

  return node, nodestate
end

---@return string|nil
---@return integer
function M:__retrieve_nodeuuid__()
  local lnum = self.result.lnum_current:snapshot() ---@type integer
  if lnum < 1 then
    return nil, lnum
  end

  local nodeuuid = self._retriever:retrieve_uuid(lnum) ---@type string|nil
  return nodeuuid, lnum
end

---@return integer
---@return integer
function M:__retrieve_lnum_range__()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local retriever = self._retriever ---@type ark.c.TreeRetriever

  if winnr == self.result:get_winnr() then
    local mode = vim.fn.mode()
    if mode == "v" or mode == "V" or mode == "\22" then
      local lnum_from, lnum_end = ark.vim.buf.retrieve_visual_lnum_range() ---@type integer, integer
      return lnum_from, lnum_end
    end
  end

  local lnum = self.result.lnum_current:snapshot() ---@type integer
  local lnum_childline = retriever:retrieve_lastchild_lnum(lnum) or lnum ---@type integer
  if lnum < lnum_childline then
    return lnum, lnum_childline
  end
  return lnum, lnum
end

---@param nodeuuid                      string|nil
---@return integer|nil
---@return string|nil
function M:__retrieve_lnum_parent__(nodeuuid)
  if nodeuuid == nil then
    return nil
  end

  local nodestate = self._treeview:retrieve(nodeuuid) ---@type ark.view.tree.INodeState|nil
  if nodestate == nil then
    return nil
  end

  if nodestate.nodetype == "location" then
    local parentuuid = nodestate.leafuuid ---@type string
    local lnum_parent = self._retriever:retrieve_lnum(parentuuid) ---@type integer|nil
    return lnum_parent, parentuuid
  end

  local node = self._tree:retrieve(nodeuuid) ---@type ark.c.ITreeNode|nil
  if node == nil then
    return nil, nil
  end

  local parentuuid = node.parent ---@type string
  local lnum_parent = self._retriever:retrieve_lnum(parentuuid) ---@type integer|nil
  return lnum_parent, parentuuid
end

---@param nodeuuid                      string
---@param open                          boolean
---@param recursively                   boolean
---@return nil
function M:__toggle_node__(nodeuuid, open, recursively)
  local node, nodestate = self:__retrieve__(nodeuuid)

  local composer = self._composer ---@type dot.module.picker.BasicComposer
  local treeview = self._treeview ---@type dot.module.picker.TreeView
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

  if not open then
    return
  end

  composer:close()
  self._on_confirm(self, { nodeuuid })
end

return M
