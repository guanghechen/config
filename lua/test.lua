local function b()
  local handle_find_files_cmd = io.popen("fd --hidden --type=file --color=never --follow > a.txt")
  if handle_find_files_cmd then
    handle_find_files_cmd:close()

    local pipe_grep_text_cmd = io.popen("rg --iglob=a.txt --hidden --color=never --no-heading --no-filename --line-number --column --follow -- rc")
    if pipe_grep_text_cmd then
      local file_list = pipe_grep_text_cmd:read("*a")
      pipe_grep_text_cmd:close()
      vim.notify(file_list)
    end
  end
end

b()
