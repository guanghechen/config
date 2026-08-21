---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.fn.find_explorer" ---@type string

local name = "era.fn.find_explorer" ---@type string
local title = "Find Explorer" ---@type string

---@class era.fn.find_explorer.IDirItem
---@field public items                  era.fn.find_explorer.IFileItem[]
---@field public icon_width             integer
---@field public name_width             integer
---@field public perm_width             integer
---@field public size_width             integer
---@field public date_width             integer
---@field public owner_width            integer
---@field public group_width            integer

---@class era.fn.find_explorer.IFileItem
---@field public type                   string
---@field public name                   string
---@field public path                   string Canonical filepath.
---@field public dir                    string Canonical dirpath.
---@field public perm                   string
---@field public size                   string
---@field public owner                  string
---@field public group                  string
---@field public date                   string
---@field public icon                   string
---@field public icon_hl                string

---@class era.fn.find_explorer.IItemData
---@field public fileitem               era.fn.find_explorer.IFileItem

---@class era.fn.find_explorer.IItem : era.m.picker.composer.list.IItem
---@field public data                   era.fn.find_explorer.IItemData

local dir_datamap = {} ---@type table<string, era.fn.find_explorer.IDirItem>
local file_datamap = {} ---@type table<string, era.fn.find_explorer.IFileItem>

---@param raw_item                      yoz.fs.IFileItemWithStatus
---@param dirpath                       string Canonical dirpath.
---@return era.fn.find_explorer.IFileItem
local function create_file_item(raw_item, dirpath)
  local filepath = raw_item.name ---@type string
  if dirpath ~= "." then
    filepath = (dirpath == "/" and dirpath or dirpath .. "/") .. filepath
  end
  local icon, icon_hl ---@type string, string

  if raw_item.type == "directory" then
    icon = stl.icon.kind.Folder
    icon_hl = "m_fe_name_dir"
  else
    icon, icon_hl = stl.fileicon.get_file_icon(raw_item.name)
  end

  ---@type era.fn.find_explorer.IFileItem
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

---@param items                         era.fn.find_explorer.IFileItem[]
---@return era.fn.find_explorer.IDirItem
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

  return vim.tbl_extend("force", { items = items }, widths) ---@type era.fn.find_explorer.IDirItem
end

---@param fileitem                      era.fn.find_explorer.IFileItem
---@param diritem                       era.fn.find_explorer.IDirItem
---@param result_width                  integer
---@param filename                      string
---@return string
---@return integer
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
  local nsnr_content = dot.var.nsnr.picker_result ---@type integer
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

  local nsnr_matches = dot.var.nsnr.picker_matches ---@type integer
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
          "m_pk_matches",
          { row, byte_pos + match_start },
          { row, byte_pos + match_end },
          { priority = 30 }
        )
      end
    end
  end
end

