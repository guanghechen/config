local Searcher = require("guanghechen.util.searcher")
local util_json = require("guanghechen.util.json")
local util_filetype = require("guanghechen.util.filetype")
local util_path = require("guanghechen.util.path")
local util_string = require("guanghechen.util.string")

local current_buf_delete_augroup = vim.api.nvim_create_augroup("current_buf_delete_augroup", { clear = true })

local nsid = vim.api.nvim_create_namespace("REPLACE_PANE") ---@type integer

---@class guagnhechen.replacer.IReplacePaneConfig : guanghechen.types.ISearcherState
---@field public replace_pattern string

---@class guanghechen.replacer.ReplacePane
---@field private mode "search"|"replace"
---@field private bufnr integer|nil
---@field private searcher guanghechen.types.ISearcher
---@field private replace_pattern string
local ReplacerPane = {}
ReplacerPane.__index = ReplacerPane

---@return guanghechen.replacer.ReplacePane
function ReplacerPane.new()
  local self = setmetatable({}, ReplacerPane)

  self.mode = "search"
  self.bufnr = nil
  self.searcher = Searcher.new()
  self.replace_pattern = ""

  return self
end

---@param winnr integer
---@param state guanghechen.types.ISearcherState|nil
---@return nil
function ReplacerPane:open(winnr, state)
  if self.bufnr == nil then
    local bufnr = vim.api.nvim_create_buf(true, true) ---@type integer
    vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })
    vim.api.nvim_set_option_value("buflisted", true, { buf = bufnr })
    vim.cmd(string.format("%sbufdo file %s/REPLACE", bufnr, bufnr)) --- Rename the buf
    vim.api.nvim_create_autocmd("BufDelete", {
      group = current_buf_delete_augroup,
      buffer = bufnr,
      callback = function()
        self.bufnr = nil
      end,
    })

    ---@param modes string|string[]
    ---@param key string
    ---@param action any
    ---@param desc string
    local function mk(modes, key, action, desc)
      vim.keymap.set(modes, key, action, { noremap = true, silent = true, buffer = bufnr, desc = desc })
    end

    function on_edit()
      self:edit(winnr)
    end

    mk({ "n" }, "i", on_edit, "Edit search config")
    mk({ "n" }, "I", on_edit, "Edit search config")
    mk({ "n" }, "a", on_edit, "Edit search config")
    mk({ "n" }, "A", on_edit, "Edit search config")

    self.bufnr = bufnr

    vim.api.nvim_set_option_value("modifiable", false, { buf = self.bufnr })
    vim.api.nvim_set_option_value("readonly", true, { buf = bufnr })
  end

  pcall(function()
    self.searcher:set_state(state)
  end)
  self:render(winnr)
end

---@return nil
function ReplacerPane:render(winnr)
  local bufnr = self.bufnr ---@type integer
  vim.api.nvim_set_option_value("readonly", false, { buf = bufnr })
  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
  vim.api.nvim_win_set_buf(winnr, bufnr)
  pcall(function()
    self:internal_render(winnr)
  end)
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
  vim.api.nvim_set_option_value("readonly", true, { buf = bufnr })
end

---@param winnr integer
---@return nil
function ReplacerPane:edit(winnr)
  local state = self.searcher:get_state() ---@type guanghechen.types.ISearcherState|nil
  if state == nil then
    return
  end

  local Popup = require("nui.popup")
  local event = require("nui.utils.autocmd").event

  local popup = Popup({
    enter = true,
    focusable = true,
    border = {
      style = "rounded",
      text = {
        top = "Search/Replace options",
        top_align = "center",
      },
    },
    position = "50%",
    size = {
      width = "80%",
      height = "60%",
    },
  })

  -- mount/open the component
  popup:mount()

  -- unmount component when cursor leaves buffer
  popup:on(event.BufLeave, function()
    popup:unmount()
  end)

  local function on_confirm()
    local content = table.concat(vim.api.nvim_buf_get_lines(popup.bufnr, 0, -1, false), "\n") ---@type string
    local ok, json = pcall(function()
      util_json.parse(content)
    end)
    if ok then
      self.searcher:set_state(json)
      self:render(winnr)
    end
    popup:unmount()
  end

  vim.api.nvim_set_option_value("filetype", "json", { buf = popup.bufnr })
  popup:map("n", "<cr>", on_confirm, { noremap = true, silent = true, desc = "Confirm" })

  -- set content
  ---@type guagnhechen.replacer.IReplacePaneConfig
  local json = {
    cwd = state.cwd,
    flag_regex = state.flag_regex,
    flag_case_sensitive = state.flag_case_sensitive,
    search_pattern = state.search_pattern,
    replace_pattern = self.replace_pattern,
    search_paths = state.search_paths,
    include_patterns = state.include_patterns,
    exclude_patterns = state.exclude_patterns,
  }
  local lines = util_json.stringify_prettier_lines(json) ---@type string[]
  vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, lines)
