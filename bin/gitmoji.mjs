#!/usr/bin/env node

const GITMOJI_MAP = {
  ':art:': '🎨',
  ':zap:': '⚡️',
  ':fire:': '🔥',
  ':bug:': '🐛',
  ':ambulance:': '🚑️',
  ':sparkles:': '✨',
  ':memo:': '📝',
  ':rocket:': '🚀',
  ':lipstick:': '💄',
  ':tada:': '🎉',
  ':white_check_mark:': '✅',
  ':lock:': '🔒️',
  ':closed_lock_with_key:': '🔐',
  ':bookmark:': '🔖',
  ':rotating_light:': '🚨',
  ':construction:': '🚧',
  ':green_heart:': '💚',
  ':arrow_down:': '⬇️',
  ':arrow_up:': '⬆️',
  ':pushpin:': '📌',
  ':construction_worker:': '👷',
  ':chart_with_upwards_trend:': '📈',
  ':recycle:': '♻️',
  ':heavy_plus_sign:': '➕',
  ':heavy_minus_sign:': '➖',
  ':wrench:': '🔧',
  ':hammer:': '🔨',
  ':globe_with_meridians:': '🌐',
  ':pencil2:': '✏️',
  ':poop:': '💩',
  ':rewind:': '⏪️',
  ':twisted_rightwards_arrows:': '🔀',
  ':package:': '📦️',
  ':alien:': '👽️',
  ':truck:': '🚚',
  ':page_facing_up:': '📄',
  ':boom:': '💥',
  ':bento:': '🍱',
  ':wheelchair:': '♿️',
  ':bulb:': '💡',
  ':beers:': '🍻',
  ':speech_balloon:': '💬',
  ':card_file_box:': '🗃️',
  ':loud_sound:': '🔊',
  ':mute:': '🔇',
  ':busts_in_silhouette:': '👥',
  ':children_crossing:': '🚸',
  ':building_construction:': '🏗️',
  ':iphone:': '📱',
  ':clown_face:': '🤡',
  ':egg:': '🥚',
  ':see_no_evil:': '🙈',
  ':camera_flash:': '📸',
  ':alembic:': '⚗️',
  ':mag:': '🔍️',
  ':label:': '🏷️',
  ':seedling:': '🌱',
  ':triangular_flag_on_post:': '🚩',
  ':goal_net:': '🥅',
  ':dizzy:': '💫',
  ':wastebasket:': '🗑️',
  ':passport_control:': '🛂',
  ':adhesive_bandage:': '🩹',
  ':monocle_face:': '🧐',
  ':coffin:': '⚰️',
  ':test_tube:': '🧪',
  ':necktie:': '👔',
  ':stethoscope:': '🩺',
  ':bricks:': '🧱',
  ':technologist:': '🧑‍💻',
  ':money_with_wings:': '💸',
  ':thread:': '🧵',
  ':safety_vest:': '🦺',
}

const GITMOJI_REGEX = new RegExp(
  Object.keys(GITMOJI_MAP)
    .map(k => k.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'))
    .join('|'),
  'g',
)

async function main() {
  const chunks = []
  for await (const chunk of process.stdin) {
    chunks.push(chunk)
  }
  const input = Buffer.concat(chunks).toString('utf8')
  const output = input.replace(GITMOJI_REGEX, match => GITMOJI_MAP[match] || match)
  process.stdout.write(output)
}

await main()
