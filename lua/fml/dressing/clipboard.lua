local __module_name__ = "fml.dressing.clipboard" ---@type string

local original_vim_paste = vim.paste

local buffer = "" ---@type string

local IMAGE_EXTENSIONS = {
  [".png"] = true,
  [".jpg"] = true,
  [".jpeg"] = true,
  [".gif"] = true,
  [".bmp"] = true,
  [".tiff"] = true,
}

---@param lines string[]
---@param phase number
local function convert_streaming_paste(lines, phase)
  if phase == 1 then
    buffer = ""
  end

  for i, line in ipairs(lines) do
    buffer = buffer .. line
    if i < #lines then
      buffer = buffer .. "\n"
    end
  end

  if phase == 3 then -- end of the paste
    local complete_lines = vim.split(buffer, "\n")
    vim.paste(complete_lines, -1) -- use -1 to indicate non-streaming paste
  end
end

---@param lines                         string[]
---@param phase                         integer
---@param silent                        boolean
---@return nil
local function fallback(lines, phase, silent)
  if not silent then
    std.reporter.warn({
      from = __module_name__,
      subject = "fallback",
      message = "Did not handle paste, calling original vim.paste",
      details = { lines = lines, filetype = vim.bo.filetype },
    })
  end
  return original_vim_paste(lines, phase)
end

-- override vim.paste to handle image pasting from system clipboard
-- vim.paste is triggered when the users drops an image or file into the terminal
-- it will contain the path to the image or file, or a link to the image
---@diagnostic disable-next-line: duplicate-set-field
vim.paste = function(lines, phase)
  local flag_dressing_clipboard = eve.context.flight.dressing_clipboard:snapshot() ---@type boolean
  if not flag_dressing_clipboard then
    return original_vim_paste(lines, phase)
  end

  if phase ~= -1 then
    return convert_streaming_paste(lines, phase)
  end

  if #lines > 1 or #lines == 0 then
    local filepaths = {} ---@type string[]
    local dirpaths = {} ---@type string[]
    local is_all_paths = true ---@type boolean
    for _, line in ipairs(lines) do
      local text = line
        :match("^%s*(.-)%s*$") -- remove leading and trailing whitespace
        :match('^"?(.-)"?$') -- remove double quotes
        :match("^'?(.-)'?$") -- remove single quotes
        :gsub("file://", "") -- remove "file://"
        :gsub("%c", "") -- remove control characters
      if #text > 0 then
        if std.path.is_exist_filepath(text) then
          table.insert(filepaths, text)
        elseif std.path.is_exist_dirpath(text) then
          table.insert(dirpaths, text)
        else
          is_all_paths = false
          break
        end
      end
    end

    if is_all_paths then
      local cwd = std.path.cwd() ---@type string
      local dirpath = cwd ---@type string

      local bufnr = vim.api.nvim_get_current_buf() ---@type integer
      local buftype = vim.bo[bufnr].buftype ---@type string
      if buftype == "" then
        local filepath_cur = vim.api.nvim_buf_get_name(bufnr) ---@type string
        dirpath = std.path.dirname(filepath_cur) ---@type string
      end

      local placeholder = std.path.relative(cwd, dirpath, false) ---@type string
      if placeholder == "" then
        placeholder = "." ---@type string
      end

      vim.ui.input({
        prompt = string.format(" Copy files (%d) ", #filepaths + #dirpaths),
        default = placeholder,
        relative = "editor",
      }, function(dirpath_container_relative)
        if dirpath_container_relative == nil or dirpath_container_relative == "" then
          return
        end

        local dirpath_container = std.path.resolve(cwd, dirpath_container_relative) ---@type string
        std.path.mkdir_if_nonexist(dirpath_container)

        local ok = pcall(function()
          for _, filepath_source in ipairs(filepaths) do
            local basename_source = std.path.basename(filepath_source) ---@type string
            local filepath_target = std.path.join(dirpath_container, basename_source) ---@type string
            eve.fs.copy_file(filepath_source, filepath_target)
          end
          for _, dirpath_source in ipairs(dirpaths) do
            local basename_source = std.path.basename(dirpath_source) ---@type string
            local dirpath_target = std.path.join(dirpath_container, basename_source) ---@type string
            eve.fs.copy_directory(dirpath_source, dirpath_target)
          end
        end)

        if not ok then
          fallback(lines, phase, false)
        end
      end)
      return true
    end

    return original_vim_paste(lines, phase)
  end

  local line = lines[1]

  -- probably not a file path or url to an image if the input is this long
  if string.len(line) > 512 then
    return original_vim_paste(lines, phase)
  end

  local text = line
    :match("^%s*(.-)%s*$") -- remove leading and trailing whitespace
    :match('^"?(.-)"?$') -- remove double quotes
    :match("^'?(.-)'?$") -- remove single quotes
    :gsub("file://", "") -- remove "file://"
    :gsub("%c", "") -- remove control characters
  local is_filepath = #text > 0 and std.path.is_exist_filepath(text) ---@type boolean
  local is_dirpath = #text > 0 and std.path.is_exist_dirpath(text) ---@type boolean
  if is_filepath or is_dirpath then
    local cwd = std.path.cwd() ---@type string
    local dirpath = cwd ---@type string
    local filepath_source = std.path.normalize(text)

    local bufnr = vim.api.nvim_get_current_buf() ---@type integer
    local buftype = vim.bo[bufnr].buftype ---@type string
    local filetype = vim.bo[bufnr].filetype ---@type string
    if buftype == "" then
      local filepath_cur = vim.api.nvim_buf_get_name(bufnr) ---@type string
      dirpath = std.path.dirname(filepath_cur) ---@type string
    end

    local basename_source = std.path.basename(filepath_source) ---@type string
    local filepath_default = std.path.join(dirpath, basename_source) ---@type string
    local suffix = is_dirpath and std.env.PATH_SEP or "" ---@type string

    local placeholder = std.path.relative(cwd, filepath_default, false) ---@type string
    if placeholder == "" then
      placeholder = "." ---@type string
    end

    vim.ui.input({
      prompt = string.format(" Copy %s to ", std.path.relative(cwd, filepath_source, false) .. suffix),
      default = placeholder .. suffix,
      relative = "editor",
    }, function(filepath_target_relative)
      if filepath_target_relative == nil or filepath_target_relative == "" then
        return
      end

      local filepath_target = std.path.resolve(cwd, filepath_target_relative) ---@type string
      std.path.mkdir_if_nonexist(std.path.dirname(filepath_target))

      local ok = pcall(function()
        if is_filepath then
          eve.fs.copy_file(filepath_source, filepath_target)
        elseif is_dirpath then
          eve.fs.copy_directory(filepath_source, filepath_target)
        end
      end)

      if ok then
        if is_filepath and eve.filetype.is_sourcefile(filetype) then
          local extname = std.path.extname(filepath_target_relative) ---@type string
          if IMAGE_EXTENSIONS[extname] then
            local src = std.path.relative(dirpath, filepath_target, true) ---@type string
            if #src > 1 then
              if src:sub(1, 1) ~= "." then
                src = "." .. std.env.PATH_SEP .. src
              end
              local filename = std.path.basename(filepath_target) ---@type string
              local alt = vim.fn.fnamemodify(filename, ":r") ---@type string
              eve.clipboard.insert_markup(alt, src)
            end
          end
        end
      else
        fallback(lines, phase, false)
      end
    end)
    return true
  end

  fallback(lines, phase, true)
end
