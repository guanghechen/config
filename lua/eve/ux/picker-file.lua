---@diagnostic disable: invisible
local __module_name__ = "eve.ux.picker-file" ---@type string

---@alias eve.ux.picker_file.IOnClosed
---| fun(self: eve.ux.FilePicker): nil

---@alias eve.ux.picker_file.IOnConfirm
---| fun(self: eve.ux.FilePicker, selected_items: eve.ux.picker_file.ISelectedItem[]|nil): nil

---@alias eve.ux.picker_file.IOnDisposed
---| fun(): nil

---@alias eve.ux.picker_file.IOnFocused
---| fun(self: eve.ux.FilePicker): nil

---@alias eve.ux.picker_file.IOnHidden
---| fun(self: eve.ux.FilePicker): nil
---
---@alias eve.ux.picker_file.IOnRefresh
---| fun(self: eve.ux.FilePicker, force: boolean): nil

---@class eve.ux.picker_file.ISelectedItem
---@field public filepath               string
---@field public locations              [integer, integer?][]

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
---@field public finder_input_history   ?std.collection.InputHistory
---@field public finder_multiline       ?boolean
---
---@field public on_closed              ?eve.ux.picker_file.IOnClosed
---@field public on_confirm             ?eve.ux.picker_file.IOnConfirm
---@field public on_disposed            ?eve.ux.picker_file.IOnDisposed
---@field public on_focused             ?eve.ux.picker_file.IOnFocused
---@field public on_hidden              ?eve.ux.picker_file.IOnHidden
---@field public on_refresh             ?eve.ux.picker_file.IOnRefresh

---@class eve.ux.FilePicker
---@field public uuid                   string
---@field public name                   string
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
---@field protected _filetree           eve.ux.view.Filetree
---@field protected _frecency           std.collection.IFrecency|nil
---@field protected _picker             eve.ux.PickerComposer
---@field protected _plainfile          eve.ux.view.Plainfile
---@field protected _retriever          std.collection.TreeviewRetriever
---@field protected _scheduler_match    std.collection.Scheduler|nil
---
---@field protected _last_input         string
---@field protected _last_offset        integer
---@field protected _last_matches       std.t.IScoredMatch[]|nil
---@field protected _last_matched_uuids table<string, boolean>|nil
---@field protected _last_preview_filepath  string|nil
---@field protected _uuid_root          string|nil
---@field protected _uuid_current       string|nil
---@field protected _uuids_file         string[]
---@field protected _uuids_order        string[]
---@field protected _uuids_selected     table<string, true>
---
---@field protected _on_confirm         eve.ux.picker_file.IOnConfirm|nil
---@field protected _on_disposed        eve.ux.picker_file.IOnDisposed
local M = {}
M.__index = M

local NSNR_PICKER_MATCHES = eve.var.nsnr.picker_matches ---@type integer

