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

---https://github.com/nvim-telescope/telescope.nvim/blob/fac83a556e7b710dc31433dec727361ca062dbe9/lua/telescope/builtin/__files.lua#L187
local function grep_text(opts)
  ---@diagnostic disable-next-line: undefined-field
  local conf = require("telescope.config").values
  local finders = require("telescope.finders")
  local make_entry = require("telescope.make_entry")
  local pickers = require("telescope.pickers")
  local sorters = require("telescope.sorters")
  local scope = opts.ghc_scope

  local picker = nil
  local last_grep_cmd = {}
  local actions = {
    show_last_grep_cmd = function()
      vim.notify("searching:" .. vim.inspect(last_grep_cmd))
    end,
    toggle_enable_regex = function()
      context.repo.flag_enable_regex:next(not context.repo.flag_enable_regex:get_snapshot())
      if picker then
        picker:refresh()
      end
    end,
    toggle_case_sensitive = function()
      context.repo.flag_case_sensitive:next(not context.repo.flag_case_sensitive:get_snapshot())
      if picker then
        picker:refresh()
      end
    end,
  }

  local live_grepper = function(prompt)
    if prompt then
      context.repo.searching_keyword:next(prompt)
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

    local additional_args = util.table.filter_non_blank_string({
      context.repo.flag_enable_regex:get_snapshot() and "" or "--fixed-strings",
      context.repo.flag_case_sensitive:get_snapshot() and "--case-sensitive" or "--ignore-case",
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
  opts.cwd = opts.cwd and vim.fn.expand(opts.cwd)
  local make_entry_from_vimgrep = make_entry.gen_from_vimgrep(opts)
  local make_entry_from_file = make_entry.gen_from_file(opts)

  opts.entry_maker = function(...)
    local last_prompt = context.repo.searching_keyword:get_snapshot()
    if not last_prompt or last_prompt == "" then
      return make_entry_from_file(...)
    else
      return make_entry_from_vimgrep(...)
    end
  end

  local selected_text = util.selection.get_selected_text()
  if selected_text and #selected_text > 1 then
    context.repo.searching_keyword:next(selected_text)
  end
  local default_text = context.repo.searching_keyword:get_snapshot()

  picker = pickers
    .new(opts, {
      prompt_title = "Search word (" .. scope .. ")",
      default_text = default_text,
      finder = finders.new_job(live_grepper, opts.entry_maker, opts.max_results, opts.cwd),
      previewer = conf.grep_previewer(opts),
      sorter = sorters.highlighter_only(opts),
      attach_mappings = function(_, map)
        if opts.mappings then
          for mode, mappings in pairs(opts.mappings) do
            for key, action in pairs(mappings) do
              map(mode, key, action)
            end
          end
        end

        map("i", "<c-n>", actions.show_last_grep_cmd)
        map("n", "<c-n>", actions.show_last_grep_cmd)
        map("i", "<c-i>", actions.toggle_case_sensitive)
        map("n", "<c-i>", actions.toggle_case_sensitive)
        map("i", "<c-r>", actions.toggle_enable_regex)
        map("n", "<c-r>", actions.toggle_enable_regex)
        return true
      end,
    })
    :find()
end

---@class ghc.core.search.grep_string
local M = {}

function M.grep_selected_text_workspace()
  grep_text({
    cwd = util.path.workspace(),
    workspace = "CWD",
    ghc_scope = "workspace",
  })
end

function M.grep_selected_text_cwd()
  grep_text({
    cwd = util.path.cwd(),
    workspace = "CWD",
    ghc_scope = "cwd",
  })
end

function M.grep_selected_text_current()
  grep_text({
    cwd = util.path.current(),
    workspace = "CWD",
    ghc_scope = "current directory",
  })
end

return M