end

---@param winnr integer
---@return nil
function ReplacerPane:internal_render(winnr)
  local bufnr = self.bufnr ---@type integer

  ---Clear the buf before render.
  vim.api.nvim_buf_clear_namespace(bufnr, nsid, 0, -1)
  vim.api.nvim_buf_clear_namespace(bufnr, nsid, 0, -1)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})

  ---Render the search/replace options
  local state = self.searcher:get_state() ---@type guanghechen.types.ISearcherState|nil

  local lineno = 0
  ---@param content string
  ---@return nil
  local function print_line(content)
    vim.api.nvim_buf_set_lines(bufnr, lineno, lineno, false, { content })
    lineno = lineno + 1
  end

  if state ~= nil then
    local mode_indicator = self.mode == "search" and "[Search]" or "[Replace]"
    print_line(mode_indicator .. " Press ? for mappings")
    print_line("Search:")
    print_line(state.search_pattern)
    if self.mode == "replace" then
      print_line("Replace:")
      print_line(self.replace_pattern)
    end
    print_line("Search Paths:" .. "    cwd=" .. state.cwd)
    print_line(table.concat(state.search_paths, ", "))
    print_line("Includes:")
    print_line(table.concat(state.include_patterns, ", "))
    print_line("Exclude:")
    print_line(table.concat(state.include_patterns, ", "))
  end

  local result = self.searcher:search() ---@type guanghechen.types.ISearchResult|nil
  if state ~= nil and result ~= nil then
    print_line("")

    if result.items == nil or result.error then
      print_line(string.format("Time: %s", result.elapsed_time))
      vim.api.nvim_win_set_cursor(winnr, { lineno - 1, 0 })
    else
      local summary = string.format("Files: %s, time: %s", #result.items, result.elapsed_time)
      local maximum_lineno = 0 ---@type integer

      ---@diagnostic disable-next-line: unused-local
      for _1, file_item in ipairs(result.items) do
        ---@diagnostic disable-next-line: unused-local
        for _2, match_item in ipairs(file_item.matches) do
          if maximum_lineno < match_item.lineno then
            maximum_lineno = match_item.lineno
          end
        end
      end

      print_line(summary)
      print_line(
        "┌─────────────────────────────────────────────────────────────────────────────"
      )
      vim.api.nvim_win_set_cursor(winnr, { lineno, 0 })

      local lineno_width = #tostring(maximum_lineno)
      local continous_line_padding = "¦ " .. string.rep(" ", lineno_width) .. "  "
      ---@diagnostic disable-next-line: unused-local
      for _1, file_item in ipairs(result.items) do
        local fileicon = util_filetype.calc_fileicon(file_item.filepath)
        local filepath = util_path.relative(state.cwd, file_item.filepath)
        print_line(fileicon .. " " .. filepath)

        ---@diagnostic disable-next-line: unused-local
        for _2, match_item in ipairs(file_item.matches) do
          local text = match_item.lines:gsub("[\r\n]+$", "") ---@type string
          local lines = util_string.split(text, "\r\n|\r|\n")
          local padding = "¦ " .. util_string.padStart(tostring(match_item.lineno), lineno_width, " ") .. ": "
          print_line(padding .. lines[1])

          for i = 2, #lines do
            print_line(continous_line_padding .. lines[i])
          end
        end
      end

      print_line(
        "└─────────────────────────────────────────────────────────────────────────────"
      )
    end
  end
end

return ReplacerPane
