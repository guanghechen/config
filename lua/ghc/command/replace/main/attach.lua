local previewer = require("ghc.command.replace.previewer")
local state = require("ghc.command.replace.state")

---@class ghc.command.replace.main
local M = require("ghc.command.replace.main.mod")

---@return nil
function M.record_cursor_pos(winnr)
  local cursor = vim.api.nvim_win_get_cursor(winnr)
  M.cursor_row = cursor[1]
  M.cursor_col = cursor[2]
end

---@param key                           ghc.enums.command.replace.StateKey
---@param position                      ?fml.enums.BoxPosition
---@return nil
function M.edit_string(key, position)
  position = position or "cursor"
  return function()
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    local value = state.get_value(key) ---@cast value string
    local lines = fml.string.split(value, "\n") ---@type string[]

    local cursor = vim.api.nvim_win_get_cursor(winnr)
    M.cursor_row = cursor[1]
    M.cursor_col = cursor[2]

    local input_col = cursor[2] - M.CFG_NAME_LEN - 2
    if key == "search_pattern" then
      input_col = input_col - 12
    end
    if input_col < 0 then
      input_col = 0
    end

    local cursor_row = 1 ---@type integer
    local cursor_col = 0 ---@type integer
    local last_line_end_index = 0 ---@type integer
    while true do
      local next_line_end_index = string.find(value, "\n", last_line_end_index + 1)
      if not next_line_end_index or next_line_end_index >= input_col then
        cursor_col = input_col - last_line_end_index
        break
      end

      cursor_row = cursor_row + 1
      cursor_col = 0
      input_col = input_col - 2 ---The width of the newline character is 3.
      last_line_end_index = next_line_end_index
    end

    cursor_col = math.max(cursor_col, 0)
    cursor_col = math.min(cursor_col, cursor_row > 0 and cursor_row <= #lines and #lines[cursor_row] or 0)
    local textarea = fml.ui.Textarea.new({
      position = position,
      height = 10,
      width = 80,
      title = "[" .. key .. "]",
      on_confirm = function(next_lines)
        local text = table.concat(next_lines, "\n") ---@type string
        state.set_value(key, text)
      end,
    })
    textarea:open({
      initial_lines = lines,
      text_cursor_row = cursor_row,
      text_cursor_col = cursor_col,
    })
  end
end

---@param key                           ghc.enums.command.replace.StateKey
---@param position                      ?"center"|"cursor
---@return nil
function M.edit_list(key, position)
  position = position or "cursor"
  return function()
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    local value = state.get_value(key) ---@cast value string
    local lines = fml.array.parse_comma_list(value) ---@type string[]

    local cursor = vim.api.nvim_win_get_cursor(winnr)
    M.cursor_row = cursor[1]
    M.cursor_col = cursor[2]

    local input_col = cursor[2] - M.CFG_NAME_LEN - 2
    if input_col < 0 then
      input_col = 0
    end

    local cursor_row = 1 ---@type integer
    local cursor_col = 0 ---@type integer
    local last_line_end_index = 0 ---@type integer
    while true do
      local next_line_end_index = string.find(value, ",", last_line_end_index + 1)
      if not next_line_end_index or next_line_end_index >= input_col then
        cursor_col = input_col - last_line_end_index
        break
      end

      cursor_row = cursor_row + 1
      cursor_col = 0
      input_col = input_col - 1 ---The width of the comma list separator is 2.
      last_line_end_index = next_line_end_index
    end

    cursor_col = math.max(cursor_col, 0)
    cursor_col = math.min(cursor_col, cursor_row > 0 and cursor_row <= #lines and #lines[cursor_row] or 0)

    local textarea = fml.ui.Textarea.new({
      position = position,
      height = 10,
      width = 80,
      title = "[" .. key .. "]",
      on_confirm = function(next_lines)
        local normalized_list = {}
        for _, line in ipairs(next_lines) do
          table.insert(normalized_list, fml.oxi.normalize_comma_list(line))
        end
        local normailized = table.concat(normalized_list, ", ")
        state.set_value(key, normailized)
      end,
    })
    textarea:open({
      initial_lines = lines,
      text_cursor_row = cursor_row,
      text_cursor_col = cursor_col,
    })
  end
end

---@return nil
function M.on_edit()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local cursor = vim.api.nvim_win_get_cursor(winnr)
  local cursor_row = cursor[1]
  local meta = M.printer:get_meta(cursor_row) ---@type ghc.types.command.replace.main.ILineMeta|nil
  if meta ~= nil and meta.key ~= nil then
    local key = meta.key
    if key == "cwd" or key == "search_pattern" or key == "replace_pattern" then
      M.edit_string(key)()
    end
    if key == "search_paths" or key == "include_patterns" or key == "exclude_patterns" then
      M.edit_list(key)()
    end
  end
end

---@return nil
function M.on_edit_full_config()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local cursor = vim.api.nvim_win_get_cursor(winnr)
  M.cursor_row = cursor[1]
  M.cursor_col = cursor[2]

  local data = state.get_data() ---@type ghc.command.replace.state.IData
  local setting = fml.ui.Setting.new({
    position = "center",
    width = 100,
    title = state.get_mode() == "search" and "[Search options]" or "[Replace options]",
    on_confirm = function(raw_data)
      ---@cast raw_data ghc.command.replace.state.IData
      local raw = vim.tbl_extend("force", data, raw_data)
      ---@type ghc.command.replace.state.IData
      local next_data = {
        cwd = raw.cwd,
        mode = raw.mode,
        flag_regex = raw.flag_regex,
        flag_case_sensitive = raw.flag_case_sensitive,
        search_pattern = raw.search_pattern,
        replace_pattern = raw.replace_pattern,
        search_paths = raw.search_paths,
        include_patterns = raw.include_patterns,
        exclude_patterns = raw.exclude_patterns,
      }
      state.set_data(next_data)
    end,
  })
  setting:open({
    initial_value = data,
    text_cursor_row = 1,
    text_cursor_col = 1,
  })
end

---@return nil
function M.on_open_file()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local cursor = vim.api.nvim_win_get_cursor(winnr)
  local cursor_row = cursor[1]
  local meta = M.printer:get_meta(cursor_row) ---@type ghc.types.command.replace.main.ILineMeta|nil
  if meta ~= nil and meta.filepath ~= nil then
    local winnr_preview = M.locate_or_create_preview_window()
    if winnr_preview ~= nil then
      local escaped_filepath = vim.fn.fnameescape(meta.filepath)
      vim.cmd("edit " .. escaped_filepath)
      if meta.lnum ~= nil then
        vim.api.nvim_win_set_cursor(winnr_preview, { meta.lnum, 0 })
      end
    end
  end
end

---@return nil
function M.on_refresh()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  M.record_cursor_pos(winnr)

  local cursor = vim.api.nvim_win_get_cursor(winnr)
  local cursor_row = cursor[1]
  local meta = M.printer:get_meta(cursor_row) ---@type ghc.types.command.replace.main.ILineMeta|nil
  if meta ~= nil and meta.filepath ~= nil then
    state.refresh_on_file(meta.filepath)
  else
    state.mark_search_dirty()
  end
end

---@return nil
function M.on_refresh_all()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  M.record_cursor_pos(winnr)

  state.mark_search_dirty()
end

---@return nil
function M.on_replace()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  M.record_cursor_pos(winnr)

  local cursor = vim.api.nvim_win_get_cursor(winnr)
  local cursor_row = cursor[1]
  local meta = M.printer:get_meta(cursor_row) ---@type ghc.types.command.replace.main.ILineMeta|nil
  if meta ~= nil and meta.filepath ~= nil then
    if meta.lnum == nil then
      ---@type boolean
      local success = fml.oxi.replace_entire_file({
        cwd = state.get_cwd(),
        filepath = meta.filepath,
        flag_regex = state.get_flag_regex(),
        flag_case_sensitive = state.get_flag_case_sensitive(),
        search_pattern = state.get_search_pattern(),
        replace_pattern = state.get_replace_pattern(),
      })
      if success then
        state.refresh_on_file(meta.filepath)
      end
    end
  end
end

---@return nil
function M.on_view_file()
  if state.get_mode() == "search" then
    M.on_open_file()
    return
  end

  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local cursor = vim.api.nvim_win_get_cursor(winnr)
  local cursor_row = cursor[1]
  local meta = M.printer:get_meta(cursor_row) ---@type ghc.types.command.replace.main.ILineMeta|nil
  if meta ~= nil and meta.filepath ~= nil then
    local winnr_previewer = M.locate_or_create_preview_window() ---@type integer|nil
    if winnr_previewer ~= nil then
      previewer.preview({
        winnr = winnr_previewer,
        filepath = meta.filepath,
        keep_search_pieces = true,
        cursor_row = meta.lnum or 1,
        cursor_col = 0,
      })
    end
  end
end

---@param bufnr                         integer
function M.attach(bufnr)
  ---@param modes string|string[]
  ---@param key string
  ---@param action any
  ---@param desc string
  local function mk(modes, key, action, desc)
    vim.keymap.set(modes, key, action, { noremap = true, silent = true, buffer = bufnr, desc = desc })
  end

  mk({ "n", "v" }, "<f6>", M.on_refresh, "replace: refresh search")
  mk({ "n", "v" }, "<f5>", M.on_refresh_all, "replace: refresh search (all)")
  mk({ "n", "v" }, "<cr>", M.on_view_file, "replace: view file")
  mk({ "n", "v" }, "<2-LeftMouse>", M.on_view_file, "replace: view file")
  mk({ "n", "v" }, "<leader><cr>", M.on_replace, "replace: replace")
  mk({ "n", "v" }, "<leader>i", state.tog_flag_case_sensitive, "replace: toggle case sensitive")
  mk({ "n", "v" }, "<leader>r", state.tog_flag_regex, "replace: toggle regex mode")
  mk({ "n", "v" }, "<leader>m", state.tog_mode, "replace: toggle ux mode")
  mk({ "n", "v" }, "A", M.on_edit_full_config, "replace: edit full config")
  mk({ "n", "v" }, "a", M.on_edit, "replace: edit config")
  mk({ "n", "v" }, "d", M.on_edit, "replace: edit config")
  mk({ "n", "v" }, "ec", M.edit_string("cwd"), "replace: edit cwd")
  mk({ "n", "v" }, "ee", M.edit_list("exclude_patterns"), "replace: edit exclude patterns")
  mk({ "n", "v" }, "ei", M.edit_list("include_patterns"), "replace: edit include patterns")
  mk({ "n", "v" }, "ep", M.edit_list("search_paths"), "replace: edit search paths")
  mk({ "n", "v" }, "er", M.edit_string("replace_pattern"), "replace: edit replace pattern")
  mk({ "n", "v" }, "es", M.edit_string("search_pattern"), "replace: edit search pattern")
  mk({ "n", "v" }, "I", M.on_edit_full_config, "replace: edit full config")
  mk({ "n", "v" }, "i", M.on_edit, "replace: edit config")
  mk({ "n", "v" }, "o", M.on_open_file, "replace: view original file")
  mk({ "n", "v" }, "r", M.on_edit, "replace: edit config")
  mk({ "n", "v" }, "u", M.on_edit, "replace: edit config")
end
