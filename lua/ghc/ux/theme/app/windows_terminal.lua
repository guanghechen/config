local template = [[
{
  "name": "{{theme}}",
  "cursorColor": "{{bg3}}",
  "selectionBackground": "{{bg4}}",

  "background": "{{bg0}}",
  "foreground": "{{fg}}",

  "black": "{{black}}",
  "blue": "{{blue}}",
  "cyan": "{{aqua}}",
  "green": "{{green}}",
  "purple": "{{purple}}",
  "red": "{{red}}",
  "white": "{{white}}",
  "yellow": "{{yellow}}",

  "brightBlack": "{{brightBlack}}",
  "brightBlue": "{{neutral_blue}}",
  "brightCyan": "{{neutral_aqua}}",
  "brightGreen": "{{neutral_green}}",
  "brightPurple": "{{neutral_purple}}",
  "brightRed": "{{neutral_red}}",
  "brightWhite": "{{brightWhite}}",
  "brightYellow": "{{neutral_yellow}}"
}
]]

---@type t.ghc.ux.theme.IApp
local M = {
  get_filepaths = function(context)
    local app_home = eve.path.locate_app_config_home("windows_terminal")
    if vim.fn.isdirectory(app_home) == 0 then
      return {}
    end
    ---@type string[]
    local filepaths = {
      eve.path.join(app_home, "theme/" .. context.theme .. ".json"),
    }
    return filepaths
  end,
  gen_theme = function(context)
    local mode = context.scheme.mode ---@type t.eve.e.ThemeMode
    local c = context.scheme.palette ---@type t.fml.ux.theme.IPalette
    local data = vim.tbl_extend("force", {}, c, {
      theme = context.theme,
      black = mode == "light" and c.fg0 or c.bg0,
      white = mode == "light" and c.bg4 or c.fg4,
      brightBlack = mode == "light" and c.fg1 or c.bg1,
      brightWhite = mode == "light" and c.bg1 or c.fg1,
    })
    local text = template:gsub("{{(.-)}}", function(key)
      return data[key] or ("{{" .. key .. "}}")
    end)
    return text
  end,
  after_written = function(context)
    local filepath = vim.fn.getenv("f_windows_terminal_settings") ---@type string|nil
    if filepath == nil then
      return
    end

    local stat = vim.uv.fs_stat(filepath)
    if stat == nil or stat.type ~= "file" then
      return
    end

    local theme = context.theme ---@type string
    eve.oxi.replace_file({
      cwd = eve.path.cwd(),
      filepath = filepath,
      search_pattern = [["colorScheme": "[^"]+"]],
      replace_pattern = [["colorScheme": "]] .. theme .. [["]],
      flag_case_sensitive = true,
      flag_regex = true,
    })
  end,
}

return M