---@param bufnr                         integer
---@param itemmap                       table<string, era.fn.find_explorer.IItem>
---@param matches                       table[]
---@param diritem                       era.fn.find_explorer.IDirItem
---@param result_width                  integer
---@return table
local function render_file_list(bufnr, itemmap, matches, diritem, result_width)
  local lines = {} ---@type string[]
  local uuids = {} ---@type string[]

  -- Generate lines
  for _, match in ipairs(matches) do
    local item = itemmap[match.uuid] ---@type era.fn.find_explorer.IItem
    local fileitem = item.data.fileitem ---@type era.fn.find_explorer.IFileItem
    local filename = item.text ---@type string

    local text_icon = stl.string.pad_start(fileitem.icon, diritem.icon_width, " ") .. "  " ---@type string
    local text_name, _ = format_filename(fileitem, diritem, result_width, filename)
    local text_perm = stl.string.pad_start(fileitem.perm, diritem.perm_width, " ") .. "  " ---@type string
    local text_size = stl.string.pad_start(fileitem.size, diritem.size_width, " ") .. "  " ---@type string
    local text_date = fileitem.date .. "  " ---@type string

    lines[#lines + 1] = text_icon .. text_name .. text_perm .. text_size .. text_date
    uuids[#uuids + 1] = item.uuid
  end

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  -- Apply highlights
  for lnum, match in ipairs(matches) do
    local row = lnum - 1 ---@type integer
    local item = itemmap[match.uuid] ---@type era.fn.find_explorer.IItem
    local fileitem = item.data.fileitem ---@type era.fn.find_explorer.IFileItem
    local filename = item.text ---@type string
    local byte_pos = 0 ---@type integer

    -- Icon highlight
    local text_icon = stl.string.pad_start(fileitem.icon, diritem.icon_width, " ") .. "  " ---@type string
    byte_pos = apply_highlight(bufnr, row, byte_pos, text_icon, fileitem.icon_hl)

    -- Filename highlight
    local display_filename, filename_max_display_width = format_filename(fileitem, diritem, result_width, filename)
    ---@type string
    local text_name = display_filename
      .. string.rep(" ", math.max(1, filename_max_display_width - vim.api.nvim_strwidth(display_filename)))
    local filename_hl = fileitem.type == "directory" and "m_fe_name_dir" or "m_fe_name_file" ---@type string
    byte_pos = apply_highlight(bufnr, row, byte_pos, text_name, filename_hl) - 1

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
    local text_perm = stl.string.pad_start(fileitem.perm, diritem.perm_width, " ") .. "  " ---@type string
    local perm_hl = fileitem.type == "directory" and "m_fe_perm_dir" or "m_fe_perm_file" ---@type string
    local nsnr_content = dot.var.nsnr.picker_result ---@type integer
    vim.hl.range(bufnr, nsnr_content, perm_hl, { row, byte_pos }, { row, byte_pos + 1 }, { priority = 10 })
    vim.hl.range(
      bufnr,
      nsnr_content,
      "m_fe_perm",
      { row, byte_pos + 1 },
      { row, byte_pos + string.len(text_perm) },
      { priority = 10 }
    )
    byte_pos = byte_pos + string.len(text_perm)

    -- Size highlight
    local text_size = stl.string.pad_start(fileitem.size, diritem.size_width, " ") .. "  " ---@type string
    byte_pos = apply_highlight(bufnr, row, byte_pos, text_size, "m_fe_size")

    -- Date highlight
    local text_date = fileitem.date .. "  " ---@type string
    apply_highlight(bufnr, row, byte_pos, text_date, "m_fe_date")
  end

  return { uuids = uuids }
end

---@param dirpath                       string
---@param force                         boolean
---@return era.fn.find_explorer.IDirItem
local function fetch_diritem(dirpath, force)
  local diritem = (not force) and dir_datamap[dirpath] or nil ---@type era.fn.find_explorer.IDirItem|nil
  if diritem ~= nil then
    return diritem
  end

  local items = {} ---@type era.fn.find_explorer.IFileItem[]
  local os_dirpath = yoz.canonical_path.to_os_path(dirpath) ---@type string
  local raw_data, raw_err = yoz.fs.readdir(os_dirpath) ---@type yoz.fs.IReaddirResult|nil, yoz.fs.IReaddirError|nil

  if raw_data == nil and raw_err ~= nil then
    stl.reporter.error({
      from = name,
      subject = "readdir failed",
      details = {
        error = raw_err.error,
        dirpath = dirpath,
      },
    })
  end

  if raw_data ~= nil then
    local raw_itself = raw_data.itself ---@type yoz.fs.IFileItemWithStatus

    ---@type era.fn.find_explorer.IFileItem
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
      icon = stl.icon.kind.Folder,
      icon_hl = "m_fe_name_dir",
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

local cwd = yoz.canonical_path.from_os_path(yoz.canonical_path.get_cwd(), false) ---@type string
local workspace = yoz.canonical_path.from_os_path(dot.path.workspace(), false) ---@type string
local state_cwd = stl.c.Observable.from_value(cwd) ---@type stl.c.Observable
local search_pattern = stl.c.Observable.from_value("") ---@type stl.c.Observable
local flag_fuzzy = stl.c.Observable.from_value(true) ---@type stl.c.Observable
local flag_regex = stl.c.Observable.from_value(false) ---@type stl.c.Observable
local flag_case_sensitive = stl.c.Observable.from_value(false) ---@type stl.c.Observable

---@return string
local function gen_title()
  local dirpath = state_cwd:snapshot() ---@type string
  if dirpath == cwd then
    return "File explorer (cwd)" ---@type string
  end

  local relative_dirpath = yoz.canonical_path.relative(cwd, dirpath, false) ---@type string
  if #relative_dirpath < 1 or relative_dirpath == "." then
    return "File explorer (cwd)" ---@type string
  end

  if dirpath == workspace then
    return "Find files (workspace)" ---@type string
  end

  dirpath = string.sub(relative_dirpath, 1, 1) ~= "." and relative_dirpath or dirpath
  return "File explorer (" .. dirpath .. ")" ---@type string
end

---@return era.m.picker.composer.list.IResetData
local function fetch_data()
  local dirpath = state_cwd:snapshot() ---@type string
  local parent_dirpath = yoz.canonical_path.dirname(dirpath, false) ---@type string
  local diritem = fetch_diritem(dirpath, false) ---@type era.fn.find_explorer.IDirItem
  fetch_diritem(parent_dirpath, false)

  ---@type era.fn.find_explorer.IItem[]
  local items = {}

  -- Add parent directory item
  local parent_fileitem = file_datamap[parent_dirpath] ---@type era.fn.find_explorer.IFileItem|nil
  if parent_fileitem ~= nil then
    ---@type era.fn.find_explorer.IItem
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

    ---@type era.fn.find_explorer.IItem
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
  local winnr_sourcefile = dot.tab.retrieve_winnr_sourcefile(tabnr) ---@type integer|nil

  if winnr_sourcefile ~= nil and vim.api.nvim_win_is_valid(winnr_sourcefile) then
    local bufnr_sourcefile = vim.api.nvim_win_get_buf(winnr_sourcefile) ---@type integer
    local filepath_sourcefile = vim.api.nvim_buf_get_name(bufnr_sourcefile) ---@type string
    if #filepath_sourcefile > 0 then
      filepath_sourcefile = yoz.canonical_path.from_os_path(filepath_sourcefile, false)
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

  ---@type era.m.picker.composer.list.IResetData
  return {
    items = items,
    uuid_current = uuid_current,
  }
end

---@param composer                      era.m.picker.ListComposer
---@param bufnr                         integer
---@return era.m.picker.preview.IDrawResult
local function preview_render(composer, bufnr)
  local lnum_current = composer.result.lnum_current:snapshot() ---@type integer

  if lnum_current < 1 then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "No file selected" })
    ---@type era.m.picker.preview.IDrawResult
    local result = {
      cursorline = false,
      number = false,
      title = title,
      whitespaces = true,
      wrap = false,
    }
    return result
  end

  local item = composer:retrieve(lnum_current) ---@type era.m.picker.composer.list.IItem|nil
  if item == nil then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "No file selected" })
    ---@type era.m.picker.preview.IDrawResult
    local result = {
      cursorline = false,
      number = false,
      title = title,
      whitespaces = true,
      wrap = false,
    }
    return result
  end

  ---@cast item era.fn.find_explorer.IItem
  local fileitem = item.data.fileitem ---@type era.fn.find_explorer.IFileItem|nil
  if fileitem == nil then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "Cannot found the file." })
    ---@type era.m.picker.preview.IDrawResult
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
    local is_text_file = stl.filetype.is_printable_file(fileitem.name) ---@type boolean
    if is_text_file then
      local filetype = vim.filetype.match({ filename = fileitem.name }) ---@type string|nil
      local os_filepath = yoz.canonical_path.to_os_path(fileitem.path) ---@type string
      local lines = stl.fs.read_file_as_lines({ filepath = os_filepath, max_lines = 300, silent = true }) ---@type string[]
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

      if filetype then
        vim.api.nvim_set_option_value("filetype", filetype, { buf = bufnr })
      end

      ---@type era.m.picker.preview.IDrawResult
      local result = {
        cursorline = true,
        number = true,
        title = yoz.canonical_path.relative(cwd, fileitem.path, false),
        whitespaces = true,
        wrap = false,
      }
      return result
    else
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "Not a text file, cannot preview." })
      ---@type era.m.picker.preview.IDrawResult
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
    local highlights = {} ---@type stl.t.IHighlight[]
    local c_diritem = fetch_diritem(fileitem.path, false) ---@type era.fn.find_explorer.IDirItem
    for lnum, c_fileitem in ipairs(c_diritem.items) do
      local byte_pos = 0 ---@type integer
      local text = "" ---@type string

      local text_perm = stl.string.pad_start(c_fileitem.perm, c_diritem.perm_width, " ") .. "  "
      local byte_len_perm = string.len(text_perm) ---@type integer
      table.insert(highlights, {
        lnum = lnum,
        coll = byte_pos,
        colr = byte_pos + 1,
        hlname = c_fileitem.type == "directory" and "m_fe_perm_dir" or "m_fe_perm_file",
      })
      table.insert(
        highlights,
        { lnum = lnum, coll = byte_pos + 1, colr = byte_pos + byte_len_perm, hlname = "m_fe_perm" }
      )
      text = text .. text_perm
      byte_pos = byte_pos + byte_len_perm

      local text_size = stl.string.pad_start(c_fileitem.size, c_diritem.size_width, " ") .. "  "
      local byte_len_size = string.len(text_size) ---@type integer
      table.insert(highlights, { lnum = lnum, coll = byte_pos, colr = byte_pos + byte_len_size, hlname = "m_fe_size" })
      text = text .. text_size
      byte_pos = byte_pos + byte_len_size

      if not stl.env.IS_WIN then
        local text_owner = stl.string.pad_start(c_fileitem.owner, c_diritem.owner_width, " ") .. " "
        local byte_len_owner = string.len(text_owner) ---@type integer
        table.insert(
          highlights,
          { lnum = lnum, coll = byte_pos, colr = byte_pos + byte_len_owner, hlname = "m_fe_owner" }
        )
        text = text .. text_owner
        byte_pos = byte_pos + byte_len_owner

        local text_group = stl.string.pad_end(c_fileitem.group, c_diritem.group_width, " ") .. "  "
        local byte_len_group = string.len(text_group) ---@type integer
        table.insert(
          highlights,
          { lnum = lnum, coll = byte_pos, colr = byte_pos + byte_len_group, hlname = "m_fe_group" }
        )
        text = text .. text_group
        byte_pos = byte_pos + byte_len_group
      end

      local text_date = stl.string.pad_end(c_fileitem.date, c_diritem.date_width, " ") .. "  "
      local byte_len_date = string.len(text_date) ---@type integer
      table.insert(highlights, { lnum = lnum, coll = byte_pos, colr = byte_pos + byte_len_date, hlname = "m_fe_date" })
      text = text .. text_date
      byte_pos = byte_pos + byte_len_date

      local text_name = stl.string.pad_end(c_fileitem.name, c_diritem.name_width, " ") .. "          "
      local byte_len_name = string.len(text_name) ---@type integer
      table.insert(highlights, {
        lnum = lnum,
        coll = byte_pos,
        colr = byte_pos + byte_len_name,
        hlname = c_fileitem.type == "directory" and "m_fe_name_dir" or "m_fe_name_file",
      })
      text = text .. text_name
      byte_pos = byte_pos + byte_len_name

      table.insert(lines, text)
    end

    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

    local nsnr_content = dot.var.nsnr.picker_preview ---@type integer
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

    local result_title = yoz.canonical_path.relative(cwd, fileitem.path, false) ---@type string
    if #result_title < 1 or string.sub(result_title, 1, 1) == "." then
      result_title = fileitem.path
    end

    ---@type era.m.picker.preview.IDrawResult
    local result = {
      cursorline = false,
      number = false,
      title = result_title,
      whitespaces = true,
      wrap = false,
    }
    return result
  end

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "Cannot preview this item." })

  ---@type era.m.picker.preview.IDrawResult
  local result = {
    cursorline = false,
    number = false,
    title = "Preview",
    whitespaces = true,
    wrap = false,
  }
  return result
