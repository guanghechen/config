local nvim_tools = require("nvim_tools")
local Input = require("kyokuya.component.input")
local Textarea = require("kyokuya.component.textarea")
local util_filetype = require("guanghechen.util.filetype")
local util_json = require("guanghechen.util.json")
local util_path = require("guanghechen.util.path")
local util_reporter = require("guanghechen.util.reporter")
local util_string = require("guanghechen.util.string")
local util_table = require("guanghechen.util.table")
local util_window = require("guanghechen.util.window")

local kyokuya_replace_buftype = "nofile"
local kyokuya_replace_filetype = "kyokuya-replace"
local kyokuya_buf_delete_augroup = vim.api.nvim_create_augroup("kyokuya_buf_delete", { clear = true })

---@return integer|nil
local function find_first_replace_buf()
  for _, bufnr in ipairs(vim.t.bufs) do
    local buftype = vim.api.nvim_get_option_value("buftype", { buf = bufnr })
    local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr })
    if buftype == kyokuya_replace_buftype and filetype == kyokuya_replace_filetype then
      return bufnr
    end
  end
  return nil
end

---@class kyokuya.replace.IReplaceViewOptions
---@field public state        kyokuya.replace.ReplaceState
---@field public nsnr         integer

---@class kyokuya.replace.ReplaceView
---@field private state       kyokuya.replace.ReplaceState
---@field private nsnr        integer
---@field private bufnr       integer|nil
---@field private lnum        integer
---@field private line_metas  table<number, kyokuya.replace.IReplaceViewLineMeta|nil>
---@field private cursor_row  integer
---@field private cursor_col  integer
local M = {}
M.__index = M

