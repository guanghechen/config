---@diagnostic disable: invisible
local __module_name__ = "eve.ux.picker.composer.filetree" ---@type string

---@alias eve.ux.picker.composer.filetree.IOnAttached
---| fun(self: eve.ux.picker.FiletreeComposer, rootpath: string): nil

---@alias eve.ux.picker.composer.filetree.IOnClosed
---| fun(self: eve.ux.picker.FiletreeComposer): nil

---@alias eve.ux.picker.composer.filetree.IOnConfirm
---| fun(self: eve.ux.picker.FiletreeComposer, selected_filepaths: string[]|nil): nil

---@alias eve.ux.picker.composer.filetree.IOnDisposed
---| fun(): nil

---@alias eve.ux.picker.composer.filetree.IOnFocused
---| fun(self: eve.ux.picker.FiletreeComposer): nil

---@alias eve.ux.picker.composer.filetree.IOnHidden
---| fun(self: eve.ux.picker.FiletreeComposer): nil
---
---@alias eve.ux.picker.composer.filetree.IOnRefresh
---| fun(self: eve.ux.picker.FiletreeComposer, force: boolean): nil

---@alias eve.ux.picker.composer.filetree.IOnResultRendered
---| fun(self: eve.ux.picker.FiletreeComposer, bufnr: integer): nil

---@alias eve.ux.picker.composer.filetree.IOnPreviewRendered
---| fun(self: eve.ux.picker.FiletreeComposer, bufnr: integer): nil

---@class eve.ux.picker.composer.filetree.ISelectedItemLocation
---@field public lnum                   integer
---@field public col                    integer|nil

---@class eve.ux.picker.composer.filetree.actions
---@field public attach_node            fun(): nil
---@field public create_node            fun(): nil
---@field public open_node              fun(): nil
---@field public remove_node            fun(): nil
---@field public rename_node            fun(): nil
---@field public toggle_node            fun(): nil
---@field public toggle_node_deeply     fun(): nil
---
---@field public add_node_to_avante     fun(): nil
---@field public add_subtree_to_avante  fun(): nil
---@field public attach_parent          fun(): nil
---@field public copy_node_filepath     fun(): nil
---@field public goto_lnum_lastchild    fun(): nil
---@field public goto_lnum_parent       fun(): nil
---@field public mark_node_invisible    fun(): nil
---@field public mark_subroot_invisible fun(): nil
---@field public send_to_qflist         fun(): nil
---@field public toggle_selection       fun(): nil

----------------------------------------------------------------------------------------------------

---@class eve.ux.picker.IFiletreeComposerProps
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
---@field public render_preview         ?eve.ux.picker.preview.IDraw
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
---
---@field public on_attached            ?eve.ux.picker.composer.filetree.IOnAttached
---@field public on_closed              ?eve.ux.picker.composer.filetree.IOnClosed
---@field public on_confirm             ?eve.ux.picker.composer.filetree.IOnConfirm
---@field public on_disposed            ?eve.ux.picker.composer.filetree.IOnDisposed
---@field public on_focused             ?eve.ux.picker.composer.filetree.IOnFocused
---@field public on_hidden              ?eve.ux.picker.composer.filetree.IOnHidden
---@field public on_refresh             ?eve.ux.picker.composer.filetree.IOnRefresh
---@field public on_preview_rendered    ?eve.ux.picker.composer.filetree.IOnPreviewRendered
---@field public on_result_rendered     ?eve.ux.picker.composer.filetree.IOnResultRendered

---@class eve.ux.picker.FiletreeComposer
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
---@field protected _filetree           std.collection.Filetree
---@field protected _frecency           std.collection.IFrecency|nil
---@field protected _composer           eve.ux.picker.BasicComposer
---@field protected _plainfile          eve.ux.view.Plainfile
---@field protected _retriever          eve.ux.retriever.TreeRetriever
---@field protected _scheduler_match    std.collection.Scheduler
---@field protected _treeview           eve.ux.picker.FiletreeView
---
---@field protected _last_preview_filepath  string|nil
---@field protected _uuid_root          string|nil
---@field protected _uuid_current       string|nil
---@field protected _uuids_file         string[]
---@field protected _uuids_order        string[]
---
---@field protected _on_attached        eve.ux.picker.composer.filetree.IOnAttached
---@field protected _on_confirm         eve.ux.picker.composer.filetree.IOnConfirm|nil
---@field protected _on_disposed        eve.ux.picker.composer.filetree.IOnDisposed
local M = {}
M.__index = M

