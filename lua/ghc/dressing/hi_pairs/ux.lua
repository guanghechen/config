local constant = require("eve.lib.constant")
local ft = require("eve.lib.filetype")

---@class ghc.dressing.hi_pairs.config
local config = {
  DELAY = 50, ---How much (in milliseconds) should the cursor stay still to calculate and render a pair.
  SEARCH_WINDOW_HEIGHT = vim.o.lines, ---How many lines to look backwards/forwards to find a pair.
  enabled_modes = {
    i = true,
    n = true,
  },
  nsnr = vim.api.nvim_create_namespace("ghc.dressing.hi_pairs.namespace"),
  all_pairs = {
    { "(", ")" },
    { "[", "]" },
    { "{", "}" },
    { "<", ">" },
    { "`", "`" },
    { "'", "'" },
    { '"', '"' },
  },
  left_to_right_pairs = {},
  right_to_left_pairs = {},
  nested = 1,
  hlgroups = {
    "f_hi_pairs_1",
    "f_hi_pairs_2",
    "f_hi_pairs_3",
    "f_hi_pairs_4",
    "f_hi_pairs_5",
    "f_hi_pairs_6",
    "f_hi_pairs_7",
  },
}

do
  local left_to_right_pairs = config.left_to_right_pairs ---@type table<string, string>
  local right_to_left_pairs = config.right_to_left_pairs ---@type table<string, string>
  for _, pair in ipairs(config.all_pairs) do
    left_to_right_pairs[pair[1]] = pair[2]
    right_to_left_pairs[pair[2]] = pair[1]
  end
end

---@class ghc.dressing.hi_pairs.IPos
---@field public row                    integer
---@field public col                    integer

---@class ghc.dressing.hi_pairs.IPair
---@field public left                   ghc.dressing.hi_pairs.IPos
---@field public right                  ghc.dressing.hi_pairs.IPos

