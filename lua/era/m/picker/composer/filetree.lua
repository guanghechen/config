---@diagnostic disable: invisible
---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.picker.composer.filetree" ---@type string

---@alias era.m.picker.composer.filetree.IOnAttached
---| fun(self: era.m.picker.FiletreeComposer, rootpath: string): nil

---@alias era.m.picker.composer.filetree.IOnClosed
---| fun(self: era.m.picker.FiletreeComposer): nil

---@alias era.m.picker.composer.filetree.IOnConfirm
---| fun(self: era.m.picker.FiletreeComposer, selected_filepaths: string[]|nil): nil

---@alias era.m.picker.composer.filetree.IOnDisposed
---| fun(): nil

---@alias era.m.picker.composer.filetree.IOnFocused
---| fun(self: era.m.picker.FiletreeComposer): nil

---@alias era.m.picker.composer.filetree.IOnHidden
---| fun(self: era.m.picker.FiletreeComposer): nil
---
---@alias era.m.picker.composer.filetree.IOnRefresh
---| fun(self: era.m.picker.FiletreeComposer, force: boolean): nil

---@alias era.m.picker.composer.filetree.IOnResultRendered
---| fun(self: era.m.picker.FiletreeComposer, bufnr: integer): nil

---@alias era.m.picker.composer.filetree.IOnPreviewRendered
---| fun(self: era.m.picker.FiletreeComposer, bufnr: integer, data: era.view.result_paths.IFile|nil): nil

---@class era.m.picker.composer.filetree.ISelectedItemLocation
---@field public lnum                   integer
---@field public col                    integer|nil

---@class era.m.picker.composer.filetree.actions
---@field public attach_node            fun(): nil
---@field public create_node            fun(): nil
---@field public open_node              fun(): nil
---@field public remove_node            fun(): nil
---@field public rename_node            fun(): nil
---@field public move_node              fun(): nil
---@field public collapse_node          fun(): nil
---@field public toggle_node            fun(): nil
---@field public toggle_node_deeply     fun(): nil
---
---@field public add_node_to_ai         fun(): nil
---@field public add_subtree_to_ai      fun(): nil
---@field public attach_parent          fun(): nil
---@field public copy_node_filepath     fun(): nil
---@field public goto_lnum_lastchild    fun(): nil
---@field public goto_lnum_parent       fun(): nil
---@field public mark_node_invisible    fun(): nil
---@field public mark_subroot_invisible fun(): nil
---@field public send_to_qflist         fun(): nil
---@field public toggle_selection       fun(): nil

----------------------------------------------------------------------------------------------------

---@class era.m.picker.composer.filetree.IPrepareOptions
---@field public prepare_entry          ?fun(data: era.view.result_paths.IFile): table Builds private metadata before adoption.
---@field public token                  ?stl.c.CancellationToken Cancels preparation before adoption.
---@field public keep_root              ?boolean Retain the requested root if it survives in the prepared collection.

---@class era.m.picker.IFiletreeComposerProps
---@field public uuid                   ?string
---@field public name                   string
---@field public permanent              boolean
---@field public preview                ?boolean
---@field public title                  string
---@field public height                 ?number
---@field public width                  ?number
---@field public treeview               ?era.view.ResultFiles Owned by this composer.
---
---@field public keymaps_common         ?stl.t.IKeymap[]
---@field public keymaps_finder         ?stl.t.IKeymap[]
---@field public keymaps_preview        ?stl.t.IKeymap[]
---@field public keymaps_result         ?stl.t.IKeymap[]
---
---@field public render_preview         ?era.m.picker.preview.IDraw
---
---@field public flag_foldempty         stl.c.Observable
---@field public flag_fuzzy             stl.c.Observable
---@field public flag_regex             stl.c.Observable
---@field public flag_case_sensitive    stl.c.Observable
---@field public flag_selected          stl.c.Observable
---@field public flag_viewtype          stl.c.Observable
---@field public flags_append           era.m.picker.result.IFlagItemRaw[]|nil
---@field public flags_prepend          era.m.picker.result.IFlagItemRaw[]|nil
---@field public flags_start_index      ?0|1
---
---@field public frecency               ?stl.c.Frecency
---
---@field public search_pattern         stl.c.Observable
---@field public search_pattern_history ?stl.c.History
---
---@field public on_attached            ?era.m.picker.composer.filetree.IOnAttached
---@field public on_closed              ?era.m.picker.composer.filetree.IOnClosed
---@field public on_confirm             ?era.m.picker.composer.filetree.IOnConfirm
---@field public on_disposed            ?era.m.picker.composer.filetree.IOnDisposed
---@field public on_focused             ?era.m.picker.composer.filetree.IOnFocused
---@field public on_hidden              ?era.m.picker.composer.filetree.IOnHidden
---@field public on_refresh             ?era.m.picker.composer.filetree.IOnRefresh
---@field public on_preview_rendered    ?era.m.picker.composer.filetree.IOnPreviewRendered
---@field public on_result_rendered     ?era.m.picker.composer.filetree.IOnResultRendered

---@class era.m.picker.FiletreeComposer
---@field public uuid                   string
---@field public fullname               string
---@field public title                  string
---
---@field public finder                 era.m.picker.Finder
---@field public result                 era.m.picker.Result
---@field public preview                era.m.picker.Preview
---
---@field public flag_foldempty         stl.c.Observable
---@field public flag_fuzzy             stl.c.Observable
---@field public flag_regex             stl.c.Observable
---@field public flag_case_sensitive    stl.c.Observable
---@field public flag_selected          stl.c.Observable
---@field public flag_viewtype          stl.c.Observable
---
---@field protected _disposed           boolean
---@field protected _filetree           era.view.ResultPaths
---@field protected _frecency           stl.c.Frecency|nil
---@field protected _composer           era.m.picker.BasicComposer
---@field protected _plainfile          era.view.Plainfile
---@field protected _scheduler_match    stl.c.Scheduler
---@field protected _search_pattern     stl.c.Observable
---@field protected _treeview           era.m.picker.FiletreeView
---
---@field protected _last_preview_filepath string|nil
---@field protected _uuid_root          string|nil
---@field protected _uuid_current       string|nil
---@field protected _uuids_file         string[]
---@field protected _uuids_order        string[]
---
---@field protected _on_attached        era.m.picker.composer.filetree.IOnAttached
---@field protected _on_confirm         era.m.picker.composer.filetree.IOnConfirm|nil
---@field protected _on_disposed        era.m.picker.composer.filetree.IOnDisposed
---@field protected _observer_unsubs    stl.c.IUnsubscribable[]|nil
---@field protected __refresh_file_indexes__ fun(self: era.m.picker.FiletreeComposer): nil
local M = {}
M.__index = M

