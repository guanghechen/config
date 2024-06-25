local Previewer = require("ghc.command.replace.previewer")
local constants = require("ghc.constant.command")
local Printer = require("ghc.ui.printer")
local buf_delete_augroup = vim.api.nvim_create_augroup("ghc_command_replace_view_buf_del", { clear = true })

---@class ghc.command.replace.Viewer
---@field private state         ghc.command.replace.State
---@field private bufnr         integer|nil
---@field private printer       ghc.ui.Printer
---@field private previewer     ghc.command.replace.Previewer
---@field private cfg_name_len  integer
---@field private cursor_row    integer
---@field private cursor_col    integer
local M = {}
M.__index = M

---@return integer|nil
local function find_first_replace_buf()
  for _, bufnr in ipairs(vim.t.bufs) do
    local buftype = vim.api.nvim_get_option_value("buftype", { buf = bufnr })
    local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr })
    if buftype == constants.replace_view_buftype and filetype == constants.replace_view_filetype then
      return bufnr
    end
  end
  return nil
end

---@class ghc.command.replace.viewer.IProps
---@field public state          ghc.command.replace.State

---@param opts ghc.command.replace.viewer.IProps
---@return ghc.command.replace.Viewer
function M.new(opts)
  local self = setmetatable({}, M)
  local state = opts.state ---@type ghc.command.replace.State

  self.state = state
  self.bufnr = nil
  self.printer = Printer.new({ bufnr = 0, nsnr = 0 })
  self.previewer = Previewer.new({ state = state, nsnr = 0 })
  self.cfg_name_len = 7
  self.cursor_row = 6
  self.cursor_col = 21

  return self
end

---@param opts { winnr: integer, force?: boolean, reuse?: boolean }
function M:render(opts)
  local winnr = opts.winnr ---@type integer
  local force = not not opts.force ---@type boolean
  local reuse = not not opts.reuse ---@type boolean

  if winnr == 0 then
    winnr = vim.api.nvim_get_current_win()
  end

  if self.bufnr == nil then
    if reuse then
      self.bufnr = find_first_replace_buf() ---@type integer|nil
    end

    if self.bufnr == nil then
      local bufnr = vim.api.nvim_create_buf(true, true) ---@type integer
      vim.api.nvim_set_current_buf(bufnr)
      vim.api.nvim_set_option_value("buftype", constants.replace_view_buftype, { buf = bufnr })
      vim.api.nvim_set_option_value("filetype", constants.replace_view_filetype, { buf = bufnr })
      vim.api.nvim_set_option_value("buflisted", true, { buf = bufnr })
      vim.opt_local.list = false
      vim.cmd(string.format("%sbufdo file %s/REPLACE", bufnr, bufnr)) --- Rename the buf
      vim.api.nvim_create_autocmd("BufDelete", {
        group = buf_delete_augroup,
        buffer = bufnr,
        callback = function()
          self.bufnr = nil
        end,
      })

      self.bufnr = bufnr
      self.printer:reset({ bufnr = bufnr, nsnr = 0 })
      self:internal_bind_keymaps(bufnr)
    end
  end

  local bufnr = self.bufnr ---@type integer

  vim.api.nvim_set_option_value("readonly", false, { buf = bufnr })
  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
  vim.api.nvim_win_set_buf(winnr, bufnr)
  pcall(function()
    self:internal_render({ winnr = winnr, bufnr = bufnr, force = force })
  end)
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
  vim.api.nvim_set_option_value("readonly", true, { buf = bufnr })
end

---@return integer|nil
function M:get_bufnr()
  return self.bufnr
end

---@param opts { winnr: integer, bufnr: integer, force?: boolean }
function M:internal_render(opts)
  local winnr = opts.winnr ---@type integer
  local force = not not opts.force ---@type boolean
  local data = self.state:get_data() ---@type ghc.types.command.replace.IStateData
  local result = self.state:search(force) ---@type fml.core.oxi.search.IResult|nil

  self.printer:clear()
  self:internal_render_cfg(data)
  if result ~= nil then
    self:internal_print("")
    self:internal_print("")
    self:internal_render_result(data, result)
  end

  ---Set cursor position.
  local current_lnum = self.printer:get_current_lnum() ---@type integer
  if self.cursor_row > current_lnum then
    self.cursor_row = current_lnum
  end
  local maximum_column_of_line = #vim.fn.getline(self.cursor_row)
  if self.cursor_col > maximum_column_of_line then
    self.cursor_col = maximum_column_of_line
  end
  vim.api.nvim_win_set_cursor(winnr, { self.cursor_row, self.cursor_col })
