local session = require("ghc.context.session")
local statusline = require("ghc.ui.statusline")
local state_frecency = require("ghc.state.frecency")
local state_input_history = require("ghc.state.input_history")

---@class ghc.command.search_files
local M = {}

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

local initial_dirpath = vim.fn.expand("%:p:h") ---@type string
local state_dirpath = fml.collection.Observable.from_value(initial_dirpath)
local state_search_cwd = fml.collection.Observable.from_value(session.get_search_scope_cwd(initial_dirpath))

local _last_preview_data = nil ---@type ghc.command.search_files.IPreviewData|nil
local _last_search_input = nil ---@type string|nil
local _last_search_result = nil ---@type fml.std.oxi.search.IResult|nil
local _item_data_map = {} ---@type table<string, ghc.command.search_files.IItemData>
fml.fn.watch_observables({ session.search_scope }, function()
  local current_search_cwd = state_search_cwd:snapshot() ---@type string
  local dirpath = state_dirpath:snapshot() ---@type string
  local next_search_cwd = session.get_search_scope_cwd(dirpath) ---@type string
  if current_search_cwd ~= next_search_cwd then
    state_search_cwd:next(next_search_cwd)
  end
end, true)
fml.fn.watch_observables({
  session.search_exclude_patterns,
  session.search_flag_case_sensitive,
  session.search_flag_gitignore,
  session.search_flag_regex,
  session.search_include_patterns,
  session.search_max_filesize,
  session.search_max_matches,
  session.search_paths,
  state_search_cwd,
}, function()
  _last_preview_data = nil
  _last_search_input = nil
  _last_search_result = nil
  M.reload()
end, true)
fml.fn.watch_observables({
  session.search_flag_replace,
  session.search_replace_pattern,
}, function()
  _last_preview_data = nil
  M.reload()
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

---@param input_text                  string
---@param callback                    fml.types.ui.search.IFetchItemsCallback
---@return nil
local function fetch_items(input_text, callback)
  local cwd = state_search_cwd:snapshot() ---@type string
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

  ---@type fml.std.oxi.search.IResult
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
      specified_filepath = nil,
    })

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

      ---@type fml.types.ui.search.IItem
      local file_item = {
        group = filepath,
        uuid = filepath,
        text = icon .. " " .. filepath,
        highlights = file_highlights,
      }
      table.insert(items, file_item)

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

            if item_data_map[file_item.uuid] == nil then
              ---@type ghc.command.search_files.IItemData
              local file_item_data = {
                filepath = filepath,
                filematch = file_match,
                match_idx = 0,
                lnum = s_lnum,
                col = s_col,
              }
              item_data_map[file_item.uuid] = file_item_data
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
            item_data_map[file_item.uuid] = item_data_map[file_item.uuid] or item_data
          end
        end
      end

      if item_data_map[file_item.uuid] == nil then
        ---@type ghc.command.search_files.IItemData
        local file_item_data = { filepath = filepath, filematch = file_match, match_idx = 1 }
        item_data_map[file_item.uuid] = file_item_data
      end
    end
  end
  _item_data_map = item_data_map
  callback(true, items)
end

---@param item                          fml.types.ui.search.IItem
---@return ghc.command.search_files.IPreviewData
local function calc_preview_data(item)
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

  local cwd = state_search_cwd:snapshot() ---@type string
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
  local match_idx_cur = item_data.match_idx ---@type integer

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

---@param item                          fml.types.ui.search.IItem
---@return fml.ui.search.preview.IData
local function fetch_preview_data(item)
  local preview_data = calc_preview_data(item) ---@type ghc.command.search_files.IPreviewData
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

local _search = nil ---@type fml.types.ui.search.ISearch|nil

---@param scope                         ghc.enums.context.SearchScope
---@return nil
local function change_scope(scope)
  local scope_current = session.search_scope:snapshot() ---@type ghc.enums.context.SearchScope
  if _search ~= nil and scope_current ~= scope then
    session.search_scope:next(scope)
  end