end

local picker ---@type era.m.picker.ListComposer

---@return era.fn.find_explorer.IItem|nil
---@return era.fn.find_explorer.IFileItem|nil
local function retrieve_current_item()
  local lnum_current = picker.result.lnum_current:snapshot() ---@type integer
  local item = picker:retrieve(lnum_current) ---@type era.m.picker.composer.list.IItem|nil
  ---@cast item era.fn.find_explorer.IItem|nil
  if item == nil then
    return nil, nil
  end

  local fileitem = item.data.fileitem ---@type era.fn.find_explorer.IFileItem|nil
  if fileitem == nil then
    return nil, nil
  end

  return item, fileitem
end

---@param value                         string
---@return string|nil
---@return string|nil
local function validate_same_dir_name(value)
  local trimmed_name = vim.trim(value) ---@type string
  if trimmed_name == "" then
    return nil, "Name cannot be empty"
  end
  if trimmed_name == "." or trimmed_name == ".." then
    return nil, "Invalid name"
  end
  if trimmed_name:find("[/\\]") ~= nil then
    return nil, "Path separator is not allowed"
  end
  return trimmed_name, nil
end

---@param value                         string
---@return string|nil
---@return boolean
---@return string|nil
local function parse_create_input(value)
  local input = vim.trim(value) ---@type string
  if input == "" then
    return nil, false, "Name cannot be empty"
  end
  if input == "." or input == ".." then
    return nil, false, "Invalid name"
  end
  if input:find("\\", 1, true) ~= nil then
    return nil, false, "Path separator is not allowed"
  end

  local is_directory = false ---@type boolean
  if input:sub(-1) == "/" then
    is_directory = true
    input = input:sub(1, -2)
  end

  local entry_name, err = validate_same_dir_name(input)
  if entry_name == nil then
    return nil, false, err
  end

  return entry_name, is_directory, nil
