---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.toggle.theme" ---@type string

local COLORS_TO_DISPLAY = {
  "bg0",
  "bg1",
  "bg2",
  "bg3",
  "bg4",
  "fg0",
  "fg1",
  "fg2",
  "fg3",
  "fg4",
  "red",
  "green",
  "blue",
  "yellow",
  "purple",
  "aqua",
  "orange",
  "brightRed",
  "brightGreen",
  "brightBlue",
  "brightYellow",
  "brightPurple",
  "brightAqua",
  "brightOrange",
  "grey",
  "pink",
  "diffDel",
  "diffDelInline",
  "diffAdd",
  "diffAddInline",
}

local MAX_WIDTH_THEMENAME = 24 ---@type integer
local themes = dot.command.definitions.toggle.theme.candidates ---@type string[]
local o_theme = dot.context.theme.theme ---@type stl.c.Observable

---@param _                             era.m.picker.ListComposer
---@param item                          era.m.picker.composer.list.IItem
---@return era.m.picker.composer.list.IPresentation
local function present(_, item)
  local name = item.text
  local prefix = stl.string.pad_end(name, MAX_WIDTH_THEMENAME, " ") .. " "
  local scheme = dot.theme.scheme[name]
  local group_prefix = "f_cs_" .. name:gsub("-", "_") .. "__"
  local highlights = {}
  for index, color in ipairs(COLORS_TO_DISPLAY) do
    local group = group_prefix .. color
    vim.api.nvim_set_hl(0, group, { bg = scheme.palette[color], default = true })
    highlights[#highlights + 1] = { coll = #prefix + index - 1, colr = #prefix + index, hlname = group }
  end
  return {
    label = prefix .. string.rep(" ", #COLORS_TO_DISPLAY),
    highlights = highlights,
    match_regions = { { 0, #name, 0 } },
  }
end

---@param theme                         string
---@return nil
local function apply_theme(theme)
  local scheme = dot.context.theme.get_scheme(theme) ---@type stl.t.theme.IScheme|nil
  if scheme == nil then
    return
  end

  local app_home = dot.path.locate_app_config_home("guanghechen")
  local script_path = dot.path.join(app_home, "cli/theme.mjs")
  local source_theme = theme ---@type string
  if scheme.opposite ~= nil then
    source_theme = string.format("%s-%s", scheme.theme, scheme.opposite)
  end

  local ok, err = pcall(function()
    local result = vim.fn.system({ "node", script_path, "toggle", source_theme, "--silent" })
    if vim.v.shell_error ~= 0 then
      error("Command failed with exit code " .. vim.v.shell_error .. ": " .. result)
    end
    return result
  end)
  if not ok then
    stl.reporter.error({
      from = __module_name__,
      subject = "apply_theme",
      message = "Failed to toggle theme.",
      details = {
        theme = theme,
        source_theme = source_theme,
        app_home = app_home,
        script_path = script_path,
        error = err,
      },
    })
  end

  if scheme ~= nil then
    vim.o.background = scheme.darken and "dark" or "light"
  end
end

---@class era.m.toggle.theme
local M = {}

---@param arg                           unknown|nil
---@return nil
function M.theme(arg)
  local theme_name = type(arg) == "string" and arg:lower() or "" ---@type string
  if vim.list_contains(themes, theme_name) then
    apply_theme(theme_name)
  else
    local current_theme = o_theme:snapshot() ---@type dot.e.ThemeFullName
    vim.ui.select(themes, {
      name = __module_name__,
      prompt = "Toggle Theme",
      uuid_current = current_theme,
      uuid_present = current_theme,
      dimension = {
        row = 5,
        width = 80, -- Increased width for color squares
      },
      present = present,
      on_toggle = function(choice)
        if choice then
          apply_theme(choice)
        end
      end,
    }, function(choice)
      if choice then
        apply_theme(choice)
      end
    end)
  end
end

return M
