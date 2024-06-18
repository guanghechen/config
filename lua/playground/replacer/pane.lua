local guanghechen = require("guanghechen")
local Replacer = require("playground.replacer.replacer")

local current_buf_delete_augroup = vim.api.nvim_create_augroup("current_buf_delete_augroup", { clear = true })

local nsid = vim.api.nvim_create_namespace("REPLACE_PANE") ---@type integer

---@class guanghechen.replacer.ReplacePane
---@field private bufnr integer|nil
---@field private replacer guanghechen.types.IReplacer
local ReplacerPane = {}
ReplacerPane.__index = ReplacerPane

---@return guanghechen.replacer.ReplacePane
function ReplacerPane.new()
  local self = setmetatable({}, ReplacerPane)

  self.bufnr = nil
  self.replacer = Replacer.new() ---@type guanghechen.types.IReplacer

  return self
end

---@param winnr integer
---@param state guanghechen.types.IReplaceState|nil
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

    self.bufnr = bufnr

    vim.api.nvim_set_option_value("modifiable", false, { buf = self.bufnr })
    vim.api.nvim_set_option_value("readonly", true, { buf = bufnr })
  end

  self:render(winnr, state)
end

---@param state guanghechen.types.IReplaceState|nil
---@return nil
function ReplacerPane:render(winnr, state)
  local bufnr = self.bufnr ---@type integer
  vim.api.nvim_set_option_value("readonly", false, { buf = bufnr })
  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
  vim.api.nvim_win_set_buf(winnr, bufnr)
  pcall(function()
    self.replacer:set_state(state)
    self:internal_render(winnr)
  end)
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
  vim.api.nvim_set_option_value("readonly", true, { buf = bufnr })
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
  local state = self.replacer:get_state() ---@type guanghechen.types.IReplaceState

  local lineno = 0
  ---@param content string
  ---@return nil
  local function print_line(content)
    vim.api.nvim_buf_set_lines(bufnr, lineno, lineno, false, { content })
    lineno = lineno + 1
  end

  if state ~= nil then
    print_line("[Search/Replace] Press ? for mappings")
    print_line("Search:")
    print_line(state.search_pattern)
    print_line("Replace:")
    print_line(state.replace_pattern)
    print_line("Search Paths:" .. "    cwd=" .. state.cwd)
    print_line(table.concat(state.search_paths, ", "))
    print_line("Includes:")
    print_line(table.concat(state.include_patterns, ", "))
    print_line("Exclude:")
    print_line(table.concat(state.include_patterns, ", "))
  end

  local result = self.replacer:replace() ---@type guanghechen.types.IReplaceResult|nil
  if state ~= nil and result ~= nil then
    print_line("")

    if result.items == nil or result.error then
      print_line(string.format("Time: %s", result.elapsed_time))
    else
      local padding = "¦  " ---@type string
      local summary = string.format("Files: %s, time: %s", #result.items, result.elapsed_time)

      print_line(summary)
      print_line(
        "┌─────────────────────────────────────────────────────────────────────────────"
      )

      for _1, file_item in ipairs(result.items) do
        local fileicon = guanghechen.util.filetype.calc_fileicon(file_item.filepath)
        local filepath = guanghechen.util.path.relative(state.cwd, file_item.filepath)
        print_line(fileicon .. " " .. filepath)

        for _2, match_item in ipairs(file_item.matches) do
          print_line(padding .. match_item.lineno .. ": " .. match_item.lines:gsub("\n", "\\n"))
        end
      end

      print_line(
        "└─────────────────────────────────────────────────────────────────────────────"
      )
    end

    print_line("")
  end

  vim.api.nvim_win_set_cursor(winnr, { 12, 0 })
end

return ReplacerPane
