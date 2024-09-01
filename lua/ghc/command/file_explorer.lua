---@class ghc.command.file_explorer.IDirItem
---@field public items                  ghc.command.file_explorer.IFileItem[]
---@field public icon_width             integer
---@field public name_width             integer
---@field public perm_width             integer
---@field public size_width             integer
---@field public date_width             integer
---@field public owner_width            integer
---@field public group_width            integer

---@class ghc.command.file_explorer.IFileItem
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

local dir_datamap = {} ---@type table<string, ghc.command.file_explorer.IDirItem>
local file_datamap = {} ---@type table<string, ghc.command.file_explorer.IFileItem>

---@param dirpath                       string
---@param force                         boolean
---@return ghc.command.file_explorer.IDirItem
local function fetch_diritem(dirpath, force)
  local diritem = (not force) and dir_datamap[dirpath] or nil ---@type ghc.command.file_explorer.IDirItem|nil
  if diritem == nil then
    local items = {} ---@type ghc.command.file_explorer.IFileItem[]
    local icon_width = 0 ---@type integer
    local name_width = 0 ---@type integer
    local perm_width = 0 ---@type integer
    local size_width = 0 ---@type integer
    local date_width = 0 ---@type integer
    local owner_width = 0 ---@type integer
    local group_width = 0 ---@type integer

    local raw_data = fml.oxi.readdir(dirpath) ---@type fml.std.oxi.IReaddirResult|nil
    if raw_data ~= nil then
      local raw_itself = raw_data.itself ---@type fml.std.oxi.IFileItemWithStatus

      ---@type ghc.command.file_explorer.IFileItem
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
        icon = fml.ui.icons.kind.Folder,
        icon_hl = "f_fe_name_dir",
      }
      file_datamap[dirpath] = itself

      for _, raw_item in ipairs(raw_data.items) do
        local filepath = dirpath .. "/" .. raw_item.name ---@type string
        local icon ---@type string
        local icon_hl ---@type string
        if raw_item.type == "directory" then
          icon = fml.ui.icons.kind.Folder
          icon_hl = "f_fe_name_dir"
        else
          icon, icon_hl = fml.util.calc_fileicon(raw_item.name)
        end

        ---@type ghc.command.file_explorer.IFileItem
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

        icon_width = math.max(icon_width, vim.fn.strwidth(item.icon)) ---@type integer)
        name_width = math.max(name_width, vim.fn.strwidth(item.name)) ---@type integer)
        perm_width = math.max(perm_width, vim.fn.strwidth(item.perm)) ---@type integer)
        size_width = math.max(size_width, vim.fn.strwidth(item.size)) ---@type integer)
        date_width = math.max(date_width, vim.fn.strwidth(item.date)) ---@type integer)
        owner_width = math.max(owner_width, vim.fn.strwidth(item.owner)) ---@type integer)
        group_width = math.max(group_width, vim.fn.strwidth(item.group)) ---@type integer)

        table.insert(items, item)
        file_datamap[filepath] = item
      end
    end
    ---@type ghc.command.file_explorer.IDirItem
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
local state_cwd = fc.c.Observable.from_value(fc.path.normalize(initial_dirpath)) ---@type fc.types.collection.IObservable
local _select = nil ---@type fml.types.ui.ISelect|nil

---@return string
local function gen_title()
  local dirpath = state_cwd:snapshot() ---@type string
  local relative_dirpath = fc.path.relative(fc.path.cwd(), dirpath, false)
  if #relative_dirpath < 1 or relative_dirpath == "." then
    return "File explorer" ---@type string
  end

  dirpath = relative_dirpath:sub(1, 1) ~= "." and relative_dirpath or dirpath
  return "File explorer (from " .. dirpath .. ")" ---@type string
end

fml.fn.watch_observables({
  state_cwd,
}, function()
  if _select ~= nil then
    _select:mark_data_dirty()

    local title = gen_title() ---@type string
    _select:change_input_title(title)
  end
end, true)

