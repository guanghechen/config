---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.diffview.commit_format" ---@type string

---Compact commit metadata formatting shared by History and standalone Commits.
---@class era.m.diffview.commit_format
local M = {}

---@see https://gitmoji.dev/
local GITMOJI = {
  adhesive_bandage = "🩹",
  alembic = "⚗️",
  alien = "👽️",
  ambulance = "🚑️",
  arrow_down = "⬇️",
  arrow_up = "⬆️",
  art = "🎨",
  beers = "🍻",
  bento = "🍱",
  boom = "💥",
  bricks = "🧱",
  bug = "🐛",
  building_construction = "🏗️",
  bulb = "💡",
  busts_in_silhouette = "👥",
  camera_flash = "📸",
  card_file_box = "🗃️",
  chart_with_upwards_trend = "📈",
  children_crossing = "🚸",
  clown_face = "🤡",
  closed_lock_with_key = "🔐",
  coffin = "⚰️",
  construction = "🚧",
  construction_worker = "👷",
  dizzy = "💫",
  egg = "🥚",
  fire = "🔥",
  globe_with_meridians = "🌐",
  goal_net = "🥅",
  green_heart = "💚",
  hammer = "🔨",
  heavy_minus_sign = "➖",
  heavy_plus_sign = "➕",
  iphone = "📱",
  label = "🏷️",
  lipstick = "💄",
  lock = "🔒️",
  loud_sound = "🔊",
  mag = "🔍️",
  memo = "📝",
  monocle_face = "🧐",
  money_with_wings = "💸",
  mute = "🔇",
  necktie = "👔",
  package = "📦️",
  page_facing_up = "📄",
  passport_control = "🛂",
  pencil2 = "✏️",
  poop = "💩",
  pushpin = "📌",
  recycle = "♻️",
  rewind = "⏪️",
  rocket = "🚀",
  rotating_light = "🚨",
  safety_vest = "🦺",
  seedling = "🌱",
  see_no_evil = "🙈",
  sparkles = "✨",
  speech_balloon = "💬",
  stethoscope = "🩺",
  tada = "🎉",
  technologist = "🧑‍💻",
  test_tube = "🧪",
  thread = "🧵",
  triangular_flag_on_post = "🚩",
  truck = "🚚",
  twisted_rightwards_arrows = "🔀",
  wastebasket = "🗑️",
  wheelchair = "♿️",
  white_check_mark = "✅",
  wrench = "🔧",
  zap = "⚡️",
} ---@type table<string, string>

---Match lazygit's default two-column author representation.
---@param author                         string
---@return string
function M.short_author(author)
  local words = {} ---@type string[]
  for word in author:gmatch("%S+") do
    words[#words + 1] = word
  end
  if #words == 0 then
    return ""
  end

  local first = vim.fn.strcharpart(words[1], 0, 1) ---@type string
  if vim.fn.strdisplaywidth(first) > 1 then
    return first
  end
  if #words == 1 then
    return vim.fn.strcharpart(words[1], 0, 2)
  end
  return first .. vim.fn.strcharpart(words[2], 0, 1)
end

---Render known gitmoji shortcodes and preserve unknown application-specific codes.
---@param message                        string
---@return string
function M.render_gitmoji(message)
  return (message:gsub(":([%w_+-]+):", function(name)
    return GITMOJI[name] or (":" .. name .. ":")
  end))
end

return M
