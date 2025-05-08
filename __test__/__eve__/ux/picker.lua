require("plenary.reload").reload_module("eve.ux.picker")

---@class __test__.ux.picker.IData
---@field public uuid                   string
---@field public filepath               string
---@field public filetype               string
---@field public basename               string

local cwd = eve.path.cwd() ---@type string
local command = string.format("fd '.lua'") ---@type string
local relative_filepaths = vim.split(vim.trim(vim.fn.system(command)), "\n", { plain = true }) ---@type string[]

local treeview = eve.ux.view.Treeview.new({
  name = "file treeview",
  indent = " ",
  indent_hln = "f_utw_indent_float",
  ---@param node                        eve.ux.view.treeview.INode
  ---@return string
  ---@return eve.t.IHighlightInline[]|nil
  renderer = function(node)
    local data = node.data ---@type __test__.ux.picker.IData
    local highlights = {} ---@type eve.t.IHighlightInline[]
    local icon, icon_hln ---@type string, string

    if node.type == "container" then
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

    local text = string.format("%s %s", icon, data.basename) ---@type string
    local highlight = { coll = 0, colr = #icon + 1, hlname = icon_hln } ---@type eve.t.IHighlightInline
    highlights[#highlights + 1] = highlight
    return text, highlights
  end,
  ---@param left                        eve.ux.view.treeview.INode
  ---@param right                       eve.ux.view.treeview.INode
  ---@return boolean
  sorter = function(left, right)
    return left.data.basename < right.data.basename
  end,
})

---! root node
local root_uuid = string.format("uuid:%s", cwd) ---@type string
do
  local filepath = cwd --@type string
  local filetype = "directory" ---@type string
  local basename = cwd ---@type string

  ---@type __test__.ux.treeview.IData
  local data = {
    uuid = root_uuid,
    filepath = filepath,
    filetype = filetype,
    basename = basename,
  }
  treeview:insert_container(root_uuid, root_uuid, data, false)
end

for _, relative_filepath in ipairs(relative_filepaths) do
  local pieces = eve.path.split(relative_filepath) ---@type string[]
  local parent_uuid = root_uuid ---@type string
  local filepath = cwd --@type string
  for index = 1, #pieces - 1, 1 do
    local filetype = "directory" ---@type string
    local basename = pieces[index] ---@type string

    filepath = filepath .. eve.env.PATH_SEP .. basename ---@type string
    local uuid = string.format("uuid:%s", filepath) ---@type string

    if not treeview:has(uuid) then
      ---@type __test__.ux.picker.IData
      local data = {
        uuid = uuid,
        filepath = filepath,
        filetype = filetype,
        basename = basename,
      }
      treeview:insert_container(uuid, parent_uuid, data, index > 2)
    end
    parent_uuid = uuid
  end

  local filetype = "lua" ---@type string
  local filename = pieces[#pieces] ---@type string

  filepath = filepath .. eve.env.PATH_SEP .. filename ---@type string
  local uuid = string.format("uuid:%s", filepath) ---@type string

  ---@type __test__.ux.picker.IData
  local data = {
    uuid = uuid,
    filepath = filepath,
    filetype = filetype,
    basename = filename,
  }
  treeview:insert_leaf(uuid, parent_uuid, data)
end

local picker = eve.ux.Picker.new({
  uuid = "__test__eve_ux_picker__",
  name = "file-picker",
  permanent = false,
  finder_title = "File Picker",
  finder_input = "eve/ux",
  finder_multiline = false,
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

        if node.type == "container" then
          treeview:collapse(node.uuid, "toggle", true)
          self:mark_result_dirty()
        else
          local data = node.data ---@type __test__.ux.picker.IData
          self:close()

          vim.schedule(function()
            eve.debug.log(string.format("open file %s", data.filepath))
            -- eve.win.open_filepath(nil, data.filepath)
          end)
        end
      end,
    },
    {
      modes = { "n" },
      key = "<2-LeftMouse>",
      desc = "filetree: toggle",
      callback = function(self)
        local lnum = self:get_result_lnum() ---@type integer
        local node = treeview:retrieve_by_lnum(lnum, true) ---@type eve.ux.view.treeview.INode|nil
        if node == nil then
          return
        end

        if node.type == "container" then
          treeview:collapse(node.uuid, "toggle", false)
          self:mark_result_dirty()
        else
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

        if node.type == "container" then
          treeview:collapse(node.uuid, "expanded", false)
          self:mark_result_dirty()
        else
          local data = node.data ---@type __test__.ux.picker.IData
          self:close()

          vim.schedule(function()
            eve.debug.log(string.format("open file %s", data.filepath))
            -- eve.win.open_filepath(nil, data.filepath)
          end)
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

        if node.type == "container" and not node.collapsed then
          treeview:collapse(node.uuid, "collapsed", false)
          self:mark_result_dirty()
        else
          local lnum_parent = treeview:retrieve_lnum(node.parent) ---@type integer|nil
          treeview:collapse(node.parent, "collapsed", false)
          self:mark_result_dirty()

          if lnum_parent ~= nil then
            vim.api.nvim_win_set_cursor(0, { lnum_parent, 0 })
          end
        end
      end,
    },
  },
  on_dispose = function()
    treeview:dispose()
  end,
  on_finder_change = function(self)
    self:mark_result_dirty()
  end,
  result_render = function(self, bufnr, input)
    treeview:render(bufnr, cwd)
    return 2
  end,
})

picker:focus()