end

---@param bufnr integer
function M:internal_bind_keymaps(bufnr)
  ---@param modes string|string[]
  ---@param key string
  ---@param action any
  ---@param desc string
  local function mk(modes, key, action, desc)
    vim.keymap.set(modes, key, action, { noremap = true, silent = true, buffer = bufnr, desc = desc })
  end

  ---@param key ghc.enums.command.replace.StateKey
  ---@param position? "center"|"cursor
  ---@return nil
  local function edit_string(key, position)
    position = position or "cursor"
    return function()
      local winnr = vim.api.nvim_get_current_win() ---@type integer
      local value = self.state:get_value(key) ---@type string
      local lines = fml.string.split(value, "\n") ---@type string[]

      local cursor = vim.api.nvim_win_get_cursor(winnr)
      self.cursor_row = cursor[1]
      self.cursor_col = cursor[2]

      local input_col = cursor[2] - self.cfg_name_len - 2
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
      local textarea = ghc.ui.Textarea.new({
        title = "[" .. key .. "]",
        position = position,
      })
      textarea:open({
        value = lines,
        cursor_row = cursor_row,
        cursor_col = cursor_col,
        height = 10,
        width = 80,
        on_confirm = function(next_lines)
          local resolved = table.concat(next_lines, "\n") ---@type string
          self.state:set_value(key, resolved)
        end,
      })
    end
  end

  ---@param key ghc.enums.command.replace.StateKey
  ---@param position? "center"|"cursor
  ---@return nil
  local function edit_list(key, position)
    position = position or "cursor"
    return function()
      local winnr = vim.api.nvim_get_current_win() ---@type integer
      local value = self.state:get_value(key) ---@type string
      local lines = fml.table.parse_comma_list(value) ---@type string[]

      local cursor = vim.api.nvim_win_get_cursor(winnr)
      self.cursor_row = cursor[1]
      self.cursor_col = cursor[2]

      local input_col = cursor[2] - self.cfg_name_len - 2
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

      local textarea = ghc.ui.Textarea.new({
        title = "[" .. key .. "]",
        position = position,
      })
      textarea:open({
        value = lines,
        cursor_row = cursor_row,
        cursor_col = cursor_col,
        height = 10,
        width = 80,
        on_confirm = function(next_value)
          local normalized_list = {}
          for _, next_line in ipairs(next_value) do
            table.insert(normalized_list, fml.oxi.normalize_comma_list(next_line))
          end
          local normailized = table.concat(normalized_list, ", ")
          self.state:set_value(key, normailized)
        end,
      })
    end
  end

  local function on_edit()
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    local cursor = vim.api.nvim_win_get_cursor(winnr)
    local cursor_row = cursor[1]
    local meta = self.printer:get_meta(cursor_row) ---@type ghc.types.command.replace.main.ILineMeta|nil
    if meta ~= nil and meta.key ~= nil then
      local key = meta.key
      if key == "cwd" or key == "search_pattern" or key == "replace_pattern" then
        edit_string(key)()
      end
      if key == "search_paths" or key == "include_patterns" or key == "exclude_patterns" then
        edit_list(key)()
      end
    end
  end

  local function on_edit_full_config()
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    local cursor = vim.api.nvim_win_get_cursor(winnr)
    self.cursor_row = cursor[1]
    self.cursor_col = cursor[2]

    local data = self.state:get_data() ---@type ghc.types.command.replace.IStateData
    local lines = fml.json.stringify_prettier_lines(data) ---@type string[]
    local textarea = ghc.ui.Textarea.new({
      title = "[Replace options]",
      position = "center",
    })
    textarea:open({
      title = data.mode == "search" and "[Search options]" or "[Replace options]",
      value = lines,
      height = #lines,
      cursor_row = 1,
      cursor_col = 1,
      width = 100,
      on_confirm = function(next_value)
        local content = table.concat(next_value, "\n") ---@type string
        local ok, json = pcall(function()
          return fml.json.parse(content)
        end)

        if not ok then
          fml.reporter.error({
            from = "ghc.command.replace.viewer",
            subject = "ui-edit.edit_replacer_state",
            message = "failed to parse json",
            details = {
              content = content,
              json = json,
            },
          })
          return
        end

        ---@cast json ghc.types.command.replace.IStateData
        local raw = vim.tbl_extend("force", data, json)

        ---@cast json ghc.types.command.replace.IStateData
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
        self.state:set_data(next_data)
      end,
    })

    local textarea_bufnr = textarea:get_bufnr()
    if textarea_bufnr ~= nil then
      vim.api.nvim_set_option_value("filetype", "json", { buf = textarea_bufnr })
    end
  end

  local function on_toggle_case_sensitive()
    self.state:toggle_flag("flag_case_sensitive")
  end

  local function on_toggle_regex()
    self.state:toggle_flag("flag_regex")
  end

  local function on_toggle_mode()
    local current_mode = self.state:get_value("mode")
    local next_mode = current_mode == "search" and "replace" or "search"
    self.state:set_value("mode", next_mode)
  end

  local function on_view_original_file()
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    local cursor = vim.api.nvim_win_get_cursor(winnr)
    local cursor_row = cursor[1]
    local meta = self.printer:get_meta(cursor_row) ---@type ghc.types.command.replace.main.ILineMeta|nil
    if meta ~= nil and meta.filepath ~= nil then
      local selected_winnr = self.previewer:select_preview_window()
      if selected_winnr == nil then
        return
      end

      local escaped_filepath = vim.fn.fnameescape(meta.filepath)
      vim.api.nvim_command("edit " .. escaped_filepath)
      if meta.lnum ~= nil then
        vim.api.nvim_win_set_cursor(selected_winnr, { meta.lnum, 0 })
      end
    end
  end

  local function on_view_file()
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    local cursor = vim.api.nvim_win_get_cursor(winnr)
    local cursor_row = cursor[1]
    local meta = self.printer:get_meta(cursor_row) ---@type ghc.types.command.replace.main.ILineMeta|nil
    if meta ~= nil and meta.filepath ~= nil then
      self.previewer:preview({
        filepath = meta.filepath,
        keep_search_pieces = true,
        cursor_row = meta.lnum or 1,
        cursor_col = 0,
      })
    end
  end

  mk({ "n", "v" }, "<leader>i", on_toggle_case_sensitive, "replace: toggle case sensitive")
  mk({ "n", "v" }, "<leader>r", on_toggle_regex, "replace: toggle regex mode")
  mk({ "n", "v" }, "<leader>m", on_toggle_mode, "replace: toggle ux mode")
  mk({ "n", "v" }, "i", on_edit, "replace: edit config")
  mk({ "n", "v" }, "a", on_edit, "replace: edit config")
  mk({ "n", "v" }, "d", on_edit, "replace: edit config")
  mk({ "n", "v" }, "r", on_edit, "replace: edit config")
  mk({ "v" }, "u", on_edit, "replace: edit config")
  mk({ "n", "v" }, "I", on_edit_full_config, "replace: edit full config")
  mk({ "n", "v" }, "A", on_edit_full_config, "replace: edit full config")
  mk({ "n", "v" }, "rr", edit_string("replace_pattern"), "replace: edit replace pattern")
  mk({ "n", "v" }, "rs", edit_string("search_pattern"), "replace: edit search pattern")
  mk({ "n", "v" }, "rc", edit_string("cwd"), "replace: edit cwd")
  mk({ "n", "v" }, "rp", edit_list("search_paths"), "replace: edit search paths")
  mk({ "n", "v" }, "re", edit_list("exclude_patterns"), "replace: edit exclude patterns")
  mk({ "n", "v" }, "ri", edit_list("include_patterns"), "replace: edit include patterns")
  mk({ "n", "v" }, "o", on_view_original_file, "replace: view original file")
  mk({ "n", "v" }, "<enter>", on_view_file, "replace: view file")
  mk({ "n", "v" }, "<2-LeftMouse>", on_view_file, "replace: view file")