end

---@param from_dir                      string
---@param entry_name                    string
---@return string
local function build_target_path(from_dir, entry_name)
  return yoz.canonical_path.join(from_dir, entry_name, false)
end

---@return integer
local function resolve_prompt_row_near_cursor()
  local lnum = vim.fn.line(".") ---@type integer
  local lnum_top = vim.fn.line("w0") ---@type integer
  local lnum_bottom = vim.fn.line("w$") ---@type integer
  local lines_above = lnum - lnum_top ---@type integer
  local lines_below = lnum_bottom - lnum ---@type integer

  if lines_below <= 1 and lines_above > 0 then
    return -1
  end

  return 1
end

---@param target_uuid                   string|nil
---@param lnum_hint                     integer|nil
---@return nil
local function refresh_current_dir(target_uuid, lnum_hint)
  local dirpath = state_cwd:snapshot() ---@type string
  dir_datamap[dirpath] = nil

  local data = fetch_data() ---@type era.m.picker.composer.list.IResetData
  local has_target = false ---@type boolean

  if target_uuid ~= nil then
    for _, item in ipairs(data.items) do
      if item.uuid == target_uuid then
        has_target = true
        break
      end
    end
    if has_target then
      data.uuid_current = target_uuid
    end
  end

  picker:reset_data(data)

  if not has_target and lnum_hint ~= nil and #data.items > 0 then
    local lnum_next = math.max(1, math.min(lnum_hint, #data.items)) ---@type integer
    picker.result:set_lnum_current(lnum_next)
  end
end

---@return nil
local function add_current_to_ai()
  local _, fileitem = retrieve_current_item()
  if fileitem == nil then
    return
  end

  era.fn.add_locations_to_ai({ { filepath = fileitem.path } })
end

---@return nil
local function create_entry()
  local item, fileitem = retrieve_current_item()

  local parent_dir = state_cwd:snapshot() ---@type string
  if item ~= nil and fileitem ~= nil then
    if item.text == "../" then
      parent_dir = state_cwd:snapshot() ---@type string
    elseif fileitem.type == "directory" then
      parent_dir = fileitem.path ---@type string
    else
      parent_dir = fileitem.dir ---@type string
    end
  end

  local winnr_current = vim.api.nvim_get_current_win() ---@type integer
  local winnr_result = picker.result:get_winnr() ---@type integer|nil

  ---@param input                       string|nil
  ---@return nil
  local function on_confirmed(input)
    if input == nil then
      return
    end

    local entry_name, is_directory, parse_err = parse_create_input(input)
    if parse_err ~= nil then
      stl.reporter.error({
        from = __module_name__,
        subject = "create",
        message = parse_err,
      })
      return
    end
    if entry_name == nil then
      return
    end

    local target = build_target_path(parent_dir, entry_name) ---@type string
    local os_target = yoz.canonical_path.to_os_path(target) ---@type string
    if yoz.path.is_exist(os_target) then
      stl.reporter.error({
        from = __module_name__,
        subject = "create",
        message = "Target already exists",
        details = { target = target },
      })
      return
    end

    local success = false ---@type boolean
    if is_directory then
      stl.env.mkdirs(os_target, true)
      success = yoz.path.is_exist_directory(os_target)
    else
      stl.env.mkdirs(os_target, false)
      local ok = pcall(vim.fn.writefile, {}, os_target) ---@type boolean
      success = ok and yoz.path.is_exist_file(os_target)
    end

    if not success then
      stl.reporter.error({
        from = __module_name__,
        subject = "create",
        message = "Failed to create target",
        details = { target = target, is_directory = is_directory },
      })
      return
    end

    stl.reporter.info({
      from = __module_name__,
      subject = "create",
      message = string.format("Created: %s", target),
    })
    refresh_current_dir(target, nil)
  end

  ---@return nil
  local function open_prompt()
    local row = resolve_prompt_row_near_cursor() ---@type integer

    vim.ui.input({
      prompt = "Create: ",
      relative = "cursor",
      row = row,
      col = 4,
    }, function(input)
      on_confirmed(input)
    end)
  end

  if winnr_result ~= nil and winnr_result > 0 and vim.api.nvim_win_is_valid(winnr_result) then
    if winnr_current == winnr_result then
      open_prompt()
    else
      vim.api.nvim_win_call(winnr_result, open_prompt)
    end
  else
    on_confirmed(vim.fn.input("Create: "))
  end
end

---@return nil
local function delete_entry()
  local item, fileitem = retrieve_current_item()
  if item == nil or fileitem == nil then
    return
  end

  if item.text == "../" then
    stl.reporter.error({
      from = __module_name__,
      subject = "delete",
      message = "Cannot delete parent entry ../",
    })
    return
  end

  local target = fileitem.path ---@type string
  local os_target = yoz.canonical_path.to_os_path(target) ---@type string
  local is_directory = fileitem.type == "directory" ---@type boolean
  local lnum_current = picker.result.lnum_current:snapshot() ---@type integer
  local winnr_current = vim.api.nvim_get_current_win() ---@type integer
  local winnr_result = picker.result:get_winnr() ---@type integer|nil

  ---@param input                       string|nil
  ---@return nil
  local function on_confirmed(input)
    if input == nil then
      return
    end

    local answer = vim.trim(input):lower() ---@type string
    if answer ~= "y" and answer ~= "yes" then
      return
    end

    local ok = false ---@type boolean
    if is_directory then
      ok = vim.fn.delete(os_target, "rf") == 0
    else
      ok = vim.fn.delete(os_target) == 0
    end

    if not ok then
      stl.reporter.error({
        from = __module_name__,
        subject = "delete",
        message = "Failed to delete target",
        details = { target = target, is_directory = is_directory },
      })
      return
    end

    stl.reporter.info({
      from = __module_name__,
      subject = "delete",
      message = string.format("Deleted: %s", target),
    })
    refresh_current_dir(nil, lnum_current)
  end

  ---@return nil
  local function open_prompt()
    local row = resolve_prompt_row_near_cursor() ---@type integer

    vim.ui.input({
      inputtype = "confirmation",
      prompt = string.format("Delete '%s'? ", item.text),
      relative = "cursor",
      row = row,
      col = 4,
    }, function(input)
      on_confirmed(input)
    end)
  end

  if winnr_result ~= nil and winnr_result > 0 and vim.api.nvim_win_is_valid(winnr_result) then
    if winnr_current == winnr_result then
      open_prompt()
    else
      vim.api.nvim_win_call(winnr_result, open_prompt)
    end
  else
    on_confirmed(vim.fn.input(string.format("Delete '%s'? ", item.text)))
  end
end

---@param filename                      string
---@param is_directory                  boolean
---@return string
local function suggest_copy_name(filename, is_directory)
  if is_directory then
    return filename .. "-copy"
  end

  local ext = yoz.path.extname(filename) ---@type string
  if ext ~= "" and #filename > #ext then
    local base = filename:sub(1, #filename - #ext) ---@type string
    return base .. "-copy" .. ext
  end

  return filename .. "-copy"
end

---@return nil
local function copy_entry_as()
  local item, fileitem = retrieve_current_item()
  if item == nil or fileitem == nil then
    return
  end

  if item.text == "../" then
    stl.reporter.error({
      from = __module_name__,
      subject = "copy_as",
      message = "Cannot copy parent entry ../",
    })
    return
  end

  local source = fileitem.path ---@type string
  local parent_dir = fileitem.dir ---@type string
  local is_directory = fileitem.type == "directory" ---@type boolean
  local suggested_name = suggest_copy_name(fileitem.name, is_directory) ---@type string
  local winnr_current = vim.api.nvim_get_current_win() ---@type integer
  local winnr_result = picker.result:get_winnr() ---@type integer|nil

  ---@param input                       string|nil
  ---@return nil
  local function on_confirmed(input)
    if input == nil then
      return
    end

    local new_name, err = validate_same_dir_name(input)
    if new_name == nil then
      if err ~= nil then
        stl.reporter.error({
          from = __module_name__,
          subject = "copy_as",
          message = err,
        })
      end
      return
    end

    local target = build_target_path(parent_dir, new_name) ---@type string
    if target == source then
      return
    end

    local os_source = yoz.canonical_path.to_os_path(source) ---@type string
    local os_target = yoz.canonical_path.to_os_path(target) ---@type string
    if yoz.path.is_exist(os_target) then
      stl.reporter.error({
        from = __module_name__,
        subject = "copy_as",
        message = "Target already exists",
        details = { target = target },
      })
      return
    end

    local ok = is_directory and stl.fs.copy_directory(os_source, os_target, true)
      or stl.fs.copy_file(os_source, os_target, true)
    if not ok then
      return
    end

    stl.reporter.info({
      from = __module_name__,
      subject = "copy_as",
      message = string.format("Copied to: %s", target),
    })
    refresh_current_dir(target, nil)
  end

  ---@return nil
  local function open_prompt()
    local row = resolve_prompt_row_near_cursor() ---@type integer

    vim.ui.input({
      prompt = "Copy as: ",
      default = suggested_name,
      relative = "cursor",
      row = row,
      col = 4,
    }, function(input)
      on_confirmed(input)
    end)
  end

  if winnr_result ~= nil and winnr_result > 0 and vim.api.nvim_win_is_valid(winnr_result) then
    if winnr_current == winnr_result then
      open_prompt()
    else
      vim.api.nvim_win_call(winnr_result, open_prompt)
    end
  else
    on_confirmed(vim.fn.input("Copy as: ", suggested_name))
  end
end

---@return nil
local function rename_entry()
  local item, fileitem = retrieve_current_item()
  if item == nil or fileitem == nil then
    return
  end

  if item.text == "../" then
    stl.reporter.error({
      from = __module_name__,
      subject = "rename",
      message = "Cannot rename parent entry ../",
    })
    return
  end

  local source = fileitem.path ---@type string
  local parent_dir = fileitem.dir ---@type string
  local is_directory = fileitem.type == "directory" ---@type boolean
  local winnr_current = vim.api.nvim_get_current_win() ---@type integer
  local winnr_result = picker.result:get_winnr() ---@type integer|nil

  ---@param input                       string|nil
  ---@return nil
  local function on_confirmed(input)
    if input == nil then
      return
    end

    local new_name, err = validate_same_dir_name(input)
    if new_name == nil then
      if err ~= nil then
        stl.reporter.error({
          from = __module_name__,
          subject = "rename",
          message = err,
        })
      end
      return
    end

    local target = build_target_path(parent_dir, new_name) ---@type string
    if target == source then
      return
    end

    local os_source = yoz.canonical_path.to_os_path(source) ---@type string
    local os_target = yoz.canonical_path.to_os_path(target) ---@type string
    if yoz.path.is_exist(os_target) then
      stl.reporter.error({
        from = __module_name__,
        subject = "rename",
        message = "Target already exists",
        details = { target = target },
      })
      return
    end

    local ok = era.fn.rename({ from = os_source, to = os_target, isdir = is_directory }) ---@type boolean
    if not ok then
      return
    end

    stl.reporter.info({
      from = __module_name__,
      subject = "rename",
      message = string.format("Renamed to: %s", target),
    })
    refresh_current_dir(target, nil)
  end

  ---@return nil
  local function open_prompt()
    local row = resolve_prompt_row_near_cursor() ---@type integer

    vim.ui.input({
      prompt = "Rename to: ",
      default = fileitem.name,
      relative = "cursor",
      row = row,
      col = 4,
    }, function(input)
      on_confirmed(input)
    end)
  end

  if winnr_result ~= nil and winnr_result > 0 and vim.api.nvim_win_is_valid(winnr_result) then
    if winnr_current == winnr_result then
      open_prompt()
    else
      vim.api.nvim_win_call(winnr_result, open_prompt)
    end
  else
    on_confirmed(vim.fn.input("Rename to: ", fileitem.name))
  end
end

---@return nil
local function copy_current_filepath()
  local _, fileitem = retrieve_current_item()
  if fileitem == nil then
    return
  end

  local filepath = fileitem.path ---@type string
  if #filepath < 1 then
    return
  end

  local winnr_current = vim.api.nvim_get_current_win() ---@type integer
  local winnr_result = picker.result:get_winnr() ---@type integer|nil
  if winnr_result == nil or winnr_result < 1 or not vim.api.nvim_win_is_valid(winnr_result) then
    return
  end

  ---@return nil
  local function handle()
    era.fn.select_copy_filepath({
      filepath = filepath,
      relative = "cursor",
      row = 1,
      col = 4,
    })
  end

  if winnr_current == winnr_result then
    handle()
  else
    vim.api.nvim_win_call(winnr_result, handle)
  end
end

picker = era.m.picker.ListComposer.new({
  name = name,
  autosort = false,
  permanent = true,
  title = gen_title(),
  height = 0.9,
  width = 0.9,

  search_pattern = search_pattern,
  flag_fuzzy = flag_fuzzy,
  flag_regex = flag_regex,
  flag_case_sensitive = flag_case_sensitive,

  render_preview = preview_render,

  keymaps_finder = {
    {
      modes = { "n", "x" },
      key = "oA",
      desc = "filetree: add to ai",
      callback = add_current_to_ai,
    },
    {
      modes = { "n", "x" },
      key = "oa",
      desc = "filetree: create",
      callback = create_entry,
    },
    {
      modes = { "n", "x" },
      key = "oc",
      desc = "filetree: copy filepath",
      callback = copy_current_filepath,
    },
    {
      modes = { "n", "x" },
      key = "od",
      desc = "filetree: delete",
      callback = delete_entry,
    },
    {
      modes = { "n", "x" },
      key = "or",
      desc = "filetree: rename",
      callback = rename_entry,
    },
    {
      modes = { "n", "x" },
      key = "c",
      desc = "filetree: copy as",
      callback = copy_entry_as,
    },
  },

  keymaps_result = {
    {
      modes = { "i", "n", "x" },
      key = "oA",
      desc = "filetree: add to ai",
      callback = add_current_to_ai,
    },
    {
      modes = { "i", "n", "x" },
      key = "oa",
      desc = "filetree: create",
      callback = create_entry,
    },
    {
      modes = { "i", "n", "x" },
      key = "oc",
      desc = "filetree: copy filepath",
      callback = copy_current_filepath,
    },
    {
      modes = { "i", "n", "x" },
      key = "od",
      desc = "filetree: delete",
      callback = delete_entry,
    },
    {
      modes = { "i", "n", "x" },
      key = "or",
      desc = "filetree: rename",
      callback = rename_entry,
    },
    {
      modes = { "i", "n", "x" },
      key = "c",
      desc = "filetree: copy as",
      callback = copy_entry_as,
    },
  },

  render_result = function(composer, bufnr, itemmap, matches)
    ---@cast itemmap                    table<string, era.fn.find_explorer.IItem>

    local winnr = composer.result:get_winnr() or 0 ---@type integer
    local result_width = vim.api.nvim_win_get_width(winnr) ---@type integer
    local dirpath = state_cwd:snapshot() ---@type string
    local diritem = dir_datamap[dirpath] ---@type era.fn.find_explorer.IDirItem|nil

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

    ---@cast item era.fn.find_explorer.IItem
    local fileitem = item.data.fileitem ---@type era.fn.find_explorer.IFileItem|nil
    if fileitem == nil then
      return
    end

    if fileitem.type == "file" then
      local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
      local winnr_sourcefile = dot.tab.retrieve_winnr_sourcefile(tabnr) ---@type integer|nil
      if winnr_sourcefile ~= nil and vim.api.nvim_win_is_valid(winnr_sourcefile) then
        vim.api.nvim_tabpage_set_win(tabnr, winnr_sourcefile)
      end

      composer:close()
      dot.win.open_filepath(winnr_sourcefile, fileitem.path)
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
      modes = { "n", "x" },
      key = "<Backspace>",
      callback = function()
        local next_cwd = yoz.canonical_path.dirname(state_cwd:snapshot(), false) ---@type string
        state_cwd:next(next_cwd)
      end,
      desc = "file explorer: goto the parent dir",
    },
  },
})

state_cwd:subscribe(
  stl.c.Subscriber.new({
    on_next = function()
      if picker and not picker:isdisposed() then
        local data = fetch_data()
        picker:reset_data(data)
      end
    end,
  }),
  true
)

---@param specified_filepath            string|nil
---@return nil
local function find_explorer(specified_filepath)
  local dirpath_resolved = false ---@type boolean
  if specified_filepath ~= nil and #specified_filepath > 0 then
    local filepath = yoz.canonical_path.from_os_path(specified_filepath, false) ---@type string
    local os_filepath = yoz.canonical_path.to_os_path(filepath) ---@type string
    if yoz.path.is_exist_directory(os_filepath) then
      state_cwd:next(filepath, { force = true })
      dirpath_resolved = true
    elseif yoz.path.is_exist_file(os_filepath) then
      local dirpath = yoz.canonical_path.dirname(filepath, false) ---@type string
      state_cwd:next(dirpath, { force = true })
      dirpath_resolved = true
    end
  end
  if not dirpath_resolved then
    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    local winnr_sourcefile = dot.tab.retrieve_winnr_sourcefile(tabnr) ---@type integer|nil
    if winnr_sourcefile ~= nil then
      local bufnr = vim.api.nvim_win_get_buf(winnr_sourcefile) ---@type integer
      local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
      if #filepath > 0 then
        filepath = yoz.canonical_path.from_os_path(filepath, false)
        local os_filepath = yoz.canonical_path.to_os_path(filepath) ---@type string
        if yoz.path.is_exist_directory(os_filepath) then
          state_cwd:next(filepath, { force = true })
        elseif yoz.path.is_exist_file(os_filepath) then
          state_cwd:next(yoz.canonical_path.dirname(filepath, false), { force = true })
        end
      end
    end
  end

  local data = fetch_data()
  picker:reset_data(data)
  picker:focus()
end

return find_explorer
