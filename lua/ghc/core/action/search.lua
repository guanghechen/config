local action_state = require("telescope.actions.state")

---@class ghc.core.action.search.grep_string.context
local context = {
  repo = require("ghc.core.context.repo"),
}

---@class ghc.core.action.search.grep_string.util
local util = {
  path = require("ghc.core.util.path"),
  regex = require("guanghechen.util.regex"),
  selection = require("guanghechen.util.selection"),
  table = require("guanghechen.util.table"),
}

---@alias ISearchContext { workspace: string, cwd: string, directory: string, bufnr: number }

---@return ISearchContext
local function get_search_context()
  return {
    workspace = util.path.workspace(),
    cwd = util.path.cwd(),
    directory = util.path.current_directory(),
    bufnr = vim.api.nvim_get_current_buf(),
  }
end

---@param scope_paths ISearchContext
---@param scope ghc.core.constant.enum.CWD_SCOPE
local function get_cwd_by_scope(scope_paths, scope)
  if scope == "W" then
    return scope_paths.workspace
  end

  if scope == "C" then
    return scope_paths.cwd
  end

  if scope == "D" then
    return scope_paths.directory
  end

  if scope == "B" then
    return scope_paths.directory
  end

  return scope_paths.cwd
end

---@param scope ghc.core.constant.enum.CWD_SCOPE
---@return string
local function get_display_name_of_scope(scope)
  if scope == "W" then
    return "workspace"
  end

  if scope == "C" then
    return "cwd"
  end

  if scope == "D" then
    return "directory"
  end

  if scope == "B" then
    return "buffer"
  end

  return "cwd"
end

---@param scope ghc.core.constant.enum.CWD_SCOPE
---@return ghc.core.constant.enum.CWD_SCOPE
local function toggle_scope_carousel(scope)
  if scope == "W" then
    return "C"
  end

  if scope == "C" then
    return "D"
  end

  if scope == "D" then
    return "B"
  end

  if scope == "B" then
    return "W"
  end

  return "C"
end

--- Checks if treesitter parser for language is installed
---@param lang string
local function has_ts_parser(lang)
  ---@diagnostic disable-next-line: unused-local
  local ok, _result = pcall(vim.treesitter.language.add, lang)
  return ok
end

---@param prompt_bufnr number
---@return nil
local function refresh_picker(prompt_bufnr)
  local picker = action_state.get_current_picker(prompt_bufnr)
  if picker then
    picker:reset_prompt(context.repo.search_keyword:get_snapshot())
  end
end

local function build_search_text_command(prompt)
  if prompt then
    context.repo.search_keyword:next(prompt)
  end

  if not prompt or prompt == "" then
    local fd_cmd = {
      "fd",
      "--type",
      "file",
      "--color=never",
      "--follow",
    }
    context.repo.search_last_command:next(fd_cmd)
    return fd_cmd
  end

  local grep_cmd = {
    "rg",
    "--color=never",
    "--no-heading",
    "--with-filename",
    "--line-number",
    "--column",
    "--follow",
  }
  if not context.repo.search_enable_regex:get_snapshot() then
    table.insert(grep_cmd, "--fixed-strings")
  end
  if context.repo.search_enable_case_sensitive:get_snapshot() then
    table.insert(grep_cmd, "--case-sensitive")
  else
    table.insert(grep_cmd, "--ignore-case")
  end
  table.insert(grep_cmd, "--")
  table.insert(grep_cmd, prompt)

  context.repo.search_last_command:next(grep_cmd)
  return grep_cmd
end

