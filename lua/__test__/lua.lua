local items = fml.oxi.collect_file_paths(fml.path.cwd(), { ".git/" })

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
