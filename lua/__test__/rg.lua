---@diagnostic disable: unused-local, unused-function
local function test_1()
  local handle_find_files_cmd = io.popen("fd --hidden --type=file --color=never --follow > a.txt")
  if handle_find_files_cmd then
    handle_find_files_cmd:close()

    local pipe_grep_text_cmd = io.popen(
      "rg --iglob=a.txt --hidden --color=never --no-heading --no-filename --line-number --column --follow -- rc"
    )
    if pipe_grep_text_cmd then
      local file_list = pipe_grep_text_cmd:read("*a")
      pipe_grep_text_cmd:close()
      fml.debug.log(file_list)
    end
  end
end

local function test_2()
  fml.debug.log({
    fml.oxi.search({
      cwd = fc.path.cwd(),
      flag_case_sensitive = true,
      flag_gitignore = true,
      flag_regex = true,
      max_filesize = "1M",
      max_matches = -1,
      search_pattern = "local function (\\w+)\\(\\)",
      search_paths = "",
      include_patterns = "",
      exclude_patterns = "",
      specified_filepath = nil,
    }),
  })
end

test_2()
