local action_autocmd = require("guanghechen.core.action.autocmd")
local context_session = require("guanghechen.core.context.session")

---@alias ISearchContext { workspace: string, cwd: string, directory: string, bufnr: number }

---@param scope_paths ISearchContext
---@param scope guanghechen.core.types.enum.SEARCH_SCOPE
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

---@param scope guanghechen.core.types.enum.SEARCH_SCOPE
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

---@param scope guanghechen.core.types.enum.SEARCH_SCOPE
---@return guanghechen.core.types.enum.SEARCH_SCOPE
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

local function build_search_text_command(prompt)
  if prompt then
    fml.context.replace.search_pattern:next(prompt)
  end

  if not prompt or prompt == "" then
    local fd_cmd = {
      "fd",
      "--hidden",
      "--type",
      "file",
      "--color=never",
      "--follow",
    }
    context_session.search_last_command:next(fd_cmd)
    return fd_cmd
  end

  local grep_cmd = {
    "rg",
    "--hidden",
    "--color=never",
    "--no-heading",
    "--with-filename",
    "--line-number",
    "--column",
    "--follow",
    "--vimgrep",
  }
  if not fml.context.replace.flag_regex:get_snapshot() then
    table.insert(grep_cmd, "--fixed-strings")
  end
  if fml.context.replace.flag_case_sensitive:get_snapshot() then
    table.insert(grep_cmd, "--case-sensitive")
  else
    table.insert(grep_cmd, "--ignore-case")
  end
  table.insert(grep_cmd, "--")
  table.insert(grep_cmd, prompt)

  context_session.search_last_command:next(grep_cmd)
  return grep_cmd
end

---@param opts table
local function search_current_buffer(opts)
  local filename = vim.api.nvim_buf_get_name(opts.bufnr)
  local filetype = vim.api.nvim_get_option_value("filetype", { buf = opts.bufnr })
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

    if query then
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
  end

  return lines_with_numbers
end

