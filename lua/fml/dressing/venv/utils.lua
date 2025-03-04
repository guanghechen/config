local M = {}

local config = require("fml.dressing.venv.config")

function M.escape_pattern(text)
  return text:gsub("([^%w])", "%%%1")
end

-- Go up in the directory tree "limit" amount of times, and then returns the path.
function M.find_parent_dir(dir, limit)
  for subdir in vim.fs.parents(dir) do
    if vim.fn.isdirectory(subdir) then
      if limit > 0 then
        return M.find_parent_dir(subdir, limit - 1)
      else
        break
      end
    end
  end

  return dir
end

-- Creating a regex search path string with all venv names separated by
-- the '|' character. We also make sure that the venv name is an exact match
-- using '^' and '$' so we dont match on paths with the venv name in the middle.
function M.create_fd_venv_names_regexp(config_venv_name)
  local venv_names = ""

  if type(config_venv_name) == "table" then
    venv_names = venv_names .. "("
    for _, venv_name in pairs(config_venv_name) do
      venv_names = venv_names .. "^" .. venv_name .. "$" .. "|" -- Creates (^venv_name1$ | ^venv_name2$ ) etc
    end
    venv_names = venv_names:sub(1, -2) -- Always remove last '|' since we only want it between words
    venv_names = venv_names .. ")"
  elseif type(config_venv_name) == "string" then
    venv_names = "^" .. config_venv_name .. "$"
  end

  return venv_names
end

-- Create a search path string to fd command with all paths instead of
-- running fd several times.
function M.create_fd_search_path_string(paths)
  local search_path_string = ""
  for _, path in pairs(paths) do
    local ishatch = path == config.settings.hatch_path
    local expanded_path = vim.fn.expand(path)

    if vim.fn.isdirectory(expanded_path) ~= 0 then
      expanded_path = expanded_path:gsub(" ", "\\ ") -- escape space so paths can have a space
      if ishatch == true then
        -- special handling for hatch
        search_path_string = search_path_string .. expanded_path .. "/*/*" .. " "
      else
        search_path_string = search_path_string .. expanded_path .. " "
      end
    end
  end
  return search_path_string
end

-- Remove last slash if it exists, otherwise return the string unmodified
function M.remove_last_slash(s)
  local last_character = string.sub(s, -1, -1)

  if last_character == "/" or last_character == "\\" then
    return string.sub(s, 1, -2)
  end

  return s
end

return M