---@param opts table
local function search_current_buffer(opts)
  local filename = vim.api.nvim_buf_get_name(opts.bufnr)
  local filetype = vim.api.nvim_buf_get_option(opts.bufnr, "filetype")
  local lines = vim.api.nvim_buf_get_lines(opts.bufnr, 0, -1, false)
  local lines_with_numbers = {}

  for lnum, line in ipairs(lines) do
    table.insert(lines_with_numbers, {
      lnum = lnum,
      bufnr = opts.bufnr,
      filename = filename,
      text = line,
    })
  end

  opts.results_ts_highlight = vim.F.if_nil(opts.results_ts_highlight, true)
  local lang = vim.treesitter.language.get_lang(filetype) or filetype
  if opts.results_ts_highlight and lang and has_ts_parser(lang) then
    local parser = vim.treesitter.get_parser(opts.bufnr, lang)
    local query = vim.treesitter.query.get(lang, "highlights")
    local root = parser:parse()[1]:root()
    local line_highlights = setmetatable({}, {
      __index = function(t, k)
        local obj = {}
        rawset(t, k, obj)
        return obj
      end,
    })

    opts.line_highlights = line_highlights

    for id, node in query:iter_captures(root, opts.bufnr, 0, -1) do
      local hl = "@" .. query.captures[id]
      if hl and type(hl) ~= "number" then
        local row1, col1, row2, col2 = node:range()

        if row1 == row2 then
          local row = row1 + 1

          for index = col1, col2 do
            line_highlights[row][index] = hl
          end
        else
          local row = row1 + 1
          for index = col1, #lines[row] do
            line_highlights[row][index] = hl
          end

          while row < row2 + 1 do
            row = row + 1

            for index = 0, #(lines[row] or {}) do
              line_highlights[row][index] = hl
            end
          end
        end
      end
    end
  end

  return lines_with_numbers
end

