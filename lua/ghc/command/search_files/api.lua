local session = require("ghc.context.session")
local state = require("ghc.command.search_files.state")

---@class ghc.command.search_files.IItemData
---@field public filepath               string
---@field public filematch              fml.std.oxi.search.IFileMatch
---@field public match_idx              integer
---@field public lnum                   ?integer
---@field public col                    ?integer

---@class ghc.command.search_files.IHighlight : fml.types.ui.IHighlight
---@field public match_idx              integer

---@class ghc.command.search_files.IPreviewData
---@field public filetype               string|nil
---@field public highlights             ghc.command.search_files.IHighlight[]
---@field public lines                  string[]
---@field public title                  string

local _item_data_map = {} ---@type table<string, ghc.command.search_files.IItemData>
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
  local col_end = math.min(lwidth - 1, r - offset)
  return lnum, col, col_end
end

---@class ghc.command.search_files.api
local M = {}

---@param item                          fml.types.ui.search.IItem
---@return ghc.command.search_files.IPreviewData
function M.calc_preview_data(item)
  local item_data = _item_data_map[item.uuid] ---@type ghc.command.search_files.IItemData|nil
  if item_data == nil then
    local lines = { "  Cannot retrieve the item by uuid=" .. item.uuid } ---@type string[]
    ---@type ghc.command.search_files.IHighlight[]
    local highlights = { { match_idx = 0, lnum = 1, coll = 0, colr = -1, hlname = "f_us_preview_error" } }
    ---@type ghc.command.search_files.IPreviewData
    local result = {
      filetype = nil,
      highlights = highlights,
      lines = lines,
      title = item.uuid,
    }
    return result
  end

  local cwd = state.search_cwd:snapshot() ---@type string
  local filepath = fml.path.join(cwd, item_data.filepath) ---@type string
  local filename = fml.path.basename(filepath) ---@type string
  if not fml.is.printable_file(filename) then
    local lines = { "  Not a text file, cannot preview." } ---@type string[]
    ---@type ghc.command.search_files.IHighlight[]
    local highlights = { { match_idx = 0, lnum = 1, coll = 0, colr = -1, hlname = "f_us_preview_error" } }
    ---@type ghc.command.search_files.IPreviewData
    local result = {
      filetype = nil,
      highlights = highlights,
      lines = lines,
      title = item_data.filepath,
    }
    return result
  end

  local filetype = vim.filetype.match({ filename = filename }) ---@type string|nil
  local flag_case_sensitive = session.search_flag_case_sensitive:snapshot() ---@type boolean
  local flag_regex = session.search_flag_regex:snapshot() ---@type boolean
  local flag_replace = session.search_flag_replace:snapshot() ---@type boolean
  local search_pattern = session.search_pattern:snapshot() ---@type string
  local replace_pattern = session.search_replace_pattern:snapshot() ---@type string
  local match_idx_cur = item_data.match_idx == 0 and 1 or item_data.match_idx ---@type integer

  if flag_replace then
    ---@type fml.std.oxi.replace.replace_file_preview_with_matches.IResult
    local preview_result = fml.oxi.replace_file_preview_with_matches({
      flag_case_sensitive = flag_case_sensitive,
      flag_regex = flag_regex,
      search_pattern = search_pattern,
      replace_pattern = replace_pattern,
      filepath = filepath,
      keep_search_pieces = true,
    })

    local lines = preview_result.lines ---@type string[]
    local lwidths = preview_result.lwidths ---@type integer[]
    local matches = preview_result.matches ---@type fml.std.oxi.search.IMatchPoint[]
    local highlights = {} ---@type ghc.command.search_files.IHighlight[]

    local lnum0 = 1 ---@type integer
    local k = 1 ---@type integer
    local offset = 0 ---@type integer
    local lwidth = lwidths[1] + 1 ---@type integer
    local is_search_match = false ---@type boolean
    local match_idx = 0.5 ---@type number
    for p_match_idx, match in ipairs(matches) do
      is_search_match = not is_search_match
      match_idx = match_idx + 0.5
      local hlname = is_search_match
          and (match_idx == match_idx_cur and "f_us_preview_search_cur" or "f_us_preview_search")
        or (match_idx == match_idx_cur and "f_us_preview_replace_cur" or "f_us_preview_replace")

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
        local col_end = math.min(lwidth - 1, r - offset) ---@type integer
        l = offset + lwidth ---@type integer

        ---@type ghc.command.search_files.IHighlight
        local highlight = { match_idx = p_match_idx, lnum = lnum, coll = col, colr = col_end, hlname = hlname }
        table.insert(highlights, highlight)
      end
    end

    ---@type ghc.command.search_files.IPreviewData
    local result = {
      filetype = filetype,
      highlights = highlights,
      lines = lines,
      title = item_data.filepath,
    }
    return result
  else
    local file_match = item_data.filematch ---@type fml.std.oxi.search.IFileMatch
    local lines = fml.fs.read_file_as_lines({ filepath = filepath, silent = true }) ---@type string[]
    local highlights = {} ---@type ghc.command.search_files.IHighlight[]
    local match_idx = 0 ---@type integer
    for _, block_match in ipairs(file_match.matches) do
      local lwidths = block_match.lwidths ---@type integer[]
      local lnum0 = block_match.lnum ---@type integer

      local k = 1 ---@type integer
      local offset = 0 ---@type integer
      local lwidth = lwidths[1] + 1 ---@type integer
      for _, match in ipairs(block_match.matches) do
        match_idx = match_idx + 1
        local hlname = match_idx == match_idx_cur and "f_us_match_cur" or "f_us_match" ---@type string

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
          local col_end = math.min(lwidth - 1, r - offset) ---@type integer
          l = offset + lwidth ---@type integer

          ---@type ghc.command.search_files.IHighlight
          local highlight = { match_idx = match_idx, lnum = lnum, coll = col, colr = col_end, hlname = hlname }
          table.insert(highlights, highlight)
        end
      end
    end

    ---@type ghc.command.search_files.IPreviewData
    local result = {
      filetype = filetype,
      highlights = highlights,
      lines = lines,
      title = item_data.filepath,
    }
    return result
  end
