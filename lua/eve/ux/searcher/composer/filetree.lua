---@diagnostic disable: invisible
local __module_name__ = "eve.ux.searcher.composer.filetree" ---@type string

---@alias eve.ux.searcher.composer.filetree.IOnAttached
---| fun(self: eve.ux.searcher.FiletreeComposer, rootpath: string): nil

---@alias eve.ux.searcher.composer.filetree.IOnClosed
---| fun(self: eve.ux.searcher.FiletreeComposer): nil

---@alias eve.ux.searcher.composer.filetree.IOnConfirm
---| fun(self: eve.ux.searcher.FiletreeComposer, selected_filepaths: string[]|nil): nil

---@alias eve.ux.searcher.composer.filetree.IOnDisposed
---| fun(): nil

---@alias eve.ux.searcher.composer.filetree.IOnFocused
---| fun(self: eve.ux.searcher.FiletreeComposer): nil

---@alias eve.ux.searcher.composer.filetree.IOnHidden
---| fun(self: eve.ux.searcher.FiletreeComposer): nil
---
---@alias eve.ux.searcher.composer.filetree.IOnRefresh
---| fun(self: eve.ux.searcher.FiletreeComposer, force: boolean): nil

---@class eve.ux.searcher.composer.filetree.actions
---@field public add_node_to_avante     fun(): nil
---@field public add_subtree_to_avante  fun(): nil
---@field public attach_node            fun(): nil
---@field public attach_parent          fun(): nil
---@field public copy_node_filepath     fun(): nil
---@field public goto_lnum_lastchild    fun(): nil
---@field public goto_lnum_parent       fun(): nil
---@field public mark_node_invisible    fun(): nil
---@field public mark_subroot_invisible fun(): nil
---@field public open_node              fun(): nil
---@field public send_to_qflist         fun(): nil
---@field public toggle_node            fun(): nil
---@field public toggle_node_recursively fun(): nil
---@field public toggle_selection       fun(): nil

----------------------------------------------------------------------------------------------------

---@class eve.ux.searcher.IFiletreeComposerProps
---@field public uuid                   ?string
---@field public name                   string
---@field public permanent              boolean
---@field public preview                ?boolean
---@field public title                  string
---@field public height                 ?number
---@field public width                  ?number
---
---@field public keymaps_common         ?std.t.IKeymap[]
---@field public keymaps_finder         ?std.t.IKeymap[]
---@field public keymaps_preview        ?std.t.IKeymap[]
---@field public keymaps_result         ?std.t.IKeymap[]
---
---@field public excludes               std.collection.IObservable
---@field public flag_exclude           std.collection.IObservable
---@field public flag_foldempty         std.collection.IObservable
---@field public flag_gitignore         std.collection.IObservable
---@field public flag_regex             std.collection.IObservable
---@field public flag_replace           std.collection.IObservable
---@field public flag_sensitive         std.collection.IObservable
---@field public flag_selected          std.collection.IObservable
---@field public flag_viewtype          std.collection.IObservable
---@field public includes               std.collection.IObservable
---@field public max_filesize           std.collection.IObservable
---@field public max_matches            std.collection.IObservable
---@field public replace_pattern        std.collection.IObservable
---@field public rootpath               std.collection.IObservable
---@field public search_pattern         std.collection.IObservable
---
---@field public flags_append           eve.ux.searcher.result.IFlagItemRaw[]|nil
---@field public flags_prepend          eve.ux.searcher.result.IFlagItemRaw[]|nil
---@field public flags_start_index      ?0|1
---
---@field public frecency               ?std.collection.IFrecency
---
---@field public finder_input_history   ?std.collection.IHistory
---
---@field public on_attached            ?eve.ux.searcher.composer.filetree.IOnAttached
---@field public on_closed              ?eve.ux.searcher.composer.filetree.IOnClosed
---@field public on_confirm             ?eve.ux.searcher.composer.filetree.IOnConfirm
---@field public on_disposed            ?eve.ux.searcher.composer.filetree.IOnDisposed
---@field public on_focused             ?eve.ux.searcher.composer.filetree.IOnFocused
---@field public on_hidden              ?eve.ux.searcher.composer.filetree.IOnHidden
---@field public on_refresh             ?eve.ux.searcher.composer.filetree.IOnRefresh

---@class eve.ux.searcher.FiletreeComposer
---@field public uuid                   string
---@field public fullname               string
---@field public title                  string
---
---@field public finder                 eve.ux.searcher.Finder
---@field public result                 eve.ux.searcher.Result
---@field public preview                eve.ux.searcher.Preview
---
---@field public excludes               std.collection.IObservable
---@field public flag_exclude           std.collection.IObservable
---@field public flag_foldempty         std.collection.IObservable
---@field public flag_gitignore         std.collection.IObservable
---@field public flag_regex             std.collection.IObservable
---@field public flag_replace           std.collection.IObservable
---@field public flag_sensitive         std.collection.IObservable
---@field public flag_selected          std.collection.IObservable
---@field public includes               std.collection.IObservable
---@field public max_filesize           std.collection.IObservable
---@field public max_matches            std.collection.IObservable
---@field public replace_pattern        std.collection.IObservable
---@field public rootpath               std.collection.IObservable
---@field public search_pattern         std.collection.IObservable
---
---@field protected _disposed           boolean
---@field protected _filetree           std.collection.Filetree
---@field protected _frecency           std.collection.IFrecency|nil
---@field protected _composer           eve.ux.searcher.BasicComposer
---@field protected _plainfile          eve.ux.searcher.PlainfileView
---@field protected _retriever          eve.ux.retriever.TreeRetriever
---@field protected _scheduler_search   std.collection.Scheduler|nil
---@field protected _treeview           eve.ux.searcher.FiletreeView
---
---@field protected _last_preview_filepath  string|nil
---@field protected _uuid_root          string|nil
---@field protected _uuid_current       string|nil
---@field protected _uuids_file         string[]
---@field protected _uuids_order        string[]
---
---@field protected _on_attached        eve.ux.searcher.composer.filetree.IOnAttached
---@field protected _on_confirm         eve.ux.searcher.composer.filetree.IOnConfirm|nil
---@field protected _on_disposed        eve.ux.searcher.composer.filetree.IOnDisposed
local M = {}
M.__index = M