---@param bufnr                         integer
---@param row                    integer
---@param col                    integer
---@return ghc.dressing.hi_pairs.IPair[]
local function find_sorrounds(bufnr, row, col)
  local ok_parser, parser = pcall(vim.treesitter.get_parser, bufnr)
  if not ok_parser or not parser then
    return {}
  end

  local tree = parser:parse()[1]
  if not tree then
    return {}
  end

  local root = tree:root()
  if not root then
    return {}
  end

  local top = math.max(1, row - vim.o.lines) ---@type integer
  local bot = math.min(vim.api.nvim_buf_line_count(bufnr), row + vim.o.lines) ---@type integer
  local surrounds = {} ---@type ghc.dressing.hi_pairs.IPair[]

  local function find_node(node)
    for child in node:iter_children() do
      local start_row, start_col, end_row, end_col = child:range()
      if start_row > row or start_row == row and start_col > col then
        break
      end

      if end_row > row or (end_row == row and end_col > col and (start_row < end_row or start_col + 1 < end_col)) then
        find_node(child)

        if #surrounds < config.nested and (start_row + 1 >= top or end_row + 1 <= bot) then
          local start_line = vim.api.nvim_buf_get_lines(bufnr, start_row, start_row + 1, false)[1] ---@type string|nil
          local end_line = vim.api.nvim_buf_get_lines(bufnr, end_row, end_row + 1, false)[1] ---@type string|nil
          if start_line ~= nil and end_line ~= nil and start_col < #start_line and end_col <= #end_line then
            local left_char = start_line:sub(start_col + 1, start_col + 1) ---@type string
            local right_char = end_line:sub(end_col, end_col) ---@type string
            local left_delimiter = config.right_to_left_pairs[right_char] ---@type string
            local right_delimiter = config.left_to_right_pairs[left_char] ---@type string

            if left_char == left_delimiter and right_char == right_delimiter then
              local left = { row = start_row + 1, col = start_col + 1 } ---@type ghc.dressing.hi_pairs.IPos
              local right = { row = end_row + 1, col = end_col } ---@type ghc.dressing.hi_pairs.IPos
              if #surrounds < 1 then
                surrounds[#surrounds + 1] = { left = left, right = right }
              else
                local last_pair = surrounds[#surrounds] ---@type ghc.dressing.hi_pairs.IPair
                if
                  (last_pair.left.row ~= left.row or last_pair.left.col ~= left.col)
                  and (last_pair.right.row ~= right.row or last_pair.right.col ~= right.col)
                then
                  surrounds[#surrounds + 1] = { left = left, right = right }
                end
              end
            end
          end
        end

        break
      end
    end
  end

  find_node(root)
  return surrounds
end

---@class ghc.dressing.hi_pairs.ux
local M = {}

---Clear `Pair` highlights.
---
---@param bufnr                         integer
---@return nil
function M.clear(bufnr)
  local viewport = vim.b[bufnr].hi_pairs_viewport
  if viewport ~= nil then
    local top = math.max(0, viewport.top - 1) ---@type integer
    local bot = math.min(vim.api.nvim_buf_line_count(bufnr), viewport.bot)
    vim.api.nvim_buf_clear_namespace(bufnr, config.nsnr, top, bot)
    vim.b[bufnr].hi_pairs_viewport = nil
  end
end

---Calculate and draw the found `Pair`.
---
---@async
---@param winnr                         integer Window to be rendered inside.
---@return uv.uv_timer_t|nil
function M.render(winnr)
  if not vim.api.nvim_win_is_valid(winnr) then
    return
  end

  local snapshot_bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local snapshot_curosr = vim.api.nvim_win_get_cursor(winnr) ---@type integer[]

  local hi_pairs_rendering_tick = (vim.b[snapshot_bufnr].hi_pairs_rendering_tick or 0) + 1 ---@type integer
  vim.b[snapshot_bufnr].hi_pairs_rendering_tick = hi_pairs_rendering_tick

  return vim.defer_fn(function()
    if not vim.api.nvim_win_is_valid(winnr) then
      return
    end

    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    if bufnr ~= snapshot_bufnr then
      return
    end

    local rendering_tick = (vim.b[bufnr].hi_pairs_rendering_tick or 0) ---@type integer
    if rendering_tick ~= hi_pairs_rendering_tick then
      return
    end

    local cursor = vim.api.nvim_win_get_cursor(winnr) ---@type integer[]
    if cursor[1] ~= snapshot_curosr[1] or cursor[2] ~= snapshot_curosr[2] then
      return
    end

    if not config.enabled_modes[vim.fn.mode()] then
      return
    end

    local filetype = vim.bo[bufnr].filetype
    if filetype == constant.FT_BIGFILE or not ft.is_plain_file(filetype) then
      return
    end

    M.clear(bufnr)

    local surrounds = find_sorrounds(bufnr, cursor[1] - 1, cursor[2]) ---@type ghc.dressing.hi_pairs.IPair[]
    if #surrounds > 0 then
      local outerest_surround = surrounds[#surrounds] ---@type ghc.dressing.hi_pairs.IPair
      vim.b[bufnr].hi_pairs_viewport = {
        top = outerest_surround.left.row,
        bot = outerest_surround.right.row,
      }

      for index, pair in ipairs(surrounds) do
        local left = pair.left ---@type ghc.dressing.hi_pairs.IPos
        local right = pair.right ---@type ghc.dressing.hi_pairs.IPos
        local hlgroup = config.hlgroups[index] ---@type string
        vim.api.nvim_buf_add_highlight( --
          bufnr,
          config.nsnr,
          hlgroup or "MatchParen",
          left.row - 1,
          left.col - 1,
          left.col
        )
        vim.api.nvim_buf_add_highlight(
          bufnr,
          config.nsnr,
          hlgroup or "MatchParen",
          right.row - 1,
          right.col - 1,
          right.col
        )
      end
    end
  end, config.DELAY)
end

return M
