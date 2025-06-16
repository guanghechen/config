local __module_name__ = "fml.action.find.explorer" ---@type string

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

---@class fml.action.find.explorer.IItemData
---@field public fileitem               fml.action.find.explorer.IFileItem

---@class fml.action.find.explorer.IItem : eve.ux.picker.composer.list.IItem
---@field public data                   fml.action.find.explorer.IItemData

local dir_datamap = {} ---@type table<string, fml.action.find.explorer.IDirItem>
local file_datamap = {} ---@type table<string, fml.action.find.explorer.IFileItem>

---@param filepath                      string
local function add_to_avante(filepath)
  local sidebar = require("avante").get()
  if not sidebar then
    return
  end

  -- ensure avante sidebar is open
  if not sidebar:is_open() then
    require("avante.api").ask()
    sidebar = require("avante").get()
  end

  local relative_path = require("avante.utils").relative_path(filepath)
  sidebar.file_selector:add_selected_file(relative_path)
  sidebar.file_selector:remove_selected_file("neo-tree filesystem [1]")
  sidebar.file_selector:remove_selected_file("untitled-1")
end

---@param raw_item                      eve.builtin.oxi.IFileItemWithStatus
---@param dirpath                       string
---@return fml.action.find.explorer.IFileItem
local function create_file_item(raw_item, dirpath)
  local filepath = dirpath .. "/" .. raw_item.name ---@type string
  local icon, icon_hl ---@type string, string

  if raw_item.type == "directory" then
    icon = eve.icon.kind.Folder
    icon_hl = "f_fe_name_dir"
  else
    icon, icon_hl = std.fileicon.get_file_icon(raw_item.name)
  end

  ---@type fml.action.find.explorer.IFileItem
  return {
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
end

---@param items                         fml.action.find.explorer.IFileItem[]
---@return fml.action.find.explorer.IDirItem
local function calculate_widths(items)
  ---@type table<string, integer>
  local widths = {
    icon_width = 0,
    name_width = 0,
    perm_width = 0,
    size_width = 0,
    date_width = 0,
    owner_width = 0,
    group_width = 0,
  }

  for _, item in ipairs(items) do
    for field, prop in pairs({
      icon_width = "icon",
      name_width = "name",
      perm_width = "perm",
      size_width = "size",
      date_width = "date",
      owner_width = "owner",
      group_width = "group",
    }) do
      widths[field] = math.max(widths[field], vim.api.nvim_strwidth(item[prop]))
    end
  end

  return vim.tbl_extend("force", { items = items }, widths) ---@type fml.action.find.explorer.IDirItem
end

---@param fileitem                      fml.action.find.explorer.IFileItem
---@param diritem                       fml.action.find.explorer.IDirItem
---@param result_width                  integer
---@param filename                      string
---@return string, integer
local function format_filename(fileitem, diritem, result_width, filename)
  local date_display_width = vim.api.nvim_strwidth(fileitem.date) ---@type integer
  local fixed_display_width = (diritem.icon_width + 2)
    + (diritem.perm_width + 2)
    + (diritem.size_width + 2)
    + (date_display_width + 4) ---@type integer
  local filename_max_display_width = result_width - fixed_display_width ---@type integer

  local filename_display_width = vim.api.nvim_strwidth(filename) ---@type integer
  ---@type string
  local display_filename = filename_display_width > filename_max_display_width
      and string.sub(filename, 1, math.max(1, filename_max_display_width - 3)) .. "..."
    or filename
  local actual_filename_display_width = vim.api.nvim_strwidth(display_filename) ---@type integer
  local filename_padding = math.max(1, filename_max_display_width - actual_filename_display_width) ---@type integer

  return display_filename .. string.rep(" ", filename_padding), filename_max_display_width
end

---@param bufnr                         integer
---@param row                           integer
---@param byte_pos                      integer
---@param text_part                     string
---@param highlight_name                string
---@return integer
local function apply_highlight(bufnr, row, byte_pos, text_part, highlight_name)
  local nsnr_content = eve.var.nsnr.picker_result ---@type integer
  local byte_len = string.len(text_part) ---@type integer
  vim.hl.range(bufnr, nsnr_content, highlight_name, { row, byte_pos }, { row, byte_pos + byte_len }, { priority = 10 })
  return byte_pos + byte_len
end

---@param bufnr                         integer
---@param match                         table
---@param row                           integer
---@param byte_pos                      integer
---@param display_filename              string
---@param filename_max_display_width    integer
---@param filename                      string
local function apply_match_highlights(
  bufnr,
  match,
  row,
  byte_pos,
  display_filename,
  filename_max_display_width,
  filename
)
  if not match.matches then
    return
  end

  local nsnr_matches = eve.var.nsnr.picker_matches ---@type integer
  local filename_display_width = vim.api.nvim_strwidth(filename) ---@type integer
  local was_truncated = filename_display_width > filename_max_display_width
  local display_filename_byte_len = string.len(display_filename) ---@type integer

  for _, m in ipairs(match.matches) do
    if not was_truncated or (m.l < display_filename_byte_len and m.r <= display_filename_byte_len) then
      local match_start = math.max(0, m.l) ---@type integer
      local match_end = was_truncated and math.min(m.r, display_filename_byte_len) or m.r ---@type integer
      if match_start < match_end then
        vim.hl.range(
          bufnr,
          nsnr_matches,
          "f_pk_matches",
          { row, byte_pos + match_start },
          { row, byte_pos + match_end },
          { priority = 30 }
        )
      end
    end
  end
end

---@param bufnr                         integer
---@param itemmap                       table<string, fml.action.find.explorer.IItem>
---@param matches                       table[]
---@param diritem                       fml.action.find.explorer.IDirItem
---@param result_width                  integer
---@return table
local function render_file_list(bufnr, itemmap, matches, diritem, result_width)
  local lines = {} ---@type string[]
  local uuids = {} ---@type string[]

  -- Generate lines
  for _, match in ipairs(matches) do
    local item = itemmap[match.uuid] ---@type fml.action.find.explorer.IItem
    local fileitem = item.data.fileitem ---@type fml.action.find.explorer.IFileItem
    local filename = item.text ---@type string

    local text_icon = std.string.pad_start(fileitem.icon, diritem.icon_width, " ") .. "  " ---@type string
    local text_name, _ = format_filename(fileitem, diritem, result_width, filename)
    local text_perm = std.string.pad_start(fileitem.perm, diritem.perm_width, " ") .. "  " ---@type string
    local text_size = std.string.pad_start(fileitem.size, diritem.size_width, " ") .. "  " ---@type string
    local text_date = fileitem.date .. "  " ---@type string

    lines[#lines + 1] = text_icon .. text_name .. text_perm .. text_size .. text_date
    uuids[#uuids + 1] = item.uuid
  end

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  -- Apply highlights
  for lnum, match in ipairs(matches) do
    local row = lnum - 1 ---@type integer
    local item = itemmap[match.uuid] ---@type fml.action.find.explorer.IItem
    local fileitem = item.data.fileitem ---@type fml.action.find.explorer.IFileItem
    local filename = item.text ---@type string
    local byte_pos = 0 ---@type integer

    -- Icon highlight
    local text_icon = std.string.pad_start(fileitem.icon, diritem.icon_width, " ") .. "  " ---@type string
    byte_pos = apply_highlight(bufnr, row, byte_pos, text_icon, fileitem.icon_hl)

    -- Filename highlight
    local display_filename, filename_max_display_width = format_filename(fileitem, diritem, result_width, filename)
    ---@type string
    local text_name = display_filename
      .. string.rep(" ", math.max(1, filename_max_display_width - vim.api.nvim_strwidth(display_filename)))
    local filename_hl = fileitem.type == "directory" and "f_fe_name_dir" or "f_fe_name_file" ---@type string
    byte_pos = apply_highlight(bufnr, row, byte_pos, text_name, filename_hl)

    -- Match highlights
    apply_match_highlights(
      bufnr,
      match,
      row,
      byte_pos - string.len(text_name),
      display_filename,
      filename_max_display_width,
      filename
    )

    -- Permission highlight
    local text_perm = std.string.pad_start(fileitem.perm, diritem.perm_width, " ") .. "  " ---@type string
    local perm_hl = fileitem.type == "directory" and "f_fe_perm_dir" or "f_fe_perm_file" ---@type string
    local nsnr_content = eve.var.nsnr.picker_result ---@type integer
    vim.hl.range(bufnr, nsnr_content, perm_hl, { row, byte_pos }, { row, byte_pos + 1 }, { priority = 10 })
    vim.hl.range(
      bufnr,
      nsnr_content,
      "f_fe_perm",
      { row, byte_pos + 1 },
      { row, byte_pos + string.len(text_perm) },
      { priority = 10 }
    )
    byte_pos = byte_pos + string.len(text_perm)

    -- Size highlight
    local text_size = std.string.pad_start(fileitem.size, diritem.size_width, " ") .. "  " ---@type string
    byte_pos = apply_highlight(bufnr, row, byte_pos, text_size, "f_fe_size")

    -- Date highlight
    local text_date = fileitem.date .. "  " ---@type string
    apply_highlight(bufnr, row, byte_pos, text_date, "f_fe_date")
  end

  return { uuids = uuids }
end

---@param dirpath                       string
---@param force                         boolean
---@return fml.action.find.explorer.IDirItem
local function fetch_diritem(dirpath, force)
  local diritem = (not force) and dir_datamap[dirpath] or nil ---@type fml.action.find.explorer.IDirItem|nil
  if diritem ~= nil then
    return diritem
  end

  local items = {} ---@type fml.action.find.explorer.IFileItem[]
  local raw_data = eve.oxi.readdir(dirpath) ---@type eve.builtin.oxi.IReaddirResult|nil

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
      icon = eve.icon.kind.Folder,
      icon_hl = "f_fe_name_dir",
    }
    file_datamap[dirpath] = itself

    for _, raw_item in ipairs(raw_data.items) do
      local item = create_file_item(raw_item, dirpath)
      table.insert(items, item)
      file_datamap[item.path] = item
    end
  end

  diritem = calculate_widths(items)
  dir_datamap[dirpath] = diritem
  return diritem
end

local state_cwd = std.Observable.from_value(std.path.cwd()) ---@type std.collection.IObservable
local finder_input = std.Observable.from_value("") ---@type std.collection.IObservable
local flag_fuzzy = std.Observable.from_value(true) ---@type std.collection.IObservable
local flag_regex = std.Observable.from_value(false) ---@type std.collection.IObservable
local flag_sensitive = std.Observable.from_value(false) ---@type std.collection.IObservable

---@return string
local function gen_title()
  local cwd = std.path.cwd() ---@type string
  local dirpath = state_cwd:snapshot() ---@type string
  if dirpath == cwd then
    return "File explorer (cwd)" ---@type string
  end

  local relative_dirpath = std.path.relative(cwd, dirpath, false)
  if #relative_dirpath < 1 or relative_dirpath == "." then
    return "File explorer (cwd)" ---@type string
  end

  local workspace = std.path.workspace() ---@type string
  if dirpath == workspace then
    return "Find files (workspace)" ---@type string
  end

  dirpath = string.sub(relative_dirpath, 1, 1) ~= "." and relative_dirpath or dirpath
  return "File explorer (" .. dirpath .. ")" ---@type string
end

---@return eve.ux.picker.composer.list.IResetData
local function fetch_data()
  local dirpath = std.path.normalize(state_cwd:snapshot()) ---@type string
  local parent_dirpath = std.path.dirname(dirpath) ---@type string
  local diritem = fetch_diritem(dirpath, false) ---@type fml.action.find.explorer.IDirItem
  fetch_diritem(parent_dirpath, false)

  ---@type fml.action.find.explorer.IItem[]
  local items = {}

  -- Add parent directory item
  local parent_fileitem = file_datamap[parent_dirpath] ---@type fml.action.find.explorer.IFileItem|nil
  if parent_fileitem ~= nil then
    ---@type fml.action.find.explorer.IItem
    local parent_item = {
      uuid = parent_dirpath,
      text = "../",
      text_lower = "../",
      highlights = {},
      data = { fileitem = parent_fileitem },
    }
    table.insert(items, parent_item)
  end

  -- Add directory items
  for _, fileitem in ipairs(diritem.items) do
    local filename = fileitem.type == "directory" and fileitem.name .. "/" or fileitem.name ---@type string

    ---@type fml.action.find.explorer.IItem
    local item = {
      uuid = fileitem.path,
      text = filename,
      text_lower = filename:lower(),
      highlights = {},
      data = { fileitem = fileitem },
    }
    table.insert(items, item)
  end

  local uuid_current = nil ---@type string|nil
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local winnr_sourcefile = eve.tab.retrieve_winnr_sourcefile(tabnr) ---@type integer|nil

  if winnr_sourcefile ~= nil and vim.api.nvim_win_is_valid(winnr_sourcefile) then
    local bufnr_sourcefile = vim.api.nvim_win_get_buf(winnr_sourcefile) ---@type integer
    local filepath_sourcefile = vim.api.nvim_buf_get_name(bufnr_sourcefile) ---@type string
    if #filepath_sourcefile > 0 then
      filepath_sourcefile = std.path.normalize(filepath_sourcefile)
      for _, item in ipairs(items) do
        if item.uuid == filepath_sourcefile then
          uuid_current = item.uuid
          break
        end
      end
    end
  end

  if uuid_current == nil and #items > 1 then
    uuid_current = items[2].uuid
  end

  ---@type eve.ux.picker.composer.list.IResetData
  return {
    items = items,
    uuid_current = uuid_current,
  }
end

---@param composer                       eve.ux.picker.ListComposer
---@param bufnr                          integer
---@return eve.ux.picker.preview.IDrawResult
local function preview_render(composer, bufnr)
  local lnum_current = composer.result.lnum_current:snapshot() ---@type integer

  if lnum_current < 1 then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "No file selected" })
    ---@type eve.ux.picker.preview.IDrawResult
    local result = {
      cursorline = false,
      number = false,
      title = "File Explorer",
      whitespaces = true,
      wrap = false,
    }
    return result
  end

  local item = composer:retrieve(lnum_current) ---@type eve.ux.picker.composer.list.IItem|nil
  if item == nil then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "No file selected" })
    ---@type eve.ux.picker.preview.IDrawResult
    local result = {
      cursorline = false,
      number = false,
      title = "File Explorer",
      whitespaces = true,
      wrap = false,
    }
    return result
  end

  ---@cast item fml.action.find.explorer.IItem
  local fileitem = item.data.fileitem ---@type fml.action.find.explorer.IFileItem|nil
  if fileitem == nil then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "Cannot found the file." })
    ---@type eve.ux.picker.preview.IDrawResult
    local result = {
      cursorline = false,
      number = false,
      title = "Error",
      whitespaces = true,
      wrap = false,
    }
    return result
  end

  if fileitem.type == "file" then
    local is_text_file = eve.filetype.is_printable_file(fileitem.name) ---@type boolean
    if is_text_file then
      local filetype = vim.filetype.match({ filename = fileitem.name }) ---@type string|nil
      local lines = std.fs.read_file_as_lines({ filepath = fileitem.path, max_lines = 300, silent = true }) ---@type string[]
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

      if filetype then
        vim.api.nvim_set_option_value("filetype", filetype, { buf = bufnr })
      end

      local title = std.path.relative(std.path.cwd(), fileitem.path, false) ---@type string
      ---@type eve.ux.picker.preview.IDrawResult
      local result = {
        cursorline = true,
        number = true,
        title = title,
        whitespaces = true,
        wrap = false,
      }
      return result
    else
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "Not a text file, cannot preview." })
      ---@type eve.ux.picker.preview.IDrawResult
      local result = {
        cursorline = false,
        number = false,
        title = fileitem.name,
        whitespaces = true,
        wrap = false,
      }
      return result
    end
  elseif fileitem.type == "directory" then
    local lines = {} ---@type string[]
    local highlights = {} ---@type std.t.IHighlight[]
    local c_diritem = fetch_diritem(fileitem.path, false) ---@type fml.action.find.explorer.IDirItem
    for lnum, c_fileitem in ipairs(c_diritem.items) do
      local byte_pos = 0 ---@type integer
      local text = "" ---@type string

      local text_perm = std.string.pad_start(c_fileitem.perm, c_diritem.perm_width, " ") .. "  "
      local byte_len_perm = string.len(text_perm) ---@type integer
      table.insert(highlights, {
        lnum = lnum,
        coll = byte_pos,
        colr = byte_pos + 1,
        hlname = c_fileitem.type == "directory" and "f_fe_perm_dir" or "f_fe_perm_file",
      })
      table.insert(
        highlights,
        { lnum = lnum, coll = byte_pos + 1, colr = byte_pos + byte_len_perm, hlname = "f_fe_perm" }
      )
      text = text .. text_perm
      byte_pos = byte_pos + byte_len_perm

      local text_size = std.string.pad_start(c_fileitem.size, c_diritem.size_width, " ") .. "  "
      local byte_len_size = string.len(text_size) ---@type integer
      table.insert(highlights, { lnum = lnum, coll = byte_pos, colr = byte_pos + byte_len_size, hlname = "f_fe_size" })
      text = text .. text_size
      byte_pos = byte_pos + byte_len_size

      if not std.env.IS_WIN then
        local text_owner = std.string.pad_start(c_fileitem.owner, c_diritem.owner_width, " ") .. " "
        local byte_len_owner = string.len(text_owner) ---@type integer
        table.insert(
          highlights,
          { lnum = lnum, coll = byte_pos, colr = byte_pos + byte_len_owner, hlname = "f_fe_owner" }
        )
        text = text .. text_owner
        byte_pos = byte_pos + byte_len_owner

        local text_group = std.string.pad_end(c_fileitem.group, c_diritem.group_width, " ") .. "  "
        local byte_len_group = string.len(text_group) ---@type integer
        table.insert(
          highlights,
          { lnum = lnum, coll = byte_pos, colr = byte_pos + byte_len_group, hlname = "f_fe_group" }
        )
        text = text .. text_group
        byte_pos = byte_pos + byte_len_group
      end

      local text_date = std.string.pad_end(c_fileitem.date, c_diritem.date_width, " ") .. "  "
      local byte_len_date = string.len(text_date) ---@type integer
      table.insert(highlights, { lnum = lnum, coll = byte_pos, colr = byte_pos + byte_len_date, hlname = "f_fe_date" })
      text = text .. text_date
      byte_pos = byte_pos + byte_len_date

      local text_name = std.string.pad_end(c_fileitem.name, c_diritem.name_width, " ") .. "          "
      local byte_len_name = string.len(text_name) ---@type integer
      table.insert(highlights, {
        lnum = lnum,
        coll = byte_pos,
        colr = byte_pos + byte_len_name,
        hlname = c_fileitem.type == "directory" and "f_fe_name_dir" or "f_fe_name_file",
      })
      text = text .. text_name
      byte_pos = byte_pos + byte_len_name

      table.insert(lines, text)
    end

    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

    local nsnr_content = eve.var.nsnr.picker_preview ---@type integer
    for _, hl in ipairs(highlights) do
      if hl.lnum <= #lines then
        vim.hl.range(
          bufnr,
          nsnr_content,
          hl.hlname,
          { hl.lnum - 1, hl.coll },
          { hl.lnum - 1, hl.colr },
          { priority = 10 }
        )
      end
    end

    local title = std.path.relative(std.path.cwd(), fileitem.path, false) ---@type string
    if #title < 1 or string.sub(title, 1, 1) == "." then
      title = std.path.normalize(fileitem.path)
    end

    ---@type eve.ux.picker.preview.IDrawResult
    local result = {
      cursorline = false,
      number = false,
      title = title,
      whitespaces = true,
      wrap = false,
    }
    return result
  end

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "Cannot preview this item." })

  ---@type eve.ux.picker.preview.IDrawResult
  local result = {
    cursorline = false,
    number = false,
    title = "Preview",
    whitespaces = true,
    wrap = false,
  }
  return result
