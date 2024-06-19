local util_json = require("guanghechen.util.json")
local util_filetype = require("guanghechen.util.filetype")
local util_path = require("guanghechen.util.path")
local util_reporter = require("guanghechen.util.reporter")
local util_string = require("guanghechen.util.string")
local util_table = require("guanghechen.util.table")
local util_window = require("guanghechen.util.window")
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

  if winnr == 0 then
    winnr = vim.api.nvim_get_current_win()
  end

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

  ---@param key kyokuya.types.IReplaceStateKey
  ---@param position? "center"|"cursor
  ---@return nil
  local function edit_string(key, position)
    position = position or "cursor"
    return function()
      local cursor = vim.api.nvim_win_get_cursor(winnr)
      local cursor_col = cursor[2]
      local input = Input.new()
      local value = state[key] ---@type string
      input:open({
        title = "[" .. key .. "]",
        prompt = "",
        value = value,
        position = position,
        cursor_col = cursor_col - 12,
        on_confirm = function(next_value)
          if value ~= next_value then
            local next_state = vim.tbl_extend("force", state, { [key] = next_value })
            on_change_from_opts(next_state)
          end
        end,
      })
    end
  end

  ---@param key kyokuya.types.IReplaceStateKey
  ---@param position? "center"|"cursor
  ---@return nil
  local function edit_list(key, position)
    position = position or "cursor"
    return function()
      local textarea = Textarea.new()
      local value = state[key] ---@type string[]
      textarea:open({
        title = "[" .. key .. "]",
        value = value,
        position = position,
        cursor_row = 1,
        cursor_col = 1,
        height = 10,
        width = 80,
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

  local function on_edit()
    local cursor = vim.api.nvim_win_get_cursor(winnr)
    local cursor_row = cursor[1]
    local meta = line_metas[cursor_row]
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
    local textarea = Textarea:new()
    local lines = util_json.stringify_prettier_lines(state) ---@type string[]
    textarea:open({
      title = state.mode == "search" and "[Search options]" or "[Replace options]",
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
        if ok then
          ---@cast json kyokuya.types.IReplacerState
          ---@type kyokuya.types.IReplacerState
          local raw = vim.tbl_extend("force", state, json)

          ---@type kyokuya.types.IReplacerState
          local next_state = {
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
          on_change_from_opts(next_state)
        else
          util_reporter.error({
            from = "kyokuya/replace",
            subject = "ui-edit.edit_replacer_state",
            message = "failed to parse json",
            details = {
              content = content,
              json = json,
            },
          })
        end
      end,
    })

    local textarea_bufnr = textarea:get_bufnr()
    if textarea_bufnr ~= nil then
      vim.api.nvim_set_option_value("filetype", "json", { buf = textarea_bufnr })
    end
  end

  local function on_enter_file()
    local cursor = vim.api.nvim_win_get_cursor(winnr)
    local cursor_row = cursor[1]
    local meta = line_metas[cursor_row]
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

  ---Render the search/replace options
  local mode_indicator = state.mode == "search" and "[Search]" or "[Replace]"
  print_line(mode_indicator .. " Press ? for mappings", nil)
  print_line("      Search: " .. state.search_pattern, { key = "search_pattern" })
  print_line("     Replace: " .. state.replace_pattern, { key = "replace_pattern" })
  print_line("         CWD: " .. state.cwd, { key = "cwd" })
  print_line("Search Paths: " .. table.concat(state.search_paths, ", "), { key = "search_paths" })
  print_line("     Include: " .. table.concat(state.include_patterns, ", "), { key = "include_patterns" })
  print_line("     Exclude: " .. table.concat(state.exclude_patterns, ", "), { key = "exclude_patterns" })

  ---Render the search/replace result
  local result = searcher:search({ state = state, force = force }) ---@type kyokuya.types.ISearchResult|nil
  if result ~= nil then
    print_line("", nil)
    print_line("", nil)

    if result.items == nil or result.error then
      local summary = string.format("Time: %s", result.elapsed_time)
      print_line(summary, nil)
      vim.api.nvim_win_set_cursor(winnr, { lnum - 1, 0 })
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
      print_line(summary, nil)

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
