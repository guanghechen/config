local util_filetype = require("guanghechen.util.filetype")
local util_path = require("guanghechen.util.path")
local util_string = require("guanghechen.util.string")

---@class kyokuya.replacer.IViewRenderOptions
---@field public searcher kyokuya.types.ISearcher
---@field public state kyokuya.types.IReplacerState
---@field public nsnr integer   namespace id
---@field public bufnr integer  buffer id
---@field public winnr integer  window id
---@field public force boolean  force research

---@param opts kyokuya.replacer.IViewRenderOptions
---@return nil
local function internal_render(opts)
  local searcher = opts.searcher ---@type kyokuya.types.ISearcher
  local nsnr = opts.nsnr ---@type integer
  local bufnr = opts.bufnr ---@type integer
  local winnr = opts.winnr ---@type integer
  local state = opts.state ---@type kyokuya.types.IReplacerState
  local force = opts.force ---@type boolean

  ---Clear the buf before render.
  vim.api.nvim_buf_clear_namespace(bufnr, nsnr, 0, -1)
  vim.api.nvim_buf_clear_namespace(bufnr, nsnr, 0, -1)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})

  local lineno = 0
  ---@param content string
  ---@return nil
  local function print_line(content)
    vim.api.nvim_buf_set_lines(bufnr, lineno, lineno, false, { content })
    lineno = lineno + 1
  end

  ---Render the search/replace options
  local mode_indicator = state.mode == "search" and "[Search]" or "[Replace]"
  print_line(mode_indicator .. " Press ? for mappings")
  print_line("Search:")
  print_line(state.search_pattern)
  if state.mode == "replace" then
    print_line("Replace:")
    print_line(state.replace_pattern)
  end
  print_line("Search Paths:" .. "    cwd=" .. state.cwd)
  print_line(table.concat(state.search_paths, ", "))
  print_line("Includes:")
  print_line(table.concat(state.include_patterns, ", "))
  print_line("Exclude:")
  print_line(table.concat(state.include_patterns, ", "))

  ---Render the search/replace result
  local result = searcher:search({ state = state, force = force }) ---@type kyokuya.types.ISearchResult|nil
  if result ~= nil then
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
      for raw_filepath, file_item in pairs(result.items) do
        local fileicon = util_filetype.calc_fileicon(raw_filepath)
        local filepath = util_path.relative(state.cwd, raw_filepath)
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

---@class guanghechen.replacer.renderer
---@field private searcher kyokuya.types.ISearcher
---@field private bufnr integer
---@field private winnr integer
---@field private nsnr integer
local M = {}

---@param opts kyokuya.replacer.IViewRenderOptions
---@return nil
function M.render(opts)
  local winnr = opts.winnr ---@type integer
  local bufnr = opts.bufnr ---@type integer

  vim.api.nvim_set_option_value("readonly", false, { buf = bufnr })
  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
  vim.api.nvim_win_set_buf(winnr, bufnr)
  pcall(function()
    internal_render(opts)
  end)
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
  vim.api.nvim_set_option_value("readonly", true, { buf = bufnr })
end

return M