---@param props                         era.m.picker.IFiletreeComposerProps
---@return era.m.picker.FiletreeComposer
function M.new(props)
  local name = props.name ---@type string
  local fullname = string.format("%s -> %s", name, __module_name__) ---@type string
  local picker_uuid = props.uuid or yoz.fn.uuid() ---@type string
  local permanent = props.permanent ---@type boolean
  local preview = props.preview ~= false ---@type boolean
  local title = props.title ---@type string
  local height = props.height ---@type number|nil
  local width = props.width ---@type number|nil

  local keymaps_common = props.keymaps_common ---@type stl.t.IKeymap[]|nil
  local keymaps_finder = props.keymaps_finder ---@type stl.t.IKeymap[]|nil
  local keymaps_preview = props.keymaps_preview ---@type stl.t.IKeymap[]|nil
  local keymaps_result = props.keymaps_result ---@type stl.t.IKeymap[]|nil

  local render_preview = props.render_preview ---@type era.m.picker.preview.IDraw|nil

  local search_pattern_history = props.search_pattern_history ---@type stl.c.History|nil
  local o_search_pattern = props.search_pattern ---@type stl.c.Observable
  local o_flag_fuzzy = props.flag_fuzzy ---@type stl.c.Observable
  local o_flag_regex = props.flag_regex ---@type stl.c.Observable
  local o_flag_foldempty = props.flag_foldempty ---@type stl.c.Observable
  local o_flag_case_sensitive = props.flag_case_sensitive ---@type stl.c.Observable
  local o_flag_selected = props.flag_selected ---@type stl.c.Observable
  local o_flag_viewtype = props.flag_viewtype ---@type stl.c.Observable

  local flags_append = props.flags_append ---@type era.m.picker.result.IFlagItemRaw[]|nil
  local flags_prepend = props.flags_prepend ---@type era.m.picker.result.IFlagItemRaw[]|nil
  local flags_start_index = props.flags_start_index ---@type 0|1|nil

  local frecency = props.frecency ---@type stl.c.Frecency|nil

  local on_attached = props.on_attached or stl.fn.noop ---@type era.m.picker.composer.filetree.IOnAttached
  local on_closed = props.on_closed or stl.fn.noop ---@type era.m.picker.composer.filetree.IOnClosed
  local on_confirm = props.on_confirm ---@type era.m.picker.composer.filetree.IOnConfirm|nil
  local on_disposed = props.on_disposed or stl.fn.noop ---@type era.m.picker.composer.filetree.IOnDisposed
  local on_focused = props.on_focused or stl.fn.noop ---@type era.m.picker.composer.filetree.IOnFocused
  local on_hidden = props.on_hidden or stl.fn.noop ---@type era.m.picker.composer.filetree.IOnHidden
  local _on_refresh = props.on_refresh or stl.fn.noop ---@type era.m.picker.composer.filetree.IOnRefresh
  local on_result_rendered = props.on_result_rendered or stl.fn.noop ---@type era.m.picker.composer.filetree.IOnResultRendered
  local on_preview_rendered = props.on_preview_rendered or stl.fn.noop ---@type era.m.picker.composer.filetree.IOnPreviewRendered

  local self = setmetatable({}, M)

  ---@type era.m.picker.FiletreeView
  local treeview = props.treeview
    or era.m.picker.FiletreeView.new({
      name = fullname,
      tree = require("era.view.result_paths").new(),
    })
  local filetree = treeview.source ---@type era.view.ResultPaths

  local retriever = treeview

  ---@type era.m.picker.composer.filetree.IOnRefresh
  local function on_refresh(_, force)
    treeview:reset_hidden()
    _on_refresh(self, force)
  end

  ---@type era.view.Plainfile
  local plainfile = era.view.Plainfile.new({
    name = fullname,
  })

  local scheduler_match = stl.c.Scheduler.new({
    name = string.format("%s#match", fullname),
    mode = "debounce",
    delay = 64,
    timeout = 0,
    silent = stl.fn.falsy,
    value = stl.c.Observable.from_value(true),
    task = function()
      local input = o_search_pattern:snapshot() ---@type string
      self:__match__(input)
      self:mark_result_dirty()
    end,
  })

  local flags = {} ---@type era.m.picker.result.IFlagItemRaw[]
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
        local viewtype = o_flag_viewtype:snapshot() ---@type era.view.result_tree.Viewtype
        local next_viewtype = viewtype == "tree" and "list" or "tree" ---@type era.view.result_tree.Viewtype
        o_flag_viewtype:next(next_viewtype)
      end,
      snapshot = function()
        local viewtype = o_flag_viewtype:snapshot() ---@type era.view.result_tree.Viewtype
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
      desc = string.format("%s: compact directory paths", name),
      disabled = function()
        local viewtype = o_flag_viewtype:snapshot() ---@type era.view.result_tree.Viewtype
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

  ---@type era.m.picker.composer.filetree.actions
  local actions = {
    attach_node = function()
      local frame = treeview:frame()
      local nodeuuid = self:__retrieve_nodeuuid__(frame) ---@type string|nil
      if nodeuuid == nil then
        return
      end

      local nodestate = treeview:retrieve(nodeuuid, frame) ---@type era.view.result_tree.IEntry|nil
      if nodestate == nil then
        return
      end

      local rootuuid = nodestate.nodetype == "location" and nodestate.leafuuid or nodeuuid
      local data = treeview:data(rootuuid, frame) ---@type era.view.result_paths.IFile|nil
      if data == nil then
        return
      end

      self._uuid_root = rootuuid
      self:mark_result_dirty()
      on_attached(self, data.filepath)
    end,
    create_node = function()
      self:__file_operation__("create")
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
    collapse_node = function()
      local nodeuuid, lnum = self:__retrieve_nodeuuid__() ---@type string|nil, integer
      if nodeuuid == nil then
        return
      end

      local nodestate = treeview:retrieve(nodeuuid) ---@type era.view.result_tree.IEntry|nil
      if nodestate ~= nil and nodestate.nodetype == "container" and not nodestate.collapsed then
        treeview:collapse(nodeuuid, "collapse", true)
        self:mark_result_dirty()
        self._composer.result:set_lnum_current(lnum)
        return
      end

      local lnum_parent, parentuuid = self:__retrieve_lnum_parent__(nodeuuid) ---@type integer|nil, string|nil
      if parentuuid == nil then
        return
      end

      treeview:collapse(parentuuid, "collapse", true)
      self:mark_result_dirty()
      if lnum_parent ~= nil then
        self._composer.result:set_lnum_current(lnum_parent)
      end
    end,
    remove_node = function()
      self:__file_operation__("delete")
    end,
    rename_node = function()
      self:__file_operation__("rename")
    end,
    move_node = function()
      self:__file_operation__("move")
    end,
    toggle_node = function()
      local nodeuuid = self:__retrieve_nodeuuid__() ---@type string|nil
      if nodeuuid ~= nil then
        self:__toggle_node__(nodeuuid, false, false)
      end
    end,
    toggle_node_deeply = function()
      local nodeuuid = self:__retrieve_nodeuuid__() ---@type string|nil
      if nodeuuid ~= nil then
        self:__toggle_node__(nodeuuid, false, true)
      end
    end,

    ------------------------------------------------------------------------------------------------

    add_node_to_ai = function()
      treeview:range_action(function(frame, first, last)
        local locations = {} ---@type dot.t.ILocation[]
        for _, _, data, entry in treeview:iter_rows(frame, first, last) do
          if data and data.filetype == "file" and entry and entry.nodetype == "leaf" then
            locations[#locations + 1] = { filepath = data.filepath }
          end
        end
        era.fn.add_locations_to_ai(locations)
      end)
    end,
    add_subtree_to_ai = function()
      treeview:range_action(function(frame, first, last)
        local locations = {} ---@type dot.t.ILocation[]
        local lnum = first
        while lnum <= last do
          local _, _, data, entry = treeview:iter_rows(frame, lnum, lnum)()
          if data and entry and entry.nodetype ~= "location" then
            locations[#locations + 1] = { filepath = data.filepath }
            if data.filetype == "directory" then
              lnum = frame:subtree_end(lnum)
            end
          end
          lnum = lnum + 1
        end
        era.fn.add_locations_to_ai(locations)
      end)
    end,

    attach_parent = function()
      local frame = treeview:frame()
      local parentuuid = treeview:parent_key(treeview:root_key(frame), frame)
      if parentuuid ~= nil then
        self._uuid_root = parentuuid ---@type string
        self:mark_result_dirty()

        local parentdata = treeview:data(parentuuid, frame) ---@type era.view.result_paths.IFile|nil
        if parentdata ~= nil then
          on_attached(self, parentdata.filepath)
        end
      end
    end,
    copy_node_filepath = function()
      local _, filedata = self:__retrieve_file__()
      if filedata == nil then
        return
      end

      local winnr_current = vim.api.nvim_get_current_win() ---@type integer
      local winnr_result = self._composer.result:get_winnr() ---@type integer|nil
      if winnr_result == nil or winnr_result < 1 or not vim.api.nvim_win_is_valid(winnr_result) then
        return
      end

      ---@return nil
      local function handle()
        era.fn.select_copy_filepath({
          filepath = filedata.filepath,
          winopts = {
            relative = "cursor",
            row = 1,
            col = 4,
          },
        })
      end

      if winnr_current == winnr_result then
        handle()
      else
        vim.api.nvim_win_call(winnr_result, handle)
      end
    end,
    copy_node_filepath_absolute = function()
      local _, filedata = self:__retrieve_file__()
      if filedata == nil then
        return
      end

      local filepath = filedata.filepath
      stl.nvim.fn.copy(filepath)
      stl.reporter.info({
        from = fullname,
        message = "Copied absolute filepath: " .. filepath,
      })
    end,
    copy_node_filepath_relative = function()
      local _, filedata = self:__retrieve_file__()
      if filedata == nil then
        return
      end

      local filepath = filedata.filepath
      local cwd = yoz.canonical_path.get_cwd()
      local relative = yoz.canonical_path.relative(cwd, filepath, false)
      stl.nvim.fn.copy(relative)
      stl.reporter.info({
        from = fullname,
        message = "Copied relative filepath: " .. relative,
      })
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
      treeview:range_action(function(frame, first, last)
        local search_pattern = o_search_pattern:snapshot() ---@type string
        treeview:mark_rows_invisible(frame, first, last, search_pattern ~= "")
        self._composer:mark_result_dirty()
      end)
    end,
    mark_subroot_invisible = function()
      treeview:range_action(function(frame, first, last)
        treeview:mark_rows_invisible(frame, first, last)
        self._composer:mark_result_dirty()
      end)
    end,
    send_to_qflist = function()
      treeview:range_action(function(frame)
        local cwd = yoz.canonical_path.get_cwd() ---@type string
        local quickfix_items = {} ---@type dot.state.qflist.IItem[]
        for _, _, data, entry in treeview:iter_rows(frame) do
          if data and data.filetype == "file" and entry and entry.nodetype == "leaf" then
            local filepath = data.filepath ---@type string
            local relative_filepath = yoz.canonical_path.relative(cwd, filepath, false) ---@type string
            local locations = entry.locations
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
        if #quickfix_items > 0 then
          self._composer:close()
          dot.state.qflist.push(quickfix_items)
          dot.state.qflist.open_qflist()
        end
      end)
    end,
    toggle_selection = function()
      treeview:toggle_selection()
    end,
  }

  for key, action in pairs(actions) do
    if key ~= "toggle_selection" then
      actions[key] = function()
        if self._disposed then
          return
        end
        if
          treeview:after_selection(function()
            if not self._disposed then
              action()
            end
          end)
        then
          return
        end
        action()
      end
    end
  end

  ---@type stl.t.IKeymap[]
  local preset_keymaps_common = {
    {
      modes = { "i", "n", "x" },
      key = "<C-q>",
      desc = "filetree: send to qflist",
      callback = actions.send_to_qflist,
    },
  }

  ---@type stl.t.IKeymap[]
  local preset_keymaps_finder = {
    {
      modes = { "n", "x" },
      key = ".",
      desc = "filetree: change root",
      callback = actions.attach_node,
    },
    {
      modes = { "n", "x" },
      key = "<Backspace>",
      desc = "filetree: change root to parent",
      callback = actions.attach_parent,
    },
    {
      modes = { "i", "n", "x" },
      key = "<Enter>",
      desc = "filetree: open",
      callback = actions.open_node,
    },
    {
      modes = { "i", "n", "x" },
      key = "<C-h>",
      desc = "filetree: collapse",
      callback = actions.collapse_node,
    },
    {
      modes = { "i", "n", "x" },
      key = "<C-l>",
      desc = "filetree: open",
      callback = actions.open_node,
    },
    {
      modes = { "n", "x" },
      key = "<Tab>",
      desc = "filetree: toggle selection",
      callback = actions.toggle_selection,
    },
    {
      modes = { "n", "x" },
      key = "<leader>D",
      desc = "filetree: mark the subroot invisible",
      callback = actions.mark_subroot_invisible,
    },
    {
      modes = { "n", "x" },
      key = "<leader>dd",
      desc = "filetree: mark the node invisible",
      callback = actions.mark_node_invisible,
    },
    {
      modes = { "n", "x" },
      key = "[i",
      desc = "filetree: goto the parent line",
      callback = actions.goto_lnum_parent,
    },
    {
      modes = { "n", "x" },
      key = "]i",
      desc = "filetree: goto the lastchild line",
      callback = actions.goto_lnum_lastchild,
    },
    {
      modes = { "n", "x" },
      key = "oA",
      desc = "filetree: add to ai (full subtree)",
      callback = actions.add_subtree_to_ai,
    },
    {
      modes = { "n", "x" },
      key = "oa",
      desc = "filetree: add to ai",
      callback = actions.add_node_to_ai,
    },
    {
      modes = { "n", "x" },
      key = "oc",
      desc = "filetree: copy filepath",
      callback = actions.copy_node_filepath,
    },
    {
      modes = { "n", "x" },
      key = "oP",
      desc = "filetree: copy filepath (absolute)",
      callback = actions.copy_node_filepath_absolute,
    },
    {
      modes = { "n", "x" },
      key = "op",
      desc = "filetree: copy filepath (relative)",
      callback = actions.copy_node_filepath_relative,
    },
    {
      modes = { "n", "x" },
      key = "od",
      desc = "filetree: remove node",
      callback = actions.remove_node,
    },
    {
      modes = { "n", "x" },
      key = "oi",
      desc = "filetree: create node",
      callback = actions.create_node,
    },
    {
      modes = { "n", "x" },
      key = "om",
      desc = "filetree: move node",
      callback = actions.move_node,
    },
    {
      modes = { "n", "x" },
      key = "or",
      desc = "filetree: rename node",
      callback = actions.rename_node,
    },
    {
      modes = { "n", "x" },
      key = "oz",
      desc = "filetree: toggle (recursively)",
      callback = actions.toggle_node_deeply,
    },
  }

  ---@type stl.t.IKeymap[]
  local preset_keymaps_result = {
    {
      modes = { "i", "n", "x" },
      key = ".",
      desc = "filetree: change root",
      callback = actions.attach_node,
    },
    {
      modes = { "i", "n", "x" },
      key = "<Backspace>",
      desc = "filetree: change root to parent",
      callback = actions.attach_parent,
    },
    {
      modes = { "i", "n", "x" },
      key = "<Enter>",
      aliases = { "w" },
      desc = "filetree: open",
      callback = actions.open_node,
    },
    {
      modes = { "i", "n", "x" },
      key = "<Right>",
      aliases = { "<Left>", "c" },
      desc = "filetree: toggle",
      callback = actions.toggle_node,
    },
    {
      modes = { "i", "n" },
      key = "l",
      desc = "filetree: open",
      callback = actions.open_node,
    },
    {
      modes = { "i", "n" },
      key = "h",
      desc = "filetree: collapse",
      callback = actions.collapse_node,
    },
    {
      modes = { "i", "n", "x" },
      key = "<C-l>",
      desc = "filetree: open",
      callback = actions.open_node,
    },
    {
      modes = { "i", "n", "x" },
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
      modes = { "i", "n", "x" },
      key = "<Tab>",
      desc = "filetree: toggle selection",
      callback = actions.toggle_selection,
    },
    {
      modes = { "i", "n", "x" },
      key = "<leader>D",
      desc = "filetree: mark the subroot invisible",
      callback = actions.mark_subroot_invisible,
    },
    {
      modes = { "i", "n", "x" },
      key = "<leader>dd",
      desc = "filetree: mark the node invisible",
      callback = actions.mark_node_invisible,
    },
    {
      modes = { "i", "n", "x" },
      key = "[i",
      desc = "filetree: goto the parent line",
      callback = actions.goto_lnum_parent,
    },
    {
      modes = { "i", "n", "x" },
      key = "]i",
      desc = "filetree: goto the lastchild line",
      callback = actions.goto_lnum_lastchild,
    },
    {
      modes = { "i", "n", "x" },
      key = "oA",
      desc = "filetree: add to ai (full subtree)",
      callback = actions.add_subtree_to_ai,
    },
    {
      modes = { "i", "n", "x" },
      key = "oa",
      desc = "filetree: add to ai",
      callback = actions.add_node_to_ai,
    },
    {
      modes = { "i", "n", "x" },
      key = "oc",
      desc = "filetree: copy filepath",
      callback = actions.copy_node_filepath,
    },
    {
      modes = { "i", "n", "x" },
      key = "oP",
      desc = "filetree: copy filepath (absolute)",
      callback = actions.copy_node_filepath_absolute,
    },
    {
      modes = { "i", "n", "x" },
      key = "op",
      desc = "filetree: copy filepath (relative)",
      callback = actions.copy_node_filepath_relative,
    },
    {
      modes = { "i", "n", "x" },
      key = "od",
      alias = { "d" },
      desc = "filetree: remove node",
      callback = actions.remove_node,
    },
    {
      modes = { "i", "n", "x" },
      key = "oi",
      alias = { "a" },
      desc = "filetree: create node",
      callback = actions.create_node,
    },
    {
      modes = { "i", "n", "x" },
      key = "om",
      desc = "filetree: move node",
      callback = actions.move_node,
    },
    {
      modes = { "i", "n", "x" },
      key = "or",
      alias = { "r" },
      desc = "filetree: rename node",
      callback = actions.rename_node,
    },
    {
      modes = { "i", "n", "x" },
      key = "oz",
      desc = "filetree: toggle (recursively)",
      callback = actions.toggle_node_deeply,
    },
  }

  if preview and render_preview == nil then
    ---@type era.m.picker.preview.IDraw|nil
    render_preview = function(bufnr, force)
      return self:render_preview(bufnr, force)
    end
  end

  ---@return stl.c.Future
  local function render_result()
    if self._disposed then
      return stl.c.Future.resolve({ kind = "Rejected", error = "picker disposed" })
    end
    if self._path_request and self._path_future and not self._path_future:is_done() then
      return self._path_future:then_(render_result)
    end
    return treeview:publish({
      mode = o_flag_viewtype:snapshot(),
      rootuuid = self._uuid_root,
      orders = self._uuids_order,
      foldempty = o_flag_foldempty:snapshot(),
      only_matched = o_search_pattern:snapshot() ~= "",
      only_selected = o_flag_selected:snapshot(),
      list_text = "ancestry",
    })
  end

  local composer = era.m.picker.BasicComposer.new({
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

    ---@type era.m.picker.result.IDraw
    result_tree = treeview,
    render_result = render_result,

    ---@type era.m.picker.preview.IDraw|nil
    preview_tree = function()
      local key = self:__retrieve_nodeuuid__()
      local entry = key and treeview:retrieve(key)
      if entry and entry.nodetype == "container" then
        local data = treeview:data(key)
        return { owner = treeview, key = key, foldempty = o_flag_foldempty:snapshot(), title = data.filepath }
      end
    end,
    render_preview = render_preview,

    on_cancel = function()
      if on_confirm ~= nil then
        on_confirm(self, nil)
      end
    end,
    on_closed = function()
      self._path_request = nil
      on_closed(self)
    end,
    on_disposed = function()
      self:dispose()
    end,
    on_focused = function()
      on_focused(self)
    end,
    on_hidden = function()
      self._path_request = nil
      on_hidden(self)
    end,
    on_refresh = function(picker, force)
      on_refresh(self, force)

      picker:mark_preview_dirty()
      picker:mark_result_flags_dirty()
      picker:mark_result_dirty()
    end,
    on_preview_rendered = function(_, bufnr)
      local _, data = self:__retrieve_file__()
      on_preview_rendered(self, bufnr, data)
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
  self.flag_case_sensitive = o_flag_case_sensitive
  self.flag_selected = o_flag_selected
  self.flag_viewtype = o_flag_viewtype

  self._disposed = false
  self._filetree = filetree
  self._frecency = frecency
  self._composer = composer
  self._plainfile = plainfile
  self._scheduler_match = scheduler_match
  self._search_pattern = o_search_pattern
  self._treeview = treeview

  self._last_preview_filepath = nil
  self._uuid_root = nil
  self._uuids_file = {}
  self._uuids_order = {}

  self._on_attached = on_attached
  self._on_confirm = on_confirm
  self._on_disposed = on_disposed
  self._observer_unsubs = nil

  local observer_unsubs = {} ---@type stl.c.IUnsubscribable[]

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
  self._path_request, self._path_future = nil, nil

  local fullname = self.fullname
  local on_dispose = self._on_disposed ---@type era.m.picker.composer.filetree.IOnDisposed
  local composer = self._composer ---@type era.m.picker.BasicComposer
  local plainfile = self._plainfile ---@type era.view.Plainfile
  local scheduler_match = self._scheduler_match ---@type stl.c.Scheduler
  local treeview = self._treeview ---@type era.m.picker.FiletreeView
  local observer_unsubs = self._observer_unsubs ---@type stl.c.IUnsubscribable[]|nil
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
    local ok6, error6 = pcall(on_dispose)

    if not (ok1 and ok2 and ok3 and ok4 and ok6) then
      stl.reporter.error({
        from = fullname,
        subject = "dispose",
        message = "Failed to dispose",
        details = {
          error1 = not ok1 and error1 or nil,
          error2 = not ok2 and error2 or nil,
          error3 = not ok3 and error3 or nil,
          error4 = not ok4 and error4 or nil,
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

  self._frecency = nil
  self._composer = nil
  self._plainfile = nil
  self._scheduler_match = nil
  self._search_pattern = nil
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
  return self._filetree:contains(uuid)
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
  self._path_request = nil
  self._composer:hide()
end

---@return nil
function M:resize()
  self._composer:resize()
end

----------------------------------------------------------------------------------------------------

---@param rootuuid                      string
---@return era.m.picker.FiletreeComposer
function M:attach(rootuuid)
  self:__health__()
  self._path_request = nil
  if self._uuid_root == rootuuid then
    return self
  end

  local filetree = self._filetree ---@type era.view.ResultPaths
  local data = filetree:get(rootuuid) ---@type era.view.result_paths.IFile|nil
  if data == nil then
    stl.reporter.error({
      from = __module_name__,
      subject = "attach",
      message = string.format("Cannot find node by the given uuid: %s", rootuuid),
    })
    return self
  end

  local treeview = self._treeview ---@type era.m.picker.FiletreeView

  self._uuid_root = rootuuid
  self._scheduler_match:schedule()

  self._on_attached(self, data.filepath)
  return self
end

---@return era.m.picker.FiletreeComposer
function M:mark_result_dirty()
  self:__health__()
  self._composer:mark_result_dirty()
  return self
end

---@return era.m.picker.FiletreeComposer
function M:mark_result_flags_dirty()
  self:__health__()
  self._composer:mark_result_flags_dirty()
  return self
end

---@param cwd                           string Canonical cwd or OS cwd at ingress.
---@param filepaths                     string[]
---@param with_positions                boolean
---@return era.m.picker.FiletreeComposer
function M:reset_filepaths(cwd, filepaths, with_positions)
  self:__health__()

  local treeview = self._treeview ---@type era.m.picker.FiletreeView

  cwd = yoz.canonical_path.from_os_path(cwd, false) ---@type string
  treeview:reset_filepaths(cwd, filepaths, with_positions)

  local uuid_cwd = require("era.view.result_paths").key(cwd) ---@type string
  self._last_preview_filepath = nil
  self._uuid_root = uuid_cwd
  self:__refresh_file_indexes__()
  self._scheduler_match:schedule()

  self._on_attached(self, cwd)
  return self
end

---Prepare a plain file collection cooperatively, then replace the live producer once.
---@param cwd                           string
---@param filepaths                     string[]
---@param opts                          ?era.m.picker.composer.filetree.IPrepareOptions
---@return stl.c.Future
function M:prepare_filepaths(cwd, filepaths, opts)
  self:__health__()
  cwd = yoz.canonical_path.from_os_path(cwd, false)
  local paths = vim.list_slice(filepaths)
  local prepare_entry, token = opts and opts.prepare_entry, opts and opts.token
  local retained_root = opts and opts.keep_root and self._uuid_root or nil
  local source, treeview = self._filetree, self._treeview
  local source_revision, revision = source.revision, treeview._revision
  local request, cancelled = {}, {}
  self._path_request = request
  local future = stl.async.run_future(function()
    local deadline = vim.uv.hrtime() + 2000000
    ---@return nil
    local function checkpoint()
      if
        self._disposed
        or token and token:is_cancelled()
        or self._path_request ~= request
        or source.revision ~= source_revision
        or treeview._revision ~= revision
      then
        error(cancelled, 0)
      end
      if vim.uv.hrtime() >= deadline then
        stl.async.scheduler()
        if
          self._disposed
          or token and token:is_cancelled()
          or self._path_request ~= request
          or source.revision ~= source_revision
          or treeview._revision ~= revision
        then
          error(cancelled, 0)
        end
        deadline = vim.uv.hrtime() + 2000000
      end
    end
    local ok, failure = pcall(function()
      local prepared = source:prepare(cwd, paths, checkpoint)
      local entries, files = {}, {}
      for key, record in pairs(prepared.records) do
        local entry = prepare_entry and prepare_entry(record.data) or {}
        entry.key, entry.nodetype = key, record.data.filetype == "directory" and "container" or "leaf"
        entries[key] = entry
        checkpoint()
      end
      local root = require("era.view.result_paths").key(cwd)
      prepared:walk(root, function(key, data)
        if data.filetype == "file" then
          files[#files + 1] = key
        end
        checkpoint()
      end)
      local ordered = vim.list_slice(files)
      if self._frecency then
        local scores = {}
        for _, key in ipairs(files) do
          scores[key] = self._frecency:score(key) or 0
          checkpoint()
        end
        ordered = require("era.view.result_order").sort(ordered, function(left, right)
          return scores[left] > scores[right]
        end, checkpoint)
      end
      checkpoint()
      if retained_root and prepared:contains(retained_root) then
        root = retained_root
      end
      treeview:adopt_filepaths(prepared, entries)
      self._last_preview_filepath, self._uuid_root = nil, root
      self._uuids_file, self._uuids_order = files, ordered
      if self._search_pattern:snapshot() ~= "" then
        self:__match__(self._search_pattern:snapshot())
      end
      self._path_request = nil
      self:mark_result_dirty()
      self._on_attached(self, prepared:get(root).filepath)
    end)
    if self._path_request == request then
      self._path_request = nil
    end
    if not ok then
      if failure == cancelled then
        return { kind = "Superseded" }
      end
      error(failure, 0)
    end
    return { kind = "Applied" }
  end)
  if self._path_request == request then
    self._path_future = future
  end
  return future
end

----------------------------------------------------------------------------------------------------

---@param bufnr                         integer
---@param force                         boolean
---@return era.m.picker.preview.IDrawResult
function M:render_preview(bufnr, force)
  local frame = self._treeview:frame()
  local nodeuuid, lnum = self:__retrieve_nodeuuid__(frame) ---@type string|nil, integer
  if nodeuuid == nil then
    self._last_preview_filepath = nil
    if lnum == 0 then
      -- An empty result set has no current row; keep the preview empty instead of presenting it as an invariant failure.
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
      return {
        cursorline = false,
        number = false,
        title = "",
        wrap = false,
        whitespaces = false,
      }
    end

    local lines = { string.format("Error: cannot retrieve node by the given lnum: %d", lnum) } ---@type string[]
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

    ---@type era.m.picker.preview.IDrawResult
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

  local treeview = self._treeview ---@type era.m.picker.FiletreeView
  local plainfile = self._plainfile ---@type era.view.Plainfile
  local o_flag_foldempty = self.flag_foldempty ---@type stl.c.Observable

  local _, data, nodestate = self:__retrieve__(nodeuuid, frame)

  force = force or data.filepath ~= self._last_preview_filepath ---@type boolean
  self._last_preview_filepath = data.filepath ---@type string|nil

  local rootdata = self:__retrieve_rootdata__(frame)
  local filepath = data.filepath ---@type string
  local relative_filepath = rootdata ~= nil and yoz.canonical_path.relative(rootdata.filepath, filepath, false)
    or filepath ---@type string

  if nodestate.nodetype == "container" then
    ---@cast nodestate          era.view.result_tree.IEntry
    ---@type era.m.picker.preview.IDrawResult
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
    ---@cast nodestate          era.view.result_tree.IEntry
    if nodestate.locations ~= nil and #nodestate.locations > 0 then
      ---@diagnostic disable-next-line: cast-local-type
      nodestate = nodestate.locations[1]
    end
  end
  ---@cast nodestate          era.view.result_tree.IEntry|era.view.result_tree.IEntry

  plainfile:render(bufnr, filepath, force)

  ---@type era.m.picker.preview.IDrawResult
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
  return self._treeview:collect_selected_rows()
end

---@return integer|nil
function M:__focus_source_win__()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local winnr_sourcefile = dot.tab.retrieve_winnr_sourcefile(tabnr) ---@type integer|nil
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
  return self._treeview:has_selected()
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
function M:__refresh_file_indexes__()
  local filetree = self._filetree ---@type era.view.ResultPaths
  local treeview = self._treeview ---@type era.m.picker.FiletreeView
  local uuid_root = self._uuid_root ---@type string|nil
  local uuids_file = uuid_root ~= nil and filetree:contains(uuid_root) and treeview:collect_file_uuids(uuid_root) or {} ---@type string[]
  self._uuids_file = uuids_file
  self:__match__("")
end

---@protected
---@param input                         string
---@return nil
function M:__match__(input)
  local frecency = self._frecency ---@type stl.c.Frecency|nil
  local treeview = self._treeview ---@type era.m.picker.FiletreeView

  if #input < 1 then
    treeview:clear_match()
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

  local pattern = input ---@type string
  if pattern:find("\\", 1, true) ~= nil then
    pattern = pattern:gsub("\\", "/")
  end

  ---@type string[]
  local uuids_order = treeview:match({
    rootuuid = self._uuid_root,
    pattern = pattern,
    case_sensitive = self.flag_case_sensitive:snapshot(),
    fuzzy = self.flag_fuzzy:snapshot(),
    regex = self.flag_regex:snapshot(),
  })

  table.sort(uuids_order, function(a, b)
    return treeview:match_score(a) > treeview:match_score(b)
  end)

  self._uuids_order = uuids_order
end

---@param nodeuuid                      string
---@return nil
function M:__open_node__(nodeuuid)
  local treeuuid, data, nodestate = self:__retrieve__(nodeuuid)

  local composer = self._composer ---@type era.m.picker.BasicComposer
  local treeview = self._treeview ---@type era.m.picker.FiletreeView

  if self:__has_selected_node__() then
    local last_nodestate = nodestate
    local filepaths = {} ---@type string[]
    local seen = {} ---@type table<string, true>
    for _, uuid in ipairs(treeview:selected_keys(true)) do
      local selected_data = treeview:data(uuid)
      treeview:set_selected(uuid, false)
      if selected_data and selected_data.filetype == "file" and not seen[selected_data.filepath] then
        seen[selected_data.filepath] = true
        filepaths[#filepaths + 1] = selected_data.filepath
      end
    end

    if #filepaths > 0 then
      ---@cast last_nodestate             era.view.result_tree.IEntry
      local locations = last_nodestate.locations
      local first_location = locations ~= nil and locations[1] or nil ---@type era.view.result_tree.IEntry|nil
      local lnum = first_location and first_location.lnum or nil ---@type integer|nil
      local col = first_location and first_location.col or nil ---@type integer|nil

      local winnr_sourcefile = self:__focus_source_win__() ---@type integer|nil
      if winnr_sourcefile ~= nil and vim.api.nvim_win_is_valid(winnr_sourcefile) then
        vim.api.nvim_set_current_win(winnr_sourcefile)
      end

      composer:close()
      composer:mark_result_dirty()
      dot.win.open_filepaths(winnr_sourcefile, filepaths, lnum, col)
      return
    end
  end

  if nodestate.nodetype == "container" then
    self._treeview:collapse(treeuuid, "toggle", false)
    composer:mark_result_dirty()
    return
  end

  if nodestate.nodetype == "leaf" and nodestate.collapsed then
    self._treeview:collapse(treeuuid, "expand", false)
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
      local first_location = nodestate.locations[1] ---@type era.view.result_tree.IEntry
      lnum = first_location.lnum ---@type integer|nil
      col = first_location.col ---@type integer|nil
    end
  end

  local winnr_sourcefile = self:__focus_source_win__() ---@type integer|nil
  if winnr_sourcefile ~= nil and vim.api.nvim_win_is_valid(winnr_sourcefile) then
    vim.api.nvim_set_current_win(winnr_sourcefile)
  end

  composer:close()
  dot.win.open_filepath(winnr_sourcefile, data.filepath, lnum, col)
end

---@param nodeuuid                      string
---@return nil
function M:__resolve_confirmation__(nodeuuid)
  local composer = self._composer ---@type era.m.picker.BasicComposer
  local treeview = self._treeview ---@type era.m.picker.FiletreeView
  local frame = treeview:frame()
  local _, data = self:__retrieve__(nodeuuid, frame)
  local rootdata = self:__retrieve_rootdata__(frame)

  if treeview:has_selected(frame) then
    local filepaths = {} ---@type string[]
    local seen = {} ---@type table<string, true>
    for _, uuid in ipairs(treeview:selected_keys(true, frame)) do
      local selected_data = treeview:data(uuid, frame)
      treeview:set_selected(uuid, false)
      if selected_data and selected_data.filetype == "file" and not seen[selected_data.filepath] then
        seen[selected_data.filepath] = true
        filepaths[#filepaths + 1] = selected_data.filepath
      end
    end

    if #filepaths > 0 then
      composer:close()
      composer:mark_result_dirty()
      self._on_confirm(self, filepaths)
      return
    end
  end

  local filepath = rootdata ~= nil and yoz.canonical_path.relative(rootdata.filepath, data.filepath, false)
    or data.filepath
  composer:close()
  self._on_confirm(self, { filepath })
end

---@param nodeuuid                      string
---@param frame                         ?yoz.ux.treeview.Frame
---@return string
---@return era.view.result_paths.IFile
---@return era.view.result_tree.IEntry
function M:__retrieve__(nodeuuid, frame)
  ---@type era.view.result_tree.IEntry|nil
  local nodestate = self._treeview:retrieve(nodeuuid, frame)
  if nodestate == nil then
    error(string.format("Cannot retrieve nodestate by the given uuid(%s)", nodeuuid))
  end

  local treeuuid = nodestate.nodetype == "location" and nodestate.leafuuid or nodeuuid ---@type string
  local data = self._treeview:data(treeuuid, frame) ---@type era.view.result_paths.IFile|nil
  if data == nil then
    error(string.format("Cannot retrieve node by the given uuid(%s), nodetype(%s)", nodeuuid, nodestate.nodetype))
  end

  return treeuuid, data, nodestate
end

---@param frame                         ?yoz.ux.treeview.Frame
---@return string|nil
---@return era.view.result_paths.IFile|nil
function M:__retrieve_file__(frame)
  local lnum = self.result.lnum_current:snapshot() ---@type integer
  if lnum < 1 then
    return
  end

  local nodeuuid = self._treeview:retrieve_uuid(lnum, frame) ---@type string|nil
  if nodeuuid == nil then
    return
  end

  local nodestate = self._treeview:retrieve(nodeuuid, frame) ---@type era.view.result_tree.IEntry|nil
  if nodestate == nil then
    return
  end

  local fileuuid = nodestate.nodetype == "location" and nodestate.leafuuid or nodeuuid ---@type string
  local data = self._treeview:data(fileuuid, frame) ---@type era.view.result_paths.IFile|nil
  return fileuuid, data
end

---@param kind                          "create"|"delete"|"rename"|"move"
---@return nil
function M:__file_operation__(kind)
  local frame = self._treeview:frame()
  local fileuuid, filedata = self:__retrieve_file__(frame)
  local rootdata = self:__retrieve_rootdata__(frame)
  local winnr = self.result:get_winnr()
  if not fileuuid or not filedata or not rootdata or not winnr or not vim.api.nvim_win_is_valid(winnr) then
    return
  end
  if self._file_operation_busy then
    stl.reporter.warn({ from = self.fullname, message = "A file operation is already running" })
    return
  end
  local record = self._filetree.records[fileuuid]
  local sourcepath = filedata.filepath
  local isdir = filedata.filetype == "directory"
  local Jobs = require("era.m.filetree.jobs")
  local Future = require("stl.c.future")
  self._file_operation_busy = true
  local future = stl.async.run_future(function()
    local captured = Jobs.capture(kind == "create" and rootdata.filepath or sourcepath):await()
    if self._disposed then
      return
    end
    local resource = captured.resource
    if kind ~= "create" and resource:info().directory ~= isdir then
      error("File type changed before the operation: " .. sourcepath, 0)
    end
    local filename = yoz.canonical_path.basename(sourcepath)
    local options
    if kind == "create" then
      local relative = yoz.canonical_path.relative(rootdata.filepath, sourcepath, false)
      options = { prompt = " New file / directory ", default = relative .. (isdir and "/" or "") }
    elseif kind == "delete" then
      local label = yoz.canonical_path.relative(rootdata.filepath, sourcepath, false)
      options = { inputtype = "confirmation", prompt = "Delete '" .. label .. (isdir and "/" or "") .. "'?" }
    else
      options = {
        prompt = string.format(' %s "%s" to: ', kind == "rename" and "Rename" or "Move", filename),
        default = (kind == "rename" and filename or sourcepath) .. (isdir and "/" or ""),
      }
    end
    local input = Future.new(function(resolve)
      vim.api.nvim_win_call(winnr, function()
        vim.ui.input(vim.tbl_extend("force", options, { relative = "cursor" }), resolve)
      end)
    end):await()
    if not input or input == "" or self._disposed then
      return
    end
    local result, destination
    if kind == "create" then
      local canonical = yoz.canonical_path.resolve(rootdata.filepath, input, true)
      isdir = yoz.canonical_path.is_dirpath(canonical)
      destination = yoz.canonical_path.from_os_path(canonical, false)
      local relative = yoz.canonical_path.relative(rootdata.filepath, destination, false)
      result = Jobs.create(captured.data, resource, relative, isdir):await()
    elseif kind == "delete" then
      local answer = vim.trim(input):lower()
      if answer ~= "y" and answer ~= "yes" then
        return
      end
      result = Jobs.run(captured.data, { kind = "delete", source = resource:source(), nodes = { resource:node() } })
        :await()
    else
      if kind == "rename" then
        local name = yoz.canonical_path.from_os_path(input, false)
        destination = name:find("/", 1, true) and yoz.canonical_path.resolve(rootdata.filepath, input, true)
          or yoz.canonical_path.join(yoz.canonical_path.dirname(sourcepath, false), input, true)
      else
        destination = yoz.canonical_path.from_os_path(input, true)
      end
      if isdir ~= yoz.canonical_path.is_dirpath(destination) then
        error("Source and destination must have the same file type; directory paths end with /", 0)
      end
      destination = yoz.canonical_path.from_os_path(destination, false)
      if destination == sourcepath then
        return
      end
      result = Jobs.move(captured.data, resource, destination, function(confirmation)
        return Future.new(function(resolve)
          vim.ui.select({ "No", "Yes" }, {
            prompt = string.format('File "%s" already exists. Overwrite?', confirmation.target_label),
          }, function(choice)
            resolve(choice == "Yes")
          end)
        end)
      end):await()
    end
    local item = result.items[1]
    if result.error then
      error(result.error, 0)
    end
    if not result.success then
      if kind == "create" and not result.status.cancelled then
        error("The filepath already exists or creation was incomplete", 0)
      end
      return
    end
    if item.sync_error then
      stl.reporter.warn({ from = self.fullname, message = item.sync_error.message })
    end
    -- An old Frame may own the IO target without owning a record in the current producer.
    if self._disposed or not record or self._filetree.records[fileuuid] ~= record then
      return
    end
    if self._treeview:selection_pending() then
      local ready = self._treeview:ready():await()
      if ready.kind == "Rejected" then
        error(ready.error, 0)
      end
      if self._disposed or self._filetree.records[fileuuid] ~= record then
        return
      end
    end
    if kind == "create" then
      if isdir then
        self._treeview:insert_dirpath(destination)
      else
        self._treeview:insert_filepath(destination, false)
      end
      self:__refresh_file_indexes__()
      self._scheduler_match:schedule()
    elseif kind == "delete" then
      self._treeview:remove(fileuuid)
      self._filetree:remove(fileuuid)
      self:__refresh_file_indexes__()
      self._scheduler_match:schedule()
    else
      self:__update_tree_after_rename__(sourcepath, item.target or destination)
    end
  end)
  future:finally(function(ok, error)
    self._file_operation_busy = false
    if not ok then
      stl.reporter.error({ from = __module_name__, subject = kind, message = tostring(error) })
    end
  end)
end

---@param from                          string Canonical filepath.
---@param to                            string Canonical filepath.
---@return nil
function M:__update_tree_after_rename__(from, to)
  from = yoz.canonical_path.from_os_path(from, false)
  to = yoz.canonical_path.from_os_path(to, false)
  local from_nodeuuid = require("era.view.result_paths").key(from) ---@type string
  local to_nodeuuid = require("era.view.result_paths").key(to) ---@type string
  local filetree = self._filetree ---@type era.view.ResultPaths
  local treeview = self._treeview ---@type era.m.picker.FiletreeView

  ---@param filepath                    string
  ---@return string
  local function rebase_filepath(filepath)
    local relative = yoz.canonical_path.relative(from, filepath, false) ---@type string
    return relative == "" and to or yoz.canonical_path.join(to, relative, false)
  end

  ---@param uuid                        string|nil
  ---@return string|nil
  local function remap_uuid(uuid)
    local data = uuid ~= nil and filetree:get(uuid) or nil ---@type era.view.result_paths.IFile|nil
    if data ~= nil and (data.filepath == from or yoz.canonical_path.is_descendant(from, data.filepath)) then
      return require("era.view.result_paths").key(rebase_filepath(data.filepath))
    end
    return uuid
  end

  local uuid_root_before = self._uuid_root ---@type string|nil
  local uuid_root = remap_uuid(uuid_root_before) ---@type string|nil
  local cursoruuid = self:__retrieve_nodeuuid__() or self._uuid_current
  local uuid_current = remap_uuid(cursoruuid) ---@type string|nil

  local moved = {}
  filetree:walk(from_nodeuuid, function(key, data)
    local entry = treeview.entries[key]
    moved[#moved + 1] = {
      path = rebase_filepath(data.filepath),
      data = data,
      entry = entry and vim.tbl_extend("force", entry, { locations = vim.list_slice(entry.locations or {}) }),
    }
  end)

  local selected_set_current = treeview:collect_selected() ---@type table<string, true>
  local selected_set = {} ---@type table<string, true>
  for uuid in pairs(selected_set_current) do
    local data = filetree:get(uuid) ---@type era.view.result_paths.IFile|nil
    if data ~= nil and (data.filepath == from or yoz.canonical_path.is_descendant(from, data.filepath)) then
      selected_set[require("era.view.result_paths").key(rebase_filepath(data.filepath))] = true
    elseif data == nil or (data.filepath ~= to and not yoz.canonical_path.is_descendant(to, data.filepath)) then
      selected_set[uuid] = true
    end
  end
  local scheduler_match = self._scheduler_match

  if to_nodeuuid ~= from_nodeuuid and filetree:contains(to_nodeuuid) then
    treeview:remove(to_nodeuuid)
    filetree:remove(to_nodeuuid)
  end
  treeview:remove(from_nodeuuid)
  filetree:remove(from_nodeuuid)

  -- Preserve result membership and location payloads; the filesystem job already owns traversal.
  for _, item in ipairs(moved) do
    local key = filetree:_insert_path(item.path, item.data.filetype)
    filetree:update(key, vim.tbl_extend("force", item.data, filetree:get(key)))
    if item.entry then
      local entry = vim.tbl_extend("force", item.entry, { key = key, locations = {} })
      for _, location in ipairs(item.entry.locations or {}) do
        local moved_location = vim.tbl_extend("force", location, { leafuuid = key })
        entry.locations[#entry.locations + 1] = moved_location
        treeview.entries[moved_location.locationuuid] = moved_location
      end
      treeview.entries[key] = entry
    end
  end
  treeview:restore_subtree(to_nodeuuid, selected_set)

  self._uuid_root = uuid_root ~= nil and filetree:contains(uuid_root) and uuid_root or nil
  self._uuid_current = uuid_current ~= nil and filetree:contains(uuid_current) and uuid_current or nil

  self:__refresh_file_indexes__()
  if self._uuid_current then
    treeview:focus_key(self._uuid_current)
  end

  if self._uuid_root ~= uuid_root_before and self._uuid_root ~= nil then
    local rootdata = filetree:get(self._uuid_root) ---@type era.view.result_paths.IFile|nil
    if rootdata ~= nil then
      self._on_attached(self, rootdata.filepath)
    end
  end

  self:mark_result_dirty()
  scheduler_match:schedule()
end

---@param frame                         ?yoz.ux.treeview.Frame
---@return era.view.result_paths.IFile|nil
function M:__retrieve_rootdata__(frame)
  frame = frame or self._treeview:frame()
  return self._treeview:data(self._treeview:root_key(frame), frame) ---@type era.view.result_paths.IFile|nil
end

---@param frame                         ?yoz.ux.treeview.Frame
---@return string|nil
---@return integer
function M:__retrieve_nodeuuid__(frame)
  local lnum = self.result.lnum_current:snapshot() ---@type integer
  if lnum < 1 then
    return nil, lnum
  end

  local nodeuuid = self._treeview:retrieve_uuid(lnum, frame) ---@type string|nil
  return nodeuuid, lnum
end

---@param nodeuuid                      string|nil
---@return integer|nil
---@return string|nil
function M:__retrieve_lnum_parent__(nodeuuid)
  return self._treeview:retrieve_parent(nodeuuid)
end

---@param nodeuuid                      string
---@param open                          boolean
---@param recursively                   boolean
---@return nil
function M:__toggle_node__(nodeuuid, open, recursively)
  local frame = self._treeview:frame()
  local treeuuid, data, nodestate = self:__retrieve__(nodeuuid, frame)

  local composer = self._composer ---@type era.m.picker.BasicComposer
  local treeview = self._treeview ---@type era.m.picker.FiletreeView
  if nodestate.nodetype == "container" then
    treeview:collapse(treeuuid, "toggle", recursively, frame)
    composer:mark_result_dirty()
    return
  end

  if nodestate.nodetype == "leaf" and nodestate.locations and #nodestate.locations > 0 then
    treeview:collapse(treeuuid, "toggle", false, frame)
    composer:mark_result_dirty()
    return
  end

  if not open or self._on_confirm ~= nil then
    return
  end

  local lnum ---@type integer|nil
  local col ---@type integer|nil
  if nodestate.nodetype == "location" then
    lnum = nodestate.lnum ---@type integer|nil
    col = nodestate.col ---@type integer|nil
  else
    if nodestate.locations ~= nil and #nodestate.locations > 0 then
      local first_location = nodestate.locations[1] ---@type era.view.result_tree.IEntry
      lnum = first_location.lnum ---@type integer|nil
      col = first_location.col ---@type integer|nil
    end
  end

  local winnr_sourcefile = self:__focus_source_win__() ---@type integer|nil
  if winnr_sourcefile ~= nil and vim.api.nvim_win_is_valid(winnr_sourcefile) then
    vim.api.nvim_set_current_win(winnr_sourcefile)
  end

  composer:close()
  dot.win.open_filepath(winnr_sourcefile, data.filepath, lnum, col)
end

return M