---@param opts kyokuya.replace.IReplaceViewOptions
---@return kyokuya.replace.ReplaceView
function M.new(opts)
  local self = setmetatable({}, M)

  self.state = opts.state
  self.nsnr = opts.nsnr
  self.bufnr = nil
  self.lnum = 0
  self.line_metas = {}
  self.cursor_row = 1
  self.cursor_col = 0

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
      vim.api.nvim_set_option_value("buftype", kyokuya_replace_buftype, { buf = bufnr })
      vim.api.nvim_set_option_value("filetype", kyokuya_replace_filetype, { buf = bufnr })
      vim.api.nvim_set_option_value("buflisted", true, { buf = bufnr })
      vim.cmd(string.format("%sbufdo file %s/REPLACE", bufnr, bufnr)) --- Rename the buf
      vim.api.nvim_create_autocmd("BufDelete", {
        group = kyokuya_buf_delete_augroup,
        buffer = bufnr,
        callback = function()
          self.bufnr = nil
        end,
      })

      self.bufnr = bufnr
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
  local bufnr = opts.bufnr ---@type integer
  local force = not not opts.force ---@type boolean
  local data = self.state:get_data() ---@type kyokuya.replace.IReplaceStateData
  local result = self.state:search(force) ---@type kyokuya.replace.ISearchResult|nil

  ---Clear temporary states.
  self.lnum = 0
  -- self.line_metas = {} --don't clear the line metas to reuse the search/replace result view.
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})

  self:internal_render_cfg(data)
  if result ~= nil then
    self:internal_print("", nil)
    self:internal_print("", nil)
    self:internal_render_result(data, result)
  end

  ---Set cursor position.
  if self.cursor_row > self.lnum then
    self.cursor_row = self.lnum
  end
  local maximum_column_of_line = vim.fn.strwidth(vim.fn.getline(self.cursor_row))
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

  ---@param key kyokuya.replace.IReplaceStateKey
  ---@param position? "center"|"cursor
  ---@return nil
  local function edit_string(key, position)
    position = position or "cursor"
    return function()
      local winnr = vim.api.nvim_get_current_win() ---@type integer
      local cursor = vim.api.nvim_win_get_cursor(winnr)
      self.cursor_row = cursor[1]
      self.cursor_col = cursor[2]

      local cursor_col = cursor[2]
      local input = Input.new()
      local value = self.state:get_value(key) ---@type string
      input:open({
        title = "[" .. key .. "]",
        prompt = "",
        value = value,
        position = position,
        cursor_col = cursor_col - 12,
        on_confirm = function(next_value)
          self.state:set_value(key, next_value)
        end,
      })
    end
  end

  ---@param key kyokuya.replace.IReplaceStateKey
  ---@param position? "center"|"cursor
  ---@return nil
  local function edit_list(key, position)
    position = position or "cursor"
    return function()
      local winnr = vim.api.nvim_get_current_win() ---@type integer
      local cursor = vim.api.nvim_win_get_cursor(winnr)
      self.cursor_row = cursor[1]
      self.cursor_col = cursor[2]

      local textarea = Textarea.new()
      local value = self.state:get_value(key) ---@type string
      local lines = util_table.parse_comma_list(value) ---@type string[]
      textarea:open({
        title = "[" .. key .. "]",
        value = lines,
        position = position,
        cursor_row = 1,
        cursor_col = 1,
        height = 10,
        width = 80,
        on_confirm = function(next_value)
          local normalized_list = {}
          for _, next_line in ipairs(next_value) do
            table.insert(normalized_list, nvim_tools.normalize_comma_list(next_line))
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
    local meta = self.line_metas[cursor_row]
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

    local textarea = Textarea:new()
    local data = self.state:get_data() ---@type kyokuya.replace.IReplaceStateData
    local lines = util_json.stringify_prettier_lines(data) ---@type string[]
    textarea:open({
      title = data.mode == "search" and "[Search options]" or "[Replace options]",
      value = lines,
      position = "center",
      cursor_row = 1,
      cursor_col = 1,
      width = 100,
      on_confirm = function(next_value)
        local content = table.concat(next_value, "\n") ---@type string
        local ok, json = pcall(function()
          return util_json.parse(content)
        end)

        if not ok then
          util_reporter.error({
            from = "kyokuya/replace",
            subject = "ui-edit.edit_replacer_state",
            message = "failed to parse json",
            details = {
              content = content,
              json = json,
            },
          })
          return
        end

        ---@cast json kyokuya.replace.IReplaceStateData
        local raw = vim.tbl_extend("force", data, json)

        ---@cast json kyokuya.replace.IReplaceStateData
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

  local function on_enter_file()
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    local cursor = vim.api.nvim_win_get_cursor(winnr)
    local cursor_row = cursor[1]
    local meta = self.line_metas[cursor_row]
    if meta ~= nil and meta.filepath ~= nil then
      local selected_winnr = util_window.pick_window({ motivation = "project" }) ---@type integer|nil
      if selected_winnr == nil then
        return
      end

      if selected_winnr < 0 then
        local width = vim.api.nvim_win_get_width(winnr)
        local max_width = 80

        vim.cmd("vsplit")
        if width / 2 > max_width then
          vim.api.nvim_win_set_width(winnr, max_width)
        end
      else
        vim.api.nvim_set_current_win(selected_winnr)
      end
      local escaped_filepath = vim.fn.fnameescape(meta.filepath)
      vim.api.nvim_command("edit " .. escaped_filepath)
      if meta.lnum ~= nil then
        vim.api.nvim_win_set_cursor(selected_winnr, { meta.lnum, 0 })
      end
    end
  end

  mk({ "n", "v" }, "i", on_edit, "replace: edit config")
  mk({ "n", "v" }, "a", on_edit, "replace: edit config")
  mk({ "n", "v" }, "I", on_edit_full_config, "replace: edit full config")
  mk({ "n", "v" }, "A", on_edit_full_config, "replace: edit full config")
  mk({ "n", "v" }, "rr", edit_string("replace_pattern"), "replace: edit replace pattern")
  mk({ "n", "v" }, "rs", edit_string("search_pattern"), "replace: edit search pattern")
  mk({ "n", "v" }, "rc", edit_string("cwd"), "replace: edit cwd")
  mk({ "n", "v" }, "rp", edit_list("search_paths"), "replace: edit search paths")
  mk({ "n", "v" }, "re", edit_list("exclude_patterns"), "replace: edit exclude patterns")
  mk({ "n", "v" }, "ri", edit_list("include_patterns"), "replace: edit include patterns")
  mk({ "n", "v" }, "<enter>", on_enter_file, "replace: view file")
end

---Render the search/replace options
---@param data kyokuya.replace.IReplaceStateData
---@return nil
function M:internal_render_cfg(data)
  local mode_indicator = data.mode == "search" and "[Search]" or "[Replace]"
  self:internal_print(mode_indicator .. " Press ? for mappings", nil)
  self:internal_print("      Search: " .. data.search_pattern, { key = "search_pattern" }, {
    { cstart = 00, cend = 06, hlname = "kyokuya_invisible" },
    { cstart = 06, cend = 14, hlname = "kyokuya_replace_cfg_name" },
    { cstart = 14, cend = -1, hlname = "kyokuya_replace_cfg_search_pattern" },
  })
  self:internal_print("     Replace: " .. data.replace_pattern, { key = "replace_pattern" }, {
    { cstart = 00, cend = 05, hlname = "kyokuya_invisible" },
    { cstart = 05, cend = 14, hlname = "kyokuya_replace_cfg_name" },
    { cstart = 14, cend = -1, hlname = "kyokuya_replace_cfg_replace_pattern" },
  })
  self:internal_print("         CWD: " .. data.cwd, { key = "cwd" }, {
    { cstart = 00, cend = 09, hlname = "kyokuya_invisible" },
    { cstart = 09, cend = 14, hlname = "kyokuya_replace_cfg_name" },
    { cstart = 14, cend = -1, hlname = "kyokuya_replace_cfg_value" },
  })
  self:internal_print("Search Paths: " .. data.search_paths, { key = "search_paths" }, {
    { cstart = 00, cend = 14, hlname = "kyokuya_replace_cfg_name" },
    { cstart = 14, cend = -1, hlname = "kyokuya_replace_cfg_value" },
  })
  self:internal_print("     Include: " .. data.include_patterns, { key = "include_patterns" }, {
    { cstart = 00, cend = 05, hlname = "kyokuya_invisible" },
    { cstart = 05, cend = 14, hlname = "kyokuya_replace_cfg_name" },
    { cstart = 14, cend = -1, hlname = "kyokuya_replace_cfg_value" },
  })
  self:internal_print("     Exclude: " .. data.exclude_patterns, { key = "exclude_patterns" }, {
    { cstart = 00, cend = 05, hlname = "kyokuya_invisible" },
    { cstart = 05, cend = 14, hlname = "kyokuya_replace_cfg_name" },
    { cstart = 14, cend = -1, hlname = "kyokuya_replace_cfg_value" },
  })
end
---Render the search/replace options
---@param data kyokuya.replace.IReplaceStateData
---@param result kyokuya.replace.ISearchResult
---@return nil
function M:internal_render_result(data, result)
  if result.items == nil or result.error then
    local summary = string.format("Time: %s", result.elapsed_time)
    self:internal_print(summary, nil)
  else
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
    self:internal_print(summary, nil)

    self:internal_print(
      "┌─────────────────────────────────────────────────────────────────────────────",
      nil
    )

    local lnum_width = #tostring(maximum_lnum)
    local continous_line_padding = "¦ " .. string.rep(" ", lnum_width) .. "  "
    for raw_filepath, file_item in pairs(result.items) do
      local fileicon, fileicon_highlight = util_filetype.calc_fileicon(raw_filepath)
      local filepath = util_path.relative(data.cwd, raw_filepath)

      self:internal_print(fileicon .. " " .. filepath, { filepath = filepath }, {
        { cstart = 0, cend = 2, hlname = fileicon_highlight },
        { cstart = 2, cend = -1, hlname = "kyokuya_replace_filepath" },
      })

      ---@diagnostic disable-next-line: unused-local
      for _2, match_item in ipairs(file_item.matches) do
        local text = match_item.lines:gsub("[\r\n]+$", "") ---@type string
        local lines = util_string.split(text, "\r\n|\r|\n")
        local padding = "¦ " .. util_string.padStart(tostring(match_item.lnum), lnum_width, " ") .. ": "
        self:internal_print(padding .. lines[1], { filepath = filepath, lnum = match_item.lnum })

        for i = 2, #lines do
          self:internal_print(continous_line_padding .. lines[i], { filepath = filepath, lnum = match_item.lnum })
        end
      end
    end

    self:internal_print(
      "└─────────────────────────────────────────────────────────────────────────────",
      nil
    )
  end
end

---@param line           string
---@param meta           kyokuya.replace.IReplaceViewLineMeta|nil
---@param highlights     ?kyokluya.replace.IReplaceViewLineHighlights[]|nil
---@return nil
function M:internal_print(line, meta, highlights)
  local nsnr = self.nsnr ---@type integer
  local bufnr = self.bufnr ---@type integer|nil
  local lnum = self.lnum ---@type integer

  if bufnr == nil then
    util_reporter.error({
      from = "kyokuya.replace.view",
      subject = "internal_print_line",
      message = "bufnr is nil",
      details = { line, meta, highlights },
    })
    return
  end

  vim.api.nvim_buf_set_lines(bufnr, lnum, lnum, false, { line })

  if highlights ~= nil then
    for _, hl in ipairs(highlights) do
      if hl.hlname ~= nil then
        vim.api.nvim_buf_add_highlight(bufnr, nsnr, hl.hlname, lnum, hl.cstart, hl.cend)
      end
    end
  end

  self.lnum = lnum + 1
  self.line_metas[self.lnum] = meta
end

return M