end

---@return nil
local function edit_config()
  ---@class ghc.command.search_files.IConfigData
  ---@field public search_pattern       string
  ---@field public replace_pattern      string
  ---@field public search_paths         string[]
  ---@field public max_filesize         string
  ---@field public max_matches          integer
  ---@field public include_patterns     string[]
  ---@field public exclude_patterns     string[]

  local s_search_pattern = session.search_pattern:snapshot() ---@type string
  local s_replace_pattern = session.search_replace_pattern:snapshot() ---@type string
  local s_search_paths = session.search_paths:snapshot() ---@type string
  local s_max_filesize = session.search_max_filesize:snapshot() ---@type string
  local s_max_matches = session.search_max_matches:snapshot() ---@type integer
  local s_include_patterns = session.search_include_patterns:snapshot() ---@type string)
  local s_exclude_patterns = session.search_exclude_patterns:snapshot() ---@type string

  ---@type ghc.command.search_files.IConfigData
  local data = {
    search_pattern = s_search_pattern,
    replace_pattern = s_replace_pattern,
    search_paths = fml.array.parse_comma_list(s_search_paths),
    max_filesize = s_max_filesize,
    max_matches = s_max_matches,
    include_patterns = fml.array.parse_comma_list(s_include_patterns),
    exclude_patterns = fml.array.parse_comma_list(s_exclude_patterns),
  }

  local setting = fml.ui.Setting.new({
    position = "center",
    width = 100,
    title = "Edit Configuration (search files)",
    validate = function(raw_data)
      if type(raw_data) ~= "table" then
        return "Invalid search_files configuration, expect an object."
      end
      ---@cast raw_data ghc.command.search_files.IConfigData

      if raw_data.search_pattern == nil or type(raw_data.search_pattern) ~= "string" then
        return "Invalid data.search_pattern, expect an string."
      end

      if raw_data.replace_pattern == nil or type(raw_data.replace_pattern) ~= "string" then
        return "Invalid data.replace_pattern, expect an string."
      end

      if raw_data.search_paths == nil or not fml.is.array(raw_data.search_paths) then
        return "Invalid data.search_paths, expect an array."
      end

      if type(raw_data.max_filesize) ~= "string" then
        return "Invalid data.max_filesize, expect a string."
      end

      if type(raw_data.max_matches) ~= "number" then
        return "Invalid data.max_matches, expect a number."
      end

      if raw_data.include_patterns == nil or not fml.is.array(raw_data.include_patterns) then
        return "Invalid data.include_patterns, expect an array."
      end

      if raw_data.exclude_patterns == nil or not fml.is.array(raw_data.exclude_patterns) then
        return "Invalid data.exclude_patterns, expect an array."
      end
    end,
    on_confirm = function(raw_data)
      local raw = vim.tbl_extend("force", data, raw_data)
      ---@cast raw ghc.command.search_files.IConfigData

      local search_pattern = raw.search_pattern ---@type string
      local replace_pattern = raw.replace_pattern ---@type string
      local max_filesize = raw.max_filesize ---@type string
      local max_matches = raw.max_matches ---@type integer
      local search_paths = table.concat(raw.search_paths, ",") ---@type string
      local include_patterns = table.concat(raw.include_patterns, ",") ---@type string
      local exclude_patterns = table.concat(raw.exclude_patterns, ",") ---@type string

      session.search_pattern:next(search_pattern)
      session.search_replace_pattern:next(replace_pattern)
      session.search_paths:next(search_paths)
      session.search_max_filesize:next(max_filesize)
      session.search_max_matches:next(max_matches)
      session.search_include_patterns:next(include_patterns)
      session.search_exclude_patterns:next(exclude_patterns)
      M.reload()
    end,
  })
  setting:open({
    initial_value = data,
    text_cursor_row = 1,
    text_cursor_col = 1,
  })