---@param props                         eve.ux.searcher.IFiletreeComposerProps
---@return eve.ux.searcher.FiletreeComposer
function M.new(props)
  local name = props.name ---@type string
  local fullname = string.format("%s -> %s", name, __module_name__) ---@type string
  local searcher_uuid = props.uuid or oxi.fn.uuid() ---@type string
  local permanent = props.permanent ---@type boolean
  local preview = props.preview ~= false ---@type boolean
  local title = props.title ---@type string
  local height = props.height ---@type number|nil
  local width = props.width ---@type number|nil

  local o_excludes = props.excludes ---@type std.collection.IObservable
  local o_flag_exclude = props.flag_exclude ---@type std.collection.IObservable
  local o_flag_foldempty = props.flag_foldempty ---@type std.collection.IObservable
  local o_flag_gitignore = props.flag_gitignore ---@type std.collection.IObservable
  local o_flag_regex = props.flag_regex ---@type std.collection.IObservable
  local o_flag_replace = props.flag_replace ---@type std.collection.IObservable
  local o_flag_case_sensitive = props.flag_sensitive ---@type std.collection.IObservable
  local o_flag_selected = props.flag_selected ---@type std.collection.IObservable
  local o_flag_viewtype = props.flag_viewtype ---@type std.collection.IObservable
  local o_includes = props.includes ---@type std.collection.IObservable
  local o_max_filesize = props.max_filesize ---@type std.collection.IObservable
  local o_max_matches = props.max_matches ---@type std.collection.IObservable
  local o_replace_pattern = props.replace_pattern ---@type std.collection.IObservable
  local o_rootpath = props.rootpath ---@type std.collection.IObservable
  local o_search_pattern = props.search_pattern ---@type std.collection.IObservable

  local finder_input_history = props.finder_input_history ---@type std.collection.IHistory|nil

  local keymaps_common = props.keymaps_common ---@type std.t.IKeymap[]|nil
  local keymaps_finder = props.keymaps_finder ---@type std.t.IKeymap[]|nil
  local keymaps_preview = props.keymaps_preview ---@type std.t.IKeymap[]|nil
  local keymaps_result = props.keymaps_result ---@type std.t.IKeymap[]|nil

  local flags_append = props.flags_append ---@type eve.ux.searcher.result.IFlagItemRaw[]|nil
  local flags_prepend = props.flags_prepend ---@type eve.ux.searcher.result.IFlagItemRaw[]|nil
  local flags_start_index = props.flags_start_index ---@type 0|1|nil

  local frecency = props.frecency ---@type std.collection.IFrecency|nil

  local on_attached = props.on_attached or std.fn.noop ---@type eve.ux.searcher.composer.filetree.IOnAttached
  local on_closed = props.on_closed or std.fn.noop ---@type eve.ux.searcher.composer.filetree.IOnClosed
  local on_confirm = props.on_confirm ---@type eve.ux.searcher.composer.filetree.IOnConfirm|nil
  local on_disposed = props.on_disposed or std.fn.noop ---@type eve.ux.searcher.composer.filetree.IOnDisposed
  local on_focused = props.on_focused or std.fn.noop ---@type eve.ux.searcher.composer.filetree.IOnFocused
  local on_hidden = props.on_hidden or std.fn.noop ---@type eve.ux.searcher.composer.filetree.IOnHidden
  local _on_refresh = props.on_refresh or std.fn.noop ---@type eve.ux.searcher.composer.filetree.IOnRefresh

  local self = setmetatable({}, M)

  ---@type std.collection.Filetree
  local filetree = std.Filetree.new({ name = fullname })

  ---@type eve.ux.searcher.FiletreeView
  local treeview = eve.ux.searcher.FiletreeView.new({
    name = fullname,
    tree = filetree,
    flag_foldempty = o_flag_foldempty,
    indent = "",
    indent_hln = "f_utw_indent_float",
  })

  ---@type eve.ux.searcher.composer.filetree.IOnRefresh
  local function on_refresh(_, force)
    treeview:mark_cache_invisible_dirty()
    _on_refresh(self, force)
  end

  ---@type eve.ux.retriever.TreeRetriever
  local retriever = eve.ux.retriever.TreeRetriever.new({
    name = fullname,
  })

  ---@type eve.ux.searcher.PlainfileView
  local plainfile = eve.ux.searcher.PlainfileView.new({
    name = fullname,
  })

  local scheduler_search = std.Scheduler.new({
    name = string.format("%s#search", fullname),
    mode = "debounce",
    delay = 64,
    timeout = 0,
    silent = std.fn.falsy,
    value = std.Observable.from_value(true),
    task = function()
      self:__search__()
      treeview:mark_cache_treeview_dirty()
      self:mark_result_dirty()
    end,
  })

  local flags = {} ---@type eve.ux.searcher.result.IFlagItemRaw[]
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
        return eve.icon.symbols.flag_selected, enabled and "picker_flag_orange" or "picker_flag_grey"
      end,
    }
    flags[#flags + 1] = {
      desc = string.format("%s: viewtype", name),
      callback = function()
        local viewtype = o_flag_viewtype:snapshot() ---@type eve.ux.view.tree.ViewtypeEnum
        local next_viewtype = viewtype == "tree" and "list" or "tree" ---@type eve.ux.view.tree.ViewtypeEnum
        o_flag_viewtype:next(next_viewtype)
      end,
      snapshot = function()
        local viewtype = o_flag_viewtype:snapshot() ---@type eve.ux.view.tree.ViewtypeEnum
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
        local viewtype = o_flag_viewtype:snapshot() ---@type eve.ux.view.tree.ViewtypeEnum
        return viewtype ~= "tree"
      end,
      callback = function()
        local enabled = o_flag_foldempty:snapshot() ---@type boolean
        o_flag_foldempty:next(not enabled)
        self._composer:mark_result_dirty()
      end,
      snapshot = function()
        local enabled = o_flag_foldempty:snapshot() ---@type boolean
        return eve.icon.symbols.flag_fold_empty_path, enabled and "picker_flag_blue" or "picker_flag_grey"
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
        return eve.icon.symbols.flag_case_sensitive, enabled and "picker_flag_blue" or "picker_flag_grey"
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
        return eve.icon.symbols.flag_regex, enabled and "picker_flag_blue" or "picker_flag_grey"
      end,
    }
    flags[#flags + 1] = {
      desc = string.format("%s: replace", name),
      callback = function()
        local enabled = o_flag_replace:snapshot() ---@type boolean
        o_flag_replace:next(not enabled)
      end,
      snapshot = function()
        local enabled = o_flag_replace:snapshot() ---@type boolean
        return eve.icon.symbols.flag_replace, enabled and "picker_flag_blue" or "picker_flag_grey"
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

  ---@type eve.ux.searcher.composer.filetree.actions
  local actions = {
    add_node_to_avante = function()
      local lnum_from, lnum_to = self:__retrieve_lnum_range__() ---@type integer, integer
      if lnum_from < 1 then
        return
      end

      local filepaths = {} ---@type string[]
      for lnum = lnum_from, lnum_to, 1 do
        local nodeuuid = retriever:retrieve_uuid(lnum) ---@type string|nil
        local node = nodeuuid ~= nil and filetree:retrieve(nodeuuid) or nil ---@type std.collection.filetree.INode|nil
        if node ~= nil and node.data.filetype == "file" then
          filepaths[#filepaths + 1] = node.data.filepath
        end
      end
      eve.plugin.avante_add_files(filepaths)
    end,
    add_subtree_to_avante = function()
      local lnum_from, lnum_to = self:__retrieve_lnum_range__() ---@type integer, integer
      if lnum_from < 1 then
        return
      end

      local filepaths = {} ---@type string[]
      local lnum = lnum_from ---@type integer
      while lnum <= lnum_to do
        local nodeuuid = retriever:retrieve_uuid(lnum) ---@type string|nil
        if nodeuuid ~= nil then
          local node = filetree:retrieve(nodeuuid) ---@type std.collection.filetree.INode|nil
          if node ~= nil then
            filepaths[#filepaths + 1] = node.data.filepath

            if node.data.filetype == "directory" then
              local lnum_childline = retriever:retrieve_lastchild_lnum(lnum) ---@type integer|nil
              if lnum_childline ~= nil and lnum_childline > 0 then
                lnum = lnum_childline
              end
            end
          end
        end
        lnum = lnum + 1
      end
      eve.plugin.avante_add_files(filepaths)
    end,
    attach_node = function()
      local nodeuuid = self:__retrieve_nodeuuid__() ---@type string|nil
      if nodeuuid == nil then
        return
      end

      local nodestate = treeview:retrieve(nodeuuid) ---@type eve.ux.searcher.view.filetree.INodeState|nil
      if nodestate == nil then
        return
      end

      if nodestate.nodetype == "container" then
        treeview:mark_cache_listview_dirty()
        self._uuid_root = nodeuuid ---@type string
        self:mark_result_dirty()

        local next_rootnode = filetree:retrieve(nodeuuid)
        if next_rootnode ~= nil then
          on_attached(self, next_rootnode.data.filepath)
        end
        return
      end

      local leafuuid = nodestate.nodetype == "location" and nodestate.leafuuid or nodeuuid ---@type string
      local leafnode = filetree:retrieve(leafuuid) ---@type std.collection.filetree.INode|nil
      if leafnode == nil then
        return
      end

      treeview:mark_cache_listview_dirty()
      self._uuid_root = leafuuid ---@type string
      self:mark_result_dirty()
      on_attached(self, leafnode.data.filepath)
    end,
    attach_parent = function()
      local rootuuid = self._uuid_root ---@type string
      local rootnode = filetree:retrieve(rootuuid) ---@type std.collection.filetree.INode|nil
      if rootnode and rootnode.parent ~= rootuuid then
        treeview:mark_cache_listview_dirty()
        self._uuid_root = rootnode.parent ---@type string
        self:mark_result_dirty()

        local next_rootnode = filetree:retrieve(rootnode.parent)
        if next_rootnode ~= nil then
          on_attached(self, next_rootnode.data.filepath)
        end
      end
    end,
    copy_node_filepath = function()
      local filenode = self:__retrieve_filenode__() ---@type std.collection.filetree.INode|nil
      if filenode == nil then
        return
      end

      local winnr_current = vim.api.nvim_get_current_win() ---@type integer
      local winnr_result = self._composer.result:get_winnr() ---@type integer|nil
      if winnr_result == nil or winnr_result < 1 or not vim.api.nvim_win_is_valid(winnr_result) then
        return
      end

      ---@return nil
      local function handle()
        eve.ux.fn.select_copy_filepath({
          filepath = filenode.data.filepath,
          winopts = {
            relative = "cursor",
            row = 1,
            col = 4,
          },
          on_completed = function()
            if winnr_current ~= winnr_result then
              vim.schedule(function()
                if vim.api.nvim_win_is_valid(winnr_current) then
                  vim.api.nvim_set_current_win(winnr_current)
                end
              end)
            end
          end,
        })
      end

      if winnr_current == winnr_result then
        handle()
      else
        vim.api.nvim_win_call(winnr_result, handle)
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
      local node = nodeuuid ~= nil and filetree:retrieve(nodeuuid) or nil ---@type std.collection.filetree.INode|nil
      local lnum_parent = node ~= nil and retriever:retrieve_lnum(node.parent) or nil ---@type integer|nil
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

      local finder_input = o_search_pattern:snapshot() ---@type string
      for lnum = lnum_from, lnum_to, 1 do
        local nodeuuid = retriever:retrieve_uuid(lnum) ---@type string|nil
        if nodeuuid ~= nil then
          local nodestate = treeview:retrieve(nodeuuid) ---@type eve.ux.searcher.view.filetree.INodeState|nil
          if nodestate ~= nil and (finder_input == "" or nodestate.nodetype ~= "container") then
            treeview:mark_node_invisible(nodeuuid)
          end
        end
      end

      plainfile:mark_dirty()
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

      if on_confirm == nil then
        self:__open_node__(nodeuuid)
      else
        self:__resolve_confirmation__(nodeuuid)
      end
    end,
    replace_all = function()
      local rootuuid = self._uuid_root ---@type string|nil
      local rootnode = rootuuid ~= nil and filetree:retrieve(rootuuid) or nil ---@type std.collection.filetree.INode|nil
      if rootnode == nil then
        return
      end

      local cwd = rootnode.data.filepath ---@type string
      local dirtied = false ---@type boolean
      local lnum_total = self.result.lnum_total:snapshot() ---@type integer
      for lnum = 1, lnum_total, 1 do
        local leafuuid = retriever:retrieve_uuid(lnum) ---@type string|nil
        if leafuuid ~= nil then
          local leafnode = filetree:retrieve(leafuuid) ---@type std.collection.filetree.INode|nil
          local leafnodestate = treeview:retrieve(leafuuid) ---@type eve.ux.searcher.view.filetree.INodeState|nil
          if leafnode ~= nil and leafnodestate ~= nil and leafnodestate.nodetype == "leaf" then
            ---@cast leafnode         std.collection.filetree.INode
            ---@cast leafnodestate    eve.ux.searcher.view.filetree.IFileNodeState
            dirtied = self:__replace_file__(cwd, leafnode, leafnodestate) or dirtied ---@type boolean
          end
        end
      end

      if dirtied then
        plainfile:mark_dirty()
        self:mark_result_dirty()
      end
    end,
    replace_in_node = function()
      local nodeuuid = self:__retrieve_nodeuuid__() ---@type string|nil
      if nodeuuid == nil then
        return
      end

      local nodestate = treeview:retrieve(nodeuuid) ---@type eve.ux.searcher.view.filetree.INodeState|nil
      if nodestate == nil then
        return
      end

      local rootuuid = self._uuid_root ---@type string|nil
      local rootnode = rootuuid ~= nil and filetree:retrieve(rootuuid) or nil ---@type std.collection.filetree.INode|nil
      if rootnode == nil then
        return
      end

      local cwd = rootnode.data.filepath ---@type string
      local flag_case_sensitive = o_flag_case_sensitive:snapshot() ---@type boolean
      local flag_regex = o_flag_regex:snapshot() ---@type boolean
      local search_pattern = o_search_pattern:snapshot() ---@type string
      local replace_pattern = o_replace_pattern:snapshot() ---@type string

      if nodestate.nodetype == "location" then
        ---@cast nodestate              eve.ux.searcher.view.filetree.ILeafLocationState

        local leafnode = filetree:retrieve(nodestate.leafuuid) ---@type std.collection.filetree.INode|nil
        if leafnode == nil then
          std.reporter.error({
            from = self.fullname,
            subject = "replace_in_node",
            message = string.format("Cannot retrieve the leaf node by the given leafuuid (%s)", nodestate.leafuuid),
            details = {
              nodeuuid = nodeuuid,
              nodestate = nodestate,
              rootuuid = rootuuid,
              rootnode = rootnode,
            },
          })
          return
        end

        local leafnodestate = treeview:retrieve(nodestate.leafuuid) ---@type eve.ux.searcher.view.filetree.INodeState|nil
        if leafnodestate == nil then
          std.reporter.error({
            from = self.fullname,
            subject = "replace_in_node",
            message = string.format(
              "Cannot retrieve the leaf nodestate by the given leafuuid (%s)",
              nodestate.leafuuid
            ),
            details = {
              nodeuuid = nodeuuid,
              nodestate = nodestate,
              rootuuid = rootuuid,
              rootnode = rootnode,
            },
          })
          return
        end
        ---@cast leafnodestate          eve.ux.searcher.view.filetree.IFileNodeState

        local offset_current = nodestate.match.preview.offset ---@type integer
        local offsets_remain = {} ---@type integer[]
        local locations = leafnodestate.locations ---@type eve.ux.searcher.view.filetree.ILeafLocationState[]|nil

        if locations == nil then
          std.reporter.error({
            from = self.fullname,
            subject = "replace_in_node",
            message = string.format("The leaf node (%s) has no locations", nodestate.leafuuid),
            details = {
              nodeuuid = nodeuuid,
              nodestate = nodestate,
              rootuuid = rootuuid,
              rootnode = rootnode,
            },
          })
          return
        end

        local L = #locations ---@type integer
        local st = 1 ---@type integer
        while st <= L and locations[st].locationuuid ~= nodestate.locationuuid do
          st = st + 1 ---@type integer
        end

        for i = st + 1, L, 1 do
          local location = locations[i] ---@type eve.ux.searcher.view.filetree.ILeafLocationState
          if treeview:isvisible(location.locationuuid) then
            offsets_remain[#offsets_remain + 1] = location.match.preview.offset ---@type integer
          end
        end

        local succeed, preview_locations = oxi.replacer.replace_file_by_matches_advance({
          cwd = cwd,
          filepath = leafnode.data.filepath,
          flag_case_sensitive = flag_case_sensitive,
          flag_regex = flag_regex,
          search_pattern = search_pattern,
          replace_pattern = replace_pattern,
          match_offsets = { offset_current },
          remain_offsets = offsets_remain,
        })
        if not succeed or preview_locations == nil then
          return
        end

        local nt = 0 ---@type integer
        for i = st + 1, L, 1 do
          local location = locations[i] ---@type eve.ux.searcher.view.filetree.ILeafLocationState
          if treeview:isvisible(location.locationuuid) then
            nt = nt + 1 ---@type integer
            local pl = preview_locations[nt] ---@type std.t.IMatchLocation
            location.match.preview.offset = pl.offset ---@type integer
            location.match.preview.lnum = pl.lnum ---@type integer
            location.match.preview.col = pl.col ---@type integer
          end
        end

        plainfile:mark_dirty()
        treeview:remove_location(leafnodestate, nodestate.locationuuid)
        self:mark_result_dirty()
        return
      end

      local node = filetree:retrieve(nodeuuid) ---@type std.collection.filetree.INode|nil
      if node == nil then
        std.reporter.error({
          from = self.fullname,
          subject = "replace_in_node",
          message = string.format("Cannot retrieve the filetree node by the given nodeuuid (%s)", nodeuuid),
          details = {
            nodeuuid = nodeuuid,
            nodestate = nodestate,
            rootuuid = rootuuid,
            rootnode = rootnode,
          },
        })
        return
      end

      if nodestate.nodetype == "leaf" then
        ---@cast nodestate              eve.ux.searcher.view.filetree.IFileNodeState

        local dirtied = self:__replace_file__(cwd, node, nodestate) ---@type boolean
        if dirtied then
          plainfile:mark_dirty()
          self:mark_result_dirty()
        end
        return
      end

      do
        local dirtied = false ---@type boolean
        local lnum_current, lnum_childline = self:__retrieve_lnum_range__() ---@type integer, integer
        for lnum = lnum_current, lnum_childline, 1 do
          local leafuuid = retriever:retrieve_uuid(lnum) ---@type string|nil
          if leafuuid ~= nil then
            local leafnode = filetree:retrieve(leafuuid) ---@type std.collection.filetree.INode|nil
            local leafnodestate = treeview:retrieve(leafuuid) ---@type eve.ux.searcher.view.filetree.INodeState|nil
            if leafnode ~= nil and leafnodestate ~= nil and leafnodestate.nodetype == "leaf" then
              ---@cast leafnode         std.collection.filetree.INode
              ---@cast leafnodestate    eve.ux.searcher.view.filetree.IFileNodeState
              dirtied = self:__replace_file__(cwd, leafnode, leafnodestate) or dirtied ---@type boolean
            end
          end
        end

        if dirtied then
          plainfile:mark_dirty()
          self:mark_result_dirty()
        end
        return
      end
    end,
    send_to_qflist = function()
      local cwd = std.path.cwd() ---@type string
      local quickfix_items = {} ---@type std.t.IQuickFixItem[]

      local linecount = retriever:linecount() ---@type integer
      for lnum = 1, linecount, 1 do
        local uuid = retriever:retrieve_uuid(lnum) ---@type string|nil
        if uuid ~= nil then
          local node = filetree:retrieve(uuid) ---@type std.collection.filetree.INode|nil
          if node ~= nil and node.data.filetype == "file" then
            local filepath = node.data.filepath ---@type string
            local relative_filepath = std.path.relative(cwd, filepath, false) ---@type string

            local nodestate = treeview:retrieve(uuid) ---@type eve.ux.searcher.view.filetree.INodeState|nil
            local locations = nodestate and nodestate.locations or nil ---@type eve.ux.searcher.view.filetree.ILeafLocationState[]|nil
            if locations == nil or #locations < 1 then
              table.insert(quickfix_items, {
                filename = relative_filepath,
                lnum = 1,
                col = 0,
              })
            else
              for _, location in ipairs(locations) do
                table.insert(quickfix_items, {
                  filename = relative_filepath,
                  lnum = location.lnum,
                  col = location.col or 0,
                  text = location.text,
                })
              end
            end
          end
        end
      end

      if #quickfix_items > 0 then
        self._composer:close()
        eve.qflist.push(quickfix_items)
        eve.qflist.open_qflist()
      end
    end,
    toggle_node = function()
      local nodeuuid = self:__retrieve_nodeuuid__() ---@type string|nil
      if nodeuuid ~= nil then
        self:__toggle_node__(nodeuuid, false)
      end
    end,
    toggle_node_recursively = function()
      local nodeuuid = self:__retrieve_nodeuuid__() ---@type string|nil
      if nodeuuid ~= nil then
        self:__toggle_node__(nodeuuid, true)
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

        local nodestate = treeview:retrieve(nodeuuid) ---@type eve.ux.searcher.view.filetree.INodeState|nil
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
          local childstate = treeview:retrieve(nodeuuid) ---@type eve.ux.searcher.view.filetree.INodeState|nil
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
          local childstate = treeview:retrieve(nodeuuid) ---@type eve.ux.searcher.view.filetree.INodeState|nil
          if childstate ~= nil and childstate.nodetype ~= "location" then
            treeview:set_selected(nodeuuid, next_selected)
          end
        end
      end
      self._composer.result:refresh_signs()
    end,
  }

  ---@type std.t.IKeymap[]
  local preset_keymaps_common = {
    {
      modes = { "i", "n", "v" },
      key = "<C-q>",
      desc = "searcher: send to qflist",
      callback = actions.send_to_qflist,
    },
  }

  ---@type std.t.IKeymap[]
  local preset_keymaps_finder = {
    {
      modes = { "n", "v" },
      key = "<C-a><cr>",
      aliases = { "<D-cr>", "<M-cr>" },
      desc = "searcher: replace all files",
      callback = actions.replace_all,
    },
    {
      modes = { "n", "v" },
      key = "<leader><cr>",
      desc = "search: replace file",
      callback = actions.replace_in_node,
    },
    {
      modes = { "n", "v" },
      key = ".",
      desc = "searcher: change root",
      callback = actions.attach_node,
    },
    {
      modes = { "n", "v" },
      key = "<Backspace>",
      desc = "searcher: change root to parent",
      callback = actions.attach_parent,
    },
    {
      modes = { "i", "n", "v" },
      key = "<Enter>",
      desc = "searcher: open",
      callback = actions.open_node,
    },
    {
      modes = { "i", "n", "v" },
      key = "<C-h>",
      aliases = { "<C-l>" },
      desc = "searcher: toggle",
      callback = actions.toggle_node,
    },
    {
      modes = { "n", "v" },
      key = "<Tab>",
      desc = "searcher: toggle selection",
      callback = actions.toggle_selection,
    },
    {
      modes = { "n", "v" },
      key = "<leader>D",
      desc = "searcher: mark the subroot invisible",
      callback = actions.mark_subroot_invisible,
    },
    {
      modes = { "n", "v" },
      key = "<leader>dd",
      desc = "searcher: mark the node invisible",
      callback = actions.mark_node_invisible,
    },
    {
      modes = { "n", "v" },
      key = "[i",
      desc = "searcher: goto the parent line",
      callback = actions.goto_lnum_parent,
    },
    {
      modes = { "n", "v" },
      key = "]i",
      desc = "searcher: goto the lastchild line",
      callback = actions.goto_lnum_lastchild,
    },
    {
      modes = { "n", "v" },
      key = "oA",
      desc = "searcher: add to avante (full subtree)",
      callback = actions.add_subtree_to_avante,
    },
    {
      modes = { "n", "v" },
      key = "oa",
      desc = "searcher: add to avante",
      callback = actions.add_node_to_avante,
    },
    {
      modes = { "n", "v" },
      key = "oc",
      desc = "searcher: copy filepath",
      callback = actions.copy_node_filepath,
    },
    {
      modes = { "n", "v" },
      key = "oz",
      desc = "searcher: toggle (recursively)",
      callback = actions.toggle_node_recursively,
    },
  }

  ---@type std.t.IKeymap[]
  local preset_keymaps_result = {
    {
      modes = { "n", "v" },
      key = "<C-a><cr>",
      aliases = { "<D-cr>", "<M-cr>" },
      desc = "searcher: replace all files",
      callback = actions.replace_all,
    },
    {
      modes = { "n", "v" },
      key = "<leader><cr>",
      desc = "search: replace file",
      callback = actions.replace_in_node,
    },
    {
      modes = { "i", "n", "v" },
      key = ".",
      desc = "searcher: change root",
      callback = actions.attach_node,
    },
    {
      modes = { "i", "n", "v" },
      key = "<Backspace>",
      desc = "searcher: change root to parent",
      callback = actions.attach_parent,
    },
    {
      modes = { "i", "n", "v" },
      key = "<Enter>",
      aliases = { "l", "w" },
      desc = "searcher: open",
      callback = actions.open_node,
    },
    {
      modes = { "i", "n", "v" },
      key = "<Right>",
      aliases = { "<Left>", "c", "h" },
      desc = "searcher: toggle",
      callback = actions.toggle_node,
    },
    {
      modes = { "i", "n", "v" },
      key = "<2-LeftMouse>",
      desc = "searcher: toggle",
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
      modes = { "i", "n", "v" },
      key = "<Tab>",
      desc = "searcher: toggle selection",
      callback = actions.toggle_selection,
    },
    {
      modes = { "i", "n", "v" },
      key = "<leader>D",
      aliases = { "D" },
      desc = "searcher: mark the subroot invisible",
      callback = actions.mark_subroot_invisible,
    },
    {
      modes = { "i", "n", "v" },
      key = "<leader>dd",
      aliases = { "dd" },
      desc = "searcher: mark the node invisible",
      callback = actions.mark_node_invisible,
    },
    {
      modes = { "i", "n", "v" },
      key = "[i",
      desc = "searcher: goto the parent line",
      callback = actions.goto_lnum_parent,
    },
    {
      modes = { "i", "n", "v" },
      key = "]i",
      desc = "searcher: goto the lastchild line",
      callback = actions.goto_lnum_lastchild,
    },
    {
      modes = { "i", "n", "v" },
      key = "oA",
      desc = "searcher: add to avante (full subtree)",
      callback = actions.add_subtree_to_avante,
    },
    {
      modes = { "i", "n", "v" },
      key = "oa",
      desc = "searcher: add to avante",
      callback = actions.add_node_to_avante,
    },
    {
      modes = { "i", "n", "v" },
      key = "oc",
      desc = "searcher: copy filepath",
      callback = actions.copy_node_filepath,
    },
    {
      modes = { "i", "n", "v" },
      key = "oz",
      desc = "searcher: toggle (recursively)",
      callback = actions.toggle_node_recursively,
    },
  }

  local composer = eve.ux.searcher.BasicComposer.new({
    uuid = searcher_uuid,
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

    finder_input = o_search_pattern,
    finder_input_history = finder_input_history,
    finder_title = title,

    result_number = true,

    ---@type eve.ux.searcher.result.IIsSelected
    result_isselected = function(_, lnum)
      local uuid = retriever:retrieve_uuid(lnum) ---@type string|nil
      return uuid ~= nil and treeview:isselected(uuid)
    end,

    ---@type eve.ux.searcher.result.IDraw
    render_result = function(bufnr)
      local viewtype = o_flag_viewtype:snapshot() ---@type eve.ux.view.tree.ViewtypeEnum
      local result ---@type eve.ux.view.tree.IRenderResult
      local only_selected = o_flag_selected:snapshot() ---@type boolean

      if viewtype == "list" then
        result = treeview:render_listview({
          bufnr = bufnr,
          rootuuid = self._uuid_root,
          orders = self._uuids_order,
          only_matched = true,
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
          only_matched = true,
          only_selected = only_selected,
          only_visible = true,
        })
      end

      retriever:attach(bufnr, result.lnum2uuid, result.uuid2lnum, result.childline)

      local uuid_current = self._uuid_current ---@type string|nil
      local lnum_current = uuid_current ~= nil and retriever:retrieve_lnum(uuid_current) or nil ---@type integer|nil
      local ret = { lnum_current = lnum_current } ---@type eve.ux.searcher.result.IDrawResult
      return ret
    end,

    ---@type eve.ux.searcher.preview.IDraw|nil
    render_preview = preview
        and function(bufnr)
          local nodeuuid, lnum = self:__retrieve_nodeuuid__() ---@type string|nil, integer
          if nodeuuid == nil then
            local lines = { string.format("Error: cannot retrieve node by the given lnum: %d", lnum) } ---@type string[]
            vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
            self._last_preview_filepath = nil

            ---@type eve.ux.searcher.preview.IDrawResult
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
              foldempty = o_flag_foldempty:snapshot(),
              only_expanded = false,
              only_matched = false,
              only_selected = false,
              only_visible = false,
            })

            ---@cast nodestate          eve.ux.searcher.view.filetree.IDirectoryNodeState
            ---@type eve.ux.searcher.preview.IDrawResult
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
            ---@cast nodestate          eve.ux.searcher.view.filetree.IFileNodeState
            if nodestate.locations ~= nil and #nodestate.locations > 0 then
              ---@diagnostic disable-next-line: cast-local-type
              nodestate = nodestate.locations[1]
            end
          end
          ---@cast nodestate            eve.ux.searcher.view.filetree.IFileNodeState|eve.ux.searcher.view.filetree.ILeafLocationState

          local leafnode = nodestate.nodetype == "location" and treeview:retrieve(nodestate.leafuuid) or nodestate
          ---@cast leafnode             eve.ux.searcher.view.filetree.IFileNodeState

          local locations = leafnode and leafnode.locations or nil ---@type eve.ux.searcher.view.filetree.ILeafLocationState[]|nil
          local match_offsets = {} ---@type integer[]

          if locations ~= nil then
            local L = #locations ---@type integer
            for i = 1, L, 1 do
              local location = locations[i] ---@type eve.ux.searcher.view.filetree.ILeafLocationState
              if treeview:isvisible(location.locationuuid) then
                match_offsets[#match_offsets + 1] = location.match.preview.offset
              end
            end
          end

          local location_current ---@type eve.ux.searcher.view.filetree.ILeafLocationState
          if nodestate.nodetype == "location" then
            ---@cast nodestate          eve.ux.searcher.view.filetree.ILeafLocationState
            location_current = nodestate
          else
            if locations ~= nil and #locations > 0 then
              location_current = locations[1] ---@type eve.ux.searcher.view.filetree.ILeafLocationState
            end
          end

          ---@type eve.ux.searcher.IPlainfileViewContext
          local plainfile_context = {
            flag_case_sensitive = o_flag_case_sensitive,
            flag_regex = o_flag_regex,
            flag_replace = o_flag_replace,
            search_pattern = o_search_pattern,
            replace_pattern = o_replace_pattern,

            filepath = filepath,
            filematch = leafnode.filematch,
            match_offsets = match_offsets,
            offset_current = location_current ~= nil and location_current.match.preview.offset or -1,
          }
          plainfile:render(plainfile_context, bufnr, filepath, force)

          ---@type eve.ux.searcher.preview.IDrawResult
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
    on_refresh = function(searcher, force)
      on_refresh(self, force)

      searcher:mark_preview_dirty()
      searcher:mark_result_flags_dirty()
      searcher:mark_result_dirty()
    end,
  })

  self.uuid = searcher_uuid
  self.fullname = fullname

  self.finder = composer.finder
  self.result = composer.result
  self.preview = composer.preview

  self.excludes = o_excludes
  self.flag_exclude = o_flag_exclude
  self.flag_foldempty = o_flag_foldempty
  self.flag_gitignore = o_flag_gitignore
  self.flag_regex = o_flag_regex
  self.flag_replace = o_flag_replace
  self.flag_sensitive = o_flag_case_sensitive
  self.flag_selected = o_flag_selected
  self.includes = o_includes
  self.max_filesize = o_max_filesize
  self.max_matches = o_max_matches
  self.search_pattern = o_search_pattern
  self.rootpath = o_rootpath
  self.replace_pattern = o_replace_pattern

  self._disposed = false
  self._filetree = filetree
  self._frecency = frecency
  self._composer = composer
  self._plainfile = plainfile
  self._retriever = retriever
  self._scheduler_search = scheduler_search
  self._treeview = treeview

  self._last_preview_filepath = nil
  self._uuid_root = nil
  self._uuids_file = {}
  self._uuids_order = {}

  self._on_attached = on_attached
  self._on_confirm = on_confirm
  self._on_disposed = on_disposed

  std.fn.observe({
    o_search_pattern,
    o_flag_foldempty,
    o_flag_regex,
    o_flag_replace,
    o_flag_case_sensitive,
    o_flag_selected,
    o_flag_viewtype,
  }, function()
    composer:mark_result_flags_dirty()
  end, true)
  std.fn.observe({ o_flag_selected, o_flag_viewtype }, function()
    composer:mark_result_dirty()
  end, true)
  std.fn.observe({ o_search_pattern, o_flag_regex, o_flag_replace, o_flag_case_sensitive }, function()
    scheduler_search:schedule()
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
  local on_dispose = self._on_disposed ---@type eve.ux.searcher.composer.filetree.IOnDisposed
  local composer = self._composer ---@type eve.ux.searcher.BasicComposer
  local plainfile = self._plainfile ---@type eve.ux.searcher.PlainfileView
  local retriever = self._retriever ---@type eve.ux.retriever.TreeRetriever
  local scheduler_search = self._scheduler_search ---@type std.collection.Scheduler
  local treeview = self._treeview ---@type eve.ux.searcher.FiletreeView

  vim.schedule(function()
    local ok1, error1 = pcall(scheduler_search.dispose, scheduler_search)
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

  self.excludes = nil
  self.flag_exclude = nil
  self.flag_foldempty = nil
  self.flag_gitignore = nil
  self.flag_regex = nil
  self.flag_replace = nil
  self.flag_sensitive = nil
  self.flag_selected = nil
  self.includes = nil
  self.max_filesize = nil
  self.max_matches = nil
  self.search_pattern = nil
  self.rootpath = nil
  self.replace_pattern = nil

  self._frecency = nil
  self._composer = nil
  self._plainfile = nil
  self._retriever = nil
  self._scheduler_search = nil
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
  return self._filetree:isexistent(uuid)
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
---@return eve.ux.searcher.FiletreeComposer
function M:attach(rootuuid)
  self:__health__()
  if self._uuid_root == rootuuid then
    return self
  end

  local node = self._filetree:retrieve(rootuuid) ---@type std.collection.filetree.INode|nil
  if node == nil then
    std.reporter.error({
      from = __module_name__,
      subject = "attach",
      message = string.format("Cannot find node by the given uuid: %s", rootuuid),
    })
    return self
  end

  local filetree = self._filetree ---@type std.collection.Filetree
  local treeview = self._treeview ---@type eve.ux.searcher.FiletreeView

  treeview:mark_cache_listview_dirty()
  self._uuid_root = rootuuid
  self._scheduler_search:schedule()

  local next_rootnode = filetree:retrieve(rootuuid)
  if next_rootnode ~= nil then
    self._on_attached(self, next_rootnode.data.filepath)
  end
  return self
end

---@return eve.ux.searcher.FiletreeComposer
function M:mark_result_dirty()
  self:__health__()
  self._composer:mark_result_dirty()
  return self
end

---@return eve.ux.searcher.FiletreeComposer
function M:mark_result_flags_dirty()
  self:__health__()
  self._composer:mark_result_flags_dirty()
  return self
end

---@param cwd                           string
---@param filepaths                     string[]
---@return eve.ux.searcher.FiletreeComposer
function M:reset_filepaths(cwd, filepaths)
  self:__health__()

  local frecency = self._frecency ---@type std.collection.IFrecency|nil
  local treeview = self._treeview ---@type eve.ux.searcher.FiletreeView

  cwd = std.path.normalize(cwd) ---@type string
  treeview:reset_filepaths(cwd, filepaths)

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
  self._on_attached(self, cwd)
  return self
end

---@return nil
function M:schedule_search()
  self:__health__()
  self._scheduler_search:schedule()
end

----------------------------------------------------------------------------------------------------

---@protected
---@return integer[]
function M:__collect_selected_lnums__()
  self:__health__()

  local retriever = self._retriever ---@type eve.ux.retriever.TreeRetriever
  local treeview = self._treeview ---@type eve.ux.searcher.FiletreeView

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

---@param offset_current                integer
---@param leafnodestate                     eve.ux.searcher.view.filetree.IFileNodeState
---@return integer[]
function M:__collect_remain_offsets__(offset_current, leafnodestate)
  local treeview = self._treeview ---@type eve.ux.searcher.FiletreeView
  local offsets_remain = {} ---@type integer[]
  if leafnodestate.locations ~= nil then
    for _, location in ipairs(leafnodestate.locations) do
      if location.s_offset ~= offset_current and treeview:isvisible(location.locationuuid) then
        offsets_remain[#offsets_remain + 1] = location.s_offset ---@type integer
      end
    end
  end
  return offsets_remain
end

---@return integer|nil
function M:__focus_source_win__()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local winnr_sourcefile = eve.tab.retrieve_winnr_sourcefile(tabnr) ---@type integer|nil
  if winnr_sourcefile ~= nil and vim.api.nvim_win_is_valid(winnr_sourcefile) then
    vim.api.nvim_tabpage_set_win(tabnr, winnr_sourcefile)
  else
    winnr_sourcefile = nil
  end
  return winnr_sourcefile
end

---@protected
---@return boolean
function M:__has_selected_node__()
  self:__health__()

  local retriever = self._retriever ---@type eve.ux.retriever.TreeRetriever
  local linecount = retriever:linecount() ---@type integer
  if linecount < 1 then
    return false
  end

  local treeview = self._treeview ---@type eve.ux.searcher.FiletreeView

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
---@return nil
function M:__search__()
  local rootpath = self.rootpath:snapshot() ---@type string

  if not std.path.is_exist(rootpath) then
    std.reporter.error({
      from = self.fullname,
      subject = "__search__",
      message = string.format("Root path does not exist: %s", rootpath),
    })
    return
  end

  local cwd = rootpath ---@type string
  local specified_filepath = nil ---@type string|nil

  if not std.path.is_exist_dirpath(rootpath) then
    cwd = std.path.dirname(rootpath) ---@type string
    specified_filepath = rootpath ---@type string
  end

  local replace_pattern = self.replace_pattern:snapshot() ---@type string|nil
  local search_pattern = self.search_pattern:snapshot() ---@type string

  local filetree = self._filetree ---@type std.collection.Filetree
  local frecency = self._frecency ---@type std.collection.IFrecency|nil
  local treeview = self._treeview ---@type eve.ux.searcher.FiletreeView

  if #search_pattern < 1 then
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

  ---@type eve.ux.searcher.view.filetree.ISearchResult|nil
  local result = treeview:search({
    cwd = cwd,
    specified_filepath = specified_filepath,
    excludes = self.excludes:snapshot(),
    includes = self.includes:snapshot(),

    flag_case_sensitive = self.flag_sensitive:snapshot(),
    flag_exclude = self.flag_exclude:snapshot(),
    flag_gitignore = self.flag_gitignore:snapshot(),
    flag_regex = self.flag_regex:snapshot(),
    flag_replace = self.flag_replace:snapshot(),
    max_filesize = self.max_filesize:snapshot(),
    max_matches = self.max_matches:snapshot(),

    search_pattern = search_pattern,
    replace_pattern = replace_pattern,
  })

  if result == nil then
    return
  end

  local items = result.items ---@type eve.ux.searcher.view.filetree.ISearchedItem[]
  local filematch_map = result.filematch_map ---@type table<string, oxi.searcher.IFileMatch>

  local filepaths = {} ---@type string[]
  local uuids = {} ---@type string[]
  do
    local N, i, j, k = #items, 1, 0, 0 ---@type integer, integer, integer
    while i <= N do
      local item = items[i] ---@type eve.ux.searcher.view.filetree.ISearchedItem
      local nodeuuid = item.uuid ---@type string

      j = i + 1 ---@type integer
      while j <= N and items[j].uuid == nodeuuid do
        j = j + 1
      end

      k = k + 1
      filepaths[k] = item.filepath ---@type string
      uuids[k] = item.uuid ---@type string

      i = j
    end
  end

  self:reset_filepaths(cwd, filepaths)
  treeview:mark_cache_match_dirty()

  local tick_matched = treeview._tick_matched ---@type integer
  local statemap = treeview.statemap ---@type table<string, eve.ux.searcher.view.filetree.INodeState>

  do
    local N, i, j = #items, 1, 0 ---@type integer, integer, integer
    while i <= N do
      local nodeuuid = items[i].uuid ---@type string

      j = i + 1 ---@type integer
      while j <= N and items[j].uuid == nodeuuid do
        j = j + 1
      end

      local leafnode = statemap[nodeuuid] ---@type eve.ux.searcher.view.filetree.INodeState|nil
      if leafnode == nil then
        std.reporter.error({
          from = self.fullname,
          subject = "__search__",
          message = string.format("Cannot retrieve node state by the given uuid: %s", nodeuuid),
          details = {
            nodeuuid = nodeuuid,
            items = vim.list_slice(items, i, j - 1),
            N = N,
          },
        })
      else
        leafnode.filematch = filematch_map[nodeuuid]

        local L = 0 ---@type integer
        local locations = leafnode.locations or {} ---@type eve.ux.searcher.view.filetree.ILeafLocationState[]
        for k = i, j - 1, 1 do
          local item = items[k] ---@type eve.ux.searcher.view.filetree.ISearchedItem

          ---@type eve.ux.searcher.view.filetree.ILeafLocationState
          local location = {
            nodetype = "location",
            leafuuid = nodeuuid,
            locationuuid = string.format("%s:%d:%d", nodeuuid, item.lnum, item.col),
            tick_invisible = 0,
            lnum = item.lnum,
            col = item.col,
            text = item.text,
            highlights = item.highlights,

            match = item,
          }

          statemap[location.locationuuid] = location

          L = L + 1 ---@type integer
          locations[L] = location
        end
        std.table.truncate_inline(locations, L)
        leafnode.locations = locations
        leafnode.tick_matched = tick_matched
      end

      i = j
    end
  end

  filetree:unsafe_traverse(nil, function(ctx)
    local nodemap = ctx.nodemap ---@type table<string, std.collection.filetree.INode>
    for _, uuid in ipairs(uuids) do
      local o = nodemap[uuid] ---@type std.collection.filetree.INode

      for _ = o.depth - 1, 1, -1 do
        o = nodemap[o.parent] ---@type std.collection.filetree.INode

        local s = statemap[o.uuid]
        if s == nil or s.tick_matched == tick_matched then
          break
        end

        s.tick_matched = tick_matched
      end
    end
  end)

  if frecency ~= nil then
    std.table.stable_sort(uuids, function(a, b)
      local sa = frecency:score(a) or 0 ---@type integer
      local sb = frecency:score(b) or 0 ---@type integer
      return sb - sa
    end)
  end

  self._uuids_order = uuids
end

---@param nodeuuid                      string
---@return nil
function M:__open_node__(nodeuuid)
  local node, nodestate = self:__retrieve__(nodeuuid)

  local composer = self._composer ---@type eve.ux.searcher.BasicComposer
  local filetree = self._filetree ---@type std.collection.Filetree
  local retriever = self._retriever ---@type eve.ux.retriever.TreeRetriever
  local treeview = self._treeview ---@type eve.ux.searcher.FiletreeView

  if self:__has_selected_node__() then
    local linecount = retriever:linecount() ---@type integer
    local last_nodestate = nil ---@type eve.ux.searcher.view.filetree.IFileNodeState|nil
    local filepaths = {} ---@type string[]

    for lnum = 1, linecount, 1 do
      local uuid = retriever:retrieve_uuid(lnum) ---@type string|nil
      if uuid ~= nil then
        local isselected = treeview:isselected(uuid) ---@type boolean
        if isselected then
          local o = filetree:retrieve(uuid) ---@type std.collection.filetree.INode|nil
          treeview:set_selected(uuid, false)
          if o ~= nil and o.data.filetype == "file" then
            filepaths[#filepaths + 1] = o.data.filepath

            local s = treeview:retrieve(nodeuuid) ---@type eve.ux.searcher.view.filetree.INodeState|nil
            if s ~= nil then
              ---@cast s                      eve.ux.searcher.view.filetree.IFileNodeState
              last_nodestate = s
            end
          end
        end
      end
    end

    if #filepaths > 0 then
      ---@cast last_nodestate             eve.ux.searcher.view.filetree.IFileNodeState
      local locations = last_nodestate.locations
      local first_location = locations ~= nil and locations[1] or nil ---@type eve.ux.searcher.view.filetree.ILeafLocationState|nil
      local lnum = first_location and first_location.lnum or nil ---@type integer|nil
      local col = first_location and first_location.col or nil ---@type integer|nil

      local winnr_sourcefile = self:__focus_source_win__() ---@type integer|nil
      if winnr_sourcefile ~= nil and vim.api.nvim_win_is_valid(winnr_sourcefile) then
        vim.api.nvim_set_current_win(winnr_sourcefile)
      end

      composer:close()
      composer:mark_result_dirty()
      eve.win.open_filepaths(winnr_sourcefile, filepaths, lnum, col)
      return
    end
  end

  if nodestate.nodetype == "container" then
    self._treeview:collapse(node.uuid, "toggle", false)
    composer:mark_result_dirty()
    return
  end

  if nodestate.nodetype == "leaf" and nodestate.collapsed then
    self._treeview:collapse(node.uuid, "expand", false)
    composer:mark_result_dirty()
    return
  end

  local lnum ---@type integer|nil
  local col ---@type integer|nil
  if nodestate.nodetype == "location" then
    lnum = nodestate.lnum ---@type integer|nil
    col = nodestate.col ---@type integer|nil
  else
    if nodestate.locations ~= nil and #nodestate.locations > 0 then
      local first_location = nodestate.locations[1] ---@type eve.ux.picker.view.filetree.ILocationNodeState
      lnum = first_location.lnum ---@type integer|nil
      col = first_location.col ---@type integer|nil
    end
  end

  local winnr_sourcefile = self:__focus_source_win__() ---@type integer|nil
  if winnr_sourcefile ~= nil and vim.api.nvim_win_is_valid(winnr_sourcefile) then
    vim.api.nvim_set_current_win(winnr_sourcefile)
  end

  composer:close()
  eve.win.open_filepath(winnr_sourcefile, node.data.filepath, lnum, col)
end

---@param cwd                           string
---@param node                          std.collection.filetree.INode
---@param nodestate                     eve.ux.searcher.view.filetree.IFileNodeState
---@return boolean
function M:__replace_file__(cwd, node, nodestate)
  local locations = nodestate.locations ---@type eve.ux.searcher.view.filetree.ILeafLocationState[]|nil
  if locations == nil then
    return false
  end

  local treeview = self._treeview ---@type eve.ux.searcher.FiletreeView
  local L = #locations ---@type integer
  local count = 0 ---@type integer
  for i = 1, L, 1 do
    local location = locations[i] ---@type eve.ux.searcher.view.filetree.ILeafLocationState
    if treeview:isvisible(location.locationuuid) then
      count = count + 1
    end
  end

  if count == 0 then
    return false
  end

  local flag_case_sensitive = self.flag_sensitive:snapshot() ---@type boolean
  local flag_regex = self.flag_regex:snapshot() ---@type boolean
  local search_pattern = self.search_pattern:snapshot() ---@type string
  local replace_pattern = self.replace_pattern:snapshot() ---@type string

  if count == L then
    ---@type boolean
    local succeed = oxi.replacer.replace_file({
      cwd = cwd,
      filepath = node.data.filepath,
      flag_case_sensitive = flag_case_sensitive,
      flag_regex = flag_regex,
      search_pattern = search_pattern,
      replace_pattern = replace_pattern,
    })

    if succeed then
      treeview:remove_all_locations(nodestate)
    end
    return succeed
  end

  local match_offsets = {} ---@type integer[]
  for i = 1, L, 1 do
    local location = locations[i] ---@type eve.ux.searcher.view.filetree.ILeafLocationState
    if treeview:isvisible(location.locationuuid) then
      match_offsets[#match_offsets + 1] = location.match.preview.offset
    end
  end

  ---@type boolean
  local succeed = oxi.replacer.replace_file_by_matches({
    cwd = cwd,
    filepath = node.data.filepath,
    flag_case_sensitive = flag_case_sensitive,
    flag_regex = flag_regex,
    search_pattern = search_pattern,
    replace_pattern = replace_pattern,
    match_offsets = match_offsets,
  })

  if succeed then
    local k = 0 ---@type integer
    local statemap = treeview.statemap ---@type table<string, eve.ux.searcher.view.filetree.INodeState>

    for i = 1, L, 1 do
      local location = locations[i] ---@type eve.ux.searcher.view.filetree.ILeafLocationState
      if treeview:isvisible(location.locationuuid) then
        statemap[location.locationuuid] = nil
      else
        k = k + 1 ---@type integer
        locations[k] = location ---@type eve.ux.searcher.view.filetree.ILeafLocationState
      end
    end
    std.table.truncate_inline(locations, k)
  end
  return succeed
end

---@param nodeuuid                      string
---@return nil
function M:__resolve_confirmation__(nodeuuid)
  local node = self:__retrieve__(nodeuuid)

  local composer = self._composer ---@type eve.ux.searcher.BasicComposer
  local filetree = self._filetree ---@type std.collection.Filetree
  local retriever = self._retriever ---@type eve.ux.retriever.TreeRetriever
  local treeview = self._treeview ---@type eve.ux.searcher.FiletreeView

  local rootnode = filetree:retrieve(self._uuid_root) ---@type std.collection.filetree.INode|nil

  if self:__has_selected_node__() then
    local linecount = retriever:linecount() ---@type integer
    local filepaths = {} ---@type string[]

    for lnum = 1, linecount, 1 do
      local uuid = retriever:retrieve_uuid(lnum) ---@type string|nil
      if uuid ~= nil then
        local isselected = treeview:isselected(uuid) ---@type boolean
        if isselected then
          local o = filetree:retrieve(uuid) ---@type std.collection.filetree.INode|nil
          treeview:set_selected(uuid, false)
          if o ~= nil and o.data.filetype == "file" then
            filepaths[#filepaths + 1] = o.data.filepath
          end
        end
      end
    end

    if #filepaths > 0 then
      composer:close()
      composer:mark_result_dirty()
      self._on_confirm(self, filepaths)
      return
    end
  end

  local filepath = rootnode ~= nil and std.path.relative(rootnode.data.filepath, node.data.filepath, false)
    or node.data.filepath
  composer:close()
  self._on_confirm(self, { filepath })
end

---@param nodeuuid                      string
---@return std.collection.filetree.INode
---@return eve.ux.searcher.view.filetree.INodeState
function M:__retrieve__(nodeuuid)
  ---@type eve.ux.searcher.view.filetree.INodeState|nil
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

---@return std.collection.filetree.INode|nil
function M:__retrieve_filenode__()
  local lnum = self.result.lnum_current:snapshot() ---@type integer
  if lnum < 1 then
    return
  end

  local nodeuuid = self._retriever:retrieve_uuid(lnum) ---@type string|nil
  if nodeuuid == nil then
    return
  end

  local nodestate = self._treeview:retrieve(nodeuuid) ---@type eve.ux.searcher.view.filetree.INodeState|nil
  if nodestate == nil then
    return
  end

  local fileuuid = nodestate.nodetype == "location" and nodestate.leafuuid or nodeuuid ---@type string
  local node = fileuuid ~= nil and self._filetree:retrieve(fileuuid) or nil ---@type std.collection.filetree.INode|nil
  return node
end

---@return std.collection.filetree.INode|nil
function M:__retrieve_rootnode__()
  local rootuuid = self._uuid_root ---@type string
  local rootnode = self._filetree:retrieve(rootuuid) ---@type std.collection.filetree.INode|nil
  return rootnode
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
  local retriever = self._retriever ---@type eve.ux.retriever.TreeRetriever

  if winnr == self.result:get_winnr() then
    local mode = vim.fn.mode()
    if mode == "v" or mode == "V" or mode == "\22" then
      local lnum_from, lnum_end = eve.buf.retrieve_visual_lnum_range() ---@type integer, integer
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

---@param nodeuuid                      string
---@param recursively                   boolean
---@return nil
function M:__toggle_node__(nodeuuid, recursively)
  local node, nodestate = self:__retrieve__(nodeuuid)

  local composer = self._composer ---@type eve.ux.searcher.BasicComposer
  local treeview = self._treeview ---@type eve.ux.searcher.FiletreeView
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

  if self._on_confirm == nil then
    local lnum ---@type integer|nil
    local col ---@type integer|nil
    if nodestate.nodetype == "location" then
      lnum = nodestate.lnum ---@type integer|nil
      col = nodestate.col ---@type integer|nil
    else
      if nodestate.locations ~= nil and #nodestate.locations > 0 then
        local first_location = nodestate.locations[1] ---@type eve.ux.picker.view.filetree.ILocationNodeState
        lnum = first_location.lnum ---@type integer|nil
        col = first_location.col ---@type integer|nil
      end
    end

    local winnr_sourcefile = self:__focus_source_win__() ---@type integer|nil
    if winnr_sourcefile ~= nil and vim.api.nvim_win_is_valid(winnr_sourcefile) then
      vim.api.nvim_set_current_win(winnr_sourcefile)
    end

    composer:close()
    eve.win.open_filepath(winnr_sourcefile, node.data.filepath, lnum, col)
  end
end

return M
