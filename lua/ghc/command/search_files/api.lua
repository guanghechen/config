local session = require("ghc.context.session")
local state = require("ghc.command.search_files.state")

---@class ghc.command.search_files.IFileItem
---@field public children               string[]
---@field public fragmentary            boolean
---@field public filematch              ?fml.std.oxi.search.IFileMatch|nil

---@class ghc.command.search_files.IItem
---@field public filepath               string
---@field public offset                 integer
---@field public lnum                   integer
---@field public col                    integer
---@field public content                string

---@class ghc.command.search_files.IHighlight : fml.types.ui.IHighlight
---@field public offset                 integer

---@class ghc.command.search_files.IPreviewData
---@field public filetype               string|nil
---@field public highlights             ghc.command.search_files.IHighlight[]
---@field public lines                  string[]
---@field public title                  string

local _fileitem_map = {} ---@type table<string, ghc.command.search_files.IFileItem>
local _item_map = {} ---@type table<string, ghc.command.search_files.IItem>
local _last_preview_data = nil ---@type ghc.command.search_files.IPreviewData|nil
local _last_search_input = nil ---@type string|nil
local _last_search_result = nil ---@type fml.std.oxi.search.IResult|nil
fml.fn.watch_observables({
  session.search_exclude_patterns,
  session.search_flag_case_sensitive,
  session.search_flag_gitignore,
  session.search_flag_regex,
  session.search_include_patterns,
  session.search_max_filesize,
  session.search_max_matches,
  session.search_paths,
  state.search_cwd,
}, function()
  _last_preview_data = nil
  _last_search_input = nil
  _last_search_result = nil
  state.reload()
end, true)
fml.fn.watch_observables({
  session.search_flag_replace,
  session.search_replace_pattern,
}, function()
  _last_preview_data = nil
  state.reload()
end, true)

---@param lwidths                       integer[]
---@param l                             integer
---@param r                             integer
---@return integer
---@return integer
---@return integer
local function calc_same_line_pos(lwidths, l, r)
  local lnum = 1 ---@type integer
  local offset = 0 ---@type integer
  local lwidth = lwidths[1] + 1 ---@type integer
  while offset + lwidth <= l and lnum < #lwidths do
    lnum = lnum + 1
    offset = offset + lwidth
    lwidth = lwidths[lnum] + 1
  end

  local col = l - offset
  local col_end = math.min(lwidth, r - offset)
  return lnum, col, col_end
end

---@class ghc.command.search_files.api
local M = {}

