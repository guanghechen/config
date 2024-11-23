---@type string[][]
local all_pairs = {
  { "(", ")" },
  { "[", "]" },
  { "{", "}" },
  { "<", ">" },
}

local left_to_right_pairs = {} ---@type table<string, string>
local right_to_left_pairs = {} ---@type table<string, string>
for _, pair in ipairs(all_pairs) do
  left_to_right_pairs[pair[1]] = pair[2]
  right_to_left_pairs[pair[2]] = pair[1]
end

---@class ghc.dressing.autopairs.config
local config = {
  VARIABLE_VIEWPORT = "ghc.dressing.autopairs.viewport",
  NAMESPACE_PAIR = "ghc.dressing.autopairs.pair",
  DELAY = 50, ---How much (in milliseconds) should the cursor stay still to calculate and render a pair.
  SEARCH_WINDOW_HALF_HEIGHT = 100, ---How many lines to look backwards/forwards to find a pair.
  enabled_modes = {
    i = true,
    n = true,
  },
  left_to_right_pairs = left_to_right_pairs,
  right_to_left_pairs = right_to_left_pairs,
}

return config
