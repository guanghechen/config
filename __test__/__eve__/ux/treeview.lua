require("plenary.reload").reload_module("eve.ux.view.treeview")

---@class __test__.ux.treeview.IData
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

    local text = string.format("%s %s", icon, data.basename) ---@type string
    local highlight = { coll = 0, colr = #icon + 1, hlname = icon_hln } ---@type eve.t.IHighlightInline
    highlights[#highlights + 1] = highlight
    return text, highlights
  end,
  ---@param left                        eve.ux.view.treeview.INode
  ---@param right                       eve.ux.view.treeview.INode
  ---@return boolean
  sorter = function(left, right)
    if left.data.filetype ~= right.data.filetype then
      if left.data.filetype == "directory" then
        return true
      end
      if right.data.filetype == "directory" then
        return false
      end
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

  ---@type __test__.ux.treeview.IData
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
  local filepath = cwd --@type string
  for index = 1, #pieces - 1, 1 do
    local filetype = "directory" ---@type string
    local basename = pieces[index] ---@type string

    filepath = filepath .. eve.env.PATH_SEP .. basename ---@type string
    local uuid = string.format("uuid:%s", filepath) ---@type string

    if not treeview:has(uuid) then
      ---@type __test__.ux.treeview.IData
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

  ---@type __test__.ux.treeview.IData
  local data = {
    uuid = uuid,
    filepath = filepath,
    filetype = filetype,
    basename = filename,
  }
  treeview:insert(uuid, parent_uuid, data, true, false)
end

local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
vim.bo[bufnr].bufhidden = "wipe"
vim.bo[bufnr].buflisted = false
vim.bo[bufnr].buftype = "nofile"
vim.bo[bufnr].filetype = "treeview"
vim.bo[bufnr].swapfile = false
vim.b[bufnr].miniindentscope_disable = true

---@type eve.t.IKeymap[]
local keymaps = {
  {
    modes = { "n" },
    key = "q",
    desc = "filetree: quit",
    callback = function()
      local winnr = vim.api.nvim_get_current_win() ---@type integer
      vim.api.nvim_win_close(winnr, true)
      pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
    end,
  },
  {
    modes = { "n" },
    key = "z",
    desc = "filetree: toggle collapsed (recursively)",
    callback = function()
      local winnr = vim.api.nvim_get_current_win() ---@type integer
      local lnum = vim.api.nvim_win_get_cursor(winnr)[1] ---@type integer
      local node = treeview:retrieve_by_lnum(lnum, true) ---@type eve.ux.view.treeview.INode|nil
      if node == nil then
        return
      end

      local data = node.data ---@type __test__.ux.picker.IData
      if data.filetype == "directory" then
        treeview:collapse(node.uuid, "toggle", true):render(bufnr)
      else
        vim.api.nvim_win_close(winnr, true)

        pcall(vim.api.nvim_buf_delete, bufnr, { force = true })

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
    callback = function()
      local winnr = vim.api.nvim_get_current_win() ---@type integer
      local lnum = vim.api.nvim_win_get_cursor(winnr)[1] ---@type integer
      local node = treeview:retrieve_by_lnum(lnum, true) ---@type eve.ux.view.treeview.INode|nil
      if node == nil then
        return
      end

      local data = node.data ---@type __test__.ux.picker.IData
      if data.filetype == "directory" then
        treeview:collapse(node.uuid, "toggle", false):render(bufnr)
      else
      end
    end,
  },
  {
    modes = { "i", "n", "v" },
    key = "<CR>",
    aliases = { "<Right>", "l", "o" },
    desc = "filetree: open",
    callback = function()
      local winnr = vim.api.nvim_get_current_win() ---@type integer
      local lnum = vim.api.nvim_win_get_cursor(winnr)[1] ---@type integer
      local node = treeview:retrieve_by_lnum(lnum, false) ---@type eve.ux.view.treeview.INode|nil
      if node == nil then
        return
      end

      local data = node.data ---@type __test__.ux.picker.IData
      if data.filetype == "directory" then
        treeview:collapse(node.uuid, "expanded", false):render(bufnr)
      else
        vim.api.nvim_win_close(winnr, true)
        pcall(vim.api.nvim_buf_delete, bufnr, { force = true })

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
    callback = function()
      local winnr = vim.api.nvim_get_current_win() ---@type integer
      local lnum = vim.api.nvim_win_get_cursor(winnr)[1] ---@type integer
      local node = treeview:retrieve_by_lnum(lnum, false) ---@type eve.ux.view.treeview.INode|nil
      if node == nil then
        return
      end

      local data = node.data ---@type __test__.ux.picker.IData
      if data.filetype == "directory" then
        treeview:collapse(node.uuid, "collapsed", false):render(bufnr)
      else
        local lnum_parent = treeview:retrieve_lnum(node.parent) ---@type integer|nil
        treeview:collapse(node.parent, "collapsed", false):render(bufnr)
        if lnum_parent ~= nil then
          vim.api.nvim_win_set_cursor(0, { lnum_parent, 0 })
        end
      end
    end,
  },
}
eve.nvim.bindkeys(keymaps, {
  bufnr = bufnr,
  noremap = true,
  nowait = true,
  silent = true,
})

treeview:render(bufnr)
local max_height = math.floor(vim.o.lines * 0.6) ---@type integer
local max_width = math.floor(vim.o.columns * 0.6) ---@type integer
max_width = math.max(48, max_width) ---@type integer
local height = math.min(40, vim.o.lines - 8, max_height + 1) ---@type integer
local width = math.min(100, vim.o.columns - 20, max_width + 2) ---@type integer
local row = 3 ---@type integer
local col = math.floor((vim.o.columns - width) / 2) ---@type integer

local wincfg = {
  zindex = 1000,
  relative = "editor",
  width = width,
  height = height,
  row = row,
  col = col,
  style = "minimal",
  border = "rounded",
  title_pos = "center",
  title = " file explorer ",
}
local winnr = vim.api.nvim_open_win(bufnr, true, wincfg) ---@type integer

eve.win.set_type(winnr, eve.win.Types.BOARD)
vim.w[winnr][eve.var.Names.WINLINE_DISABLED] = true

vim.wo[winnr].number = false
vim.wo[winnr].cursorline = true
vim.wo[winnr].relativenumber = false
vim.wo[winnr].signcolumn = "no"
vim.wo[winnr].spell = false
vim.wo[winnr].winfixbuf = true
vim.wo[winnr].wrap = false
vim.wo[winnr].winblend = 10
vim.wo[winnr].winhighlight = "Normal:FloatNormal,FloatBorder:FloatActiveBorder,CursorLine:CursorLine"