---@param props                         eve.ux.picker.IFiletreeComposerProps
---@return eve.ux.picker.FiletreeComposer
function M.new(props)
  local name = props.name ---@type string
  local fullname = string.format("%s -> %s", name, __module_name__) ---@type string
  local picker_uuid = props.uuid or oxi.fn.uuid() ---@type string
  local permanent = props.permanent ---@type boolean
  local preview = props.preview ~= false ---@type boolean
  local title = props.title ---@type string
  local height = props.height ---@type number|nil
  local width = props.width ---@type number|nil

  local keymaps_common = props.keymaps_common ---@type std.t.IKeymap[]|nil
  local keymaps_finder = props.keymaps_finder ---@type std.t.IKeymap[]|nil
  local keymaps_preview = props.keymaps_preview ---@type std.t.IKeymap[]|nil
  local keymaps_result = props.keymaps_result ---@type std.t.IKeymap[]|nil

  local render_preview = props.render_preview ---@type eve.ux.picker.preview.IDraw|nil

  local finder_input_history = props.finder_input_history ---@type std.collection.IHistory|nil
  local o_finder_input = props.finder_input ---@type std.collection.IObservable
  local o_flag_fuzzy = props.flag_fuzzy ---@type std.collection.IObservable
  local o_flag_regex = props.flag_regex ---@type std.collection.IObservable
  local o_flag_foldempty = props.flag_foldempty ---@type std.collection.IObservable
  local o_flag_sensitive = props.flag_sensitive ---@type std.collection.IObservable
  local o_flag_selected = props.flag_selected ---@type std.collection.IObservable
  local o_flag_viewtype = props.flag_viewtype ---@type std.collection.IObservable

  local flags_append = props.flags_append ---@type eve.ux.picker.result.IFlagItemRaw[]|nil
  local flags_prepend = props.flags_prepend ---@type eve.ux.picker.result.IFlagItemRaw[]|nil
  local flags_start_index = props.flags_start_index ---@type 0|1|nil

  local frecency = props.frecency ---@type std.collection.IFrecency|nil

  local on_attached = props.on_attached or std.fn.noop ---@type eve.ux.picker.composer.filetree.IOnAttached
  local on_closed = props.on_closed or std.fn.noop ---@type eve.ux.picker.composer.filetree.IOnClosed
  local on_confirm = props.on_confirm ---@type eve.ux.picker.composer.filetree.IOnConfirm|nil
  local on_disposed = props.on_disposed or std.fn.noop ---@type eve.ux.picker.composer.filetree.IOnDisposed
  local on_focused = props.on_focused or std.fn.noop ---@type eve.ux.picker.composer.filetree.IOnFocused
  local on_hidden = props.on_hidden or std.fn.noop ---@type eve.ux.picker.composer.filetree.IOnHidden
  local _on_refresh = props.on_refresh or std.fn.noop ---@type eve.ux.picker.composer.filetree.IOnRefresh
  local on_result_rendered = props.on_result_rendered or std.fn.noop ---@type eve.ux.picker.composer.filetree.IOnResultRendered
  local on_preview_rendered = props.on_preview_rendered or std.fn.noop ---@type eve.ux.picker.composer.filetree.IOnPreviewRendered

  local self = setmetatable({}, M)

  ---@type std.collection.Filetree
  local filetree = std.Filetree.new({ name = fullname })

  ---@type eve.ux.picker.FiletreeView
  local treeview = eve.ux.picker.FiletreeView.new({
    name = fullname,
    tree = filetree,
    flag_foldempty = o_flag_foldempty,
    indent = "",
    indent_hln = "f_utw_indent_float",
  })

  ---@type eve.ux.picker.composer.filetree.IOnRefresh
  local function on_refresh(_, force)
    treeview:mark_cache_invisible_dirty()
    _on_refresh(self, force)
  end

  ---@type eve.ux.retriever.TreeRetriever
  local retriever = eve.ux.retriever.TreeRetriever.new({
    name = fullname,
  })

  ---@type eve.ux.view.Plainfile
  local plainfile = eve.ux.view.Plainfile.new({
    name = fullname,
  })

  local scheduler_match = std.Scheduler.new({
    name = string.format("%s#match", fullname),
    mode = "debounce",
    delay = 64,
    timeout = 0,
    silent = std.fn.falsy,
    value = std.Observable.from_value(true),
    task = function()
      local input = o_finder_input:snapshot() ---@type string
      self:__match__(input)
      treeview:mark_cache_treeview_dirty()
      self:mark_result_dirty()
    end,
  })

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
      desc = string.format("%s: fuzzy", name),
      callback = function()
        local enabled = o_flag_fuzzy:snapshot() ---@type boolean
        o_flag_fuzzy:next(not enabled)
      end,
      snapshot = function()
        local enabled = o_flag_fuzzy:snapshot() ---@type boolean
        return eve.icon.symbols.flag_fuzzy, enabled and "picker_flag_blue" or "picker_flag_grey"
      end,
    }
    flags[#flags + 1] = {
      desc = string.format("%s: sensitive", name),
      callback = function()
        local enabled = o_flag_sensitive:snapshot() ---@type boolean
        o_flag_sensitive:next(not enabled)
      end,
      snapshot = function()
        local enabled = o_flag_sensitive:snapshot() ---@type boolean
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

  ---@type eve.ux.picker.composer.filetree.actions
  local actions = {
    attach_node = function()
      local nodeuuid = self:__retrieve_nodeuuid__() ---@type string|nil
      if nodeuuid == nil then
        return
      end

      local nodestate = treeview:retrieve(nodeuuid) ---@type eve.ux.picker.view.filetree.INodeState|nil
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
    create_node = function()
      local filenode = self:__retrieve_filenode__() ---@type std.collection.filetree.INode|nil
      if filenode == nil then
        return
      end

      local rootnode = self:__retrieve_rootnode__() ---@type std.collection.filetree.INode|nil
      if rootnode == nil then
        return
      end

      local winnr_current = vim.api.nvim_get_current_win() ---@type integer
      local winnr_result = self._composer.result:get_winnr() ---@type integer|nil
      if winnr_result == nil or winnr_result < 1 or not vim.api.nvim_win_is_valid(winnr_result) then
        return
      end

      local rootpath = rootnode.data.filepath ---@type string
      local nodepath = filenode.data.filepath ---@type string
      local relpath = std.path.relative(rootpath, nodepath, false) ---@type string
      if filenode.data.filetype == "directory" and #relpath > 0 then
        relpath = relpath .. std.env.PATH_SEP ---@type string
      end

      ---@param filepath                string|nil
      ---@return nil
      local function on_confirmed(filepath)
        if filepath == nil or filepath == "" then
          return
        end

        local isdir = std.path.is_dirpath(filepath) ---@type boolean
        filepath = std.path.resolve(rootpath, filepath) ---@type string

        if std.path.is_exist(filepath) then
          std.reporter.error({
            from = fullname,
            subject = "create_node",
            message = "The filepath is already exist.",
            details = { filepath = filepath, isdir = isdir },
          })
          return
        end

        if isdir then
          vim.fn.mkdir(filepath, "p")
          treeview:insert_dirpath(filepath)
        else
          std.path.mkdir_if_nonexist(std.path.dirname(filepath))
          vim.fn.writefile({}, filepath)
          treeview:insert_filepath(filepath, false)

          local uuid = std.Filetree.uuid(filepath)
          table.insert(self._uuids_file, uuid)
          table.insert(self._uuids_order, uuid)
        end

        scheduler_match:schedule()
      end

      ---@return nil
      local function handle()
        vim.ui.input({
          prompt = string.format(" New file / directory ", std.env.PATH_SEP),
          default = relpath,
          relative = "cursor",
        }, function(filepath)
          on_confirmed(filepath)

          if winnr_current ~= winnr_result then
            vim.schedule(function()
              if vim.api.nvim_win_is_valid(winnr_current) then
                vim.api.nvim_set_current_win(winnr_current)
              end
            end)
          end
        end)
      end

      if winnr_current == winnr_result then
        handle()
      else
        vim.api.nvim_win_call(winnr_result, handle)
      end
    end,
    open_node = function()
      local nodeuuid = self:__retrieve_nodeuuid__() ---@type string|nil
      if nodeuuid ~= nil then
        if on_confirm == nil then
          self:__open_node__(nodeuuid)
        else
          self:__resolve_confirmation__(nodeuuid)
        end
      end
    end,
    remove_node = function()
      local filenode = self:__retrieve_filenode__() ---@type std.collection.filetree.INode|nil
      if filenode == nil then
        return
      end

      local rootnode = self:__retrieve_rootnode__() ---@type std.collection.filetree.INode|nil
      if rootnode == nil then
        return
      end

      local winnr_current = vim.api.nvim_get_current_win() ---@type integer
      local winnr_result = self._composer.result:get_winnr() ---@type integer|nil
      if winnr_result == nil or winnr_result < 1 or not vim.api.nvim_win_is_valid(winnr_result) then
        return
      end

      local nodepath = filenode.data.filepath ---@type string
      local rootpath = rootnode.data.filepath ---@type string
      local relpath = std.path.relative(rootpath, nodepath, false) ---@type string
      if filenode.data.filetype == "directory" and #relpath > 0 then
        relpath = relpath .. std.env.PATH_SEP ---@type string
      end

      ---@param answer                  string|nil
      ---@return nil
      local function on_confirmed(answer)
        if answer == nil then
          return
        end

        answer = vim.trim(answer:lower()) ---@type string
        if answer:sub(1, 1) ~= "y" then
          return
        end

        local isdir = filenode.data.filetype == "directory" ---@type boolean

        local success = false ---@type boolean
        if isdir then
          success = vim.fn.delete(nodepath, "rf") == 0
        else
          success = vim.fn.delete(nodepath) == 0
        end

        if not success then
          std.reporter.error({
            from = fullname,
            subject = "remove_node",
            message = string.format("Failed to delete %s.", isdir and "directory" or "file"),
            details = { filepath = nodepath, isdir = isdir },
          })
          return
        end

        local fileuuid = filenode.uuid ---@type string
        treeview:remove(fileuuid)
        if not isdir then
          std.table.filter_inline(self._uuids_file, function(uuid)
            return uuid ~= fileuuid
          end)
          std.table.filter_inline(self._uuids_order, function(uuid)
            return uuid ~= fileuuid
          end)
        end
        scheduler_match:schedule()
      end

      ---@return nil
      local function handle()
        vim.ui.input({
          inputtype = "confirmation",
          prompt = string.format(" Delete '%s' ", relpath),
          relative = "cursor",
        }, function(answer)
          on_confirmed(answer)

          if winnr_current ~= winnr_result then
            vim.schedule(function()
              if vim.api.nvim_win_is_valid(winnr_current) then
                vim.api.nvim_set_current_win(winnr_current)
              end
            end)
          end
        end)
      end

      if winnr_current == winnr_result then
        handle()
      else
        vim.api.nvim_win_call(winnr_result, handle)
      end
    end,
    rename_node = function()
      local filenode = self:__retrieve_filenode__() ---@type std.collection.filetree.INode|nil
      if filenode == nil then
        return
      end

      local winnr_current = vim.api.nvim_get_current_win() ---@type integer
      local winnr_result = self._composer.result:get_winnr() ---@type integer|nil
      if winnr_result == nil or winnr_result < 1 or not vim.api.nvim_win_is_valid(winnr_result) then
        return
      end

      local filepath = filenode.data.filepath ---@type string
      local dirname = std.path.dirname(filepath) ---@type string
      local filename = std.path.basename(filepath) ---@type string

      ---@param next_filename           string|nil
      ---@return nil
      local function on_confirmed(next_filename)
        if next_filename == nil or next_filename == "" then
          return
        end

        if next_filename:find("[/\\]") then
          std.reporter.error({
            from = fullname,
            subject = "rename_node",
            message = "Filename cannot contain path separators (/ or \\).",
            details = { from = filepath, filename = filename, next_filename = next_filename },
          })
          return
        end

        local next_filepath = std.path.join(dirname, next_filename)
        if std.path.is_exist(next_filepath) then
          -- Ask user if they want to overwrite
          vim.ui.select({ "No", "Yes" }, {
            prompt = string.format('File "%s" already exists. Overwrite?', next_filename),
            format_item = function(item)
              return item
            end,
          }, function(choice)
            if choice == "Yes" then
              local isdir = filenode.data.filetype == "directory"
              local success = eve.fn.rename({
                from = filepath,
                to = next_filepath,
                isdir = isdir,
                force = true,
              })

              if success then
                self:__update_tree_after_rename__(filepath, next_filepath, isdir)
              end
            end
          end)
          return
        end

        local isdir = filenode.data.filetype == "directory"
        local success = eve.fn.rename({
          from = filepath,
          to = next_filepath,
          isdir = isdir,
        })

        if not success then
          -- Error already reported by eve.fn.rename, just return
          return
        end

        self:__update_tree_after_rename__(filepath, next_filepath, isdir)
      end

      ---@return nil
      local function handle()
        vim.ui.input({
          prompt = string.format(' Rename for "%s" ', filename),
          default = filename,
          relative = "cursor",
        }, function(next_filename)
          on_confirmed(next_filename)

          if winnr_current ~= winnr_result then
            vim.schedule(function()
              if vim.api.nvim_win_is_valid(winnr_current) then
                vim.api.nvim_set_current_win(winnr_current)
              end
            end)
          end
        end)
      end

      if winnr_current == winnr_result then
        handle()
      else
        vim.api.nvim_win_call(winnr_result, handle)
      end
    end,
    toggle_node = function()
      local nodeuuid = self:__retrieve_nodeuuid__() ---@type string|nil
      if nodeuuid ~= nil then
        self:__toggle_node__(nodeuuid, false)
      end
    end,
    toggle_node_deeply = function()
      local nodeuuid = self:__retrieve_nodeuuid__() ---@type string|nil
      if nodeuuid ~= nil then
        self:__toggle_node__(nodeuuid, true)
      end
    end,

    ------------------------------------------------------------------------------------------------

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

      local finder_input = o_finder_input:snapshot() ---@type string
      for lnum = lnum_from, lnum_to, 1 do
        local nodeuuid = retriever:retrieve_uuid(lnum) ---@type string|nil
        if nodeuuid ~= nil then
          local nodestate = treeview:retrieve(nodeuuid) ---@type eve.ux.picker.view.filetree.INodeState|nil
          if nodestate ~= nil and (finder_input == "" or nodestate.nodetype ~= "container") then
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

            local nodestate = treeview:retrieve(uuid) ---@type eve.ux.picker.view.filetree.INodeState|nil
            local locations = nodestate and nodestate.locations or nil ---@type eve.ux.picker.view.filetree.ILocationNodeState[]|nil
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

        local nodestate = treeview:retrieve(nodeuuid) ---@type eve.ux.picker.view.filetree.INodeState|nil
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
          local childstate = treeview:retrieve(nodeuuid) ---@type eve.ux.picker.view.filetree.INodeState|nil
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
          local childstate = treeview:retrieve(nodeuuid) ---@type eve.ux.picker.view.filetree.INodeState|nil
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
      desc = "filetree: send to qflist",
      callback = actions.send_to_qflist,
    },
  }

  ---@type std.t.IKeymap[]
  local preset_keymaps_finder = {
    {
      modes = { "n", "v" },
      key = ".",
      desc = "filetree: change root",
      callback = actions.attach_node,
    },
    {
      modes = { "n", "v" },
      key = "<Backspace>",
      desc = "filetree: change root to parent",
      callback = actions.attach_parent,
    },
    {
      modes = { "i", "n", "v" },
      key = "<Enter>",
      desc = "filetree: open",
      callback = actions.open_node,
    },
    {
      modes = { "i", "n", "v" },
      key = "<C-h>",
      aliases = { "<C-l>" },
      desc = "filetree: toggle",
      callback = actions.toggle_node,
    },
    {
      modes = { "n", "v" },
      key = "<Tab>",
      desc = "filetree: toggle selection",
      callback = actions.toggle_selection,
    },
    {
      modes = { "n", "v" },
      key = "<leader>D",
      desc = "filetree: mark the subroot invisible",
      callback = actions.mark_subroot_invisible,
    },
    {
      modes = { "n", "v" },
      key = "<leader>dd",
      desc = "filetree: mark the node invisible",
      callback = actions.mark_node_invisible,
    },
    {
      modes = { "n", "v" },
      key = "[i",
      desc = "filetree: goto the parent line",
      callback = actions.goto_lnum_parent,
    },
    {
      modes = { "n", "v" },
      key = "]i",
      desc = "filetree: goto the lastchild line",
      callback = actions.goto_lnum_lastchild,
    },
    {
      modes = { "n", "v" },
      key = "oA",
      desc = "filetree: add to avante (full subtree)",
      callback = actions.add_subtree_to_avante,
    },
    {
      modes = { "n", "v" },
      key = "oa",
      desc = "filetree: add to avante",
      callback = actions.add_node_to_avante,
    },
    {
      modes = { "n", "v" },
      key = "oc",
      desc = "filetree: copy filepath",
      callback = actions.copy_node_filepath,
    },
    {
      modes = { "n", "v" },
      key = "od",
      desc = "filetree: remove node",
      callback = actions.remove_node,
    },
    {
      modes = { "n", "v" },
      key = "oi",
      desc = "filetree: create node",
      callback = actions.create_node,
    },
    {
      modes = { "n", "v" },
      key = "or",
      desc = "filetree: rename node",
      callback = actions.rename_node,
    },
    {
      modes = { "n", "v" },
      key = "oz",
      desc = "filetree: toggle (recursively)",
      callback = actions.toggle_node_deeply,
    },
  }

  ---@type std.t.IKeymap[]
  local preset_keymaps_result = {
    {
      modes = { "i", "n", "v" },
      key = ".",
      desc = "filetree: change root",
      callback = actions.attach_node,
    },
    {
      modes = { "i", "n", "v" },
      key = "<Backspace>",
      desc = "filetree: change root to parent",
      callback = actions.attach_parent,
    },
    {
      modes = { "i", "n", "v" },
      key = "<Enter>",
      aliases = { "l", "w" },
      desc = "filetree: open",
      callback = actions.open_node,
    },
    {
      modes = { "i", "n", "v" },
      key = "<Right>",
      aliases = { "<Left>", "c", "h" },
      desc = "filetree: toggle",
      callback = actions.toggle_node,
    },
    {
      modes = { "i", "n", "v" },
      key = "<2-LeftMouse>",
      desc = "filetree: toggle",
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
      desc = "filetree: toggle selection",
      callback = actions.toggle_selection,
    },
    {
      modes = { "i", "n", "v" },
      key = "<leader>D",
      desc = "filetree: mark the subroot invisible",
      callback = actions.mark_subroot_invisible,
    },
    {
      modes = { "i", "n", "v" },
      key = "<leader>dd",
      desc = "filetree: mark the node invisible",
      callback = actions.mark_node_invisible,
    },
    {
      modes = { "i", "n", "v" },
      key = "[i",
      desc = "filetree: goto the parent line",
      callback = actions.goto_lnum_parent,
    },
    {
      modes = { "i", "n", "v" },
      key = "]i",
      desc = "filetree: goto the lastchild line",
      callback = actions.goto_lnum_lastchild,
    },
    {
      modes = { "i", "n", "v" },
      key = "oA",
      desc = "filetree: add to avante (full subtree)",
      callback = actions.add_subtree_to_avante,
    },
    {
      modes = { "i", "n", "v" },
      key = "oa",
      desc = "filetree: add to avante",
      callback = actions.add_node_to_avante,
    },
    {
      modes = { "i", "n", "v" },
      key = "oc",
      desc = "filetree: copy filepath",
      callback = actions.copy_node_filepath,
    },
    {
      modes = { "i", "n", "v" },
      key = "od",
      alias = { "d" },
      desc = "filetree: remove node",
      callback = actions.remove_node,
    },
    {
      modes = { "i", "n", "v" },
      key = "oi",
      alias = { "a" },
      desc = "filetree: create node",
      callback = actions.create_node,
    },
    {
      modes = { "i", "n", "v" },
      key = "or",
      alias = { "r" },
      desc = "filetree: rename node",
      callback = actions.rename_node,
    },
    {
      modes = { "i", "n", "v" },
      key = "oz",
      desc = "filetree: toggle (recursively)",
      callback = actions.toggle_node_deeply,
    },
  }

  if preview and render_preview == nil then
    ---@type eve.ux.picker.preview.IDraw|nil
    render_preview = function(bufnr, force)
      return self:render_preview(bufnr, force)
    end
  end

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

    finder_input = o_finder_input,
    finder_input_history = finder_input_history,
    finder_title = title,

    result_number = true,

    ---@type eve.ux.picker.result.IIsSelected
    result_isselected = function(_, lnum)
      local uuid = retriever:retrieve_uuid(lnum) ---@type string|nil
      return uuid ~= nil and treeview:isselected(uuid)
    end,

    ---@type eve.ux.picker.result.IDraw
    render_result = function(bufnr)
      local viewtype = o_flag_viewtype:snapshot() ---@type eve.ux.view.tree.ViewtypeEnum
      local result ---@type eve.ux.view.tree.IRenderResult
      local only_matched = o_finder_input:snapshot() ~= "" ---@type boolean
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
      local ret = { lnum_current = lnum_current } ---@type eve.ux.picker.result.IDrawResult
      return ret
    end,

    ---@type eve.ux.picker.preview.IDraw|nil
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
    on_preview_rendered = function(_, bufnr)
      on_preview_rendered(self, bufnr)
    end,
    on_result_rendered = function(_, bufnr)
      on_result_rendered(self, bufnr)
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
  self.flag_sensitive = o_flag_sensitive
  self.flag_selected = o_flag_selected
  self.flag_viewtype = o_flag_viewtype

  self._disposed = false
  self._filetree = filetree
  self._frecency = frecency
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
    { o_finder_input, o_flag_foldempty, o_flag_fuzzy, o_flag_regex, o_flag_sensitive, o_flag_selected, o_flag_viewtype },
    function()
      composer:mark_result_flags_dirty()
    end,
    true
  )
  std.fn.observe({ o_flag_selected, o_flag_viewtype }, function()
    composer:mark_result_dirty()
  end, true)
  std.fn.observe({ o_finder_input, o_flag_fuzzy, o_flag_regex, o_flag_sensitive }, function()
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
  local on_dispose = self._on_disposed ---@type eve.ux.picker.composer.filetree.IOnDisposed
  local composer = self._composer ---@type eve.ux.picker.BasicComposer
  local plainfile = self._plainfile ---@type eve.ux.view.Plainfile
  local retriever = self._retriever ---@type eve.ux.retriever.TreeRetriever
  local scheduler_match = self._scheduler_match ---@type std.collection.Scheduler
  local treeview = self._treeview ---@type eve.ux.picker.FiletreeView

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

  self._frecency = nil
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
---@return eve.ux.picker.FiletreeComposer
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
  local treeview = self._treeview ---@type eve.ux.picker.FiletreeView

  treeview:mark_cache_listview_dirty()
  self._uuid_root = rootuuid
  self._scheduler_match:schedule()

  local next_rootnode = filetree:retrieve(rootuuid)
  if next_rootnode ~= nil then
    self._on_attached(self, next_rootnode.data.filepath)
  end
  return self
end

---@return eve.ux.picker.FiletreeComposer
function M:mark_result_dirty()
  self:__health__()
  self._composer:mark_result_dirty()
  return self
end

---@return eve.ux.picker.FiletreeComposer
function M:mark_result_flags_dirty()
  self:__health__()
  self._composer:mark_result_flags_dirty()
  return self
end

---@param cwd                           string
---@param filepaths                     string[]
---@param with_positions                boolean
---@return eve.ux.picker.FiletreeComposer
function M:reset_filepaths(cwd, filepaths, with_positions)
  self:__health__()

  local frecency = self._frecency ---@type std.collection.IFrecency|nil
  local treeview = self._treeview ---@type eve.ux.picker.FiletreeView

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

  self._on_attached(self, cwd)
  return self
end

----------------------------------------------------------------------------------------------------

---@param bufnr                         integer
---@param force                         boolean
---@return eve.ux.picker.preview.IDrawResult
function M:render_preview(bufnr, force)
  local nodeuuid, lnum = self:__retrieve_nodeuuid__() ---@type string|nil, integer
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

  local filetree = self._filetree ---@type std.collection.Filetree
  local treeview = self._treeview ---@type eve.ux.picker.FiletreeView
  local plainfile = self._plainfile ---@type eve.ux.view.Plainfile
  local o_flag_foldempty = self.flag_foldempty ---@type std.collection.IObservable

  local node, nodestate = self:__retrieve__(nodeuuid)

  force = force or node.data.filepath ~= self._last_preview_filepath ---@type boolean
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

    ---@cast nodestate          eve.ux.picker.view.filetree.IDirectoryNodeState
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
    ---@cast nodestate          eve.ux.picker.view.filetree.IFileNodeState
    if nodestate.locations ~= nil and #nodestate.locations > 0 then
      ---@diagnostic disable-next-line: cast-local-type
      nodestate = nodestate.locations[1]
    end
  end
  ---@cast nodestate          eve.ux.picker.view.filetree.IFileNodeState|eve.ux.picker.view.filetree.ILocationNodeState

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

----------------------------------------------------------------------------------------------------

---@protected
---@return integer[]
function M:__collect_selected_lnums__()
  self:__health__()

  local retriever = self._retriever ---@type eve.ux.retriever.TreeRetriever
  local treeview = self._treeview ---@type eve.ux.picker.FiletreeView

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

  local treeview = self._treeview ---@type eve.ux.picker.FiletreeView

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
  local frecency = self._frecency ---@type std.collection.IFrecency|nil
  local treeview = self._treeview ---@type eve.ux.picker.FiletreeView

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
      ---@cast na                       eve.ux.picker.view.filetree.IFileNodeState
      ---@cast nb                       eve.ux.picker.view.filetree.IFileNodeState

      local sa = na.cache_match and na.cache_match.score or 0 + (frecency:score(a) or 0) ---@type integer
      local sb = nb.cache_match and nb.cache_match.score or 0 + (frecency:score(b) or 0) ---@type integer
      return sa > sb
    end)
  else
    table.sort(uuids_order, function(a, b)
      local na = treeview:retrieve(a)
      local nb = treeview:retrieve(b)
      ---@cast na                       eve.ux.picker.view.filetree.IFileNodeState
      ---@cast nb                       eve.ux.picker.view.filetree.IFileNodeState

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

  local composer = self._composer ---@type eve.ux.picker.BasicComposer
  local filetree = self._filetree ---@type std.collection.Filetree
  local retriever = self._retriever ---@type eve.ux.retriever.TreeRetriever
  local treeview = self._treeview ---@type eve.ux.picker.FiletreeView

  if self:__has_selected_node__() then
    local linecount = retriever:linecount() ---@type integer
    local last_nodestate = nil ---@type eve.ux.picker.view.filetree.IFileNodeState|nil
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

            local s = treeview:retrieve(nodeuuid) ---@type eve.ux.picker.view.filetree.INodeState|nil
            if s ~= nil then
              ---@cast s                      eve.ux.picker.view.filetree.IFileNodeState
              last_nodestate = s
            end
          end
        end
      end
    end

    if #filepaths > 0 then
      ---@cast last_nodestate             eve.ux.picker.view.filetree.IFileNodeState
      local locations = last_nodestate.locations
      local first_location = locations ~= nil and locations[1] or nil ---@type eve.ux.picker.view.filetree.ILocationNodeState|nil
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

---@param nodeuuid                      string
---@return nil
function M:__resolve_confirmation__(nodeuuid)
  local node = self:__retrieve__(nodeuuid)

  local composer = self._composer ---@type eve.ux.picker.BasicComposer
  local filetree = self._filetree ---@type std.collection.Filetree
  local retriever = self._retriever ---@type eve.ux.retriever.TreeRetriever
  local treeview = self._treeview ---@type eve.ux.picker.FiletreeView

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
---@return eve.ux.picker.view.filetree.INodeState
function M:__retrieve__(nodeuuid)
  ---@type eve.ux.picker.view.filetree.INodeState|nil
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

  local nodestate = self._treeview:retrieve(nodeuuid) ---@type eve.ux.picker.view.filetree.INodeState|nil
  if nodestate == nil then
    return
  end

  local fileuuid = nodestate.nodetype == "location" and nodestate.leafuuid or nodeuuid ---@type string
  local node = fileuuid ~= nil and self._filetree:retrieve(fileuuid) or nil ---@type std.collection.filetree.INode|nil
  return node
end

---@param from                          string
---@param to                            string
---@param isdir                         boolean
---@return nil
function M:__update_tree_after_rename__(from, to, isdir)
  local from_nodeuuid = std.Filetree.uuid(from) ---@type string
  local to_nodeuuid = std.Filetree.uuid(to) ---@type string

  local filepaths = {} ---@type string[]

  if isdir then
    local result = oxi.fs.collect_files(from, true)
    if result and result.files then
      for _, relative_filepath in ipairs(result.files) do
        local to_filepath = to .. std.env.PATH_SEP .. relative_filepath ---@type string
        filepaths[#filepaths + 1] = to_filepath
      end
    end
  else
    filepaths[#filepaths + 1] = to ---@type string
  end

  local filetree = self._filetree ---@type std.collection.Filetree
  local treeview = self._treeview ---@type eve.ux.picker.FiletreeView
  local selected_set = treeview:collect_selected() ---@type table<string, true>
  local scheduler_match = self._scheduler_match

  treeview:remove(from_nodeuuid)
  filetree:remove(from_nodeuuid)

  for _, filepath in ipairs(filepaths) do
    filetree:insert_file_absolute(filepath)
  end

  local tick_selected = treeview._tick_selected ---@type integer
  local statemap = treeview.statemap ---@type table<string, eve.ux.view.tree.INodeState>
  ---@cast statemap                     table<string, eve.ux.picker.view.filetree.INodeState>

  filetree:unsafe_traverse(to_nodeuuid, function(ctx)
    local nodemap = ctx.nodemap ---@type table<string, std.collection.filetree.INode>

    ---@param node                      std.collection.filetree.INode
    ---@return nil
    local function traverse(node)
      if node.data.filetype == "directory" then
        ---@type eve.ux.picker.view.filetree.IDirectoryNodeState
        local nodestate = {
          nodetype = "container",
          collapsed = false,
          tick_invisible = 0,
          tick_matched = 0,
          tick_selected = selected_set[node.uuid] and tick_selected or 0,
          tick_selected_maximum = 0,
        }
        statemap[node.uuid] = nodestate

        for _, uuid in ipairs(node.children) do
          local childnode = nodemap[uuid] ---@type std.collection.filetree.INode|nil
          if childnode ~= nil then
            traverse(childnode)
          end
        end
        return
      end

      if node.data.filetype == "file" then
        ---@type eve.ux.picker.view.filetree.IFileNodeState
        local nodestate = {
          nodetype = "leaf",
          collapsed = false,
          tick_invisible = 0,
          tick_matched = 0,
          tick_selected = selected_set[node.uuid] and tick_selected or 0,
        }
        statemap[node.uuid] = nodestate
        return
      end

      std.reporter.error({
        from = self.fullname,
        subject = "reset_filepaths",
        message = "Unexpected filetype",
        details = {
          nodeuuid = node.uuid,
          nodedata = node.data,
        },
      })
    end

    traverse(ctx.rootnode)
  end)

  treeview:mark_cache_treeview_dirty()
  self:mark_result_dirty()
  scheduler_match:schedule()
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

  local composer = self._composer ---@type eve.ux.picker.BasicComposer
  local treeview = self._treeview ---@type eve.ux.picker.FiletreeView
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