---@param uuid                          string
---@return ghc.command.search_files.IPreviewData
---@return integer
---@return integer
function M.calc_preview_data(uuid)
  local item = _item_map[uuid] ---@type ghc.command.search_files.IItem|nil
  if item == nil then
    local lines = { "  Cannot retrieve the item by uuid=" .. uuid } ---@type string[]

    ---@type ghc.command.search_files.IHighlight[]
    local highlights = { { offset = -1, lnum = 1, coll = 0, colr = -1, hlname = "f_us_preview_error" } }

    ---@type ghc.command.search_files.IPreviewData
    local result = { filetype = nil, highlights = highlights, lines = lines, title = uuid }
    return result, 1, 0
  end

  local cwd = state.search_cwd:snapshot() ---@type string
  local filepath = fml.path.join(cwd, item.filepath) ---@type string
  local filename = fml.path.basename(filepath) ---@type string
  if not fc.is.printable_file(filename) then
    local lines = { "  Not a text file, cannot preview." } ---@type string[]

    ---@type ghc.command.search_files.IHighlight[]
    local highlights = { { offset = -1, lnum = 1, coll = 0, colr = -1, hlname = "f_us_preview_error" } }

    ---@type ghc.command.search_files.IPreviewData
    local result = { filetype = nil, highlights = highlights, lines = lines, title = item.filepath }
    return result, 1, 0
  end

  local filetype = vim.filetype.match({ filename = filename }) ---@type string|nil
  local flag_case_sensitive = session.search_flag_case_sensitive:snapshot() ---@type boolean
  local flag_regex = session.search_flag_regex:snapshot() ---@type boolean
  local flag_replace = session.search_flag_replace:snapshot() ---@type boolean
  local search_pattern = session.search_pattern:snapshot() ---@type string
  local replace_pattern = session.search_replace_pattern:snapshot() ---@type string
  local match_offset_cur = item.offset ---@type integer
  local match_offsets = M.collect_valid_match_offsets(uuid) ---@type integer[]
  local lines = {} ---@type string[]
  local highlights = {} ---@type ghc.command.search_files.IHighlight[]
  local cur_lnum = -1 ---@type integer
  local cur_col = 0 ---@type integer

  if flag_replace then
    ---@type fml.std.oxi.replace.replace_file_preview_advance_by_matches.IResult
    local preview_result = fml.oxi.replace_file_preview_advance_by_matches({
      flag_case_sensitive = flag_case_sensitive,
      flag_regex = flag_regex,
      search_pattern = search_pattern,
      replace_pattern = replace_pattern,
      filepath = filepath,
      keep_search_pieces = true,
      match_offsets = match_offsets,
    })

    lines = preview_result.lines ---@type string[]
    highlights = {} ---@type ghc.command.search_files.IHighlight[]
    local lwidths = preview_result.lwidths ---@type integer[]
    local matches = preview_result.matches ---@type fml.types.IMatchPoint[]

    local lnum0 = 1 ---@type integer
    local k = 1 ---@type integer
    local offset = 0 ---@type integer
    local lwidth = lwidths[1] + 1 ---@type integer

    local order = 0 ---@type integer
    local offset_delta = 0 ---@type integer
    local match_offset = 0 ---@type integer
    local is_search_match = false ---@type boolean
    for _, match in ipairs(matches) do
      is_search_match = not is_search_match
      if is_search_match then
        order = order + 1
        match_offset = match.l - offset_delta ---@type integer
      else
        offset_delta = offset_delta + (match.r - match.l)
      end

      local is_match_cur = match_offset_cur == match_offset or (match_offset_cur < 0 and order == 1) ---@type boolean
      local hlname = is_search_match and (is_match_cur and "f_us_preview_search_cur" or "f_us_preview_search")
        or (is_match_cur and "f_us_preview_replace_cur" or "f_us_preview_replace")

      local l = match.l ---@type integer
      local r = match.r ---@type integer
      while l < r do
        while l >= offset + lwidth and k < #lwidths do
          k = k + 1
          offset = offset + lwidth
          lwidth = lwidths[k] + 1
        end

        local lnum = lnum0 + k - 1 ---@type integer
        local col = l - offset ---@type integer
        local col_end = math.min(lwidth, r - offset) ---@type integer
        l = offset + lwidth ---@type integer

        ---@type ghc.command.search_files.IHighlight
        local highlight = { offset = match_offset, lnum = lnum, coll = col, colr = col_end, hlname = hlname }
        table.insert(highlights, highlight)

        if is_match_cur and cur_lnum < 0 then
          cur_lnum = lnum
          cur_col = col
        end
      end
    end
  else
    lines = fml.fs.read_file_as_lines({ filepath = filepath, silent = true }) ---@type string[]
    highlights = {} ---@type ghc.command.search_files.IHighlight[]

    local filematch = M.get_filematch(item.filepath) ---@type fml.std.oxi.search.IFileMatch|nil
    if filematch ~= nil then
      local order = 0 ---@type integer
      for _, block_match in ipairs(filematch.matches) do
        local lwidths = block_match.lwidths ---@type integer[]
        local lnum0 = block_match.lnum ---@type integer

        local k = 1 ---@type integer
        local offset = 0 ---@type integer
        local lwidth = lwidths[1] + 1 ---@type integer
        for _, search_match in ipairs(block_match.matches) do
          local match_offset = block_match.offset + search_match.l ---@type integer
          if fc.array.contains(match_offsets, match_offset) then
            order = order + 1 ---@type integer
            local is_match_cur = match_offset_cur == match_offset or (match_offset_cur < 0 and order == 1) ---@type boolean
            local hlname = is_match_cur and "f_us_match_cur" or "f_us_match" ---@type string

            local l = search_match.l ---@type integer
            local r = search_match.r ---@type integer
            while l < r do
              while l >= offset + lwidth and k < #lwidths do
                k = k + 1
                offset = offset + lwidth
                lwidth = lwidths[k] + 1
              end

              local lnum = lnum0 + k - 1 ---@type integer
              local col = l - offset ---@type integer
              local col_end = math.min(lwidth, r - offset) ---@type integer
              l = offset + lwidth ---@type integer

              ---@type ghc.command.search_files.IHighlight
              local highlight = { offset = match_offset, lnum = lnum, coll = col, colr = col_end, hlname = hlname }
              table.insert(highlights, highlight)

              if is_match_cur and cur_lnum < 0 then
                cur_lnum = lnum
                cur_col = col
              end
            end
          end
        end
      end
    end
  end

  ---@type ghc.command.search_files.IPreviewData
  local data = {
    filetype = filetype,
    highlights = highlights,
    lines = lines,
    title = item.filepath,
  }
  return data, cur_lnum < 0 and 1 or cur_lnum, cur_col
