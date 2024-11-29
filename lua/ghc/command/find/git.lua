local uuids = eve.commander.uuids ---@type eve.builtin.commander.uuids

eve.commander.register({
  uuid = uuids.find_git_not_committed,
  desc = "find: git files (Not committed)",
  action = function()
    local cwd = eve.path.cwd() ---@type string
    local workspace = eve.path.workspace() ---@type string

    fml.fn.select_files({
      cwd = cwd,
      title = "Find: git files (Not committed)",
      flag_fuzzy = true,
      flag_regex = false,
      fetch_filepaths = function()
        local result = vim.fn.system("git diff HEAD --name-only") ---@type string
        local lines = eve.oxi.parse_lines(result) ---@type string[]

        local filepaths = {} ---@type string[]
        for _, line in ipairs(lines) do
          local absolute_filepath = eve.path.join(workspace, line) ---@type string
          local filepath = eve.path.relative(cwd, absolute_filepath, true) ---@type string
          local filename = eve.path.basename(filepath) ---@type string
          local is_text_file = eve.validator.is_printable_file(filename) ---@type boolean
          if is_text_file then
            table.insert(filepaths, filepath)
          end
        end
        return filepaths
      end,
    })
  end,
})
