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
---@return nil
local function fallback(lines, phase)
  eve.reporter.warn({
    from = __module_name__,
    subject = "fallback",
    message = "Did not handle paste, calling original vim.paste",
    details = { lines = lines, filetype = vim.bo.filetype },
  })
  return original_vim_paste(lines, phase)
end

-- override vim.paste to handle image pasting from system clipboard
-- vim.paste is triggered when the users drops an image or file into the terminal
-- it will contain the path to the image or file, or a link to the image
---@diagnostic disable-next-line: duplicate-set-field
vim.paste = function(lines, phase)
  if phase ~= -1 then
    return convert_streaming_paste(lines, phase)
  end

  if #lines > 2 or #lines == 0 then
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
  if eve.path.is_exist_filepath(text) then
    local cwd = eve.path.cwd() ---@type string
    local dirpath = cwd ---@type string
    local filepath_source = eve.path.normalize(text)

    local bufnr = vim.api.nvim_get_current_buf() ---@type integer
    local buftype = vim.bo[bufnr].buftype ---@type string
    local filetype = vim.bo[bufnr].filetype ---@type string
    if buftype == "" then
      local filepath_cur = vim.api.nvim_buf_get_name(bufnr) ---@type string
      dirpath = eve.path.dirname(filepath_cur) ---@type string
    end

    local filename_default = eve.path.basename(filepath_source) ---@type string
    local filepath_default = eve.path.join(dirpath, filename_default) ---@type string
    local placeholder = eve.path.relative(cwd, filepath_default, false) ---@type string

    vim.ui.input({
      prompt = string.format(" Copy %s to ", eve.path.relative(cwd, filepath_source, false)),
      default = placeholder,
      relative = "editor",
    }, function(filepath_target_relative)
      if filepath_target_relative == nil or filepath_target_relative == "" then
        return
      end

      local filepath_target = eve.path.resolve(cwd, filepath_target_relative) ---@type string
      local extname = eve.path.extname(filepath_target_relative) ---@type string
      eve.path.mkdir_if_nonexist(eve.path.dirname(filepath_target))

      local ok = pcall(function()
        eve.fs.copy_file(filepath_source, filepath_target)
      end)

      if ok then
        if not eve.filetype.is_not_sourcefile(filetype) then
          if IMAGE_EXTENSIONS[extname] then
            local src = eve.path.relative(dirpath, filepath_target, true) ---@type string
            if #src > 1 then
              if src:sub(1, 1) ~= "." then
                src = "." .. eve.env.PATH_SEP .. src
              end
              local filename = eve.path.basename(filepath_target) ---@type string
              local alt = vim.fn.fnamemodify(filename, ":r") ---@type string
              eve.clipboard.insert_markup(alt, src)
            end
          end
        end
      else
        fallback(lines, phase)
      end
    end)
    return true
  end

  fallback(lines, phase)
end
