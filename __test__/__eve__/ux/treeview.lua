---@class __test__.ux.treeview.IData
---@field public uuid                   string
---@field public filetype               string
---@field public basename               string

local filepaths = vim.split(vim.trim(vim.fn.system("fd '.lua' lua/ ")), "\n", { plain = true }) ---@type string[]

local treeview = eve.ux.view.Treeview.new({
  name = "file treeview",
  keymaps = {
    {
      modes = { "n" },
      key = "q",
      callback = function(bufnr)
        vim.cmd.close()
        pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
      end,
      desc = "quit",
    },
    {
      modes = { "n" },
      key = "z",
      callback = function(bufnr, lnum, treeview)
        local node = treeview:retrieve_by_lnum(lnum, true) ---@type eve.ux.view.treeview.INode|nil
        if node ~= nil and node.type == "container" then
          treeview:collapse(node.uuid, "toggle", true):render(bufnr)
        end
      end,
    },
    {
      modes = { "i", "n", "v" },
      key = "<CR>",
      aliases = { "<Left>", "<Right>", "h", "l", "o" },
      callback = function(bufnr, lnum, treeview)
        local node = treeview:retrieve_by_lnum(lnum, false) ---@type eve.ux.view.treeview.INode|nil
        if node == nil then
          return
        end

        if node.type == "container" then
          treeview:collapse(node.uuid, "toggle", false):render(bufnr)
          return
        end

        local data = node.data ---@type __test__.ux.treeview.IData
        eve.debug.log("click on filepath: %s", data)
      end,
      desc = "open file",
    },
  },
  ---@param node                        eve.ux.view.treeview.INode
  ---@return string
  ---@return eve.t.IHighlightInline[]|nil
  renderer = function(node)
    local data = node.data ---@type __test__.ux.treeview.IData
    if node.type == "container" then
      if node.collapsed then
        return string.format("%s %s", eve.icon.filetype.Folder, data.basename)
      end
      return string.format("%s %s", eve.icon.filetype.FolderOpen, data.basename)
    end

    local fileicon = eve.fn.fileicon(data.basename)
    return string.format("%s %s", fileicon, data.basename)
  end,
  ---@param left                        __test__.ux.treeview.IData
  ---@param right                       __test__.ux.treeview.IData
  ---@return boolean
  sorter = function(left, right)
    return left.basename < right.basename
  end,
})

for _, filepath in ipairs(filepaths) do
  local pieces = eve.path.split(filepath) ---@type string[]
  local parent_uuid = nil ---@type string
  local uuid = "" ---@type string
  for index = 1, #pieces - 1, 1 do
    local filetype = "directory" ---@type string
    local basename = pieces[index] ---@type string
    uuid = index == 1 and pieces[1] or (uuid .. eve.env.PATH_SEP .. basename) ---@type string

    if not treeview:has(uuid) then
      ---@type __test__.ux.treeview.IData
      local data = {
        uuid = uuid,
        filetype = filetype,
        basename = basename,
      }
      treeview:insert_container(uuid, parent_uuid or uuid, data, false)
    end
    parent_uuid = uuid
  end

  local filetype = "lua" ---@type string
  local filename = pieces[#pieces] ---@type string
  uuid = uuid .. eve.env.PATH_SEP .. filename ---@type string
  ---@type __test__.ux.treeview.IData
  local data = {
    uuid = uuid,
    filetype = filetype,
    basename = filename,
  }
  treeview:insert_leaf(uuid, parent_uuid, data)
end

local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
vim.bo[bufnr].bufhidden = "wipe"
vim.bo[bufnr].buflisted = false
vim.bo[bufnr].buftype = "nofile"
vim.bo[bufnr].filetype = "treeview"
vim.bo[bufnr].swapfile = false
vim.b[bufnr].miniindentscope_disable = true

treeview
  --
  :bindkeys({ bufnr = bufnr, silent = true, noremap = true, nowait = true })
  :render(bufnr)
local max_height, max_width = treeview:measure() ---@type integer, integer
local height = math.min(40, vim.o.lines - 8, max_height + 1) ---@type integer
local width = math.min(100, vim.o.columns - 20, max_width + 2) ---@type integer
local row = 3 ---@type integer
local col = math.floor((vim.o.columns - width) / 2) ---@type integer

local wincfg = {
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
vim.wo[winnr].relativenumber = false
vim.wo[winnr].signcolumn = "no"
vim.wo[winnr].spell = false
vim.wo[winnr].winfixbuf = true
vim.wo[winnr].wrap = false