---https://github.com/nvim-telescope/telescope.nvim/blob/fac83a556e7b710dc31433dec727361ca062dbe9/lua/telescope/builtin/__files.lua#L187
---@param opts? table
local function search(opts)
  ---@diagnostic disable-next-line: undefined-field
  local conf = require("telescope.config").values
  local finders = require("telescope.finders")
  local make_entry = require("telescope.make_entry")
  local pickers = require("telescope.pickers")
  local sorters = require("telescope.sorters")

  ---@return ISearchContext
  local search_context = {
    workspace = fml.path.workspace(),
    cwd = fml.path.cwd(),
    directory = fml.path.current_directory(),
    bufnr = vim.api.nvim_get_current_buf(),
  }
  context_session.caller_winnr:next(vim.api.nvim_get_current_win())
  context_session.caller_bufnr:next(vim.api.nvim_get_current_buf())

  opts = opts or {}
  opts.initial_mode = "normal"
  opts.bufnr = search_context.bufnr
  opts.show_untracked = true
  opts.vimgrep_arguments = opts.vimgrep_arguments or conf.vimgrep_arguments
  opts.use_regex = fml.context.replace.flag_regex:get_snapshot()

  local selected_text = fml.fn.get_selected_text()
  if selected_text and #selected_text > 1 then
    fml.context.replace.search_pattern:next(selected_text)
  end

  ---@type fun():nil
  local open_picker

  ---@param scope_next guanghechen.core.types.enum.SEARCH_SCOPE
  local function change_scope(scope_next)
    local scope_current = context_session.search_scope:get_snapshot()
    if scope_next ~= scope_current then
      context_session.search_scope:next(scope_next)
      open_picker()
    end
  end

  local actions = {
    show_last_search_cmd = function()
      local last_cmd = context_session.search_last_command:get_snapshot() or {}
      fml.reporter.info({
        from = "search.lua",
        subject = "show_last_search_cmd",
        details = {
          context = search_context,
          last_cmd = last_cmd,
        },
      })
    end,
    toggle_enable_regex = function()
      local next_flag_regex = not fml.context.replace.flag_regex:get_snapshot() ---@type boolean
      fml.context.replace.flag_regex:next(next_flag_regex)
      opts.use_regex = next_flag_regex
      open_picker()
    end,
    toggle_case_sensitive = function()
      local next_flag_case_sensitive = not fml.context.replace.flag_case_sensitive:get_snapshot() ---@type boolean
      fml.context.replace.flag_case_sensitive:next(next_flag_case_sensitive)
      open_picker()
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
      ---@type guanghechen.core.types.enum.SEARCH_SCOPE
      local scope = context_session.search_scope:get_snapshot()
      local scope_next = toggle_scope_carousel(scope)
      change_scope(scope_next)
    end,
  }

  open_picker = function()
    ---@type guanghechen.core.types.enum.SEARCH_SCOPE
    local scope = context_session.search_scope:get_snapshot()
    opts.cwd = get_cwd_by_scope(search_context, scope)

    local resolved_opts
    local picker_params = {
      prompt_title = "Search word (" .. get_display_name_of_scope(scope) .. ")",
      default_text = fml.context.replace.search_pattern:get_snapshot(),
      attach_mappings = function(prompt_bufnr)
        local function mapkey(mode, key, action, desc)
          vim.keymap.set(mode, key, action, { buffer = prompt_bufnr, silent = true, noremap = true, desc = desc })
        end

        if resolved_opts.mappings then
          for mode, mappings in pairs(resolved_opts.mappings) do
            for key, action in pairs(mappings) do
              mapkey(mode, key, action)
            end
          end
        end

        mapkey("n", "<leader>n", actions.show_last_search_cmd)
        mapkey("n", "<leader>i", actions.toggle_case_sensitive)
        mapkey("n", "<leader>r", actions.toggle_enable_regex)
        mapkey("n", "<leader>w", actions.change_scope_workspace)
        mapkey("n", "<leader>c", actions.change_scope_cwd)
        mapkey("n", "<leader>d", actions.change_scope_directory)
        mapkey("n", "<leader>b", actions.change_scope_buffer)
        mapkey("n", "<leader>s", actions.change_scope_carousel)

        ---@type guanghechen.core.types.enum.BUFTYPE_EXTRA
        local buftype_extra = "search"
        context_session.buftype_extra:next(buftype_extra)

        action_autocmd.autocmd_clear_buftype_extra(prompt_bufnr)
        return true
      end,
    }

    if scope == "B" then
      resolved_opts = vim.tbl_deep_extend("force", {}, opts)
      local results = search_current_buffer(resolved_opts)
      local entry_maker = make_entry.gen_from_buffer_lines(resolved_opts)

      picker_params.finder = finders.new_table({ results = results, entry_maker = entry_maker })
      picker_params.previewer = conf.grep_previewer(resolved_opts)
      picker_params.sorter = conf.generic_sorter(resolved_opts)
    else
      local make_entry_from_vimgrep = make_entry.gen_from_vimgrep(opts)
      local make_entry_from_file = make_entry.gen_from_file(opts)
      local entry_maker = function(...)
        local last_prompt = fml.context.replace.search_pattern:get_snapshot()
        if not last_prompt or last_prompt == "" then
          return make_entry_from_file(...)
        else
          return make_entry_from_vimgrep(...)
        end
      end

      resolved_opts = opts
      picker_params.finder = finders.new_job(build_search_text_command, entry_maker, resolved_opts.max_results, resolved_opts.cwd)
      picker_params.previewer = conf.grep_previewer(resolved_opts)
      picker_params.sorter = sorters.highlighter_only(resolved_opts)
    end

    pickers.new(resolved_opts, picker_params):find()
  end

  open_picker()
end

---@class guanghechen.core.action.search
local M = {}

function M.grep_selected_text_workspace()
  context_session.search_scope:next("W")
  search()
end

function M.grep_selected_text_cwd()
  context_session.search_scope:next("C")
  search()
end

function M.grep_selected_text_directory()
  context_session.search_scope:next("D")
  search()
end

function M.grep_selected_text_buffer()
  context_session.search_scope:next("B")
  search()
end

function M.grep_selected_text()
  search()
end

return M