end

---@param uuid                          string
---@return integer[]
function M.collect_valid_match_offsets(uuid)
  local item = _item_map[uuid] ---@type ghc.command.search_files.IItem|nil
  if item == nil then
    return {}
  end

  local fileitem = _fileitem_map[item.filepath] ---@type ghc.command.search_files.IFileItem
  local offsets = {} ---@type integer[]
  for _, child_uuid in ipairs(fileitem.children) do
    if not state.has_item_deleted(child_uuid) then
      local child_item = _item_map[child_uuid]
      table.insert(offsets, child_item.offset)
    end
  end
  return offsets
end

---@param input_text                  string
---@param force                       boolean
---@param callback                    fml.types.ui.search.IFetchDataCallback
---@return nil
function M.fetch_data(input_text, force, callback)
  local cwd = state.search_cwd:snapshot() ---@type string
  local scope = session.search_scope:snapshot() ---@type ghc.enums.context.SearchScope
  local _, current_buf_path = fml.ui.search.get_current_path() ---@type string, string|nil
  local flag_case_sensitive = session.search_flag_case_sensitive:snapshot() ---@type boolean
  local flag_gitignore = session.search_flag_gitignore:snapshot() ---@type boolean
  local flag_regex = session.search_flag_regex:snapshot() ---@type boolean
  local flag_replace = session.search_flag_replace:snapshot() ---@type boolean
  local max_filesize = session.search_max_filesize:snapshot() ---@type string
  local max_matches = session.search_max_matches:snapshot() ---@type integer
  local search_paths = session.search_paths:snapshot() ---@type string
  local replace_pattern = session.search_replace_pattern:snapshot() ---@type string
  local include_patterns = session.search_include_patterns:snapshot() ---@type string
  local exclude_patterns = session.search_exclude_patterns:snapshot() ---@type string
  local is_searching_current_buf = scope == "B" and current_buf_path ~= nil ---@type boolean

  ---@type fml.std.oxi.search.IResult|nil
  local result = (
    not force
    and _last_search_input ~= nil
    and _last_search_input == input_text
    and _last_search_result ~= nil
  )
      and _last_search_result
    or fml.oxi.search({
      cwd = cwd,
      flag_case_sensitive = flag_case_sensitive,
      flag_gitignore = flag_gitignore,
      flag_regex = flag_regex,
      max_filesize = max_filesize,
      max_matches = max_matches,
      search_pattern = input_text,
      search_paths = search_paths,
      include_patterns = include_patterns,
      exclude_patterns = exclude_patterns,
      specified_filepath = scope == "B" and current_buf_path or nil,
    })

  if result == nil then
    callback(false, "Failed to run search command.")
    return
  end

  if result.error ~= nil or result.items == nil then
    callback(false, result.error)
    return
  end

  local search_items = {} ---@type fml.types.ui.search.IItem[]
  local fileitem_map = {} ---@type table<string, ghc.command.search_files.IFileItem>
  local item_map = {} ---@type table<string, ghc.command.search_files.IItem>
  for _, filepath in ipairs(result.item_orders) do
    local filematch = result.items[filepath] ---@type fml.std.oxi.search.IFileMatch|nil
    if filematch ~= nil then
      ---@type ghc.command.search_files.IFileItem
      local fileitem = {
        children = {},
        fragmentary = false,
        filematch = filematch,
      }
      fileitem_map[filepath] = fileitem

      local filename = fml.path.basename(filepath) ---@type string
      local icon, icon_hl = fml.util.calc_fileicon(filename)
      local icon_width = string.len(icon) ---@type integer
      local file_highlights = { { coll = 0, colr = icon_width, hlname = icon_hl } } ---@type fml.types.ui.IInlineHighlight[]

      local file_item_uuid = filepath ---@type string
      if not is_searching_current_buf then
        local text = icon .. " " .. filepath ---@type string

        ---@type fml.types.ui.search.IItem
        local search_item = {
          group = filepath,
          uuid = file_item_uuid,
          text = text,
          highlights = file_highlights,
        }
        table.insert(search_items, search_item)

        ---@type ghc.command.search_files.IItem
        local item = {
          filepath = filepath,
          offset = -1,
          lnum = 1,
          col = 0,
          content = filepath,
        }
        item_map[file_item_uuid] = item
      end

      if flag_replace then
        local lnum_delta = 0 ---@type integer
        for _, block_match in ipairs(filematch.matches) do
          ---@type fml.std.oxi.replace.replace_text_preview_advance.IResult
          local preview_result = fml.oxi.replace_text_preview_advance({
            flag_case_sensitive = flag_case_sensitive,
            flag_regex = flag_regex,
            keep_search_pieces = true,
            search_pattern = input_text,
            replace_pattern = replace_pattern,
            text = block_match.text,
          })

          local r_lines = preview_result.lines ---@type string[]
          local r_lwidths = preview_result.lwidths ---@type integer[]
          local r_matches = preview_result.matches ---@type fml.types.IMatchPoint[]
          local s_lines = block_match.lines ---@type string[]
          local s_lwidths = block_match.lwidths ---@type integer[]
          local s_matches = block_match.matches ---@type fml.types.IMatchPoint[]
          for i = 1, #s_matches, 1 do
            local original_search_match = s_matches[i] ---@type fml.types.IMatchPoint
            local k, col, col_end = calc_same_line_pos(s_lwidths, original_search_match.l, original_search_match.r)
            local line = s_lines[k] ---@type string
            local lnum = block_match.lnum + k - 1 ---@type integer

            local search_match = r_matches[i * 2 - 1] ---@type fml.types.IMatchPoint
            local s_k, s_col = calc_same_line_pos(r_lwidths, search_match.l, search_match.r)
            local s_lnum = block_match.lnum + s_k - 1 + lnum_delta ---@type integer

            local replace_match = r_matches[i * 2] ---@type fml.types.IMatchPoint
            local r_k, r_col, r_col_end = calc_same_line_pos(r_lwidths, replace_match.l, replace_match.r)
            local r_line = r_lines[r_k] ---@type string

            local text_prefix = "  " .. lnum .. ":" .. col .. " " ---@type string
            local width_prefix = string.len(text_prefix) ---@type integer
            local search_item ---@type fml.types.ui.search.IItem
            if s_k == r_k then
              local prettier_line = line:sub(1, col_end) .. r_line:sub(r_col + 1, r_col_end) .. line:sub(col_end + 1) ---@type string
              local text = text_prefix .. prettier_line .. fml.ui.icons.listchars.eol ---@type string

              ---@type fml.types.ui.IInlineHighlight[]
              local highlights = {
                { coll = 0, colr = width_prefix, hlname = "f_us_main_match_lnum" },
                { coll = width_prefix + col, colr = width_prefix + col_end, hlname = "f_us_main_search" },
                {
                  coll = width_prefix + col_end,
                  colr = width_prefix + col_end + (r_col_end - r_col),
                  hlname = "f_us_main_replace",
                },
              }

              ---@type fml.types.ui.search.IItem
              search_item = {
                group = filepath,
                parent = file_item_uuid,
                uuid = filepath .. text_prefix,
                text = text,
                highlights = highlights,
              }
            else
              local prettier_line = line ---@type string
              local text = text_prefix .. prettier_line .. fml.ui.icons.listchars.eol ---@type string

              ---@type fml.types.ui.IInlineHighlight[]
              local highlights = {
                { coll = 0, colr = width_prefix, hlname = "f_us_main_match_lnum" },
                { coll = width_prefix + col, colr = width_prefix + col_end, hlname = "f_us_main_search" },
              }

              ---@type fml.types.ui.search.IItem
              search_item = {
                group = filepath,
                parent = file_item_uuid,
                uuid = filepath .. text_prefix,
                text = text,
                highlights = highlights,
              }
            end

            table.insert(search_items, search_item)
            table.insert(fileitem.children, search_item.uuid)

            ---@type ghc.command.search_files.IItem
            local item = {
              filepath = filepath,
              offset = block_match.offset + original_search_match.l,
              lnum = s_lnum,
              col = s_col,
              content = s_lines[s_k],
            }
            item_map[search_item.uuid] = item
          end

          lnum_delta = lnum_delta + #r_lwidths - #s_lwidths
        end
      else
        for _, block_match in ipairs(filematch.matches) do
          local lines = block_match.lines ---@type string[]
          local lwidths = block_match.lwidths ---@type integer[]
          local matches = block_match.matches ---@type fml.types.IMatchPoint[]
          for _, search_match in ipairs(matches) do
            local k, col, col_end = calc_same_line_pos(lwidths, search_match.l, search_match.r)
            local lnum = block_match.lnum + k - 1 ---@type integer

            local text_prefix = "  " .. lnum .. ":" .. col .. " " ---@type string
            local text = text_prefix .. lines[k] .. fml.ui.icons.listchars.eol ---@type string
            local width_prefix = string.len(text_prefix) ---@type integer

            ---@type fml.types.ui.IInlineHighlight[]
            local highlights = {
              { coll = 0, colr = width_prefix, hlname = "f_us_main_match_lnum" },
              { coll = width_prefix + col, colr = width_prefix + col_end, hlname = "f_us_main_match" },
            }

            ---@type fml.types.ui.search.IItem
            local search_item = {
              group = filepath,
              parent = file_item_uuid,
              uuid = filepath .. text_prefix,
              text = text,
              highlights = highlights,
            }
            table.insert(search_items, search_item)
            table.insert(fileitem.children, search_item.uuid)

            ---@type ghc.command.search_files.IItem
            local item = {
              filepath = filepath,
              offset = block_match.offset + search_match.l,
              lnum = lnum,
              col = col,
              content = lines[k],
            }
            item_map[search_item.uuid] = item
          end
        end
      end
    end
  end

  _last_search_result = result
  _last_preview_data = nil
  _fileitem_map = fileitem_map
  _item_map = item_map

  local data = { items = search_items } ---@type fml.types.ui.search.IData
  callback(true, data)