---@return fml.types.ui.ISelect
local function get_select()
  if _select == nil then
    local state_frecency = require("ghc.state.frecency")
    local state_input_history = require("ghc.state.input_history")
    local frecency = state_frecency.load_and_autosave().files ---@type fc.types.collection.IFrecency
    local input_history = state_input_history.load_and_autosave().find_files ---@type fc.types.collection.IHistory

    local main_width = 0.4 ---@type number
    ---@type fml.types.ui.search.IRawDimension
    local dimension = {
      height = 0.8,
      max_height = 1,
      max_width = 1,
      width = main_width,
      width_preview = 0.45,
    }

    ---@type fml.types.ui.select.IProvider
    local provider = {
      fetch_data = function(force)
        local dirpath = fc.path.normalize(state_cwd:snapshot()) ---@type string
        local parent_dirpath = fc.path.dirname(dirpath) ---@type string
        local diritem = fetch_diritem(dirpath, force) ---@type ghc.command.file_explorer.IDirItem
        fetch_diritem(parent_dirpath, force)

        ---@type fml.types.ui.select.IItem[]
        local items = {
          --- { group = nil, uuid = dirpath, text = "./" },
          { group = nil, uuid = parent_dirpath, text = "../" },
        }
        for _, fileitem in ipairs(diritem.items) do
          local filename = fileitem.type == "directory" and fileitem.name .. "/" or fileitem.name ---@type string
          local item = { group = nil, uuid = fileitem.path, text = filename } ---@type fml.types.ui.select.IItem
          table.insert(items, item)
        end

        ---@type fml.types.ui.select.IData
        return { items = items, cursor_uuid = #items > 1 and items[2].uuid or nil }
      end,
      fetch_preview_data = function(item)
        local fileitem = file_datamap[item.uuid] ---@type ghc.command.file_explorer.IFileItem|nil
        if fileitem == nil then
          local lines = { "  Cannot found the file.  " } ---@type string[]
          local highlights = { { lnum = 1, coll = 0, colr = -1, hlname = "f_us_preview_error" } } ---@type fml.types.ui.IHighlight[]

          ---@type fml.ui.search.preview.IData
          return { lines = lines, highlights = highlights, filetype = nil, title = item.text }
        end

        local dirpath = fileitem.dir ---@type string
        local diritem = dir_datamap[dirpath] ---@type ghc.command.file_explorer.IDirItem|nil
        if diritem == nil then
          local lines = { "  Cannot found the parent directory.  " } ---@type string[]
          local highlights = { { lnum = 1, coll = 0, colr = -1, hlname = "f_us_preview_error" } } ---@type fml.types.ui.IHighlight[]

          ---@type fml.ui.search.preview.IData
          return { lines = lines, highlights = highlights, filetype = nil, title = item.text }
        end

        if fileitem.type == "file" then
          local is_text_file = fc.is.printable_file(fileitem.name) ---@type boolean
          if is_text_file then
            local filetype = vim.filetype.match({ filename = fileitem.name }) ---@type string|nil
            local lines = fc.fs.read_file_as_lines({ filepath = fileitem.path, max_lines = 300, silent = true }) ---@type string[]
            local title = fc.path.relative(fc.path.cwd(), item.uuid, false) ---@type string

            ---@type fml.ui.search.preview.IData
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
          local highlights = {} ---@type fml.types.ui.IHighlight[]
          local c_diritem = fetch_diritem(fileitem.path, false) ---@type ghc.command.file_explorer.IDirItem
          for lnum, c_fileitem in ipairs(c_diritem.items) do
            local width = 0 ---@type integer
            local text = "" ---@type string

            local sep_perm = string.rep(" ", 2) ---@type string
            local text_perm = fc.string.pad_start(c_fileitem.perm, c_diritem.perm_width, " ") .. sep_perm
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
            local text_size = fc.string.pad_start(c_fileitem.size, c_diritem.size_width, " ") .. sep_size
            local width_size = string.len(text_size) ---@type integer
            table.insert(highlights, { lnum = lnum, coll = width, colr = width + width_size, hlname = "f_fe_size" })
            text = text .. text_size
            width = width + width_size

            if not fc.os.is_win() then
              local sep_owner = string.rep(" ", 1) ---@type string
              local text_owner = fc.string.pad_start(c_fileitem.owner, c_diritem.owner_width, " ") .. sep_owner
              local width_owner = string.len(text_owner) ---@type integer
              table.insert(highlights, { lnum = lnum, coll = width, colr = width + width_owner, hlname = "f_fe_owner" })
              text = text .. text_owner
              width = width + width_owner

              local sep_group = string.rep(" ", 2) ---@type string
              local text_group = fc.string.pad_end(c_fileitem.group, c_diritem.group_width, " ") .. sep_group
              local width_group = string.len(text_group) ---@type integer
              table.insert(highlights, { lnum = lnum, coll = width, colr = width + width_group, hlname = "f_fe_group" })
              text = text .. text_group
              width = width + width_group
            end

            local sep_date = string.rep(" ", 2) ---@type string
            local text_date = fc.string.pad_end(c_fileitem.date, c_diritem.date_width, " ") .. sep_date
            local width_date = string.len(text_date) ---@type integer
            table.insert(highlights, { lnum = lnum, coll = width, colr = width + width_date, hlname = "f_fe_date" })
            text = text .. text_date
            width = width + width_date

            local sep_name = string.rep(" ", 10) ---@type string
            local text_name = fc.string.pad_end(c_fileitem.name, c_diritem.name_width, " ") .. sep_name
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

          local title = fc.path.relative(fc.path.cwd(), item.uuid, false) ---@type string
          if #title < 1 or title:sub(1, 1) == "." then
            title = fc.path.normalize(item.uuid)
          end

          ---@type fml.ui.search.preview.IData
          return { lines = lines, highlights = highlights, filetype = nil, title = title }
        end

        local lines = { "  Not a text file, cannot preview." } ---@type string[]
        local highlights = { { lnum = 1, coll = 0, colr = -1, hlname = "f_us_preview_error" } } ---@type fml.types.ui.IHighlight[]

        ---@type fml.ui.search.preview.IData
        return { lines = lines, highlights = highlights, filetype = nil, title = item.text, lnum = 1, col = 0 }
      end,
      render_item = function(item, match)
        local fileitem = file_datamap[item.uuid] ---@type ghc.command.file_explorer.IFileItem|nil
        if fileitem == nil then
          return item.text, {}
        end

        local dirpath = state_cwd:snapshot() ---@type string
        local diritem = dir_datamap[dirpath] ---@type ghc.command.file_explorer.IDirItem|nil
        if diritem == nil then
          return item.text, {}
        end

        local highlights = {} ---@type fml.types.ui.IInlineHighlight[]
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
        local text_icon = fc.string.pad_start(fileitem.icon, diritem.icon_width, " ") .. sep_icon ---@type string
        local width_icon = string.len(text_icon) ---@type integer
        table.insert(highlights, { coll = width, colr = width + width_icon, hlname = fileitem.icon_hl })
        text = text .. text_icon
        width = width + width_icon

        local sep_name = string.rep(" ", filename_sep_width) ---@type string
        local text_name = fc.string.pad_end(filename, diritem.name_width + 1, " ") .. sep_name ---@type string
        local width_name = string.len(text_name) ---@type integer
        table.insert(highlights, {
          coll = width,
          colr = width + width_name,
          hlname = fileitem.type == "directory" and "f_fe_name_dir" or "f_fe_name_file",
        })
        for _, piece in ipairs(match.matches) do
          ---@type fml.types.ui.IInlineHighlight
          local highlight = { coll = width + piece.l, colr = width + piece.r, hlname = "f_fe_match" }
          table.insert(highlights, highlight)
        end
        text = text .. text_name
        width = width + width_name

        local sep_perm = string.rep(" ", 2) ---@type string
        local text_perm = fc.string.pad_start(fileitem.perm, diritem.perm_width, " ") .. sep_perm ---@type string
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
        local text_size = fc.string.pad_start(fileitem.size, diritem.size_width, " ") .. sep_size ---@type string
        local width_size = string.len(text_size) ---@type integer
        table.insert(highlights, { coll = width, colr = width + width_size, hlname = "f_fe_size" })
        text = text .. text_size
        width = width + width_size

        local sep_date = string.rep(" ", 2) ---@type string
        local text_date = fc.string.pad_end(fileitem.date, diritem.date_width, " ") .. sep_date ---@type string
        local width_date = string.len(text_date) ---@type integer
        table.insert(highlights, { coll = width, colr = width + width_date, hlname = "f_fe_date" })
        text = text .. text_date
        width = width + width_date

        return text, highlights
      end,
    }

    ---@type fml.types.IKeymap[]
    local common_keymaps = {
      {
        modes = { "n", "v" },
        key = "<Backspace>",
        callback = function()
          local next_cwd = fc.path.dirname(state_cwd:snapshot())
          state_cwd:next(next_cwd)
        end,
        desc = "file explorer: goto the parent dir",
      },
    }

    ---@type fml.types.IKeymap[]
    local input_keymaps = fc.array.concat({}, common_keymaps)

    ---@type fml.types.IKeymap[]
    local main_keymaps = fc.array.concat({}, common_keymaps)

    ---@type fml.types.IKeymap[]
    local preview_keymaps = fc.array.concat({}, common_keymaps)

    _select = fml.ui.Select.new({
      destroy_on_close = false,
      dimension = dimension,
      dirty_on_close = true,
      enable_preview = true,
      extend_preset_keymaps = true,
      frecency = frecency,
      input_history = input_history,
      input_keymaps = input_keymaps,
      main_keymaps = main_keymaps,
      preview_keymaps = preview_keymaps,
      provider = provider,
      title = gen_title(),
      on_confirm = function(item)
        local fileitem = file_datamap[item.uuid] ---@type ghc.command.file_explorer.IFileItem|nil
        if fileitem == nil then
          return false
        end

        if fileitem.type == "directory" then
          local dirpath = fileitem.path ---@type string
          state_cwd:next(dirpath)
          return false
        end

        if fileitem.type == "file" then
          return fml.api.buf.open_in_current_valid_win(fileitem.path)
        end

        return false
      end,
    })
  end

  return _select
end

---@class ghc.command.find_explorer
local M = {}

---@return nil
function M.open()
  local win_detail = fml.api.win.get_cur_win_details_if_valid() ---@type fml.api.win.IDetails|nil
  if win_detail ~= nil and win_detail.dirpath ~= nil then
    state_cwd:next(win_detail.dirpath)
  end

  local select = get_select() ---@type fml.types.ui.ISelect
  select:open()
end

return M