---@param props                         eve.ux.IFilePickerProps
---@return eve.ux.FilePicker
function M.new(props)
  local name = props.name ---@type string
  local uuid = props.uuid or std.fn.uuid() ---@type string
  local permanent = props.permanent ---@type boolean
  local preview = props.preview ~= false ---@type boolean
  local title = props.title ---@type string
  local height = props.height ---@type number|nil
  local width = props.width ---@type number|nil

  local finder_input = props.finder_input ---@type std.collection.IObservable
  local finder_input_history = props.finder_input_history ---@type std.collection.InputHistory|nil
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

  local on_closed = props.on_closed or std.fn.noop ---@type eve.ux.picker_file.IOnClosed
  local on_confirm = props.on_confirm ---@type eve.ux.picker_file.IOnConfirm|nil
  local on_disposed = props.on_disposed or std.fn.noop ---@type eve.ux.picker_file.IOnDisposed
  local on_focused = props.on_focused or std.fn.noop ---@type eve.ux.picker_file.IOnFocused
  local on_hidden = props.on_hidden or std.fn.noop ---@type eve.ux.picker_file.IOnHidden
  local on_refresh = props.on_refresh or std.fn.noop ---@type eve.ux.picker_file.IOnRefresh

  local indents = {} ---@type string[]

  local self = setmetatable({}, M)

  ---@type std.collection.TreeviewRetriever
  local retriever = std.TreeviewRetriever.new({
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

  local scheduler_match = std.Scheduler.new({
    name = string.format("%s#match", name),
    mode = "debounce",
    delay = 64,
    timeout = 0,
    silent = std.fn.falsy,
    value = std.Observable.from_value(true),
    task = function()
      local input = finder_input:snapshot() ---@type string
      self:__match__(input)
      filetree:mark_treeview_node_cache_dirty()
      self:mark_result_dirty()
    end,
  })

  ---@return eve.ux.view.filetree.INode|nil
  ---@return integer
  local function retrieve()
    local lnum = self._picker:get_result_lnum() ---@type integer
    local node_uuid = retriever:retrieve_uuid(lnum) ---@type string|nil
    if node_uuid == nil then
      return node_uuid, lnum
    end
    local node = filetree:retrieve_by_uuid(node_uuid) ---@type eve.ux.view.filetree.INode|nil
    return node, lnum
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
    flags[#flags + 1] = {
      desc = string.format("%s: fold empty path", name),
      disabled = function()
        local viewtype = flag_viewtype:snapshot() ---@type eve.ux.view.treeview.ViewtypeEnum
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
      local node = retrieve() ---@type  eve.ux.view.filetree.INode|nil, integer
      if node == nil then
        return
      end

      if on_confirm == nil then
        self:__open_node__(node)
      else
        self:__resolve_confirmation__(node)
      end
    end,
    on_filetree_toggle = function()
      local node = retrieve() ---@type  eve.ux.view.filetree.INode|nil, integer
      if node ~= nil then
        self:__toggle_node__(node, false)
      end
    end,
    on_filetree_toggle_recursively = function()
      local node = retrieve() ---@type  eve.ux.view.filetree.INode|nil, integer
      if node ~= nil then
        self:__toggle_node__(node, true)
      end
    end,
    on_toggle_selection = function()
      local node = retrieve() ---@type  eve.ux.view.filetree.INode|nil, integer
      if node == nil then
        return
      end

      local picker = self._picker ---@type eve.ux.PickerComposer
      local lnum = retriever:retrieve_lnum(node.uuid) ---@type integer|nil
      if lnum == nil or lnum < 0 then
        return
      end

      local uuids_selected = self._uuids_selected ---@type table<string, true>
      if node.type == "container" then
        local lastchild_index = self._retriever:retrieve_lastchild_lnum(lnum) ---@type integer|nil
        if lastchild_index ~= nil and lnum <= lastchild_index then
          local next_selected = false ---@type boolean
          local next_selected_value = nil ---@type boolean|nil
          for index = lnum, lastchild_index, 1 do
            local node_uuid = retriever:retrieve_uuid(index) ---@type string|nil
            if node_uuid ~= nil and uuids_selected[node_uuid] ~= true then
              next_selected = true
              next_selected_value = true
              break
            end
          end

          for index = lnum, lastchild_index, 1 do
            local node_uuid = retriever:retrieve_uuid(index) ---@type string|nil
            if node_uuid ~= nil then
              uuids_selected[node_uuid] = next_selected_value
              picker.result:toggle_selected(index, next_selected)
            end
          end
        end
        return
      end

      if node.type == "leaf" then
        if uuids_selected[node.uuid] then
          uuids_selected[node.uuid] = nil
        else
          uuids_selected[node.uuid] = true
        end
        picker.result:toggle_selected(lnum)
        return
      end
    end,
  }

  ---@type std.t.IKeymap[]
  local finder_keymaps = {
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
      modes = { "n" },
      key = "z",
      desc = "filetree: toggle (recursively)",
      callback = actions.on_filetree_toggle_recursively,
    },
    {
      modes = { "n" },
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
      key = "<Tab>",
      desc = "filetree: toggle selection",
      callback = actions.on_toggle_selection,
    },
  }

  local picker = eve.ux.PickerComposer.new({
    uuid = uuid,
    name = name,
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
      local viewtype = flag_viewtype:snapshot() ---@type eve.ux.view.treeview.ViewtypeEnum
      local result ---@type eve.ux.view.treeview.IRenderResult
      if flag_selected:snapshot() then
        local visible_uuids = filetree:calc_include_uuid_set(vim.tbl_keys(self._uuids_selected)) ---@type table<string, boolean>
        result = filetree:render(bufnr, viewtype, self._uuid_root, visible_uuids, self._uuids_order) ---@type eve.ux.view.treeview.IRenderResult
      else
        result = filetree:render(bufnr, viewtype, self._uuid_root, self._last_matched_uuids, self._uuids_order) ---@type eve.ux.view.treeview.IRenderResult
      end
      indents = result.indents ---@type string[]
      retriever:attach(bufnr, result.uuids, result.childline)

      local lnums_selected = {} ---@type integer[]
      for uuid_selected in pairs(self._uuids_selected) do
        local lnum_selected = retriever:retrieve_lnum(uuid_selected) ---@type integer|nil
        if lnum_selected ~= nil and lnum_selected > 0 then
          lnums_selected[#lnums_selected + 1] = lnum_selected
        end
      end

      local uuid_current = self._uuid_current ---@type string|nil
      local lnum_current = uuid_current ~= nil and retriever:retrieve_lnum(uuid_current) or nil ---@type integer|nil
      local ret = { lnum_current = lnum_current, lnums_selected = lnums_selected } ---@type eve.ux.picker.result.IDrawResult
      return ret
    end,

    ---@type eve.ux.picker.preview.IDraw|nil
    preview_render = preview
        and function(bufnr)
          local node, lnum = retrieve() ---@type  eve.ux.view.filetree.INode|nil, integer
          if node == nil then
            local lines = { string.format("Error: cannot retrieve node by the given lnum: %d", lnum) } ---@type string[]
            vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
            self._last_preview_filepath = nil

            ---@cast node                 eve.ux.view.filetree.ILocationNode
            ---@type eve.ux.picker.preview.IDrawResult
            local result = {
              cursorline = true,
              number = true,
              title = string.format("Unknown lnum(%d)", lnum),
              wrap = true,
              lnum = 1,
            }
            return result
          end

          local force = node.data.filepath ~= self._last_preview_filepath ---@type boolean
          self._last_preview_filepath = node.data.filepath ---@type string|nil

          if node.type == "container" then
            filetree:render_tree(bufnr, node.uuid, nil, true)
            ---@cast node                 eve.ux.view.filetree.ILocationNode
            ---@type eve.ux.picker.preview.IDrawResult
            local result = {
              cursorline = true,
              number = true,
              title = node.data.filepath,
              wrap = false,
              lnum = 1,
            }
            return result
          end

          if node.type == "leaf" and #node.children > 0 then
            node = node.children[1] ---@type eve.ux.view.filetree.INode
          end

          local filepath = node.data.filepath ---@type string
          plainfile:render(bufnr, filepath, force)

          local root = filetree:retrieve_by_uuid(self._uuid_root) ---@type eve.ux.view.filetree.INode|nil
          local relative_filepath = root ~= nil
              and std.path.relative(root.data.filepath or std.path.cwd(), filepath, false)
            or filepath

          ---@cast node                 eve.ux.view.filetree.ILocationNode
          ---@type eve.ux.picker.preview.IDrawResult
          local result = {
            cursorline = true,
            number = true,
            title = relative_filepath,
            wrap = false,
            lnum = node.data.lnum,
            col = node.data.col,
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
    on_refresh = function(_, force)
      on_refresh(self, force)
    end,
    on_result_rendered = function(_, bufnr)
      local last_matches = self._last_matches ---@type std.t.IScoredMatch[]|nil
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
                  "f_pk_matches",
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
                "f_pk_matches",
                { row, offset_final + m.l },
                { row, offset_final + m.r }
              )
            end
          end
        end
        return
      end
    end,
  })

  self.uuid = uuid
  self.name = name

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

  self._last_input = ""
  self._last_offset = 0
  self._last_matches = nil
  self._last_matched_uuids = nil
  self._last_preview_filepath = nil
  self._uuid_root = nil
  self._uuids_file = {}
  self._uuids_order = {}
  self._uuids_selected = {}

  self._on_confirm = on_confirm
  self._on_disposed = on_disposed

  std.fn.observe(
    { finder_input, flag_foldempty, flag_fuzzy, flag_regex, flag_sensitive, flag_selected, flag_viewtype },
    function()
      picker:mark_result_flags_dirty()
    end,
    true
  )
  std.fn.observe({ finder_input, flag_fuzzy, flag_regex, flag_sensitive, flag_selected, flag_viewtype }, function()
    picker:mark_result_dirty()
  end, true)
  std.fn.observe({ finder_input, flag_fuzzy, flag_regex, flag_sensitive }, function()
    scheduler_match:schedule()
  end)
  std.fn.observe({ picker.result.lnum_current }, function()
    local lnum = picker.result.lnum_current:snapshot() ---@type integer
    local node_uuid = retriever:retrieve_uuid(lnum) ---@type string|nil
    if node_uuid ~= nil then
      self._uuid_current = node_uuid
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

  local on_dispose = self._on_disposed ---@type eve.ux.picker.composer.IOnDisposed
  self._scheduler_match:dispose()
  self._filetree:dispose()
  self._plainfile:dispose()
  self._retriever:dispose()
  self._picker:dispose()

  self.finder = nil
  self.result = nil
  self.preview = nil

  self.flag_foldempty = nil
  self.flag_fuzzy = nil
  self.flag_regex = nil
  self.flag_sensitive = nil
  self.flag_selected = nil

  self._filetree = nil
  self._frecency = nil
  self._picker = nil
  self._plainfile = nil
  self._retriever = nil
  self._scheduler_match = nil

  self._last_input = nil
  self._last_offset = nil
  self._last_matches = nil
  self._last_matched_uuids = nil
  self._last_preview_filepath = nil
  self._uuid_root = nil
  self._uuids_file = nil
  self._uuids_order = nil
  self._uuids_selected = nil

  self._on_confirm = nil
  self._on_disposed = nil

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
    std.reporter.error({
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

  cwd = std.path.normalize(cwd) ---@type string
  self._filetree:reset_filepaths(cwd, filepaths, with_positions)

  local frecency = self._frecency ---@type std.collection.IFrecency|nil
  local uuid_cwd = self._filetree:retrieve_uuid_by_filepath(cwd) ---@type string|nil
  local uuids_file = self._filetree:collect_file_uuids(uuid_cwd) ---@type string[]
  local uuids_order = vim.list_slice(uuids_file) ---@type string[]

  if frecency ~= nil then
    table.sort(uuids_order, function(a, b)
      local sa = frecency:score(a) or 0 ---@type integer
      local sb = frecency:score(b) or 0 ---@type integer
      return sa > sb
    end)
  end

  self._last_input = ""
  self._last_offset = nil
  self._last_matches = nil
  self._last_matched_uuids = nil
  self._last_preview_filepath = nil
  self._uuid_root = uuid_cwd
  self._uuids_file = uuids_file
  self._uuids_order = uuids_order
  self._uuids_selected = {}
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
  local frecency = self._frecency ---@type std.collection.IFrecency|nil

  if #input < 1 then
    local uuids_order = vim.list_slice(self._uuids_file) ---@type string[]
    if frecency ~= nil then
      table.sort(uuids_order, function(a, b)
        local sa = frecency:score(a) or 0 ---@type integer
        local sb = frecency:score(b) or 0 ---@type integer
        return sa >= sb
      end)
    end

    self._last_input = ""
    self._last_offset = 0
    self._last_matches = nil
    self._last_matched_uuids = nil
    self._uuids_order = uuids_order
    return
  end

  local filetree = self._filetree ---@type eve.ux.view.Filetree
  local flag_fuzzy = self.flag_fuzzy:snapshot() ---@type boolean
  local flag_regex = self.flag_regex:snapshot() ---@type boolean
  local flag_sensitive = self.flag_sensitive:snapshot() ---@type boolean

  local lines = {} ---@type string[]
  local uuids = {} ---@type string[]

  local root = filetree:retrieve_by_uuid(self._uuid_root) ---@type eve.ux.view.filetree.INode|nil
  local offset = root ~= nil and #root.data.filepath > 2 and #root.data.filepath + 2 or 0 ---@type integer

  local last_input = self._last_input ---@type string
  local last_matches = self._last_matches ---@type std.t.IScoredMatch[]|nil
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

  local keyword = flag_sensitive and input or input:lower() ---@type string

  ---@type eve.builtin.oxi.string.ILineMatch[]|nil
  local oxi_matches = eve.oxi.find_match_points_line_by_line(keyword, lines, flag_fuzzy, flag_regex)
  if oxi_matches == nil then
    self._last_input = ""
    self._last_offset = 0
    self._last_matches = nil
    self._last_matched_uuids = nil
    self._uuids_order = {}
    return
  end

  if frecency ~= nil then
    for _, match in ipairs(oxi_matches) do
      local score = frecency:score(uuids[match.lnum]) or 0 ---@type integer
      match.score = match.score + score
    end
    table.sort(oxi_matches, function(a, b)
      return a.score > b.score
    end)
  end

  local matches = {} ---@type std.t.IScoredMatch[]
  local matched_uuids = {} ---@type string[]
  local uuids_order = {} ---@type string[]
  for _, oxi_match in ipairs(oxi_matches) do
    local lnum = oxi_match.lnum ---@type integer

    ---@type std.t.IScoredMatch
    local match = {
      order = lnum,
      uuid = uuids[lnum],
      score = oxi_match.score,
      matches = oxi_match.matches,
    }

    matches[#matches + 1] = match
    matched_uuids[#matched_uuids + 1] = match.uuid
    uuids_order[#uuids_order + 1] = match.uuid
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
  self._uuids_order = uuids_order
end

---@param node                          eve.ux.view.filetree.INode
---@return nil
function M:__open_node__(node)
  local filetree = self._filetree ---@type eve.ux.view.Filetree
  local picker = self._picker ---@type eve.ux.PickerComposer

  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local winnr_sourcefile = eve.tab.retrieve_winnr_sourcefile(tabnr) ---@type integer|nil
  if winnr_sourcefile ~= nil and vim.api.nvim_win_is_valid(winnr_sourcefile) then
    vim.api.nvim_tabpage_set_win(tabnr, winnr_sourcefile)
  else
    winnr_sourcefile = nil
  end

  local uuids_selected = self._uuids_selected ---@type table<string, true>
  local filepath_set = {} ---@type table<string, eve.ux.view.filetree.IFileNode|eve.ux.view.filetree.ILocationNode>
  for uuid in pairs(uuids_selected) do
    local o = filetree:retrieve_by_uuid(uuid) ---@type eve.ux.view.filetree.INode|nil
    if o ~= nil then
      if o.type == "leaf" then
        filepath_set[o.data.filepath] = filepath_set[o.data.filepath] or o
      elseif o.type == "location" then
        filepath_set[o.data.filepath] = o
      end
    end
  end
  local filepaths = {} ---@type string[]
  for filepath in pairs(filepath_set) do
    filepaths[#filepaths + 1] = filepath
  end

  if #filepaths > 0 then
    local last_filepath = filepaths[#filepaths] ---@type string
    local lastnode = filepath_set[last_filepath] ---@type eve.ux.view.filetree.IFileNode|eve.ux.view.filetree.ILocationNode

    picker:close()
    eve.win.open_filepaths(winnr_sourcefile, filepaths, lastnode.data.lnum, lastnode.data.col)
    return
  end

  if node.type == "container" then
    filetree:collapse(node.uuid, "toggle", false)
    picker:mark_result_dirty()
    return
  end

  if node.type == "leaf" and node.collapsed then
    filetree:collapse(node.uuid, "expand", false)
    picker:mark_result_dirty()
    return
  end

  picker:close()
  eve.win.open_filepath(winnr_sourcefile, node.data.filepath, node.data.lnum, node.data.col)
end

---@param node                          eve.ux.view.filetree.INode
---@return eve.ux.picker_file.ISelectedItem[]|nil
function M:__resolve_confirmation__(node)
  local filetree = self._filetree ---@type eve.ux.view.Filetree
  local picker = self._picker ---@type eve.ux.PickerComposer
  local root = filetree:retrieve_by_uuid(self._uuid_root) ---@type eve.ux.view.filetree.INode|nil
  local uuids_selected = self._uuids_selected ---@type table<string, true>

  local item_map = {} ---@type table<string, eve.ux.picker_file.ISelectedItem[]>
  for uuid in pairs(uuids_selected) do
    local o = filetree:retrieve_by_uuid(uuid) ---@type eve.ux.view.filetree.INode|nil
    if o ~= nil and (o.type == "leaf" or o.type == "location") then
      local item = item_map[o.data.filepath] ---@type eve.ux.picker_file.ISelectedItem[]|nil
      if item == nil then
        local filepath = root ~= nil and std.path.relative(root.data.filepath or std.path.cwd(), o.data.filepath, false)
          or o.data.filepath

        item = { filepath = filepath, locations = {} } ---@type eve.ux.picker_file.ISelectedItem
        item_map[filepath] = item
      end

      if o.data.lnum ~= nil then
        item.locations[#item.locations + 1] = {
          lnum = o.data.lnum,
          col = o.data.col,
        }
      end
    end
  end
  local items = {} ---@type eve.ux.picker_file.ISelectedItem[]
  for _, item in pairs(item_map) do
    items[#items + 1] = item
  end

  if #items > 0 then
    picker:close()
    self._on_confirm(self, items)
    return
  end

  if node.type == "container" then
    filetree:collapse(node.uuid, "toggle", false)
    picker:mark_result_dirty()
    return
  end

  if node.type == "leaf" and node.collapsed then
    filetree:collapse(node.uuid, "expand", false)
    picker:mark_result_dirty()
    return
  end

  local filepath = root ~= nil and std.path.relative(root.data.filepath or std.path.cwd(), node.data.filepath, false)
    or node.data.filepath

  local item = { filepath = filepath, locations = {} } ---@type eve.ux.picker_file.ISelectedItem
  if node.data.lnum ~= nil then
    item.locations[#item.locations + 1] = {
      lnum = node.data.lnum,
      col = node.data.col,
    }
  end

  picker:close()
  self._on_confirm(self, items)
end

---@param node                          eve.ux.view.filetree.INode
---@param recursively                   boolean
---@return nil
function M:__toggle_node__(node, recursively)
  local filetree = self._filetree ---@type eve.ux.view.Filetree
  local picker = self._picker ---@type eve.ux.PickerComposer
  if node.type == "container" then
    filetree:collapse(node.uuid, "toggle", recursively)
    picker:mark_result_dirty()
    return
  end

  if node.type == "leaf" and #node.children > 0 then
    filetree:collapse(node.uuid, "toggle", false)
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
    eve.win.open_filepath(winnr_sourcefile, node.data.filepath, node.data.lnum, node.data.col)
  end
end

return M
