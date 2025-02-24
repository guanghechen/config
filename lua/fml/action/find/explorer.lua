local env = require("eve.builtin.env")
local fn = require("eve.builtin.fn")
local fs = require("eve.builtin.fs")
local oxi = require("eve.builtin.oxi")
local path = require("eve.builtin.path")
local Observable = require("eve.collection.observable")
local Subscriber = require("eve.collection.subscriber")
local ft = require("eve.constant.filetype")
local icons = require("eve.constant.icon")
local editor = require("eve.module.editor")
local calc_fileicon = require("eve.module.fileicon").calc_fileicon
local state = require("eve.state")
local command = require("eve.command")

local Select = require("fml.ux.select")

---@class fml.action.find.explorer.IDirItem
---@field public items                  fml.action.find.explorer.IFileItem[]
---@field public icon_width             integer
---@field public name_width             integer
---@field public perm_width             integer
---@field public size_width             integer
---@field public date_width             integer
---@field public owner_width            integer
---@field public group_width            integer

---@class fml.action.find.explorer.IFileItem
---@field public type                   string
---@field public name                   string
---@field public path                   string
---@field public dir                    string
---@field public perm                   string
---@field public size                   string
---@field public owner                  string
---@field public group                  string
---@field public date                   string
---@field public icon                   string
---@field public icon_hl                string

local dir_datamap = {} ---@type table<string, fml.action.find.explorer.IDirItem>
local file_datamap = {} ---@type table<string, fml.action.find.explorer.IFileItem>

---@param dirpath                       string
---@param force                         boolean
---@return fml.action.find.explorer.IDirItem
local function fetch_diritem(dirpath, force)
  local diritem = (not force) and dir_datamap[dirpath] or nil ---@type fml.action.find.explorer.IDirItem|nil
  if diritem == nil then
    local items = {} ---@type fml.action.find.explorer.IFileItem[]
    local icon_width = 0 ---@type integer
    local name_width = 0 ---@type integer
    local perm_width = 0 ---@type integer
    local size_width = 0 ---@type integer
    local date_width = 0 ---@type integer
    local owner_width = 0 ---@type integer
    local group_width = 0 ---@type integer

    local raw_data = oxi.readdir(dirpath) ---@type eve.builtin.oxi.IReaddirResult|nil
    if raw_data ~= nil then
      local raw_itself = raw_data.itself ---@type eve.builtin.oxi.IFileItemWithStatus

      ---@type fml.action.find.explorer.IFileItem
      local itself = {
        type = raw_itself.type,
        name = raw_itself.name,
        path = dirpath,
        dir = dirpath,
        perm = raw_itself.perm,
        size = raw_itself.size,
        owner = raw_itself.owner,
        group = raw_itself.group,
        date = raw_itself.date,
        icon = icons.kind.Folder,
        icon_hl = "f_fe_name_dir",
      }
      file_datamap[dirpath] = itself

      for _, raw_item in ipairs(raw_data.items) do
        local filepath = dirpath .. "/" .. raw_item.name ---@type string
        local icon ---@type string
        local icon_hl ---@type string
        if raw_item.type == "directory" then
          icon = icons.kind.Folder
          icon_hl = "f_fe_name_dir"
        else
          icon, icon_hl = calc_fileicon(raw_item.name)
        end

        ---@type fml.action.find.explorer.IFileItem
        local item = {
          type = raw_item.type,
          name = raw_item.name,
          path = filepath,
          dir = dirpath,
          perm = raw_item.perm,
          size = raw_item.size,
          owner = raw_item.owner,
          group = raw_item.group,
          date = raw_item.date,
          icon = icon,
          icon_hl = icon_hl,
        }

        icon_width = math.max(icon_width, vim.api.nvim_strwidth(item.icon)) ---@type integer)
        name_width = math.max(name_width, vim.api.nvim_strwidth(item.name)) ---@type integer)
        perm_width = math.max(perm_width, vim.api.nvim_strwidth(item.perm)) ---@type integer)
        size_width = math.max(size_width, vim.api.nvim_strwidth(item.size)) ---@type integer)
        date_width = math.max(date_width, vim.api.nvim_strwidth(item.date)) ---@type integer)
        owner_width = math.max(owner_width, vim.api.nvim_strwidth(item.owner)) ---@type integer)
        group_width = math.max(group_width, vim.api.nvim_strwidth(item.group)) ---@type integer)

        table.insert(items, item)
        file_datamap[filepath] = item
      end
    end
    ---@type fml.action.find.explorer.IDirItem
    diritem = {
      items = items,
      icon_width = icon_width,
      name_width = name_width,
      perm_width = perm_width,
      size_width = size_width,
      date_width = date_width,
      owner_width = owner_width,
      group_width = group_width,
    }
    dir_datamap[dirpath] = diritem
  end
  return diritem