end

---@param input_text                  string
---@param callback                    fml.types.ui.search.IFetchItemsCallback
---@return nil
function M.fetch_items(input_text, callback)
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
  local result = (_last_search_input ~= nil and _last_search_input == input_text and _last_search_result ~= nil)
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

  local items = {} ---@type fml.types.ui.search.IItem[]
  local item_data_map = {} ---@type table<string, ghc.command.search_files.IItemData>
  for _, raw_filepath in ipairs(result.item_orders) do
    local file_match = result.items[raw_filepath] ---@type fml.std.oxi.search.IFileMatch|nil
    if file_match ~= nil then
      local filename = fml.path.basename(raw_filepath) ---@type string
      local filepath = fml.path.relative(cwd, raw_filepath) ---@type string
      local icon, icon_hl = fml.util.calc_fileicon(filename)
      local icon_width = string.len(icon) ---@type integer
      local file_highlights = { { coll = 0, colr = icon_width, hlname = icon_hl } } ---@type fml.types.ui.IInlineHighlight[]

      local file_item_uuid = filepath ---@type string
      if not is_searching_current_buf then
        ---@type fml.types.ui.search.IItem
        local file_item = {
          group = filepath,
          uuid = file_item_uuid,
          text = icon .. " " .. filepath,
          highlights = file_highlights,
        }
        table.insert(items, file_item)
      end

      if flag_replace then
        local lnum_delta = 0 ---@type integer
        local match_idx = 0 ---@type integer
        for _, block_match in ipairs(file_match.matches) do
          ---@type fml.std.oxi.replace.replace_text_preview_with_matches.IResult
          local preview_result = fml.oxi.replace_text_preview_with_matches({
            flag_case_sensitive = flag_case_sensitive,
            flag_regex = flag_regex,
            keep_search_pieces = true,
            search_pattern = input_text,
            replace_pattern = replace_pattern,
            text = block_match.text,
          })

          local r_lines = preview_result.lines ---@type string[]
          local r_lwidths = preview_result.lwidths ---@type integer[]
          local r_matches = preview_result.matches ---@type fml.std.oxi.search.IMatchPoint[]
          local s_lines = block_match.lines ---@type string[]
          local s_lwidths = block_match.lwidths ---@type integer[]
          local s_matches = block_match.matches ---@type fml.std.oxi.search.IMatchPoint[]
          for i = 1, #s_matches, 1 do
            match_idx = match_idx + 1
            local original_search_match = s_matches[i] ---@type fml.std.oxi.search.IMatchPoint
            local k, col, col_end = calc_same_line_pos(s_lwidths, original_search_match.l, original_search_match.r)
            local line = s_lines[k] ---@type string
            local lnum = block_match.lnum + k - 1 ---@type integer

            local search_match = r_matches[i * 2 - 1] ---@type fml.std.oxi.search.IMatchPoint
            local s_k, s_col = calc_same_line_pos(r_lwidths, search_match.l, search_match.r)
            local s_lnum = block_match.lnum + s_k - 1 + lnum_delta ---@type integer

            local replace_match = r_matches[i * 2] ---@type fml.std.oxi.search.IMatchPoint
            local r_k, r_col, r_col_end = calc_same_line_pos(r_lwidths, replace_match.l, replace_match.r)
            local r_line = r_lines[r_k] ---@type string

            local text_prefix = "  " .. lnum .. ":" .. col .. " " ---@type string
            local width_prefix = string.len(text_prefix) ---@type integer
            local item ---@type fml.types.ui.search.IItem
            if s_k == r_k then
              local prettier_line = line:sub(1, col_end) .. r_line:sub(r_col + 1, r_col_end) .. line:sub(col_end + 1) ---@type string
              local text = text_prefix .. prettier_line ---@type string

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
              item = { group = filepath, uuid = filepath .. text_prefix, text = text, highlights = highlights }
            else
              local prettier_line = line ---@type string
              local text = text_prefix .. prettier_line ---@type string

              ---@type fml.types.ui.IInlineHighlight[]
              local highlights = {
                { coll = 0, colr = width_prefix, hlname = "f_us_main_match_lnum" },
                { coll = width_prefix + col, colr = width_prefix + col_end, hlname = "f_us_main_search" },
              }

              ---@type fml.types.ui.search.IItem
              item = { group = filepath, uuid = filepath .. text_prefix, text = text, highlights = highlights }
            end

            table.insert(items, item)

            ---@type ghc.command.search_files.IItemData
            local item_data = {
              filepath = filepath,
              filematch = file_match,
              match_idx = match_idx,
              lnum = s_lnum,
              col = s_col,
            }
            item_data_map[item.uuid] = item_data

            if not is_searching_current_buf then
              if item_data_map[file_item_uuid] == nil then
                ---@type ghc.command.search_files.IItemData
                local file_item_data = {
                  filepath = filepath,
                  filematch = file_match,
                  match_idx = 0,
                  lnum = s_lnum,
                  col = s_col,
                }
                item_data_map[file_item_uuid] = file_item_data
              end
            end
          end

          lnum_delta = lnum_delta + #r_lwidths - #s_lwidths
        end
      else
        local match_idx = 0 ---@type integer
        for _, block_match in ipairs(file_match.matches) do
          local lines = block_match.lines ---@type string[]
          local lwidths = block_match.lwidths ---@type integer[]
          local matches = block_match.matches ---@type fml.std.oxi.search.IMatchPoint[]
          for _, search_match in ipairs(matches) do
            match_idx = match_idx + 1
            local k, col, col_end = calc_same_line_pos(lwidths, search_match.l, search_match.r)
            local lnum = block_match.lnum + k - 1 ---@type integer

            local text_prefix = "  " .. lnum .. ":" .. col .. " " ---@type string
            local text = text_prefix .. lines[k] ---@type string
            local width_prefix = string.len(text_prefix) ---@type integer

            ---@type fml.types.ui.IInlineHighlight[]
            local highlights = {
              { coll = 0, colr = width_prefix, hlname = "f_us_main_match_lnum" },
              { coll = width_prefix + col, colr = width_prefix + col_end, hlname = "f_us_main_match" },
            }

            ---@type fml.types.ui.search.IItem
            local item = { group = filepath, uuid = filepath .. text_prefix, text = text, highlights = highlights }
            table.insert(items, item)

            ---@type ghc.command.search_files.IItemData
            local item_data = {
              filepath = filepath,
              filematch = file_match,
              match_idx = match_idx,
              lnum = lnum,
              col = col,
            }
            item_data_map[item.uuid] = item_data

            if not is_searching_current_buf then
              if item_data_map[file_item_uuid] == nil then
                ---@type ghc.command.search_files.IItemData
                local file_item_data = {
                  filepath = filepath,
                  filematch = file_match,
                  match_idx = 0,
                  lnum = lnum,
                  col = col,
                }
                item_data_map[file_item_uuid] = file_item_data
              end
            end
          end
        end
      end

      if item_data_map[file_item_uuid] == nil then
        ---@type ghc.command.search_files.IItemData
        local file_item_data = { filepath = filepath, filematch = file_match, match_idx = 0 }
        item_data_map[file_item_uuid] = file_item_data
      end
    end
  end
  _item_data_map = item_data_map
  callback(true, items)