end

local picker ---@type eve.ux.picker.ListComposer
picker = eve.ux.picker.ListComposer.new({
  name = __module_name__,
  autosort = false,
  permanent = true,
  title = gen_title(),
  height = math.floor(0.8 * vim.o.lines),
  width = math.floor(0.85 * vim.o.columns),

  finder_input = finder_input,
  flag_fuzzy = flag_fuzzy,
  flag_regex = flag_regex,
  flag_sensitive = flag_sensitive,

  preview_render = preview_render,

  keymaps_finder = {
    {
      modes = { "n", "v" },
      key = "oa",
      desc = "filetree: add to avante",
      callback = function()
        local lnum_current = picker.result.lnum_current:snapshot() ---@type integer
        local item = picker:retrieve(lnum_current) ---@type eve.ux.picker.composer.list.IItem|nil
        ---@cast item                   fml.action.find.explorer.IItem|nil

        if item ~= nil then
          add_to_avante(item.data.fileitem.path)
        end
      end,
    },
  },

  keymaps_result = {
    {
      modes = { "i", "n", "v" },
      key = "oa",
      desc = "filetree: add to avante",
      callback = function()
        local lnum_current = picker.result.lnum_current:snapshot() ---@type integer
        local item = picker:retrieve(lnum_current) ---@type eve.ux.picker.composer.list.IItem|nil
        ---@cast item                   fml.action.find.explorer.IItem|nil

        if item ~= nil then
          add_to_avante(item.data.fileitem.path)
        end
      end,
    },
  },

  result_render = function(composer, bufnr, itemmap, matches)
    ---@cast itemmap                    table<string, fml.action.find.explorer.IItem>

    local winnr = composer.result:get_winnr() or 0 ---@type integer
    local result_width = vim.api.nvim_win_get_width(winnr) ---@type integer
    local dirpath = state_cwd:snapshot() ---@type string
    local diritem = dir_datamap[dirpath] ---@type fml.action.find.explorer.IDirItem|nil

    if diritem == nil then
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
      return { uuids = {} }
    end

    local data = render_file_list(bufnr, itemmap, matches, diritem, result_width)
    return { uuids = data.uuids }
  end,

  on_confirm = function(composer, item)
    if item == nil then
      return
    end

    ---@cast item fml.action.find.explorer.IItem
    local fileitem = item.data.fileitem ---@type fml.action.find.explorer.IFileItem|nil
    if fileitem == nil then
      return
    end

    if fileitem.type == "file" then
      local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
      local winnr_sourcefile = eve.tab.retrieve_winnr_sourcefile(tabnr) ---@type integer|nil
      if winnr_sourcefile ~= nil and vim.api.nvim_win_is_valid(winnr_sourcefile) then
        vim.api.nvim_tabpage_set_win(tabnr, winnr_sourcefile)
      end

      composer:close()
      eve.win.open_filepath(winnr_sourcefile, fileitem.path)
    elseif fileitem.type == "directory" then
      local dirpath = fileitem.path ---@type string
      state_cwd:next(dirpath)
    end
  end,

  on_refresh = function(composer)
    local data = fetch_data()
    composer:reset_data(data)
  end,

  keymaps = {
    {
      modes = { "n", "v" },
      key = "<Backspace>",
      callback = function()
        local next_cwd = std.path.dirname(state_cwd:snapshot())
        state_cwd:next(next_cwd)
      end,
      desc = "file explorer: goto the parent dir",
    },
  },
})

