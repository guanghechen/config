local items = {
  "lua/fml/collection/batch_disposable.lua",
  "lua/fml/collection/batch_handler.lua",
  "lua/fml/collection/circular_queue.lua",
  "lua/fml/collection/disposable.lua",
  "lua/fml/collection/history.lua",
  "lua/fml/collection/observable.lua",
  "lua/fml/collection/subscriber.lua",
  "lua/fml/collection/subscribers.lua",
  "lua/fml/collection/ticker.lua",
  "lua/fml/constant.lua",
}

local matches = {} ---@type fml.types.ui.select.ILineMatch[]
local input = "observable" ---@type string
local N1 = #input ---@type integer
for lnum, text in ipairs(items) do
  local l = 1 ---@type integer
  local r = N1 ---@type integer
  local score = 0 ---@type integer
  local pieces = {} ---@type fml.types.ui.select.ILineMatchPiece[]
  local N2 = #text ---@type integer
  while r <= N2 do
    if string.sub(text, l, r) == input then
      table.insert(pieces, { l = l, r = r })
      score = score + 10
      l = r + 1
      r = r + N1
    else
      l = l + 1
      r = r + 1
    end
  end
  if #pieces > 0 then
    table.insert(matches, { lnum = lnum, score = score, pieces = pieces })
  end
end
fml.debug.log({ matches = matches })