end

---@param item                          fml.types.ui.search.IItem
---@return fml.ui.search.preview.IData
function M.fetch_preview_data(item)
  local preview_data = M.calc_preview_data(item) ---@type ghc.command.search_files.IPreviewData
  _last_preview_data = preview_data

  local item_data = _item_data_map[item.uuid] ---@type ghc.command.search_files.IItemData|nil
  ---@type fml.ui.search.preview.IData
  local data = {
    filetype = preview_data.filetype,
    title = preview_data.title,
    lines = preview_data.lines,
    highlights = preview_data.highlights,
    lnum = item_data and item_data.lnum,
    col = item_data and item_data.col,
  }
  return data
end

---@param uuid                          string
---@return ghc.command.search_files.IItemData|nil
function M.get_item_data(uuid)
  return _item_data_map and _item_data_map[uuid]
end

---@param item                          fml.types.ui.search.IItem
---@param frecency                      fml.types.collection.IFrecency
---@return boolean
function M.open_file(item, frecency)
  local winnr = fml.api.state.win_history:present() ---@type integer
  if winnr ~= nil then
    local cwd = state.search_cwd:snapshot() ---@type string
    local workspace = fml.path.workspace() ---@type string
    local data = _item_data_map and _item_data_map[item.uuid] ---@type ghc.command.search_files.IItemData|nil
    if data ~= nil then
      local absolute_filepath = fml.path.join(cwd, data.filepath) ---@type string
      local relative_filepath = fml.path.relative(workspace, absolute_filepath) ---@type string
      frecency:access(relative_filepath)

      vim.schedule(function()
        fml.api.buf.open(winnr, absolute_filepath)
        local lnum = data.lnum ---@type integer|nil
        local col = data.col ---@type integer|nil
        if lnum ~= nil and col ~= nil then
          vim.api.nvim_win_set_cursor(0, { lnum, col })
        end
      end)
    end
    return true
  end
  return false