state_cwd:subscribe(
  std.Subscriber.new({
    on_next = function()
      if picker and not picker:isdisposed() then
        local data = fetch_data()
        picker:reset_data(data)
      end
    end,
  }),
  true
)

---@class fml.action.find
local M = {}

---@param specified_filepath            string|nil
---@return nil
function M.find_explorer(specified_filepath)
  local dirpath_resolved = false ---@type boolean
  if specified_filepath ~= nil and #specified_filepath > 0 then
    if std.path.is_exist_dirpath(specified_filepath) then
      local dirpath = std.path.normalize(specified_filepath) ---@type string
      state_cwd:next(dirpath, { force = true })
      dirpath_resolved = true
    elseif std.path.is_exist_filepath(specified_filepath) then
      local dirpath = std.path.dirname(specified_filepath) ---@type string
      state_cwd:next(dirpath, { force = true })
      dirpath_resolved = true
    end
  end
  if not dirpath_resolved then
    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    local winnr_sourcefile = eve.tab.retrieve_winnr_sourcefile(tabnr) ---@type integer|nil
    if winnr_sourcefile ~= nil then
      local bufnr = vim.api.nvim_win_get_buf(winnr_sourcefile) ---@type integer
      local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
      if #filepath > 0 then
        if std.path.is_exist_dirpath(filepath) then
          state_cwd:next(filepath, { force = true })
        elseif std.path.is_exist_filepath(filepath) then
          state_cwd:next(std.path.dirname(filepath), { force = true })
        end
      end
    end
  end

  local data = fetch_data()
  picker:reset_data(data)
  picker:focus()
end

return M
