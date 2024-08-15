local session = require("ghc.context.session")
local statusline = require("ghc.ui.statusline")
local state_frecency = require("ghc.state.frecency")
local state_input_history = require("ghc.state.input_history")

---@class ghc.command.search_files
local M = {}

---@class ghc.command.search_files.IItemData
---@field public filepath               string
---@field public filematch              fml.std.oxi.search.IFileMatch
---@field public lnum                   ?integer
---@field public col                    ?integer

local initial_dirpath = vim.fn.expand("%:p:h") ---@type string
local state_dirpath = fml.collection.Observable.from_value(initial_dirpath)
local state_search_cwd = fml.collection.Observable.from_value(session.get_search_scope_cwd(initial_dirpath))

local _last_search_input = nil ---@type string|nil
local _last_search_result = nil ---@type fml.std.oxi.search.IResult|nil
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
  _last_search_input = nil
  _last_search_result = nil
end, true)
fml.fn.watch_observables({
  session.search_exclude_patterns,
  session.search_flag_case_sensitive,
  session.search_flag_gitignore,
  session.search_flag_regex,
  session.search_flag_replace,
  session.search_include_patterns,
  session.search_max_filesize,
  session.search_max_matches,
  session.search_paths,
  session.search_replace_pattern,
  state_search_cwd,
}, function()
  M.reload()
end, true)

local _item_data_map = {} ---@type table<string, ghc.command.search_files.IItemData>

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

      ---@class ghc.command.search_files.IItemData
      item_data_map[file_item.uuid] = {
        filepath = filepath,
        filematch = file_match,
      }
      local is_first_item = true ---@type boolean

      for _, block_match in ipairs(file_match.matches) do
        local lines = block_match.lines ---@type string[]
        local lnum0 = block_match.lnum ---@type integer

        local k = 1 ---@type integer
        local offset = 0 ---@type integer
        local lwidth = string.len(lines[1]) + 1 ---@type integer
        for _, match in ipairs(block_match.matches) do
          local l = match.l ---@type integer
          local r = match.r ---@type integer

          while l >= offset + lwidth and k < #lines do
            k = k + 1
            offset = offset + lwidth
            lwidth = string.len(lines[k]) + 1
          end

          local lnum = lnum0 + k - 1 ---@type integer
          local col = l - offset ---@type integer
          local col_end = math.min(lwidth - 1, r - offset) ---@type integer
          local text_prefix = "  " .. lnum .. ":" .. col .. " " ---@type string
          local text = text_prefix .. lines[k] ---@type string

          local offset_prefix = string.len(text_prefix) ---@type integer
          local offset_start = offset_prefix + col ---@type integer
          local offset_end = offset_prefix + col_end ---@type integer

          ---@type fml.types.ui.IInlineHighlight[]
          local highlights = {
            { coll = 0, colr = offset_prefix, hlname = "f_us_main_match_lnum" },
            { coll = offset_start, colr = offset_end, hlname = "f_us_main_match" },
          }

          ---@type fml.types.ui.search.IItem
          local match_item = {
            group = filepath,
            uuid = filepath .. text_prefix,
            text = text,
            highlights = highlights,
          }
          table.insert(items, match_item)

          ---@class ghc.command.search_files.IItemData
          item_data_map[match_item.uuid] = {
            filepath = filepath,
            filematch = file_match,
            lnum = lnum,
            col = col,
          }

          if is_first_item then
            is_first_item = false

            ---@class ghc.command.search_files.IItemData
            item_data_map[file_item.uuid] = {
              filepath = filepath,
              filematch = file_match,
              lnum = lnum,
              col = col,
            }
          end
        end
      end

      ---@class ghc.command.search_files.IItemData
      item_data_map[file_item.uuid] = {
        filepath = filepath,
        filematch = file_match,
      }
    end
  end
  _item_data_map = item_data_map
  callback(true, items)
end