end

---@return fml.types.ui.search.ISearch
local function get_search()
  if _search == nil then
    local actions = {
      change_scope_workspace = function()
        change_scope("W")
      end,
      change_scope_cwd = function()
        change_scope("C")
      end,
      change_scope_directory = function()
        change_scope("D")
      end,
      toggle_regex = function()
        local flag = session.search_flag_regex:snapshot() ---@type boolean
        session.search_flag_regex:next(not flag)
      end,
      toggle_case_sensitive = function()
        local flag = session.search_flag_case_sensitive:snapshot() ---@type boolean
        session.search_flag_case_sensitive:next(not flag)
      end,
      toggle_flag_gitignore = function()
        local flag = session.search_flag_gitignore:snapshot() ---@type boolean
        session.search_flag_gitignore:next(not flag)
      end,
      toggle_flag_replace = function()
        local flag = session.search_flag_replace:snapshot() ---@type boolean
        session.search_flag_replace:next(not flag)
      end,
      replace_file = function()
        if _search == nil then
          return
        end

        local item = _search.state:get_current() ---@type fml.types.ui.search.IItem|nil
        if item == nil then
          return
        end

        local item_data = _item_data_map[item.uuid] ---@type ghc.command.search_files.IItemData|nil
        if item_data == nil then
          return
        end

        local cwd = state_search_cwd:snapshot() ---@type string
        local filepath = item_data.filepath ---@type string
        local flag_case_sensitive = session.search_flag_case_sensitive:snapshot() ---@type boolean
        local flag_regex = session.search_flag_regex:snapshot() ---@type boolean
        local search_pattern = session.search_pattern:snapshot() ---@type string
        local replace_pattern = session.search_replace_pattern:snapshot() ---@type string

        local succeed = false ---@type boolean
        if item_data.match_idx > 0 then
          succeed = fml.oxi.replace_file_by_matches({
            cwd = cwd,
            filepath = filepath,
            flag_case_sensitive = flag_case_sensitive,
            flag_regex = flag_regex,
            search_pattern = search_pattern,
            replace_pattern = replace_pattern,
            match_idxs = { item_data.match_idx },
          })
        else
          succeed = fml.oxi.replace_file({
            cwd = cwd,
            filepath = filepath,
            flag_case_sensitive = flag_case_sensitive,
            flag_regex = flag_regex,
            search_pattern = search_pattern,
            replace_pattern = replace_pattern,
          })
        end

        if succeed and _last_search_result ~= nil then
          local flag_gitignore = session.search_flag_gitignore:snapshot() ---@type boolean
          local max_filesize = session.search_max_filesize:snapshot() ---@type string
          local max_matches = session.search_max_matches:snapshot() ---@type integer
          local search_paths = session.search_paths:snapshot() ---@type string
          local include_patterns = session.search_include_patterns:snapshot() ---@type string
          local exclude_patterns = session.search_exclude_patterns:snapshot() ---@type string
          local specified_filepath = fml.path.join(cwd, filepath) ---@type string

          ---@type fml.std.oxi.search.IResult
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

          if partial_search_result.error == nil and partial_search_result.items ~= nil then
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
        M.reload()
      end,
    }

    ---@type fml.types.IKeymap[]
    local input_keymaps = {
      {
        modes = { "i", "n" },
        key = "<C-a>c",
        callback = edit_config,
        desc = "search: edit configuration",
      },
      {
        modes = { "i", "n" },
        key = "<M-c>",
        callback = edit_config,
        desc = "search: edit configuration",
      },
      {
        modes = { "n", "v" },
        key = "<leader>w",
        callback = actions.change_scope_workspace,
        desc = "search: change scope (workspace)",
      },
      {
        modes = { "n", "v" },
        key = "<leader>c",
        callback = actions.change_scope_cwd,
        desc = "search: change scope (cwd)",
      },
      {
        modes = { "n", "v" },
        key = "<leader>d",
        callback = actions.change_scope_directory,
        desc = "search: change scope (directory)",
      },
      {
        modes = { "n", "v" },
        key = "<leader>r",
        callback = actions.toggle_regex,
        desc = "search: toggle regex",
      },
      {
        modes = { "n", "v" },
        key = "<leader>i",
        callback = actions.toggle_case_sensitive,
        desc = "search: toggle case sensitive",
      },
      {
        modes = { "n", "v" },
        key = "<leader>g",
        callback = actions.toggle_flag_gitignore,
        desc = "search: toggle gitignore",
      },
      {
        modes = { "n", "v" },
        key = "<leader>R",
        callback = actions.toggle_flag_replace,
        desc = "search: toggle mode",
      },
      {
        modes = { "n", "v" },
        key = "<leader><cr>",
        callback = actions.replace_file,
        desc = "search: replace file",
      },
    }

    ---@type fml.types.IKeymap[]
    local main_keymaps = vim.tbl_deep_extend("force", {}, input_keymaps)

    local frecency = state_frecency.load_and_autosave().files ---@type fml.types.collection.IFrecency
    local input_history = state_input_history.load_and_autosave().search_in_files ---@type fml.types.collection.IHistory
    _search = fml.ui.search.Search.new({
      title = "Search in files",
      input = session.search_pattern,
      input_history = input_history,
      input_keymaps = input_keymaps,
      main_keymaps = main_keymaps,
      fetch_items = fetch_items,
      fetch_delay = 512,
      render_delay = 64,
      width = 0.4,
      height = 0.8,
      width_preview = 0.45,
      max_height = 1,
      max_width = 1,
      on_close = function()
        statusline.disable(statusline.cnames.search_files)
      end,
      fetch_preview_data = fetch_preview_data,
      patch_preview_data = function(item, _, last_data)
        local item_data = _item_data_map[item.uuid] ---@type ghc.command.search_files.IItemData|nil
        if _last_preview_data == nil or item_data == nil then
          return fetch_preview_data(item)
        end

        local match_idx = item_data.match_idx ---@type integer
        local flag_replace = session.search_flag_replace:snapshot() ---@type boolean
        local highlights = {} ---@type fml.types.ui.IHighlight[]
        if flag_replace then
          for _, hl in ipairs(_last_preview_data.highlights) do
            local is_search_match = hl.match_idx % 2 == 1 ---@type boolean
            local midx = is_search_match and ((hl.match_idx + 1) / 2) or (hl.match_idx / 2) ---@type integer
            local hlname = is_search_match
                and (midx == match_idx and "f_us_preview_search_cur" or "f_us_preview_search")
              or (midx == match_idx and "f_us_preview_replace_cur" or "f_us_preview_replace")
            local highlight = { lnum = hl.lnum, coll = hl.coll, colr = hl.colr, hlname = hlname } ---@type fml.types.ui.IHighlight
            table.insert(highlights, highlight)
          end
        else
          for _, hl in ipairs(_last_preview_data.highlights) do
            local midx = hl.match_idx ---@type integer
            local hlname = midx == match_idx and "f_us_match_cur" or "f_us_match" ---@type string
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
      end,
      on_confirm = function(item)
        local winnr = fml.api.state.win_history:present() ---@type integer
        if winnr ~= nil then
          local cwd = state_search_cwd:snapshot() ---@type string
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
      end,
    })
  end
  return _search
end

---@return nil
function M.reload()
  if _search ~= nil then
    _search.state:mark_dirty()
  end
end

---@return nil
function M.focus()
  state_dirpath:next(vim.fn.expand("%:p:h"))
  local search = get_search() ---@type fml.types.ui.search.ISearch
  statusline.enable(statusline.cnames.search_files)
  search:focus()
end

return M