end

---@param item                          fml.types.ui.search.IItem
---@param last_item                     fml.types.ui.search.IItem
---@param last_data                     fml.ui.search.preview.IData
---@diagnostic disable-next-line: unused-local
function M.patch_preview_data(item, last_item, last_data)
  local item_data = _item_data_map[item.uuid] ---@type ghc.command.search_files.IItemData|nil
  if _last_preview_data == nil or item_data == nil then
    return M.fetch_preview_data(item)
  end

  local match_idx_cur = item_data.match_idx == 0 and 1 or item_data.match_idx ---@type integer
  local flag_replace = session.search_flag_replace:snapshot() ---@type boolean
  local highlights = {} ---@type fml.types.ui.IHighlight[]
  if flag_replace then
    for _, hl in ipairs(_last_preview_data.highlights) do
      local is_search_match = hl.match_idx % 2 == 1 ---@type boolean
      local match_idx = is_search_match and ((hl.match_idx + 1) / 2) or (hl.match_idx / 2) ---@type integer
      local hlname = is_search_match
          and (match_idx == match_idx_cur and "f_us_preview_search_cur" or "f_us_preview_search")
        or (match_idx == match_idx_cur and "f_us_preview_replace_cur" or "f_us_preview_replace")
      local highlight = { lnum = hl.lnum, coll = hl.coll, colr = hl.colr, hlname = hlname } ---@type fml.types.ui.IHighlight
      table.insert(highlights, highlight)
    end
  else
    for _, hl in ipairs(_last_preview_data.highlights) do
      local match_idx = hl.match_idx ---@type integer
      local hlname = match_idx == match_idx_cur and "f_us_match_cur" or "f_us_match" ---@type string
      local highlight = { lnum = hl.lnum, coll = hl.coll, colr = hl.colr, hlname = hlname } ---@type fml.types.ui.IHighlight
      table.insert(highlights, highlight)
    end
  end

  ---@type fml.ui.search.preview.IData
  local data = {
    lines = last_data.lines,
    highlights = highlights or last_data.highlights,
    filetype = last_data.filetype,
    title = last_data.title,
    lnum = item_data.lnum,
    col = item_data.col,
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
        local file_match = partial_search_result.items[raw_filepath] ---@type fml.std.oxi.search.IFileMatch|nil
        if file_match ~= nil then
          _last_search_result.items[raw_filepath] = file_match
        end
      end
    end
  end

  _last_preview_data = nil
end

return M