end

---@param search_item                   fml.types.ui.search.IItem
---@return fml.ui.search.preview.IData
function M.fetch_preview_data(search_item)
  local preview_data, lnum, col = M.calc_preview_data(search_item.uuid) ---@type ghc.command.search_files.IPreviewData
  _last_preview_data = preview_data

  ---@type fml.ui.search.preview.IData
  return {
    filetype = preview_data.filetype,
    title = preview_data.title,
    lines = preview_data.lines,
    highlights = preview_data.highlights,
    lnum = lnum,
    col = col,
  }
end

---@return fml.types.IQuickFixItem[]
function M.gen_quickfix_items()
  local cwd = fml.path.cwd() ---@type string
  local search_cwd = state.search_cwd:snapshot() ---@type string
  local quickfix_items = {} ---@type fml.types.IQuickFixItem[]
  for _, item in pairs(_item_map) do
    if item.offset >= 0 then
      local absolute_filepath = fml.path.join(search_cwd, item.filepath) ---@type string
      local relative_filepath = fml.path.relative(cwd, absolute_filepath, false) ---@type string
      table.insert(quickfix_items, {
        filename = relative_filepath,
        lnum = item.lnum,
        col = item.col,
        text = item.content,
      })
    end
  end
  return quickfix_items
end

---@param filepath                      string
---@return fml.std.oxi.search.IFileMatch|nil
function M.get_filematch(filepath)
  local fileitem = _fileitem_map[filepath] ---@type ghc.command.search_files.IFileItem|nil
  if fileitem == nil then
    return nil
  end

  if fileitem.filematch == nil then
    M.refresh_file_item(filepath)
  end
  return fileitem.filematch
