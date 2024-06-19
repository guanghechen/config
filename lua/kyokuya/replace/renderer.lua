local util_filetype = require("guanghechen.util.filetype")
local util_path = require("guanghechen.util.path")
local util_string = require("guanghechen.util.string")
local util_table = require("guanghechen.util.table")
local Input = require("kyokuya.component.input")
local Textarea = require("kyokuya.component.textarea")

---@class kyokuya.replacer.IViewRenderOptions
---@field public searcher kyokuya.types.ISearcher
---@field public state kyokuya.types.IReplacerState
---@field public nsnr integer   namespace id
---@field public bufnr integer  buffer id
---@field public winnr integer  window id
---@field public force boolean  force research
---@field public on_change fun(next_state: kyokuya.types.IReplacerState):nil

---@param opts kyokuya.replacer.IViewRenderOptions
---@return nil
local function internal_render(opts)
  local searcher = opts.searcher ---@type kyokuya.types.ISearcher
  local nsnr = opts.nsnr ---@type integer
  local bufnr = opts.bufnr ---@type integer
  local winnr = opts.winnr ---@type integer
  local state = opts.state ---@type kyokuya.types.IReplacerState
  local force = opts.force ---@type boolean
  local on_change_from_opts = opts.on_change

  ---Clear the buf before render.
  vim.api.nvim_buf_clear_namespace(bufnr, nsnr, 0, -1)
  vim.api.nvim_buf_clear_namespace(bufnr, nsnr, 0, -1)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})

  local line_metas = {} ---@type (kyokuya.types.IReplaceResultLineMeta|nil)[]

  local lnum = 0
  ---@param content string
  ---@param meta kyokuya.types.IReplaceResultLineMeta|nil
  ---@return nil
  local function print_line(content, meta)
    vim.api.nvim_buf_set_lines(bufnr, lnum, lnum, false, { content })
    lnum = lnum + 1
    line_metas[lnum] = meta
  end

  ---@param modes string|string[]
  ---@param key string
  ---@param action any
  ---@param desc string
  local function mk(modes, key, action, desc)
    vim.keymap.set(modes, key, action, { noremap = true, silent = true, buffer = bufnr, desc = desc })
  end

  local function on_edit()
    local cursor = vim.api.nvim_win_get_cursor(winnr)
    local cursor_row = cursor[1]
    local cursor_col = cursor[2]
    local meta = line_metas[cursor_row]
    if meta ~= nil and meta.key ~= nil then
      local key = meta.key
      if key == "cwd" or key == "search_pattern" or key == "replace_pattern" then
        local input = Input.new()
        local value = state[key] ---@type string
        input:open({
          icon = "",
          title = key,
          value = value,
          cursor_col = cursor_col - 12,
          on_confirm = function(next_value)
            if value ~= next_value then
              local next_state = vim.tbl_extend("force", state, { [key] = next_value })
              on_change_from_opts(next_state)
            end
          end,
        })
      end
      if key == "search_paths" or key == "include_patterns" or key == "exclude_patterns" then
        local textarea = Textarea.new()
        local value = state[key] ---@type string[]
        textarea:open({
          icon = "",
          title = key,
          value = value,
          cursor_row = 1,
          cursor_col = 1,
          on_confirm = function(next_value)
            local normailized = util_table.parse_comma_list(next_value)
            if not util_table.equals_array(value, normailized) then
              local next_state = vim.tbl_extend("force", state, { [key] = normailized })
              on_change_from_opts(next_state)
            end
          end,
        })
      end
    end
  end

  mk({ "n" }, "i", on_edit, "Edit search/replace config")
  mk({ "n" }, "a", on_edit, "Edit search/replace config")

  ---Render the search/replace options
  local mode_indicator = state.mode == "search" and "[Search]" or "[Replace]"
  print_line(mode_indicator .. " Press ? for mappings", nil)
  print_line("      Search: " .. state.search_pattern, { key = "search_pattern" })
  print_line("     Replace: " .. state.replace_pattern, { key = "replace_pattern" })
  print_line("         CWD: " .. state.cwd, { key = "cwd" })
  print_line("Search Paths: " .. table.concat(state.search_paths, ", "), { key = "search_paths" })
  print_line("    Includes: " .. table.concat(state.include_patterns, ", "), { key = "include_patterns" })
  print_line("     Exclude: " .. table.concat(state.exclude_patterns, ", "), { key = "exclude_patterns" })

  ---Render the search/replace result
  local result = searcher:search({ state = state, force = force }) ---@type kyokuya.types.ISearchResult|nil
  if result ~= nil then
    print_line("", nil)
    print_line("", nil)
    print_line(
      "####################################################################################################",
      nil
    )
    print_line("", nil)
    print_line("", nil)

    if result.items == nil or result.error then
      local summary = string.format("Time: %s", result.elapsed_time)
      print_line(summary, nil)
      vim.api.nvim_win_set_cursor(winnr, { lnum - 1, 0 })
    else
      local summary = string.format("Files: %s, time: %s", #result.items, result.elapsed_time)
      print_line(summary, nil)

      local maximum_lnum = 0 ---@type integer
      ---@diagnostic disable-next-line: unused-local
      for _1, file_item in pairs(result.items) do
        ---@diagnostic disable-next-line: unused-local
        for _2, match_item in ipairs(file_item.matches) do
          if maximum_lnum < match_item.lnum then
            maximum_lnum = match_item.lnum
          end
        end
      end

      print_line(
        "┌─────────────────────────────────────────────────────────────────────────────",
        nil
      )
      vim.api.nvim_win_set_cursor(winnr, { lnum, 0 })

      local lnum_width = #tostring(maximum_lnum)
      local continous_line_padding = "¦ " .. string.rep(" ", lnum_width) .. "  "
      for raw_filepath, file_item in pairs(result.items) do
        local fileicon = util_filetype.calc_fileicon(raw_filepath)
        local filepath = util_path.relative(state.cwd, raw_filepath)
        print_line(fileicon .. " " .. filepath, { filepath = filepath })

        ---@diagnostic disable-next-line: unused-local
        for _2, match_item in ipairs(file_item.matches) do
          local text = match_item.lines:gsub("[\r\n]+$", "") ---@type string
          local lines = util_string.split(text, "\r\n|\r|\n")
          local padding = "¦ " .. util_string.padStart(tostring(match_item.lnum), lnum_width, " ") .. ": "
          print_line(padding .. lines[1], { filepath = filepath, lnum = match_item.lnum })

          for i = 2, #lines do
            print_line(continous_line_padding .. lines[i], { filepath = filepath, lnum = match_item.lnum })
          end
        end
      end

      print_line(
        "└─────────────────────────────────────────────────────────────────────────────",
        nil
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