end

---Render the search/replace options
---@param data ghc.types.command.replace.IStateData
---@return nil
function M:internal_render_cfg(data)
  ---@param key     ghc.enums.command.replace.StateKey
  ---@param title   string
  ---@param hlvalue string
  ---@param flags   ?{ icon: string, enabled: boolean }[]
  local function print_cfg_field(key, title, hlvalue, flags)
    local title_width = #title ---@type integer
    local cfg_name_len = self.cfg_name_len ---@type integer
    local invisible_width = cfg_name_len - title_width ---@type integer
    local left = fml.string.pad_start(title, cfg_name_len, " ") .. ": " ---@type string
    local value_start_pos = cfg_name_len + 2 ---@type integer

    ---@type ghc.ui.printer.ILineHighlight[]
    local highlights = {
      { cstart = 0, cend = invisible_width, hlname = "GhcReplaceInvisible" },
      { cstart = invisible_width, cend = cfg_name_len, hlname = "GhcReplaceOptName" },
    }

    if flags ~= nil and #flags > 0 then
      for _, flag in ipairs(flags) do
        local extra = " " .. flag.icon .. " " ---@type string
        local next_value_start_pos = value_start_pos + #extra ---@type integer
        local hlflag = flag.enabled and "GhcReplaceFlagEnabled" or "GhcReplaceFlag"

        left = left .. extra
        table.insert(highlights, {
          cstart = value_start_pos,
          cend = next_value_start_pos,
          hlname = hlflag,
        })
        value_start_pos = next_value_start_pos
      end
      left = left .. " "
    end

    local value = string.gsub(data[key], "\n", "↲")
    table.insert(highlights, { cstart = value_start_pos, cend = -1, hlname = hlvalue })
    self:internal_print(left .. value, highlights, { key = key })
  end

  local mode_indicator = data.mode == "search" and "[Search]" or "[Replace]"
  self:internal_print(
    mode_indicator .. " Press ? for mappings",
    { { cstart = 0, cend = -1, hlname = "GhcReplaceUsage" } }
  )
  print_cfg_field("cwd", "CWD", "GhcReplaceOptValue")
  print_cfg_field("search_paths", "Paths", "GhcReplaceOptValue")
  print_cfg_field("include_patterns", "Include", "GhcReplaceOptValue")
  print_cfg_field("exclude_patterns", "Exclude", "GhcReplaceOptValue")
  print_cfg_field("search_pattern", "Search", "GhcReplaceOptSearchPattern", {
    { icon = "󰑑", enabled = data.flag_regex },
    { icon = "", enabled = data.flag_case_sensitive },
  })
  if data.mode == "replace" then
    print_cfg_field("replace_pattern", "Replace", "GhcReplaceOptReplacePattern")
  end
