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

---@alias IScopePaths { workspace: string, cwd: string, directory: string, filepath: string }

---@return IScopePaths
local function get_scope_paths()
  return {
    workspace = util.path.workspace(),
    cwd = util.path.cwd(),
    directory = util.path.current_directory(),
    filepath = util.path.current_filepath(),
  }
end

---@param scope_paths IScopePaths
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

  if scope == "F" then
    return scope_paths.directory
  end

  return scope_paths.cwd
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
    return "F"
  end

  if scope == "F" then
    return "W"
  end

  return "C"
end

---@param prompt_bufnr number
---@return nil
local function refresh_picker(prompt_bufnr)
  local picker = action_state.get_current_picker(prompt_bufnr)
  if picker then
    picker:reset_prompt(context.repo.search_keyword:get_snapshot())
  end
end

local function search_text(prompt)
  local additional_args = util.table.filter_non_blank_string({
    context.repo.search_enable_regex:get_snapshot() and "" or "--fixed-strings",
    context.repo.search_enable_case_sensitive:get_snapshot() and "--case-sensitive" or "--ignore-case",
  })
  local grep_cmd = vim.tbl_flatten({
    "rg",
    "--color=never",
    "--no-heading",
    "--with-filename",
    "--line-number",
    "--column",
    "--follow",
    additional_args,
    "--",
    prompt,
  })
  return grep_cmd
end

---https://github.com/nvim-telescope/telescope.nvim/blob/fac83a556e7b710dc31433dec727361ca062dbe9/lua/telescope/builtin/__files.lua#L187
---@param scope_paths IScopePaths
---@param opts? table
local function search(scope_paths, opts)
  ---@diagnostic disable-next-line: undefined-field
  local conf = require("telescope.config").values
  local finders = require("telescope.finders")
  local make_entry = require("telescope.make_entry")
  local pickers = require("telescope.pickers")
  local sorters = require("telescope.sorters")
  local last_grep_cmd = {}

  opts = opts or {}

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
      vim.notify("searching:" .. "[" .. vim.inspect(scope_paths) .. "]" .. vim.inspect(last_grep_cmd))
    end,
    toggle_enable_regex = function(prompt_bufnr)
      context.repo.search_enable_regex:next(not context.repo.search_enable_regex:get_snapshot())
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
    change_scope_file = function()
      change_scope("F")
    end,
    change_scope_carousel = function()
      ---@type ghc.core.constant.enum.CWD_SCOPE
      local scope = context.repo.search_scope:get_snapshot()
      local scope_next = toggle_scope_carousel(scope)
      change_scope(scope_next)
    end,
  }

  local live_grepper = function(prompt)
    if prompt then
      context.repo.search_keyword:next(prompt)
    end

    if not prompt or prompt == "" then
      return {
        "fd",
        "--type",
        "file",
        "--color=never",
        "--follow",
      }
    end

    ---@type ghc.core.constant.enum.CWD_SCOPE
    local scope = context.repo.search_scope:get_snapshot()
    if scope == "W" or scope == "C" or scope == "D" then
      last_grep_cmd = search_text(prompt)
      return last_grep_cmd
    end

    local additional_args = util.table.filter_non_blank_string({
      context.repo.search_enable_regex:get_snapshot() and "" or "--fixed-strings",
      context.repo.search_enable_case_sensitive:get_snapshot() and "--case-sensitive" or "--ignore-case",
    })
    local grep_cmd = vim.tbl_flatten({
      "rg",
      "--color=never",
      "--no-heading",
      "--with-filename",
      "--line-number",
      "--column",
      "--follow",
      additional_args,
      "--",
      prompt,
    })

    last_grep_cmd = grep_cmd
    return grep_cmd
  end

  opts.use_regex = false
  opts.show_untracked = true
  opts.vimgrep_arguments = opts.vimgrep_arguments or conf.vimgrep_arguments
  local make_entry_from_vimgrep = make_entry.gen_from_vimgrep(opts)
  local make_entry_from_file = make_entry.gen_from_file(opts)

  opts.entry_maker = function(...)
    local last_prompt = context.repo.search_keyword:get_snapshot()
    if not last_prompt or last_prompt == "" then
      return make_entry_from_file(...)
    else
      return make_entry_from_vimgrep(...)
    end
  end

  local selected_text = util.selection.get_selected_text()
  if selected_text and #selected_text > 1 then
    context.repo.search_keyword:next(selected_text)
  end
  local default_text = context.repo.search_keyword:get_snapshot()

  open_picker = function()
    ---@type ghc.core.constant.enum.CWD_SCOPE
    local scope = context.repo.search_scope:get_snapshot()
    opts.cwd = get_cwd_by_scope(scope_paths, scope)
    pickers
      .new(opts, {
        prompt_title = "Search word (" .. scope .. ")",
        default_text = default_text,
        finder = finders.new_job(live_grepper, opts.entry_maker, opts.max_results, opts.cwd),
        previewer = conf.grep_previewer(opts),
        sorter = sorters.highlighter_only(opts),
        attach_mappings = function(prompt_bufnr, map)
          if opts.mappings then
            for mode, mappings in pairs(opts.mappings) do
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
          map("n", "<leader>F", actions.change_scope_file)
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
  ---@type IScopePaths
  local scope_paths = get_scope_paths()
  search(scope_paths)
end

function M.grep_selected_text_cwd()
  context.repo.search_scope:next("C")
  ---@type IScopePaths
  local scope_paths = get_scope_paths()
  search(scope_paths)
end

function M.grep_selected_text_directory()
  context.repo.search_scope:next("D")
  ---@type IScopePaths
  local scope_paths = get_scope_paths()
  search(scope_paths)
end

function M.grep_selected_text()
  ---@type IScopePaths
  local scope_paths = get_scope_paths()
  search(scope_paths)
end

return M
