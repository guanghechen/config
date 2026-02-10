local function get_starship_config()
  local sep = package.config:sub(1, 1)
  local home = os.getenv("HOME")
  if home then
    return home .. sep .. ".config" .. sep .. "starship" .. sep .. "yazi.toml"
  end
  local appdata = os.getenv("APPDATA")
  if appdata then
    return appdata .. sep .. "starship" .. sep .. "yazi.toml"
  end
  return nil
end

require("git"):setup()
require("full-border"):setup({
  type = ui.Border.ROUNDED,
})
require("starship"):setup({
  hide_flags = false,
  flags_after_prompt = true,
  config_file = get_starship_config(),
})

function Status:name()
  local h = self._current.hovered
  if not h then
    return ""
  end

  local linked = ""
  if h.link_to ~= nil then
    linked = " -> " .. tostring(h.link_to)
  end
  return ui.Line(" " .. h.name .. linked)
end
