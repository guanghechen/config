require("plenary.reload").reload_module("eve.ux.picker")
require("plenary.reload").reload_module("eve.ux.view.treeview")

---@class __test__.ux.picker.ITreeNodeData
---@field public uuid                   string
---@field public filepath               string
---@field public filetype               string
---@field public basename               string

local cwd = eve.path.cwd() ---@type string
local command = string.format("fd '.lua'") ---@type string
local relative_filepaths = vim.split(vim.trim(vim.fn.system(command)), "\n", { plain = true }) ---@type string[]

local treeview = eve.ux.view.Treeview.new({
  name = "file treeview",
  foldempty = false,
  indent_hln = "f_utw_indent_float",
  ---@type eve.ux.view.treeview.INodeRenderer
  node_renderer = function(treeview, node, folded_depth)
    local data = node.data ---@type __test__.ux.picker.ITreeNodeData
    local icon, icon_hln ---@type string, string

    if data.filetype == "directory" then
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
      local hln_basename = data.filetype == "directory" and "f_utw_dirname" or "f_utw_filename" ---@type string
      highlights[#highlights + 1] = { coll = #icon + 1, colr = #text, hlname = hln_basename }
    else
      local basenames = {} ---@type string[]
      basenames[folded_depth + 1] = data.basename ---@type string
      for index = folded_depth, 1, -1 do
        local parent_uuid = node.parent ---@type string
        local parent = treeview:retrieve_by_uuid(parent_uuid) ---@type eve.ux.view.treeview.INode|nil
        ---@cast parent eve.ux.view.treeview.INode

        local parent_data = parent.data ---@type __test__.ux.picker.ITreeNodeData
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
  end,
  ---@type eve.ux.view.treeview.INodeSorter
  sorter = function(left, right)
    if left.leaf ~= right.leaf then
      return right.leaf
    end
    return left.data.basename < right.data.basename
  end,
})

---! root node
local root_uuid = string.format("uuid:%s", cwd) ---@type string
do
  local filepath = cwd --@type string
  local filetype = "directory" ---@type string
  local basename = cwd ---@type string

  ---@type __test__.ux.picker.ITreeNodeData
  local data = {
    uuid = root_uuid,
    filepath = filepath,
    filetype = filetype,
    basename = basename,
  }
  treeview:insert(root_uuid, root_uuid, data, false, false)
end

for _, relative_filepath in ipairs(relative_filepaths) do
  local pieces = eve.path.split(relative_filepath) ---@type string[]
  local parent_uuid = root_uuid ---@type string
  local filepath = cwd ---@type string
  for index = 1, #pieces - 1, 1 do
    local filetype = "directory" ---@type string
    local basename = pieces[index] ---@type string

    filepath = filepath .. eve.env.PATH_SEP .. basename ---@type string
    local uuid = string.format("uuid:%s", filepath) ---@type string

    if not treeview:has(uuid) then
      ---@type __test__.ux.picker.ITreeNodeData
      local data = {
        uuid = uuid,
        filepath = filepath,
        filetype = filetype,
        basename = basename,
      }
      treeview:insert(uuid, parent_uuid, data, false, index > 2)
    end
    parent_uuid = uuid
  end

  local filetype = "lua" ---@type string
  local filename = pieces[#pieces] ---@type string

  filepath = filepath .. eve.env.PATH_SEP .. filename ---@type string
  local uuid = string.format("uuid:%s", filepath) ---@type string

  ---@type __test__.ux.picker.ITreeNodeData
  local data = {
    uuid = uuid,
    filepath = filepath,
    filetype = filetype,
    basename = filename,
  }
  treeview:insert(uuid, parent_uuid, data, true, false)
end

local fuzzy = eve.std.Observable.from_value(false)
local sensitive = eve.std.Observable.from_value(true)

local picker = eve.ux.Picker.new({
  uuid = "__test__eve_ux_picker__",
  name = "file-picker",
  permanent = false,
  finder_title = "File Picker",
  finder_input = "eve/ux",
  finder_multiline = false,
  flags = {
    {
      type = "enum",
      desc = "file-picker: open settings",
      callback = eve.std.fn.noop,
      snapshot = function()
        return true, eve.icon.symbols.setting
      end,
    },
    {
      type = "boolean",
      desc = "file-picker: fuzzy",
      callback = function()
        local enabled = fuzzy:snapshot() ---@type boolean
        fuzzy:next(not enabled)
      end,
      snapshot = function()
        local enabled = fuzzy:snapshot() ---@type boolean
        return enabled, eve.icon.symbols.flag_fuzzy
      end,
    },
    {
      type = "boolean",
      desc = "file-picker: sensitive",
      callback = function()
        local enabled = sensitive:snapshot() ---@type boolean
        sensitive:next(not enabled)
      end,
      snapshot = function()
        local enabled = sensitive:snapshot() ---@type boolean
        return enabled, eve.icon.symbols.flag_case_sensitive
      end,
    },
    {
      type = "boolean",
      desc = "file-picker: fold empty path",
      callback = function(picker)
        local enabled = treeview:isfoldempty() ---@type boolean
        treeview:set_foldempty(not enabled)
        picker:mark_result_dirty()
      end,
      snapshot = function()
        local enabled = treeview:isfoldempty() ---@type boolean
        return enabled, ""
      end,
    },
  },
  flags_start_index = 0,
  finder_keymaps = {
    {
      modes = { "i", "n", "v" },
      key = "<C-l>",
      desc = "filetree: open",
      callback = function(self)
        local lnum = self:get_result_lnum() ---@type integer
        local node = treeview:retrieve_by_lnum(lnum, false) ---@type eve.ux.view.treeview.INode|nil
        if node == nil then
          return
        end

        local data = node.data ---@type __test__.ux.picker.ITreeNodeData
        if data.filetype == "directory" then
          treeview:collapse(node.uuid, "expanded", false)
          self:mark_result_dirty()
        else
          local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
          local winnr_sourcefile = eve.tab.retrieve_winnr_sourcefile(tabnr) ---@type integer|nil
          if winnr_sourcefile ~= nil and vim.api.nvim_win_is_valid(winnr_sourcefile) then
            vim.api.nvim_tabpage_set_win(tabnr, winnr_sourcefile)
          end

          self:close()
          local filepath = data.filepath ---@type string
          eve.win.open_filepath(winnr_sourcefile, filepath)
        end
      end,
    },
    {
      modes = { "i", "n", "v" },
      key = "<C-h>",
      desc = "filetree: close",
      callback = function(self)
        local lnum = self:get_result_lnum() ---@type integer
        local node = treeview:retrieve_by_lnum(lnum, false) ---@type eve.ux.view.treeview.INode|nil
        if node == nil then
          return
        end

        local data = node.data ---@type __test__.ux.picker.ITreeNodeData
        if data.filetype == "directory" and not node.collapsed then
          treeview:collapse(node.uuid, "collapsed", false)
          self:mark_result_dirty()
        else
          local lnum_parent = treeview:retrieve_lnum(node.parent) ---@type integer|nil
          treeview:collapse(node.parent, "collapsed", false)
          self:mark_result_dirty()
          if lnum_parent ~= nil then
            self:set_result_lnum(lnum_parent)
          end
        end
      end,
    },
  },
  result_keymaps = {
    {
      modes = { "n" },
      key = "z",
      desc = "filetree: toggle collapsed (recursively)",
      callback = function(self)
        local lnum = self:get_result_lnum() ---@type integer
        local node = treeview:retrieve_by_lnum(lnum, true) ---@type eve.ux.view.treeview.INode|nil
        if node == nil then
          return
        end

        local data = node.data ---@type __test__.ux.picker.ITreeNodeData
        if data.filetype == "directory" then
          treeview:collapse(node.uuid, "toggle", true)
          self:mark_result_dirty()
        else
          local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
          local winnr_sourcefile = eve.tab.retrieve_winnr_sourcefile(tabnr) ---@type integer|nil
          if winnr_sourcefile ~= nil and vim.api.nvim_win_is_valid(winnr_sourcefile) then
            vim.api.nvim_tabpage_set_win(tabnr, winnr_sourcefile)
          end

          self:close()
          local filepath = data.filepath ---@type string
          eve.win.open_filepath(winnr_sourcefile, filepath)
        end
      end,
    },
    {
      modes = { "n" },
      key = "<2-LeftMouse>",
      desc = "filetree: toggle",
      callback = function(self)
        local result_winnr = self:get_result_winnr() ---@type integer|nil
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

          local data = node.data ---@type __test__.ux.picker.ITreeNodeData
          if data.filetype == "directory" then
            treeview:collapse(node.uuid, "toggle", false)
            self:mark_result_dirty()
          else
            local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
            local winnr_sourcefile = eve.tab.retrieve_winnr_sourcefile(tabnr) ---@type integer|nil
            if winnr_sourcefile ~= nil and vim.api.nvim_win_is_valid(winnr_sourcefile) then
              vim.api.nvim_tabpage_set_win(tabnr, winnr_sourcefile)
            end

            self:close()
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
      callback = function(self)
        local lnum = self:get_result_lnum() ---@type integer
        local node = treeview:retrieve_by_lnum(lnum, false) ---@type eve.ux.view.treeview.INode|nil
        if node == nil then
          return
        end

        local data = node.data ---@type __test__.ux.picker.ITreeNodeData
        if data.filetype == "directory" then
          treeview:collapse(node.uuid, "expanded", false)
          self:mark_result_dirty()
        else
          local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
          local winnr_sourcefile = eve.tab.retrieve_winnr_sourcefile(tabnr) ---@type integer|nil
          if winnr_sourcefile ~= nil and vim.api.nvim_win_is_valid(winnr_sourcefile) then
            vim.api.nvim_tabpage_set_win(tabnr, winnr_sourcefile)
          end

          self:close()
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
      callback = function(self)
        local lnum = self:get_result_lnum() ---@type integer
        local node = treeview:retrieve_by_lnum(lnum, false) ---@type eve.ux.view.treeview.INode|nil
        if node == nil then
          return
        end

        local data = node.data ---@type __test__.ux.picker.ITreeNodeData
        if data.filetype == "directory" and not node.collapsed then
          treeview:collapse(node.uuid, "collapsed", false)
          self:mark_result_dirty()
        else
          local lnum_parent = treeview:retrieve_lnum(node.parent) ---@type integer|nil
          treeview:collapse(node.parent, "collapsed", false)
          self:mark_result_dirty()
          if lnum_parent ~= nil then
            self:set_result_lnum(lnum_parent)
          end
        end
      end,
    },
  },
  on_dispose = function()
    treeview:dispose()
  end,
  on_finder_change = function(picker)
    picker:mark_result_dirty()
  end,
  ---@type eve.ux.picker.IResultRender
  result_render = function(_, bufnr, input)
    treeview:render(bufnr, root_uuid)
  end,
  ---@type eve.ux.picker.IPreviewRender
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

    local data = node.data ---@type __test__.ux.picker.ITreeNodeData
    if data.filetype == "directory" then
      ---@type string[]
      local lines = {
        string.format("Directory: %s", data.filepath),
      }
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      return data.filepath
    end

    local lines = eve.fs.read_file_as_lines({ filepath = data.filepath, silent = true }) ---@type string[]
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

    local filetype = data.filetype ---@type string
    if filetype ~= nil then
      if vim.treesitter ~= nil and vim.treesitter.language ~= nil then
        local lang = vim.treesitter.language.get_lang(filetype) or filetype
        local loaded = vim.treesitter.language.add(lang)
        if loaded then
          vim.treesitter.stop(bufnr)
          vim.treesitter.start(bufnr, lang)
        end
      end
    end
    return data.filepath
  end,
})

eve.fn.observe({ fuzzy, sensitive }, function()
  picker:mark_result_flags_dirty()
end, true)

picker:focus()
