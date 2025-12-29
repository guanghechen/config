local __module_name__ = "era.action.toggle.theme" ---@type string

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

---@type dot.module.picker.composer.list.IRenderResult
local function render_result(_, bufnr, itemmap, matches)
  local lines = {} ---@type string[]
  local uuids = {} ---@type string[]

  for _, match_data in ipairs(matches) do
    local item = itemmap[match_data.uuid] ---@type dot.module.picker.composer.list.IItem
    uuids[#uuids + 1] = match_data.uuid ---@type string

    local themename = item.text ---@type string
    local colorsquares = string.rep(" ", #COLORS_TO_DISPLAY) ---@type string
    local line = string.format("%s %s", ark.string.pad_end(themename, MAX_WIDTH_THEMENAME, " "), colorsquares) ---@type string
    lines[#lines + 1] = line
  end

  -- Set buffer lines
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  local nsnr_content = ark.var.nsnr.picker_result ---@type integer
  local nsnr_matches = ark.var.nsnr.picker_matches ---@type integer

  -- Apply highlights
  for lnum, match_data in ipairs(matches) do
    local row = lnum - 1 ---@type integer
    local offset = MAX_WIDTH_THEMENAME + 2 ---@type integer
    local item = itemmap[match_data.uuid] ---@type dot.module.picker.composer.list.IItem
    local themename = item.text ---@type string
    local hlgroup_prefix = "f_cs_" .. themename:gsub("-", "_") .. "__" ---@type string

    local scheme = ark.theme.scheme[themename] ---@type stl.t.theme.IScheme
    for _, color in ipairs(COLORS_TO_DISPLAY) do
      local hlgroup = hlgroup_prefix .. color ---@type string
      local hex = scheme.palette[color] ---@type string
      vim.api.nvim_set_hl(0, hlgroup, { bg = hex, default = true })

      vim.hl.range(bufnr, nsnr_content, hlgroup, { row, offset }, { row, offset + 1 })
      offset = offset + 1
    end

    if match_data.matches then
      for _, m in ipairs(match_data.matches) do
        vim.hl.range(bufnr, nsnr_matches, "m_pk_matches", { row, m.l }, { row, m.r }, { priority = 30 })
      end
    end
  end

  ---@type dot.module.picker.composer.list.IRenderResultData
  local result = { uuids = uuids }
  return result
end

---@param theme                         string
---@return nil
local function apply_theme(theme)
  local scheme = dot.context.theme.get_scheme(theme) ---@type stl.t.theme.IScheme|nil
  if scheme == nil then
    return
  end

  local app_home = dot.path.locate_app_config_home("guanghechen")
  local script_path = dot.path.join(app_home, "config/theme/apply_theme.mjs")
  local ok, err = pcall(function()
    local result = vim.fn.system({ "node", script_path, theme })
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
      details = { theme = theme, app_home = app_home, script_path = script_path, error = err },
    })
  end

  if scheme ~= nil then
    vim.o.background = scheme.darken and "dark" or "light"
  end
end

---@class era.action.toggle.theme
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
      render_result = render_result, -- Add the custom renderer
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