end

local initial_dirpath = vim.fn.expand("%:p:h") ---@type string
local state_cwd = Observable.from_value(vim.fs.normalize(initial_dirpath)) ---@type eve.collection.IObservable
local _select = nil ---@type fml.ux.ISelect|nil

---@return string
local function gen_title()
  local dirpath = state_cwd:snapshot() ---@type string
  local relative_dirpath = path.relative(path.cwd(), dirpath, false)
  if #relative_dirpath < 1 or relative_dirpath == "." then
    return "File explorer" ---@type string
  end

  dirpath = relative_dirpath:sub(1, 1) ~= "." and relative_dirpath or dirpath
  return "File explorer (from " .. dirpath .. ")" ---@type string
end

state_cwd:subscribe(
  Subscriber.new({
    on_next = function()
      if _select ~= nil then
        _select:mark_data_dirty()

        local title = gen_title() ---@type string
        _select:change_input_title(title)
      end
    end,
  }),
  true
)

---@return fml.ux.ISelect
local function get_select()
  if _select == nil then
    local frecency = state.frecency.files ---@type eve.collection.IFrecency
    local input_history = state.select.find_file.input_history ---@type eve.collection.IHistory

    local main_width = 0.4 ---@type number
    ---@type fml.ux.search.IRawDimension
    local dimension = {
      height = 0.8,
      max_height = 1,
      max_width = 1,
      width = main_width,
      width_preview = 0.45,
    }

    ---@type fml.ux.select.IProvider
    local provider = {
      fetch_data = function(force)
        local dirpath = vim.fs.normalize(state_cwd:snapshot()) ---@type string
        local parent_dirpath = vim.fs.dirname(dirpath) ---@type string
        local diritem = fetch_diritem(dirpath, force) ---@type fml.action.find.explorer.IDirItem
        fetch_diritem(parent_dirpath, force)

        ---@type fml.ux.select.IItem[]
        local items = {
          --- { group = nil, uuid = dirpath, text = "./" },
          { group = nil, uuid = parent_dirpath, text = "../" },
        }
        for _, fileitem in ipairs(diritem.items) do
          local filename = fileitem.type == "directory" and fileitem.name .. "/" or fileitem.name ---@type string
          local item = { group = nil, uuid = fileitem.path, text = filename } ---@type fml.ux.select.IItem
          table.insert(items, item)
        end

        ---@type fml.ux.select.IData
        return { items = items, uuid_cursor = #items > 1 and items[2].uuid or nil }
      end,
      fetch_preview_data = function(item)
        local fileitem = file_datamap[item.uuid] ---@type fml.action.find.explorer.IFileItem|nil
        if fileitem == nil then
          local lines = { "  Cannot found the file.  " } ---@type string[]
          local highlights = { { lnum = 1, coll = 0, colr = -1, hlname = "f_us_preview_error" } } ---@type eve.t.IHighlight[]

          ---@type fml.ux.search.preview.IData
          return { lines = lines, highlights = highlights, filetype = nil, title = item.text }
        end

        local dirpath = fileitem.dir ---@type string
        local diritem = dir_datamap[dirpath] ---@type fml.action.find.explorer.IDirItem|nil
        if diritem == nil then
          local lines = { "  Cannot found the parent directory.  " } ---@type string[]
          local highlights = { { lnum = 1, coll = 0, colr = -1, hlname = "f_us_preview_error" } } ---@type eve.t.IHighlight[]

          ---@type fml.ux.search.preview.IData
          return { lines = lines, highlights = highlights, filetype = nil, title = item.text }
        end

        if fileitem.type == "file" then
          local is_text_file = ft.is_printable_file(fileitem.name) ---@type boolean
          if is_text_file then
            local filetype = vim.filetype.match({ filename = fileitem.name }) ---@type string|nil
            local lines = fs.read_file_as_lines({ filepath = fileitem.path, max_lines = 300, silent = true }) ---@type string[]
            local title = path.relative(path.cwd(), item.uuid, false) ---@type string

            ---@type fml.ux.search.preview.IData
            return {
              lines = lines,
              highlights = {},
              filetype = filetype,
              title = title,
              lnum = 1,
              col = 0,
            }
          end
        elseif fileitem.type == "directory" then
          local lines = {} ---@type string[]
          local highlights = {} ---@type eve.t.IHighlight[]
          local c_diritem = fetch_diritem(fileitem.path, false) ---@type fml.action.find.explorer.IDirItem
          for lnum, c_fileitem in ipairs(c_diritem.items) do
            local width = 0 ---@type integer
            local text = "" ---@type string

            local sep_perm = string.rep(" ", 2) ---@type string
            local text_perm = fn.pad_start(c_fileitem.perm, c_diritem.perm_width, " ") .. sep_perm
            local width_perm = string.len(text_perm) ---@type integer
            table.insert(highlights, {
              lnum = lnum,
              coll = width,
              colr = width + 1,
              hlname = c_fileitem.type == "directory" and "f_fe_perm_dir" or "f_fe_perm_file",
            })
            table.insert(highlights, { lnum = lnum, coll = width + 1, colr = width + width_perm, hlname = "f_fe_perm" })
            text = text .. text_perm
            width = width + width_perm

            local sep_size = string.rep(" ", 2) ---@type string
            local text_size = fn.pad_start(c_fileitem.size, c_diritem.size_width, " ") .. sep_size
            local width_size = string.len(text_size) ---@type integer
            table.insert(highlights, { lnum = lnum, coll = width, colr = width + width_size, hlname = "f_fe_size" })
            text = text .. text_size
            width = width + width_size

            if not env.IS_WIN then
              local sep_owner = string.rep(" ", 1) ---@type string
              local text_owner = fn.pad_start(c_fileitem.owner, c_diritem.owner_width, " ") .. sep_owner
              local width_owner = string.len(text_owner) ---@type integer
              table.insert(highlights, { lnum = lnum, coll = width, colr = width + width_owner, hlname = "f_fe_owner" })
              text = text .. text_owner
              width = width + width_owner

              local sep_group = string.rep(" ", 2) ---@type string
              local text_group = fn.pad_end(c_fileitem.group, c_diritem.group_width, " ") .. sep_group
              local width_group = string.len(text_group) ---@type integer
              table.insert(highlights, { lnum = lnum, coll = width, colr = width + width_group, hlname = "f_fe_group" })
              text = text .. text_group
              width = width + width_group
            end

            local sep_date = string.rep(" ", 2) ---@type string
            local text_date = fn.pad_end(c_fileitem.date, c_diritem.date_width, " ") .. sep_date
            local width_date = string.len(text_date) ---@type integer
            table.insert(highlights, { lnum = lnum, coll = width, colr = width + width_date, hlname = "f_fe_date" })
            text = text .. text_date
            width = width + width_date

            local sep_name = string.rep(" ", 10) ---@type string
            local text_name = fn.pad_end(c_fileitem.name, c_diritem.name_width, " ") .. sep_name
            local width_name = string.len(text_name) ---@type integer
            table.insert(highlights, {
              lnum = lnum,
              coll = width,
              colr = width + width_name,
              hlname = c_fileitem.type == "directory" and "f_fe_name_dir" or "f_fe_name_file",
            })
            text = text .. text_name
            width = width + width_name

            table.insert(lines, text)
          end

          local title = path.relative(path.cwd(), item.uuid, false) ---@type string
          if #title < 1 or title:sub(1, 1) == "." then
            title = vim.fs.normalize(item.uuid)
          end

          ---@type fml.ux.search.preview.IData
          return { lines = lines, highlights = highlights, filetype = nil, title = title }
        end

        local lines = { "  Not a text file, cannot preview." } ---@type string[]
        local highlights = { { lnum = 1, coll = 0, colr = -1, hlname = "f_us_preview_error" } } ---@type eve.t.IHighlight[]

        ---@type fml.ux.search.preview.IData
        return { lines = lines, highlights = highlights, filetype = nil, title = item.text, lnum = 1, col = 0 }
      end,
      render_item = function(item, match)
        local fileitem = file_datamap[item.uuid] ---@type fml.action.find.explorer.IFileItem|nil
        if fileitem == nil then
          return item.text, {}
        end

        local dirpath = state_cwd:snapshot() ---@type string
        local diritem = dir_datamap[dirpath] ---@type fml.action.find.explorer.IDirItem|nil
        if diritem == nil then
          return item.text, {}
        end

        local highlights = {} ---@type eve.t.IHighlightInline[]
        local width = 0 ---@type integer
        local text = "" ---@type string
        local filename = ((item.text == "../") or (item.text == "./")) and item.text
          or fileitem.type == "directory" and fileitem.name .. "/"
          or fileitem.name ---@type string

        local max_width = math.floor(main_width * vim.o.columns) - 1 ---@type integer
        ---@type integer
        local filename_sep_width = max_width
          - (diritem.icon_width + 2)
          - (diritem.name_width + 1)
          - (diritem.perm_width + 2)
          - (diritem.size_width + 2)
          - (diritem.date_width + 2)

        local sep_icon = string.rep(" ", 2) ---@type string
        local text_icon = fn.pad_start(fileitem.icon, diritem.icon_width, " ") .. sep_icon ---@type string
        local width_icon = string.len(text_icon) ---@type integer
        table.insert(highlights, { coll = width, colr = width + width_icon, hlname = fileitem.icon_hl })
        text = text .. text_icon
        width = width + width_icon

        local sep_name = string.rep(" ", filename_sep_width) ---@type string
        local text_name = fn.pad_end(filename, diritem.name_width + 1, " ") .. sep_name ---@type string
        local width_name = string.len(text_name) ---@type integer
        table.insert(highlights, {
          coll = width,
          colr = width + width_name,
          hlname = fileitem.type == "directory" and "f_fe_name_dir" or "f_fe_name_file",
        })
        for _, piece in ipairs(match.matches) do
          ---@type eve.t.IHighlightInline
          local highlight = { coll = width + piece.l, colr = width + piece.r, hlname = "f_fe_match" }
          table.insert(highlights, highlight)
        end
        text = text .. text_name
        width = width + width_name

        local sep_perm = string.rep(" ", 2) ---@type string
        local text_perm = fn.pad_start(fileitem.perm, diritem.perm_width, " ") .. sep_perm ---@type string
        local width_perm = string.len(text_perm) ---@type integer
        table.insert(highlights, {
          coll = width,
          colr = width + 1,
          hlname = fileitem.type == "directory" and "f_fe_perm_dir" or "f_fe_perm_file",
        })
        table.insert(highlights, { coll = width + 1, colr = width + width_perm, hlname = "f_fe_perm" })
        text = text .. text_perm
        width = width + width_perm

        local sep_size = string.rep(" ", 2) ---@type string
        local text_size = fn.pad_start(fileitem.size, diritem.size_width, " ") .. sep_size ---@type string
        local width_size = string.len(text_size) ---@type integer
        table.insert(highlights, { coll = width, colr = width + width_size, hlname = "f_fe_size" })
        text = text .. text_size
        width = width + width_size

        local sep_date = string.rep(" ", 2) ---@type string
        local text_date = fn.pad_end(fileitem.date, diritem.date_width, " ") .. sep_date ---@type string
        local width_date = string.len(text_date) ---@type integer
        table.insert(highlights, { coll = width, colr = width + width_date, hlname = "f_fe_date" })
        text = text .. text_date
        width = width + width_date

        return text, highlights
      end,
    }

    ---@type eve.t.IKeymap[]
    local common_keymaps = {
      {
        modes = { "n", "v" },
        key = "<Backspace>",
        callback = function()
          local next_cwd = vim.fs.dirname(state_cwd:snapshot())
          state_cwd:next(next_cwd)
        end,
        desc = "file explorer: goto the parent dir",
      },
    }

    ---@type eve.t.IKeymap[]
    local input_keymaps = vim.list_slice(common_keymaps)

    ---@type eve.t.IKeymap[]
    local main_keymaps = vim.list_slice(common_keymaps)

    ---@type eve.t.IKeymap[]
    local preview_keymaps = vim.list_slice(common_keymaps)

    _select = Select.new({
      dimension = dimension,
      dirty_on_invisible = true,
      preview_enabled = true,
      extend_preset_keymaps = true,
      frecency = frecency,
      input_history = input_history,
      input_keymaps = input_keymaps,
      main_keymaps = main_keymaps,
      multiple = true,
      permanent = true,
      preview_keymaps = preview_keymaps,
      provider = provider,
      title = gen_title(),
      on_confirm = function(widget, items)
        local filepaths = {} ---@type string[]
        for _, item in ipairs(items) do
          local fileitem = file_datamap[item.uuid] ---@type fml.action.find.explorer.IFileItem|nil
          if fileitem ~= nil and fileitem.type == "file" then
            table.insert(filepaths, fileitem.path)
          end
        end

        if #filepaths > 0 then
          widget:hide()
          local winnr_source = command.context_winnr() ---@type integer|nil
          for _, filepath in ipairs(filepaths) do
            editor.open_filepath(winnr_source, filepath)
          end
          return
        end

        if #items == 1 then
          local item = items[1] ---@type fml.ux.select.IItem
          local fileitem = file_datamap[item.uuid] ---@type fml.action.find.explorer.IFileItem|nil
          if fileitem ~= nil and fileitem.type == "directory" then
            local dirpath = fileitem.path ---@type string
            state_cwd:next(dirpath)
            return
          end
        end
      end,
    })
  end

  return _select
end

---@class fml.action.find
local M = {}

---@param context                       eve.command.IContext
---@return nil
function M.find_explorer(context)
  local winnr = context.winnr ---@type integer
  if winnr ~= nil and winnr > 0 and vim.api.nvim_win_is_valid(winnr) then
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
    if #filepath > 0 then
      local doctype = fs.is_file_or_dir(filepath) ---@type eve.e.FileType|nil
      local dirpath = doctype == "file" and vim.fs.dirname(filepath) or filepath ---@type string
      state_cwd:next(dirpath)
    end
  end

  local select = get_select() ---@type fml.ux.ISelect
  select:show()
end

return M