end
---Render the search/replace options
---@param data ghc.types.command.replace.IStateData
---@param result fml.core.oxi.search.IResult
---@return nil
function M:internal_render_result(data, result)
  if result.items == nil or result.error then
    local summary = string.format("Time: %s", result.elapsed_time)
    self:internal_print(summary)
  else
    local mode = data.mode ---@type ghc.enums.command.replace.Mode
    local count_files = 0
    local count_matches = 0
    local maximum_lnum = 0 ---@type integer
    ---@diagnostic disable-next-line: unused-local
    for _1, file_item in pairs(result.items) do
      count_files = count_files + 1
      ---@diagnostic disable-next-line: unused-local
      for _2, match_item in ipairs(file_item.matches) do
        count_matches = count_matches + 1
        if maximum_lnum < match_item.lnum then
          maximum_lnum = match_item.lnum
        end
      end
    end

    local summary = string.format("Files: %s, matches: %s, time: %s", count_files, count_matches, result.elapsed_time)
    self:internal_print(summary)

    self:internal_print(
      "┌─────────────────────────────────────────────────────────────────────────────",
      { { cstart = 0, cend = -1, hlname = "GhcReplaceFence" } }
    )

    local lnum_width = #tostring(maximum_lnum)
    --local continous_line_padding = "¦ " .. string.rep(" ", lnum_width) .. "  "
    local continous_line_padding = "│ " .. string.rep(" ", lnum_width) .. "  "
    for raw_filepath, file_item in pairs(result.items) do
      local fileicon, fileicon_highlight = fml.fn.calc_fileicon(raw_filepath)
      local filepath = fml.path.relative(data.cwd, raw_filepath)

      self:internal_print(fileicon .. " " .. filepath, {
        { cstart = 0, cend = 2, hlname = fileicon_highlight },
        { cstart = 2, cend = -1, hlname = "GhcReplaceFilepath" },
      }, { filepath = filepath })

      if mode == "search" then
        ---@diagnostic disable-next-line: unused-local
        for _2, block_match in ipairs(file_item.matches) do
          local text = block_match.text
          for i, line in ipairs(block_match.lines) do
            ---@type ghc.ui.printer.ILineHighlight[]
            local match_highlights = {
              { cstart = 0, cend = 1, hlname = "GhcReplaceFence" },
            }
            local padding = i > 1 and continous_line_padding
              or "│ " .. fml.string.pad_start(tostring(block_match.lnum), lnum_width, " ") .. ": "
            ---@diagnostic disable-next-line: unused-local
            for _3, piece in ipairs(line.p) do
              table.insert(
                match_highlights,
                { cstart = #padding + piece.l, cend = #padding + piece.r, hlname = "GhcReplaceTextDeleted" }
              )
            end
            self:internal_print(
              padding .. text:sub(line.l + 1, line.r),
              match_highlights,
              { filepath = filepath, lnum = block_match.lnum + i - 1 }
            )
          end
        end
      else
        ---@diagnostic disable-next-line: unused-local
        for _2, _block_match in ipairs(file_item.matches) do
          ---@type fml.core.oxi.replace.IPreviewBlockItem
          local block_match = fml.oxi.replace_text_preview({
            text = _block_match.text,
            search_pattern = data.search_pattern,
            replace_pattern = data.replace_pattern,
            keep_search_pieces = true,
            flag_regex = data.flag_regex,
            flag_case_sensitive = data.flag_case_sensitive,
          })

          local text = block_match.text ---@type string
          local start_lnum = _block_match.lnum ---@type integer
          for i, line in ipairs(block_match.lines) do
            ---@type ghc.ui.printer.ILineHighlight[]
            local match_highlights = {
              { cstart = 0, cend = 1, hlname = "GhcReplaceFence" },
            }
            local padding = i > 1 and continous_line_padding
              or "│ " .. fml.string.pad_start(tostring(start_lnum), lnum_width, " ") .. ": "
            ---@diagnostic disable-next-line: unused-local
            for _3, piece in ipairs(line.p) do
              local hlname = piece.i % 2 == 0 and "GhcReplaceTextDeleted" or "GhcReplaceTextAdded" ---@type string
              table.insert(
                match_highlights,
                { cstart = #padding + piece.l, cend = #padding + piece.r, hlname = hlname }
              )
            end
            self:internal_print(
              padding .. text:sub(line.l + 1, line.r),
              match_highlights,
              { filepath = filepath, lnum = start_lnum + i - 1 }
            )
          end
        end
      end
    end

    self:internal_print(
      "└─────────────────────────────────────────────────────────────────────────────",
      { { cstart = 0, cend = -1, hlname = "GhcReplaceFence" } }
    )
  end
end

---@param line           string
---@param highlights     ?ghc.ui.printer.ILineHighlight[]
---@param meta           ?ghc.types.command.replace.main.ILineMeta
---@return nil
function M:internal_print(line, highlights, meta)
  local bufnr = self.bufnr ---@type integer|nil
  if bufnr == nil then
    fml.reporter.error({
      from = "ghc.command.replace.viewer",
      subject = "internal_print_line",
      message = "bufnr is nil",
      details = { line, meta, highlights },
    })
    return
  end

  self.printer:print(line, highlights, meta)
end

return M