end

---@param item                          fml.types.ui.search.IItem
---@param frecency                      fml.types.collection.IFrecency
---@return boolean
function M.open_file(item, frecency)
  local cwd = state.search_cwd:snapshot() ---@type string
  local workspace = fml.path.workspace() ---@type string
  local data = _item_map and _item_map[item.uuid] ---@type ghc.command.search_files.IItem|nil
  if data ~= nil then
    local absolute_filepath = fml.path.join(cwd, data.filepath) ---@type string
    local relative_filepath = fml.path.relative(workspace, absolute_filepath, true) ---@type string
    frecency:access(relative_filepath)
    local opened = fml.api.buf.open_in_current_valid_win(absolute_filepath) ---@type boolean

    if opened then
      vim.schedule(function()
        local lnum = data.lnum ---@type integer|nil
        local col = data.col ---@type integer|nil
        if lnum ~= nil and col ~= nil then
          vim.api.nvim_win_set_cursor(0, { lnum, col })
        end
      end)
      return true
    end
  end
  return false
end

---@param search_item                   fml.types.ui.search.IItem
---@param last_search_item              fml.types.ui.search.IItem
---@param last_data                     fml.ui.search.preview.IData
---@diagnostic disable-next-line: unused-local
function M.patch_preview_data(search_item, last_search_item, last_data)
  local item = _item_map[search_item.uuid] ---@type ghc.command.search_files.IItem|nil
  if _last_preview_data == nil or item == nil then
    return M.fetch_preview_data(search_item)
  end

  local highlights = {} ---@type fml.types.ui.IHighlight[]
  local cur_lnum = -1 ---@type integer
  local cur_col = 0 ---@type integer
  local flag_replace = session.search_flag_replace:snapshot() ---@type boolean
  local match_offset_cur = item.offset ---@type integer

  if flag_replace then
    local order = 0 ---@type integer
    local offset = -1 ---@type integer
    for _, hl in ipairs(_last_preview_data.highlights) do
      if hl.offset ~= offset then
        offset = hl.offset
        order = order + 1
      end

      local is_match_cur = match_offset_cur == hl.offset or (match_offset_cur < 0 and order == 1) ---@type boolean
      local is_search_match = hl.hlname == "f_us_preview_search_cur" or hl.hlname == "f_us_preview_search"
      local hlname = is_search_match and (is_match_cur and "f_us_preview_search_cur" or "f_us_preview_search")
        or (is_match_cur and "f_us_preview_replace_cur" or "f_us_preview_replace")

      local highlight = { lnum = hl.lnum, coll = hl.coll, colr = hl.colr, hlname = hlname } ---@type fml.types.ui.IHighlight
      table.insert(highlights, highlight)

      if is_match_cur and cur_lnum < 0 then
        cur_lnum = hl.lnum
        cur_col = hl.coll
      end
    end
  else
    local order = 0 ---@type integer
    local offset = -1 ---@type integer
    for _, hl in ipairs(_last_preview_data.highlights) do
      if hl.offset ~= offset then
        offset = hl.offset
        order = order + 1
      end

      local is_match_cur = match_offset_cur == hl.offset or (match_offset_cur < 0 and order == 1) ---@type boolean
      local hlname = is_match_cur and "f_us_match_cur" or "f_us_match" ---@type string
      local highlight = { lnum = hl.lnum, coll = hl.coll, colr = hl.colr, hlname = hlname } ---@type fml.types.ui.IHighlight
      table.insert(highlights, highlight)

      if is_match_cur and cur_lnum < 0 then
        cur_lnum = hl.lnum
        cur_col = hl.coll
      end
    end
  end

  ---@type fml.ui.search.preview.IData
  local data = {
    lines = last_data.lines,
    highlights = highlights or last_data.highlights,
    filetype = last_data.filetype,
    title = last_data.title,
    lnum = cur_lnum < 0 and 1 or cur_lnum,
    col = cur_col,
  }
  return data