---https://github.com/nvim-telescope/telescope.nvim/blob/fac83a556e7b710dc31433dec727361ca062dbe9/lua/telescope/builtin/__files.lua#L187
---@param search_context ISearchContext
---@param opts? table
local function search(search_context, opts)
  ---@diagnostic disable-next-line: undefined-field
  local conf = require("telescope.config").values
  local finders = require("telescope.finders")
  local make_entry = require("telescope.make_entry")
  local pickers = require("telescope.pickers")
  local sorters = require("telescope.sorters")

  opts = opts or {}
  opts.bufnr = search_context.bufnr
  opts.show_untracked = true
  opts.vimgrep_arguments = opts.vimgrep_arguments or conf.vimgrep_arguments

  local selected_text = util.selection.get_selected_text()
  if selected_text and #selected_text > 1 then
    context.repo.search_keyword:next(selected_text)
  end

  ---@type fun():nil
  local open_picker

  ---@param scope_next ghc.core.constant.enum.CWD_SCOPE
  local function change_scope(scope_next)
    local scope_current = context.repo.search_scope:get_snapshot()
    if scope_next ~= scope_current then
      context.repo.search_scope:next(scope_next)
      opts.initial_mode = "normal"
      open_picker()
    end
  end

  local actions = {
    show_last_grep_cmd = function()
      local last_cmd = context.repo.search_last_command:get_snapshot() or {}
      vim.notify("searching:" .. "[" .. vim.inspect(search_context) .. "]" .. vim.inspect(last_cmd))
    end,
    toggle_enable_regex = function(prompt_bufnr)
      context.repo.search_enable_regex:next(not context.repo.search_enable_regex:get_snapshot())
      opts.use_regex = context.repo.search_enable_regex:get_snapshot()
      refresh_picker(prompt_bufnr)
    end,
    toggle_case_sensitive = function(prompt_bufnr)
      context.repo.search_enable_case_sensitive:next(not context.repo.search_enable_case_sensitive:get_snapshot())
      refresh_picker(prompt_bufnr)
    end,
    change_scope_workspace = function()
      change_scope("W")
    end,
    change_scope_cwd = function()
      change_scope("C")
    end,
    change_scope_directory = function()
      change_scope("D")
    end,
    change_scope_buffer = function()
      change_scope("B")
    end,
    change_scope_carousel = function()
      ---@type ghc.core.constant.enum.CWD_SCOPE
      local scope = context.repo.search_scope:get_snapshot()
      local scope_next = toggle_scope_carousel(scope)
      change_scope(scope_next)
    end,
  }

  open_picker = function()
    ---@type ghc.core.constant.enum.CWD_SCOPE
    local scope = context.repo.search_scope:get_snapshot()
    opts.cwd = get_cwd_by_scope(search_context, scope)

    local resolved_opts
    local finder
    local sorter
    local previewer
    local prompt_title = "Search word (" .. get_display_name_of_scope(scope) .. ")"
    local default_text = context.repo.search_keyword:get_snapshot()
    if scope == "B" then
      resolved_opts = vim.tbl_deep_extend("force", {}, opts)
      local results = search_current_buffer(resolved_opts)
      local entry_maker = make_entry.gen_from_buffer_lines(resolved_opts)

      finder = finders.new_table({ results = results, entry_maker = entry_maker })
      sorter = conf.generic_sorter(resolved_opts)
      previewer = conf.grep_previewer(resolved_opts)
    else
      local make_entry_from_vimgrep = make_entry.gen_from_vimgrep(opts)
      local make_entry_from_file = make_entry.gen_from_file(opts)
      local entry_maker = function(...)
        local last_prompt = context.repo.search_keyword:get_snapshot()
        if not last_prompt or last_prompt == "" then
          return make_entry_from_file(...)
        else
          return make_entry_from_vimgrep(...)
        end
      end

      resolved_opts = opts
      finder = finders.new_job(build_search_text_command, entry_maker, resolved_opts.max_results, resolved_opts.cwd)
      sorter = sorters.highlighter_only(resolved_opts)
      previewer = conf.grep_previewer(resolved_opts)
    end

    pickers
      .new(resolved_opts, {
        prompt_title = prompt_title,
        default_text = default_text,
        finder = finder,
        previewer = previewer,
        sorter = sorter,
        attach_mappings = function(prompt_bufnr, map)
          if resolved_opts.mappings then
            for mode, mappings in pairs(resolved_opts.mappings) do
              for key, action in pairs(mappings) do
                map(mode, key, action)
              end
            end
          end

          map("n", "<leader>N", actions.show_last_grep_cmd)
          map("n", "<leader>I", actions.toggle_case_sensitive)
          map("n", "<leader>R", actions.toggle_enable_regex)
          map("n", "<leader>W", actions.change_scope_workspace)
          map("n", "<leader>C", actions.change_scope_cwd)
          map("n", "<leader>D", actions.change_scope_directory)
          map("n", "<leader>B", actions.change_scope_buffer)
          map("n", "<leader>S", actions.change_scope_carousel)

          context.repo.searching:next(true)
          vim.api.nvim_create_autocmd("BufLeave", {
            buffer = prompt_bufnr,
            nested = true,
            once = true,
            callback = function()
              context.repo.searching:next(false)
            end,
          })
          return true
        end,
      })
      :find()
  end

  open_picker()
end

---@class ghc.core.search.grep_string
local M = {}

function M.grep_selected_text_workspace()
  context.repo.search_scope:next("W")
  ---@type ISearchContext
  local search_context = get_search_context()
  search(search_context)
end

function M.grep_selected_text_cwd()
  context.repo.search_scope:next("C")
  ---@type ISearchContext
  local search_context = get_search_context()
  search(search_context)
end

function M.grep_selected_text_directory()
  context.repo.search_scope:next("D")
  ---@type ISearchContext
  local search_context = get_search_context()
  search(search_context)
end

function M.grep_selected_text_filepath()
  context.repo.search_scope:next("B")
  ---@type ISearchContext
  local search_context = get_search_context()
  search(search_context)
end

function M.grep_selected_text()
  ---@type ISearchContext
  local search_context = get_search_context()
  search(search_context)
end

return M