---@param item                          ghc.command.search_files.IItemData
---@return fml.types.ui.IHighlight[]
local function calc_search_highlights(item)
  local file_match = item.filematch ---@type fml.std.oxi.search.IFileMatch
  local highlights = {} ---@type fml.types.ui.IHighlight[]
  for _, block_match in ipairs(file_match.matches) do
    local lines = block_match.lines ---@type string[]
    local lnum0 = block_match.lnum ---@type integer

    local k = 1 ---@type integer
    local offset = 0 ---@type integer
    local lwidth = string.len(lines[1]) + 1 ---@type integer
    for _, match in ipairs(block_match.matches) do
      local l = match.l ---@type integer
      local r = match.r ---@type integer
      local hlname = nil ---@type string|nil

      while l < r do
        while l >= offset + lwidth and k < #lines do
          k = k + 1
          offset = offset + lwidth
          lwidth = string.len(lines[k]) + 1
        end

        local lnum = lnum0 + k - 1 ---@type integer
        local col = l - offset ---@type integer
        local col_end = math.min(lwidth - 1, r - offset) ---@type integer

        if hlname == nil then
          hlname = (item.lnum == lnum and item.col == col) and "f_us_match_cur" or "f_us_match"
        end

        ---@type fml.types.ui.IHighlight
        local highlight = { lnum = lnum, coll = col, colr = col_end, hlname = hlname }
        table.insert(highlights, highlight)

        l = offset + lwidth ---@type integer
      end
    end
  end
  return highlights
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

  local search_pattern = session.search_pattern:snapshot() ---@type string
  local replace_pattern = session.search_replace_pattern:snapshot() ---@type string
  local s_search_paths = session.search_paths:snapshot() ---@type string
  local s_max_filesize = session.search_max_filesize:snapshot() ---@type string
  local s_max_matches = session.search_max_matches:snapshot() ---@type integer
  local s_include_patterns = session.search_include_patterns:snapshot() ---@type string)
  local s_exclude_patterns = session.search_exclude_patterns:snapshot() ---@type string

  ---@type ghc.command.search_files.IConfigData
  local data = {
    search_pattern = search_pattern,
    replace_pattern = replace_pattern,
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
        return "Invalid data.input, expect an string."
      end

      if raw_data.replace_pattern == nil or type(raw_data.replace_pattern) ~= "string" then
        return "Invalid data.replace, expect an string."
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
      ---@cast raw_data ghc.command.search_files.IConfigData
      local raw = vim.tbl_extend("force", data, raw_data)
      local input = raw.input ---@type string
      local replace = raw.replace ---@type string
      local max_filesize = raw.max_filesize ---@type string
      local max_matches = raw.max_matches ---@type integer
      local search_paths = table.concat(raw.search_paths, ",") ---@type string
      local include_patterns = table.concat(raw.include_patterns, ",") ---@type string
      local exclude_patterns = table.concat(raw.exclude_patterns, ",") ---@type string

      session.search_pattern:next(input)
      session.search_replace_pattern:next(replace)
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
      fetch_preview_data = function(item)
        local item_data = _item_data_map[item.uuid] ---@type ghc.command.search_files.IItemData|nil
        if item_data ~= nil then
          local cwd = state_search_cwd:snapshot() ---@type string
          local filepath = fml.path.join(cwd, item_data.filepath) ---@type string
          local filename = fml.path.basename(filepath) ---@type string

          local is_text_file = fml.is.printable_file(filename) ---@type boolean
          if is_text_file then
            local filetype = vim.filetype.match({ filename = filename }) ---@type string|nil
            local highlights = calc_search_highlights(item_data) ---@type fml.types.ui.IHighlight[]

            ---@type fml.ui.search.preview.IData
            local data = {
              filetype = filetype,
              show_numbers = true,
              title = item_data.filepath,
              lines = fml.fs.read_file_as_lines({ filepath = filepath, silent = true }),
              highlights = highlights,
              lnum = item_data.lnum,
              col = item_data.col,
            }
            return data
          end

          ---@type fml.types.ui.IHighlight[]
          local highlights = { { lnum = 1, coll = 0, colr = -1, hlname = "f_us_preview_error" } }

          ---@type fml.ui.search.preview.IData
          local data = {
            lines = { "  Not a text file, cannot preview." },
            highlights = highlights,
            filetype = nil,
            show_numbers = false,
            title = item_data.filepath,
          }
          return data
        end

        ---@type fml.types.ui.IHighlight[]
        local highlights = { { lnum = 1, coll = 0, colr = -1, hlname = "f_us_preview_error" } }

        ---@type fml.ui.search.preview.IData
        local data = {
          lines = { "  Cannot retrieve the item by uuid=" .. item.uuid },
          highlights = highlights,
          filetype = nil,
          show_numbers = false,
          title = item.text,
        }
        return data
      end,
      patch_preview_data = function(item, _, last_data)
        local item_data = _item_data_map and _item_data_map[item.uuid] ---@type ghc.command.search_files.IItemData|nil
        local lnum = item_data ~= nil and item_data.lnum or nil ---@type integer|nil
        local col = item_data ~= nil and item_data.col or nil ---@type integer|nil

        ---@type fml.types.ui.IHighlight[]|nil
        local highlights = item_data and calc_search_highlights(item_data) or nil

        ---@type fml.ui.search.preview.IData
        local data = {
          lines = last_data.lines,
          highlights = highlights or last_data.highlights,
          filetype = last_data.filetype,
          show_numbers = last_data.show_numbers,
          title = last_data.title,
          lnum = lnum,
          col = col,
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