end

---@param filepath                      string
---@return nil
function M.refresh_file_item(filepath)
  if _last_search_result ~= nil then
    local cwd = state.search_cwd:snapshot() ---@type string
    local flag_case_sensitive = session.search_flag_case_sensitive:snapshot() ---@type boolean
    local flag_gitignore = session.search_flag_gitignore:snapshot() ---@type boolean
    local flag_regex = session.search_flag_regex:snapshot() ---@type boolean
    local max_filesize = session.search_max_filesize:snapshot() ---@type string
    local max_matches = session.search_max_matches:snapshot() ---@type integer
    local search_paths = session.search_paths:snapshot() ---@type string
    local search_pattern = session.search_pattern:snapshot() ---@type string
    local include_patterns = session.search_include_patterns:snapshot() ---@type string
    local exclude_patterns = session.search_exclude_patterns:snapshot() ---@type string
    local specified_filepath = fml.path.join(cwd, filepath) ---@type string

    ---@type fml.std.oxi.search.IResult|nil
    local partial_search_result = fml.oxi.search({
      cwd = cwd,
      flag_case_sensitive = flag_case_sensitive,
      flag_gitignore = flag_gitignore,
      flag_regex = flag_regex,
      max_filesize = max_filesize,
      max_matches = max_matches,
      search_pattern = search_pattern,
      search_paths = search_paths,
      include_patterns = include_patterns,
      exclude_patterns = exclude_patterns,
      specified_filepath = specified_filepath,
    })

    if partial_search_result ~= nil and partial_search_result.error == nil and partial_search_result.items ~= nil then
      _last_search_result.items[filepath] = nil
      for _, raw_filepath in ipairs(partial_search_result.item_orders) do
        local filematch = partial_search_result.items[raw_filepath] ---@type fml.std.oxi.search.IFileMatch|nil
        if filematch ~= nil then
          _last_search_result.items[raw_filepath] = filematch
        end
      end

      local fileitem = _fileitem_map[filepath]
      if fileitem ~= nil then
        local filematch = _last_search_result.items[filepath]
        fileitem.filematch = filematch
      end
    end
  end

  _last_preview_data = nil
