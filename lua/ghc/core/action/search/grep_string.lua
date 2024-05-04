---@class ghc.core.action.search.grep_string
local util = {
  path = require("ghc.core.util.path"),
  regex = require("guanghechen.util.regex"),
  selection = require("guanghechen.util.selection"),
}

---https://github.com/nvim-telescope/telescope.nvim/blob/fac83a556e7b710dc31433dec727361ca062dbe9/lua/telescope/builtin/__files.lua#L187
local function grep_literal_text(opts)
  ---@diagnostic disable-next-line: undefined-field
  local conf = require("telescope.config").values
  local finders = require("telescope.finders")
  local make_entry = require("telescope.make_entry")
  local pickers = require("telescope.pickers")
  local sorters = require("telescope.sorters")
  local scope = opts.ghc_scope

  opts.use_regex = false
  opts.show_untracked = true
  opts.vimgrep_arguments = opts.vimgrep_arguments or conf.vimgrep_arguments
  opts.entry_maker = opts.entry_maker or make_entry.gen_from_vimgrep(opts)
  opts.cwd = opts.cwd and vim.fn.expand(opts.cwd)

  local last_grep_cmd = {}
  local flags = {
    case_sensitive = true,
  }
  local live_grepper = function(prompt)
    if not prompt or prompt == "" then
      return nil
    end

    local additional_args = {}
    if flags.case_sensitive then
      table.insert(additional_args, "--case-sensitive")
    end

    local grep_cmd = vim.tbl_flatten({
      "rg",
      "--color=never",
      "--no-heading",
      "--with-filename",
      "--line-number",
      "--column",
      "--fixed-strings",
      "--follow",
      additional_args,
      "--",
      prompt,
    })

    last_grep_cmd = grep_cmd
    return grep_cmd
  end

  local actions = {
    show_last_grep_cmd = function()
      vim.notify("searching:" .. vim.inspect(last_grep_cmd))
    end,
    toggle_case_sensitive = function()
      flags.case_sensitive = not flags.case_sensitive
    end,
  }

  pickers
    .new(opts, {
      prompt_title = "Search literal word (" .. scope .. ")",
      finder = finders.new_job(live_grepper, opts.entry_maker, opts.max_results, opts.cwd),
      previewer = conf.grep_previewer(opts),
      sorter = sorters.highlighter_only(opts),
      default_text = util.selection.get_selected_text(),
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
        map("n", "<leader>ti", actions.toggle_case_sensitive)
        return true
      end,
    })
    :find()
end

---@class ghc.core.search.grep_string
local M = {}

function M.grep_selected_text_workspace()
  grep_literal_text({
    cwd = util.path.workspace(),
    workspace = "CWD",
    ghc_scope = "workspace",
  })
end

function M.grep_selected_text_cwd()
  grep_literal_text({
    cwd = util.path.cwd(),
    workspace = "CWD",
    ghc_scope = "cwd",
  })
end

function M.grep_selected_text_current()
  grep_literal_text({
    cwd = util.path.current(),
    workspace = "CWD",
    ghc_scope = "current directory",
  })
end

return M