end

---@param uuid                          string
---@return nil
function M.replace_file(uuid)
  local item = _item_map[uuid] ---@type ghc.command.search_files.IItem|nil
  if item == nil then
    return
  end

  local fileitem = _fileitem_map[item.filepath] ---@type ghc.command.search_files.IFileItem|nil
  if fileitem == nil then
    return
  end

  local cwd = state.search_cwd:snapshot() ---@type string
  local filepath = item.filepath ---@type string
  local flag_case_sensitive = session.search_flag_case_sensitive:snapshot() ---@type boolean
  local flag_regex = session.search_flag_regex:snapshot() ---@type boolean
  local search_pattern = session.search_pattern:snapshot() ---@type string
  local replace_pattern = session.search_replace_pattern:snapshot() ---@type string

  if item.offset >= 0 then
    local children = fileitem.children ---@type string[]
    local remain_child_uuids = {} ---@type string[]
    local remain_offsets = {} ---@type integer[]
    local N = #children ---@type integer
    local k = 1 ---@type integer
    for i = 1, N, 1 do
      local child_uuid = children[i] ---@type string
      if child_uuid ~= uuid and not state.has_item_deleted(child_uuid) then
        remain_child_uuids[k] = child_uuid
        remain_offsets[k] = _item_map[child_uuid].offset
        k = k + 1
      end
    end

    local succeed, locations = fml.oxi.replace_file_advance_by_matches({
      cwd = cwd,
      filepath = filepath,
      flag_case_sensitive = flag_case_sensitive,
      flag_regex = flag_regex,
      search_pattern = search_pattern,
      replace_pattern = replace_pattern,
      match_offsets = { item.offset },
      remain_offsets = remain_offsets,
    })

    if not succeed then
      return
    end

    if #locations ~= #remain_offsets then
      fc.reporter.error({
        from = "ghc.command.search_files.api",
        subject = "replace_file",
        mesage = "Bad locations, the size of locations should match the given remain_offsets.",
        details = {
          cwd = cwd,
          item = item,
          locations = locations,
          remain_offsets = remain_offsets,
          remain_child_uuids = remain_child_uuids,
        },
      })
      return
    end

    _item_map[uuid] = nil
    fileitem.children = remain_child_uuids
    fileitem.filematch = nil
    fileitem.fragmentary = true
    if _last_search_result ~= nil then
      _last_search_result.items[item.filepath] = nil
    end

    for i = 1, #locations, 1 do
      local child_uuid = remain_child_uuids[i] ---@type string
      local child_item = _item_map[child_uuid] ---@type ghc.command.search_files.IItem
      local location = locations[i] ---@type fml.types.IMatchLocation
      child_item.offset = location.offset
      child_item.lnum = location.lnum
      child_item.col = location.col
    end

    ---! Refresh the filematch and preview data and lnum/cols
    _last_preview_data = M.calc_preview_data(uuid)
    state.mark_item_deleted(uuid)
    return
  end

  if not fileitem.fragmentary then
    for _, child_uuid in ipairs(fileitem.children) do
      if state.has_item_deleted(child_uuid) then
        fileitem.fragmentary = true
        break
      end
    end
  end

  local succeed = false ---@type boolean
  if fileitem.fragmentary then
    local match_offsets = {} ---@type string[]
    for _, child_uuid in ipairs(fileitem.children) do
      if not state.has_item_deleted(child_uuid) then
        local child_item = _item_map[child_uuid]
        table.insert(match_offsets, child_item.offset)
      end
    end

    ---@type boolean
    succeed = fml.oxi.replace_file_by_matches({
      cwd = cwd,
      filepath = filepath,
      flag_case_sensitive = flag_case_sensitive,
      flag_regex = flag_regex,
      search_pattern = search_pattern,
      replace_pattern = replace_pattern,
      match_offsets = match_offsets,
    })
  else
    ---@type boolean
    succeed = fml.oxi.replace_file({
      cwd = cwd,
      filepath = filepath,
      flag_case_sensitive = flag_case_sensitive,
      flag_regex = flag_regex,
      search_pattern = search_pattern,
      replace_pattern = replace_pattern,
    })
  end

  if succeed then
    for _, child_uuid in ipairs(fileitem.children) do
      _item_map[child_uuid] = nil
    end
    _fileitem_map[item.filepath] = nil
    _item_map[uuid] = nil
    state.mark_item_deleted(uuid)
  end
end

---@return nil
function M.replace_file_all()
  for filepath, fileitem in pairs(_fileitem_map) do
    local cwd = state.search_cwd:snapshot() ---@type string
    local flag_case_sensitive = session.search_flag_case_sensitive:snapshot() ---@type boolean
    local flag_regex = session.search_flag_regex:snapshot() ---@type boolean
    local search_pattern = session.search_pattern:snapshot() ---@type string
    local replace_pattern = session.search_replace_pattern:snapshot() ---@type string

    if not fileitem.fragmentary then
      for _, child_uuid in ipairs(fileitem.children) do
        if state.has_item_deleted(child_uuid) then
          fileitem.fragmentary = true
          break
        end
      end
    end

    if fileitem.fragmentary then
      local match_offsets = {} ---@type string[]
      for _, child_uuid in ipairs(fileitem.children) do
        if not state.has_item_deleted(child_uuid) then
          local child_item = _item_map[child_uuid]
          table.insert(match_offsets, child_item.offset)
        end
      end

      fml.oxi.replace_file_by_matches({
        cwd = cwd,
        filepath = filepath,
        flag_case_sensitive = flag_case_sensitive,
        flag_regex = flag_regex,
        search_pattern = search_pattern,
        replace_pattern = replace_pattern,
        match_offsets = match_offsets,
      })
    else
      ---@type boolean
      fml.oxi.replace_file({
        cwd = cwd,
        filepath = filepath,
        flag_case_sensitive = flag_case_sensitive,
        flag_regex = flag_regex,
        search_pattern = search_pattern,
        replace_pattern = replace_pattern,
      })
    end
  end

  _fileitem_map = {}
  _item_map = {}
  _last_preview_data = nil
  _last_search_input = nil
  _last_search_result = nil
  state:mark_all_items_deleted()
end

return M
